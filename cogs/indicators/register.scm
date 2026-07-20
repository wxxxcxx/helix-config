;; cogs/indicators/register.scm

(require "helix/components.scm")
(require "helix/editor.scm")
(require "cogs/indicators/core.scm")

(provide register-indicator)

(define (register-indicator #:fg (fg-fn (lambda () Color/Reset))
                             #:bg (bg-fn (lambda () Color/Reset)))
  (status-element
    (lambda (view-id focused?)
      (define reg (selected-register!))
      (define bg (resolve-color bg-fn))
      (define fg (resolve-color fg-fn))
      (if (and reg (not (equal? reg #\")))
          (list
            (span " \"" (named-style fg bg))
            (span (string reg) (named-style fg bg))
            (span " " (named-style fg bg)))
          '()))))
