;; cogs/indicators/left-arc.scm

(require "helix/components.scm")

(provide left-arc-indicator)

(define (left-arc-indicator #:style (style (lambda args (style))))
  (status-element
    (lambda (view-id focused?)
      (list (span "" (if (procedure? style) (style view-id focused?) style))))))
