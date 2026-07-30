(require "cogs/file-manager/core/collections.scm")

(define (assert-equal! expected actual)
  (unless (equal? expected actual)
    (error! (string-append "expected " (to-string expected)
                           ", got " (to-string actual)))))

(assert-equal! #t (fm-member? "/a" '("/b" "/a")))
(assert-equal! #t (fm-member? 'modified '(added modified)))
(assert-equal! #f (fm-member? "/missing" '("/b" "/a")))
(assert-equal! '("/a" "/b") (fm-add-unique "/a" '("/b")))
(assert-equal! '("/a" "/b") (fm-add-unique "/a" '("/a" "/b")))
