(require (only-in "../../package.scm"
                  package
                  package-git-dependency
                  package-reference
                  package-reference-kind))

(define (assert-equal actual expected message)
  (unless (equal? actual expected)
    (error (string-append message
                          ": expected " (to-string expected)
                          ", got " (to-string actual)))))

(define (assert-error thunk message)
  (unless (with-handler (lambda (_) #t) (begin (thunk) #f))
    (error message)))

(define (test-package . references)
  (apply package
         (append (list #:name "fixture"
                       #:url "https://example.com/fixture.git")
                 references)))

(define branch-package (test-package #:branch "main"))
(assert-equal (package-reference-kind branch-package) 'branch
              "branch kind is retained")
(assert-equal (package-reference branch-package) "main"
              "branch name is retained")

(define tag-package (test-package #:tag "v1.2.3"))
(assert-equal (package-reference-kind tag-package) 'tag
              "tag kind is retained")
(assert-equal (package-reference tag-package) "v1.2.3"
              "tag name is retained")

(define commit-package (test-package #:commit "0123456789abcdef"))
(assert-equal (package-reference-kind commit-package) 'commit
              "commit kind is retained")

(define legacy-package
  (package-git-dependency
    #:name "fixture"
    #:url "https://example.com/fixture.git"
    #:revision "0123456789abcdef"))
(assert-equal (package-reference-kind legacy-package) 'commit
              "legacy revision maps to commit")

(assert-error
  (lambda () (test-package #:branch "main" #:tag "v1.2.3"))
  "branch and tag must be mutually exclusive")
(assert-error
  (lambda () (test-package #:branch ""))
  "empty branch must be rejected")
(assert-error
  (lambda ()
    (package #:name "fixture"
             #:url "https://example.com/fixture.git"
             #:verify "../outside"))
  "parent traversal in verification path must be rejected")
