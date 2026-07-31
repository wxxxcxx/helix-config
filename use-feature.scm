(provide use-feature
         use-feature-initialize!
         use-feature-failures
         use-feature-report-failures!
         use-feature-reset-failures!
         use-feature-status)

(define *use-feature-failures* '())
(define *use-feature-definitions* (hash))
(define *use-feature-order* '())
(define *use-feature-stack* '())
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

(define (use-feature-register! name dependencies path config-thunk)
  (if (hash-contains? *use-feature-definitions* name)
      (begin
        (use-feature-set-status! name 'failed)
        (use-feature-record-message!
          name
          'definition
          (string-append "feature "
                         (symbol->string name)
                         " definition failed: duplicate declaration")))
      (begin
        (set! *use-feature-definitions*
              (hash-insert
                *use-feature-definitions*
                name
                (hash 'name name
                      'dependencies dependencies
                      'path path
                      'config config-thunk)))
        (set! *use-feature-order* (cons name *use-feature-order*))
        (use-feature-set-status! name 'pending)
        #t)))

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

(define (use-feature-run-definition! definition)
  (use-feature-run!
    (hash-get definition 'name)
    (hash-get definition 'dependencies)
    (lambda ()
      ;; Dynamic require crosses the load handler instead of aborting startup,
      ;; while preserving the feature module's `provide` boundary.
      (use-feature-load! (hash-get definition 'path)))
    (hash-get definition 'config)))

(define (use-feature-finished? status)
  (or (equal? status 'ready)
      (equal? status 'failed)
      (equal? status 'skipped)))

(define (use-feature-record-cycle! name)
  (use-feature-set-status! name 'skipped)
  (use-feature-record-message!
    name
    'dependency
    (string-append "feature "
                   (symbol->string name)
                   " dependency failed: cyclic dependency")))

(define (use-feature-initialize-one! name)
  (define status (use-feature-status name))
  (cond [(equal? status 'ready) #t]
        [(use-feature-finished? status) #f]
        [(not (hash-contains? *use-feature-definitions* name)) #f]
        [(member name *use-feature-stack*) (use-feature-record-cycle! name)]
        [else
         (let ([definition (hash-get *use-feature-definitions* name)])
           (set! *use-feature-stack* (cons name *use-feature-stack*))
           (for-each
             (lambda (dependency)
               (when (hash-contains? *use-feature-definitions* dependency)
                 (use-feature-initialize-one! dependency)))
             (hash-get definition 'dependencies))
           (set! *use-feature-stack* (cdr *use-feature-stack*))
           (let ([status-after-dependencies (use-feature-status name)])
             (if (use-feature-finished? status-after-dependencies)
                 (equal? status-after-dependencies 'ready)
                 (use-feature-run-definition! definition))))]))

(define (use-feature-initialize!)
  (for-each use-feature-initialize-one! (reverse *use-feature-order*)))

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
  (set! *use-feature-definitions* (hash))
  (set! *use-feature-order* '())
  (set! *use-feature-stack* '())
  (set! *use-feature-statuses* (hash)))

;; Usage:
;; (use-feature example
;;   (:depends foundation)
;;   (:load "features/example/example.scm")
;;   (:config (example-init)))
;;
;; `use-feature` records declarations only. Call `use-feature-initialize!` after
;; all declarations; dependencies may appear later but must reach `ready`.
;; Missing or failed dependencies skip this feature before its file is loaded.
;;
;; This isolates control flow, not state: effects completed before an exception
;; cannot be rolled back. Required files must therefore keep their top level pure.
(define-syntax use-feature
  (syntax-rules (:depends :load :config)
    [(_ name (:depends dependency ...) (:load path) (:config form ...))
     (use-feature-register!
       'name
       '(dependency ...)
       path
       (lambda () (use-feature-configure! '(begin form ...))))]
    [(_ name (:depends dependency ...) (:load path))
     (use-feature name (:depends dependency ...) (:load path) (:config))]
    [(_ name (:load path) (:config form ...))
     (use-feature name (:depends) (:load path) (:config form ...))]
    [(_ name (:load path))
     (use-feature name (:load path) (:config))]))
