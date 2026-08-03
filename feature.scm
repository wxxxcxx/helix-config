(require-builtin steel/time)
(require (only-in "package.scm" package-install-all!))

(provide feature
         feature-initialize!
         feature-initialize-elapsed-milliseconds
         feature-failures
         feature-profile
         feature-profiles
         feature-report-failures!
         feature-reset-failures!
         feature-status)

(define *feature-failures* '())
(define *feature-definitions* (hash))
(define *feature-order* '())
(define *feature-stack* '())
(define *feature-statuses* (hash))
(define *feature-profiles* (hash))
(define *feature-initialize-start* #f)
(define *feature-root* (parent-name (current-module)))
(define *feature-path-separator* (path-separator))

(define (feature-error-message name phase err)
  (string-append "feature "
                 (symbol->string name)
                 " "
                 (symbol->string phase)
                 " failed: "
                 (error-object-message err)))

(define (feature-record-message! name phase message)
  (set! *feature-failures*
        (cons (hash 'name name 'phase phase 'message message)
              *feature-failures*))
  (displayln message)
  #f)

(define (feature-record-failure! name phase err)
  (feature-record-message! name phase
                           (feature-error-message name phase err)))

(define (feature-protect name phase thunk)
  (with-handler
    (lambda (err) (feature-record-failure! name phase err))
    (begin (thunk) #t)))

(define (feature-resolve-path path)
  ;; Windows module paths can use the verbatim `\\?\` prefix, where forward
  ;; slashes are not accepted. Feature declarations stay portable with `/`.
  (canonicalize-path
    (string-append *feature-root*
                   *feature-path-separator*
                   (string-replace path "/" *feature-path-separator*))))

(define (feature-load! path)
  ;; Evaluate require dynamically so failures remain catchable while Steel's
  ;; module boundary exposes only identifiers explicitly listed by `provide`.
  (eval `(require ,(feature-resolve-path path))))

(define (feature-configure! forms)
  (eval forms))

(define (feature-status name)
  (if (hash-contains? *feature-statuses* name)
      (hash-get *feature-statuses* name)
      'missing))

(define (feature-set-status! name status)
  (set! *feature-statuses*
        (hash-insert *feature-statuses* name status)))

(define (feature-empty-profile name)
  (hash 'name name 'package-ms 0 'load-ms 0 'config-ms 0 'total-ms 0))

(define (feature-profile name)
  (hash-try-get *feature-profiles* name))

(define (feature-profiles)
  (sort
    (map feature-profile (reverse *feature-order*))
    (lambda (left right)
      (> (hash-get left 'total-ms) (hash-get right 'total-ms)))))

(define (feature-record-elapsed! name phase elapsed-ms)
  (define profile
    (or (feature-profile name) (feature-empty-profile name)))
  (define elapsed-key
    (cond [(equal? phase 'package) 'package-ms]
          [(equal? phase 'load) 'load-ms]
          [else 'config-ms]))
  (define with-phase (hash-insert profile elapsed-key elapsed-ms))
  (define updated
    (hash-insert with-phase
                 'total-ms
                 (+ (hash-get with-phase 'package-ms)
                    (hash-get with-phase 'load-ms)
                    (hash-get with-phase 'config-ms))))
  (set! *feature-profiles*
        (hash-insert *feature-profiles* name updated)))

(define (feature-register! name dependencies packages path config-thunk)
  (if (hash-contains? *feature-definitions* name)
      (begin
        (feature-set-status! name 'failed)
        (feature-record-message!
          name
          'definition
          (string-append "feature "
                         (symbol->string name)
                         " definition failed: duplicate declaration")))
      (begin
        (set! *feature-profiles*
              (hash-insert *feature-profiles*
                           name
                           (feature-empty-profile name)))
        (set! *feature-definitions*
              (hash-insert
                *feature-definitions*
                name
                (hash-insert
                  (hash 'name name
                        'dependencies dependencies
                        'path path
                        'config config-thunk)
                  'packages
                  packages)))
        (set! *feature-order* (cons name *feature-order*))
        (feature-set-status! name 'pending)
        #t)))

(define (feature-dependency-label dependency)
  (string-append (symbol->string dependency)
                 " ("
                 (symbol->string (feature-status dependency))
                 ")"))

(define (feature-join labels)
  (cond [(null? labels) ""]
        [(null? (cdr labels)) (car labels)]
        [else (string-append (car labels) ", " (feature-join (cdr labels)))]))

(define (feature-dependencies-ready? name dependencies)
  (define unavailable
    (filter (lambda (dependency)
              (not (equal? (feature-status dependency) 'ready)))
            dependencies))
  (if (null? unavailable)
      #t
      (feature-record-message!
        name
        'dependency
        (string-append "feature "
                       (symbol->string name)
                       " dependency failed: "
                       (feature-join
                         (map feature-dependency-label unavailable))))))

(define (feature-run-phase! name phase thunk)
  (define started-at (instant/now))
  (define succeeded? (feature-protect name phase thunk))
  (feature-record-elapsed!
    name phase (duration->millis (instant/elapsed started-at)))
  succeeded?)

(define (feature-run! name dependencies package-thunk load-thunk config-thunk)
  (if (not (feature-dependencies-ready? name dependencies))
      (begin
        (feature-set-status! name 'skipped)
        #f)
      (begin
        (feature-set-status! name 'installing)
        (if (not (feature-run-phase! name 'package package-thunk))
            (begin
              (feature-set-status! name 'failed)
              #f)
            (begin
              (feature-set-status! name 'loading)
              (if (not (feature-run-phase! name 'load load-thunk))
                  (begin
                    (feature-set-status! name 'failed)
                    #f)
                  (begin
                    (feature-set-status! name 'loaded)
                    (if (feature-run-phase! name 'config config-thunk)
                        (begin
                          (feature-set-status! name 'ready)
                          #t)
                        (begin
                          (feature-set-status! name 'failed)
                          #f)))))))))

(define (feature-run-definition! definition)
  (feature-run!
    (hash-get definition 'name)
    (hash-get definition 'dependencies)
    (lambda ()
      (package-install-all! (hash-get definition 'packages)))
    (lambda ()
      ;; Dynamic require crosses the load handler instead of aborting startup,
      ;; while preserving the feature module's `provide` boundary.
      (feature-load! (hash-get definition 'path)))
    (hash-get definition 'config)))

(define (feature-finished? status)
  (or (equal? status 'ready)
      (equal? status 'failed)
      (equal? status 'skipped)))

(define (feature-record-cycle! name)
  (feature-set-status! name 'skipped)
  (feature-record-message!
    name
    'dependency
    (string-append "feature "
                   (symbol->string name)
                   " dependency failed: cyclic dependency")))

(define (feature-initialize-one! name)
  (define status (feature-status name))
  (cond [(equal? status 'ready) #t]
        [(feature-finished? status) #f]
        [(not (hash-contains? *feature-definitions* name)) #f]
        [(member name *feature-stack*) (feature-record-cycle! name)]
        [else
         (let ([definition (hash-get *feature-definitions* name)])
           (set! *feature-stack* (cons name *feature-stack*))
           (for-each
             (lambda (dependency)
               (when (hash-contains? *feature-definitions* dependency)
                 (feature-initialize-one! dependency)))
             (hash-get definition 'dependencies))
           (set! *feature-stack* (cdr *feature-stack*))
           (let ([status-after-dependencies (feature-status name)])
             (if (feature-finished? status-after-dependencies)
                 (equal? status-after-dependencies 'ready)
                 (feature-run-definition! definition))))]))

(define (feature-initialize-elapsed-milliseconds)
  (and *feature-initialize-start*
       (duration->millis (instant/elapsed *feature-initialize-start*))))

(define (feature-initialize!)
  (set! *feature-initialize-start* (instant/now))
  (for-each feature-initialize-one! (reverse *feature-order*)))

(define (feature-failures)
  (reverse *feature-failures*))

(define (feature-report-failures! reporter)
  (unless (null? *feature-failures*)
    (reporter
      (string-append "Configuration skipped "
                     (number->string (length *feature-failures*))
                     " feature(s); see the Helix log."))))

(define (feature-reset-failures!)
  (set! *feature-failures* '())
  (set! *feature-definitions* (hash))
  (set! *feature-order* '())
  (set! *feature-stack* '())
  (set! *feature-initialize-start* #f)
  (set! *feature-statuses* (hash))
  (set! *feature-profiles* (hash)))

;; Usage:
;; (feature example
;;   (:depends foundation)
;;   (:package (package #:name "example"
;;                     #:url "https://example.com/example.git"
;;                     #:tag "v1.0.0"))
;;   (:load "features/example/example.scm")
;;   (:config (example-init)))
;;
;; `feature` records declarations only. Call `feature-initialize!` after
;; all declarations; dependencies may appear later but must reach `ready`.
;; Missing or failed dependencies skip this feature before its file is loaded.
;;
;; This isolates control flow, not state: effects completed before an exception
;; cannot be rolled back. Required files must therefore keep their top level pure.
(define-syntax feature
  (syntax-rules (:depends :package :load :config)
    [(_ name
        (:depends dependency ...)
        (:package package-spec ...)
        (:load path)
        (:config form ...))
     (feature-register!
       'name
       '(dependency ...)
       (list package-spec ...)
       path
       (lambda () (feature-configure! '(begin form ...))))]
    [(_ name (:depends dependency ...) (:package package-spec ...) (:load path))
     (feature name
              (:depends dependency ...)
              (:package package-spec ...)
              (:load path)
              (:config))]
    [(_ name (:depends dependency ...) (:load path) (:config form ...))
     (feature name
              (:depends dependency ...)
              (:package)
              (:load path)
              (:config form ...))]
    [(_ name (:depends dependency ...) (:load path))
     (feature name
              (:depends dependency ...)
              (:package)
              (:load path)
              (:config))]
    [(_ name (:package package-spec ...) (:load path) (:config form ...))
     (feature name
              (:depends)
              (:package package-spec ...)
              (:load path)
              (:config form ...))]
    [(_ name (:package package-spec ...) (:load path))
     (feature name
              (:depends)
              (:package package-spec ...)
              (:load path)
              (:config))]
    [(_ name (:load path) (:config form ...))
     (feature name
              (:depends)
              (:package)
              (:load path)
              (:config form ...))]
    [(_ name (:load path))
     (feature name (:load path) (:config))]))
