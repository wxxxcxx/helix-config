(require "../../core/path.scm")

(define (assert-equal! expected actual message)
  (unless (equal? expected actual)
    (error! (string-append message
                           ": expected " (to-string expected)
                           ", got " (to-string actual)))))

(define separator (path-separator))

(assert-equal! #t (core-path-root? separator)
               "platform root is recognized")
(assert-equal! separator (core-path-parent-or-self separator)
               "platform root is its own bounded parent")
(assert-equal! separator (core-path-ensure-trailing-separator separator)
               "root separator is not duplicated")
(assert-equal! (string-append separator "shared")
               (core-path-join separator "shared")
               "joining from root preserves the root separator")
(assert-equal! "file.scm"
               (core-path-base-name
                 (string-append separator "tmp" separator "file.scm"))
               "base name is platform independent")
