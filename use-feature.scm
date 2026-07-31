(provide use-feature
         use-feature-failures
         use-feature-report-failures!
         use-feature-reset-failures!
         use-feature-status)

(define *use-feature-failures* '())
(define *use-feature-statuses* (hash))
(define *use-feature-root* (parent-name (current-module)))

(define (use-feature-error-message name phase err)
  (string-append "feature "
                 (symbol->string name)
                 " "
                 (symbol->string phase)
                 " failed: "
                 (error-object-message err)))

(define (use-feature-record-message! name phase message)
  (set! *use-feature-failures*
        (cons (hash 'name name 'phase phase 'message message)
              *use-feature-failures*))
  (displayln message)
  #f)

(define (use-feature-record-failure! name phase err)
  (use-feature-record-message! name phase
                               (use-feature-error-message name phase err)))

(define (use-feature-protect name phase thunk)
  (with-handler
    (lambda (err) (use-feature-record-failure! name phase err))
    (begin (thunk) #t)))

(define (use-feature-resolve-path path)
  (canonicalize-path (string-append *use-feature-root* "/" path)))

(define (use-feature-load! path)
  ;; Evaluate require dynamically so failures remain catchable while Steel's
  ;; module boundary exposes only identifiers explicitly listed by `provide`.
  (eval `(require ,(use-feature-resolve-path path))))

(define (use-feature-configure! forms)
  (eval forms))

(define (use-feature-status name)
  (if (hash-contains? *use-feature-statuses* name)
      (hash-get *use-feature-statuses* name)
      'missing))

(define (use-feature-set-status! name status)
  (set! *use-feature-statuses*
        (hash-insert *use-feature-statuses* name status)))

(define (use-feature-dependency-label dependency)
  (string-append (symbol->string dependency)
                 " ("
                 (symbol->string (use-feature-status dependency))
                 ")"))

(define (use-feature-join labels)
  (cond [(null? labels) ""]
        [(null? (cdr labels)) (car labels)]
        [else (string-append (car labels) ", " (use-feature-join (cdr labels)))]))

(define (use-feature-dependencies-ready? name dependencies)
  (define unavailable
    (filter (lambda (dependency)
              (not (equal? (use-feature-status dependency) 'ready)))
            dependencies))
  (if (null? unavailable)
      #t
      (use-feature-record-message!
        name
        'dependency
        (string-append "feature "
                       (symbol->string name)
                       " dependency failed: "
                       (use-feature-join
                         (map use-feature-dependency-label unavailable))))))

(define (use-feature-run! name dependencies load-thunk config-thunk)
  (if (not (use-feature-dependencies-ready? name dependencies))
      (begin
        (use-feature-set-status! name 'skipped)
        #f)
      (begin
        (use-feature-set-status! name 'loading)
        (if (not (use-feature-protect name 'load load-thunk))
            (begin
              (use-feature-set-status! name 'failed)
              #f)
            (begin
              (use-feature-set-status! name 'loaded)
              (if (use-feature-protect name 'config config-thunk)
                  (begin
                    (use-feature-set-status! name 'ready)
                    #t)
                  (begin
                    (use-feature-set-status! name 'failed)
                    #f)))))))

(define (use-feature-failures)
  (reverse *use-feature-failures*))

(define (use-feature-report-failures! reporter)
  (unless (null? *use-feature-failures*)
    (reporter
      (string-append "Configuration skipped "
                     (number->string (length *use-feature-failures*))
                     " feature(s); see the Helix log."))))

(define (use-feature-reset-failures!)
  (set! *use-feature-failures* '())
  (set! *use-feature-statuses* (hash)))

;; Usage:
;; (use-feature example
;;   (:depends foundation)
;;   (:load "features/example/example.scm")
;;   (:config (example-init)))
;;
;; Dependencies must appear earlier and reach `ready`; missing or failed
;; dependencies skip this feature before its file is loaded.
;;
;; This isolates control flow, not state: effects completed before an exception
;; cannot be rolled back. Required files must therefore keep their top level pure.
(define-syntax use-feature
  (syntax-rules (:depends :load :config)
    [(_ name (:depends dependency ...) (:load path) (:config form ...))
     (use-feature-run!
       'name
       '(dependency ...)
       (lambda ()
         ;; Dynamic require crosses the load handler instead of aborting startup,
         ;; while preserving the feature module's `provide` boundary.
         (use-feature-load! path))
       (lambda () (use-feature-configure! '(begin form ...))))]
    [(_ name (:depends dependency ...) (:load path))
     (use-feature name (:depends dependency ...) (:load path) (:config))]
    [(_ name (:load path) (:config form ...))
     (use-feature name (:depends) (:load path) (:config form ...))]
    [(_ name (:load path))
     (use-feature name (:load path) (:config))]))
