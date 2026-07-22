;; cogs/indicators/register.scm

(require "helix/components.scm")
(require "helix/editor.scm")
(require "cogs/indicators/core.scm")

(provide register-indicator)

(define (register-indicator #:style (style (lambda args (style))))
  (status-element
    (lambda (view-id focused?)
      (define s (resolve-style style view-id focused?))
      (define reg (selected-register!))
      (if (and reg (not (equal? reg #\")))
          (list
            (span " \"" s)
            (span (string reg) s)
            (span " " s))
          '()))))
