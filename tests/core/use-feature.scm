(require (only-in "../../use-feature.scm"
                  use-feature
                  use-feature-initialize!
                  use-feature-failures
                  use-feature-report-failures!
                  use-feature-reset-failures!
                  use-feature-status))

(define (assert-equal actual expected message)
  (unless (equal? actual expected)
    (error (string-append message
                          ": expected " (to-string expected)
                          ", got " (to-string actual)))))

(use-feature dependent
  (:depends good)
  (:load "tests/fixtures/use-feature/good.scm")
  (:config
    (unless (= (fixture-value) 42)
      (error "ready dependency was not available"))))

(use-feature blocked-failed
  (:depends bad-runtime)
  (:load "tests/fixtures/use-feature/good.scm")
  (:config (error "dependent config must not run")))

(use-feature good
  (:load "tests/fixtures/use-feature/good.scm")
  (:config
    (fixture-init)
    (unless (= (fixture-value) 42)
      (error "successful feature did not initialize"))))

(use-feature bad-syntax
  (:load "tests/fixtures/use-feature/bad-syntax.scm")
  (:config (malformed-init)))
(use-feature bad-runtime
  (:load "tests/fixtures/use-feature/bad-runtime.scm")
  (:config (broken-init)))
(use-feature missing
  (:load "tests/fixtures/use-feature/missing.scm"))
(use-feature blocked-missing
  (:depends never-declared)
  ;; This path must never be loaded because dependency checks run first.
  (:load "tests/fixtures/use-feature/missing.scm"))
(use-feature after-failure
  (:load "tests/fixtures/use-feature/good.scm")
  (:config
    (fixture-init)
    (unless (= (fixture-value) 42)
      (error "feature after failures did not initialize"))))

(assert-equal (use-feature-status 'dependent) 'pending
              "registered feature waits for final initialization")
(assert-equal (use-feature-status 'good) 'pending
              "late dependency waits for final initialization")

(use-feature-initialize!)

(assert-equal
  (with-handler (lambda (_) 'not-visible)
    (eval '*fixture-private-value*))
  'not-visible
  "unprovided feature bindings remain private")
(assert-equal (use-feature-status 'good) 'ready "successful feature is ready")
(assert-equal (use-feature-status 'dependent) 'ready
              "feature with later ready dependency initializes")
(assert-equal (use-feature-status 'bad-runtime) 'failed
              "config failure marks feature failed")
(assert-equal (use-feature-status 'blocked-missing) 'skipped
              "missing dependency skips feature")
(assert-equal (use-feature-status 'blocked-failed) 'skipped
              "failed dependency skips feature")
(assert-equal (use-feature-status 'after-failure) 'ready
              "independent feature after failures is ready")
(assert-equal (length (use-feature-failures)) 5 "failures are isolated")
(define *reported-message* #f)
(use-feature-report-failures! (lambda (message) (set! *reported-message* message)))
(assert-equal *reported-message*
              "Configuration skipped 5 feature(s); see the Helix log."
              "failure summary is reported")
(use-feature-reset-failures!)
(assert-equal (use-feature-status 'good) 'missing "reset clears feature statuses")
