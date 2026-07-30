(provide use-feature
         use-feature-failures
         use-feature-report-failures!
         use-feature-reset-failures!)

(define *use-feature-failures* '())
(define *use-feature-root* (parent-name (current-module)))

(define (use-feature-error-message name phase err)
  (string-append "feature "
                 (symbol->string name)
                 " "
                 (symbol->string phase)
                 " failed: "
                 (error-object-message err)))

(define (use-feature-record-failure! name phase err)
  (define message (use-feature-error-message name phase err))
  (set! *use-feature-failures*
        (cons (hash 'name name 'phase phase 'message message)
              *use-feature-failures*))
  (displayln message)
  #f)

(define (use-feature-protect name phase thunk)
  (with-handler
    (lambda (err) (use-feature-record-failure! name phase err))
    (begin (thunk) #t)))

(define (use-feature-resolve-path path)
  (canonicalize-path (string-append *use-feature-root* "/" path)))

(define (use-feature-load! path)
  (load (use-feature-resolve-path path)))

(define (use-feature-configure! forms)
  (eval forms))

(define (use-feature-failures)
  (reverse *use-feature-failures*))

(define (use-feature-report-failures! reporter)
  (unless (null? *use-feature-failures*)
    (reporter
      (string-append "Configuration skipped "
                     (number->string (length *use-feature-failures*))
                     " feature(s); see the Helix log."))))

(define (use-feature-reset-failures!)
  (set! *use-feature-failures* '()))

;; Usage:
;; (use-feature example
;;   (:load "cogs/example.scm")
;;   (:config (example-init)))
;;
;; This isolates control flow, not state: effects completed before an exception
;; cannot be rolled back. Loaded files must therefore keep their top level pure.
(define-syntax use-feature
  (syntax-rules (:load :config)
    [(_ name (:load path) (:config form ...))
     (when
       (use-feature-protect
         'name
         'load
         (lambda ()
           ;; `load` compiles in the active VM, so syntax and evaluation errors
           ;; cross this handler instead of aborting the remaining startup.
           (use-feature-load! path)))
       (use-feature-protect
         'name
         'config
         (lambda () (use-feature-configure! '(begin form ...)))))]
    [(_ name (:load path))
     (use-feature name (:load path) (:config))]))
