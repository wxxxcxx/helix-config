(require (only-in "../../use-feature.scm"
                  use-feature
                  use-feature-failures
                  use-feature-report-failures!
                  use-feature-reset-failures!))

(define (assert-equal actual expected message)
  (unless (equal? actual expected)
    (error (string-append message
                          ": expected " (to-string expected)
                          ", got " (to-string actual)))))

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
(use-feature after-failure
  (:load "tests/fixtures/use-feature/good.scm")
  (:config
    (fixture-init)
    (unless (= (fixture-value) 42)
      (error "feature after failures did not initialize"))))

(assert-equal (length (use-feature-failures)) 3 "failures are isolated")
(define *reported-message* #f)
(use-feature-report-failures! (lambda (message) (set! *reported-message* message)))
(assert-equal *reported-message*
              "Configuration skipped 3 feature(s); see the Helix log."
              "failure summary is reported")
(use-feature-reset-failures!)
