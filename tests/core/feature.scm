(require (only-in "../../feature.scm"
                  feature
                  feature-initialize!
                  feature-initialize-elapsed-milliseconds
                  feature-failures
                  feature-profile
                  feature-profiles
                  feature-report-failures!
                  feature-reset-failures!
                  feature-status))

(define (assert-equal actual expected message)
  (unless (equal? actual expected)
    (error (string-append message
                          ": expected " (to-string expected)
                          ", got " (to-string actual)))))

(define (assert-profile profile name)
  (unless (hash? profile)
    (error (string-append "missing profile for " (symbol->string name))))
  (assert-equal (hash-get profile 'name) name "profile records its feature name")
  (for-each
    (lambda (key)
      (define elapsed (hash-get profile key))
      (unless (and (integer? elapsed) (>= elapsed 0))
        (error (string-append "profile " (symbol->string key)
                              " should be a nonnegative integer"))))
    '(load-ms config-ms total-ms))
  (assert-equal (hash-get profile 'total-ms)
                (+ (hash-get profile 'load-ms) (hash-get profile 'config-ms))
                "profile total is the sum of its phases"))

(define (profiles-descending? profiles)
  (or (null? profiles)
      (null? (cdr profiles))
      (and (>= (hash-get (car profiles) 'total-ms)
               (hash-get (car (cdr profiles)) 'total-ms))
           (profiles-descending? (cdr profiles)))))

(feature dependent
  (:depends good)
  (:load "tests/fixtures/feature/good.scm")
  (:config
    (unless (= (fixture-value) 42)
      (error "ready dependency was not available"))))

(feature blocked-failed
  (:depends bad-runtime)
  (:load "tests/fixtures/feature/good.scm")
  (:config (error "dependent config must not run")))

(feature good
  (:load "tests/fixtures/feature/good.scm")
  (:config
    (fixture-init)
    (unless (= (fixture-value) 42)
      (error "successful feature did not initialize"))))

(feature bad-syntax
  (:load "tests/fixtures/feature/bad-syntax.scm")
  (:config (malformed-init)))
(feature bad-runtime
  (:load "tests/fixtures/feature/bad-runtime.scm")
  (:config (broken-init)))
(feature missing
  (:load "tests/fixtures/feature/missing.scm"))
(feature blocked-missing
  (:depends never-declared)
  ;; This path must never be loaded because dependency checks run first.
  (:load "tests/fixtures/feature/missing.scm"))
(feature after-failure
  (:load "tests/fixtures/feature/good.scm")
  (:config
    (fixture-init)
    (unless (= (fixture-value) 42)
      (error "feature after failures did not initialize"))))

(assert-equal (feature-status 'dependent) 'pending
              "registered feature waits for final initialization")
(assert-equal (feature-status 'good) 'pending
              "late dependency waits for final initialization")
(assert-equal (feature-initialize-elapsed-milliseconds) #f
              "feature timer is idle before initialization")

(feature-initialize!)

(define *initialize-elapsed-ms* (feature-initialize-elapsed-milliseconds))
(unless (integer? *initialize-elapsed-ms*)
  (error "feature initialization should record elapsed milliseconds"))
(unless (>= *initialize-elapsed-ms* 0)
  (error "feature initialization elapsed time should be nonnegative"))

(assert-equal
  (with-handler (lambda (_) 'not-visible)
    (eval '*fixture-private-value*))
  'not-visible
  "unprovided feature bindings remain private")
(assert-equal (feature-status 'good) 'ready "successful feature is ready")
(assert-equal (feature-status 'dependent) 'ready
              "feature with later ready dependency initializes")
(assert-equal (feature-status 'bad-runtime) 'failed
              "config failure marks feature failed")
(assert-equal (feature-status 'blocked-missing) 'skipped
              "missing dependency skips feature")
(assert-equal (feature-status 'blocked-failed) 'skipped
              "failed dependency skips feature")
(assert-equal (feature-status 'after-failure) 'ready
              "independent feature after failures is ready")
(for-each
  (lambda (name) (assert-profile (feature-profile name) name))
  '(dependent blocked-failed good bad-syntax bad-runtime missing
              blocked-missing after-failure))
(unless (profiles-descending? (feature-profiles))
  (error "feature profiles should be sorted by descending total time"))
(assert-equal (length (feature-failures)) 5 "failures are isolated")
(define *reported-message* #f)
(feature-report-failures! (lambda (message) (set! *reported-message* message)))
(assert-equal *reported-message*
              "Configuration skipped 5 feature(s); see the Helix log."
              "failure summary is reported")
(feature-reset-failures!)
(assert-equal (feature-status 'good) 'missing "reset clears feature statuses")
(assert-equal (feature-profile 'good) #f "reset clears feature profiles")
(assert-equal (feature-profiles) '() "reset clears the profile list")
(assert-equal (feature-initialize-elapsed-milliseconds) #f
              "reset clears feature initialization timer")
