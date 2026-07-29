(require "cogs/file-manager/core/session.scm")

(define (assert-equal! expected actual)
  (unless (equal? expected actual)
    (error! (string-append "expected " (to-string expected)
                           ", got " (to-string actual)))))

(define empty (fm-session-empty))
(define marked
  (fm-session-toggle-mark (fm-session-toggle-mark empty "/a") "/b"))
(assert-equal! '("/b" "/a") (fm-session-marked marked))

(define staged (fm-session-stage marked 'copy '("/a" "/b")))
(assert-equal! '() (fm-session-marked staged))
(assert-equal! 'copy (fm-session-mode staged))

(define completed (fm-session-complete-paths staged '("/a")))
(assert-equal! '("/b") (fm-session-clipboard completed))
(assert-equal! 'copy (fm-session-mode completed))

(define renamed (fm-session-replace-path completed "/b" "/renamed"))
(assert-equal! '("/renamed") (fm-session-clipboard renamed))

(define cleared (fm-session-complete-paths renamed '("/renamed")))
(assert-equal! '() (fm-session-clipboard cleared))
(assert-equal! #f (fm-session-mode cleared))

(define marked-with-clipboard (fm-session-toggle-mark staged "/selected"))
(define marks-cleared (fm-session-clear-marks marked-with-clipboard))
(assert-equal! '() (fm-session-marked marks-cleared))
(assert-equal! '("/a" "/b") (fm-session-clipboard marks-cleared))
