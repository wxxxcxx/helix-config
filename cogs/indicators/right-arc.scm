;; cogs/indicators/right-arc.scm

(require "helix/components.scm")

(provide right-arc-indicator)

(define (right-arc-indicator #:style (style (lambda args (style))))
  (status-element
    (lambda (view-id focused?)
      (list (span "" (if (procedure? style) (style view-id focused?) style))))))
