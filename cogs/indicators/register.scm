;; cogs/indicators/register.scm

(require "helix/components.scm")
(require "helix/editor.scm")

(provide register-indicator)

(define (register-indicator #:style (style (lambda args (style))))
  (status-element
    (lambda (view-id focused?)
      (define s (if (procedure? style) (style view-id focused?) style))
      (define reg (selected-register!))
      (if (and reg (not (equal? reg #\")))
          (list
            (span " \"" s)
            (span (string reg) s)
            (span " " s))
          '()))))
