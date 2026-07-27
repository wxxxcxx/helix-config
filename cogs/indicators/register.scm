;; cogs/indicators/register.scm

(require "helix/components.scm")
(require "helix/editor.scm")
(require "cogs/indicators/style.scm")

(provide register-indicator)

(define (register-indicator #:fg (fg #f) #:bg (bg #f))
  (status-element
    (lambda (view-id focused?)
      (define s (make-style fg bg focused?))
      (define reg (selected-register!))
      (if (and reg (not (equal? reg #\")))
          (list
            (span " \"" s)
            (span (string reg) s)
            (span " " s))
          '()))))
