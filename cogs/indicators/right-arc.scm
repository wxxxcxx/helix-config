;; cogs/indicators/right-arc.scm

(require "helix/components.scm")
(require "cogs/indicators/core.scm")

(provide right-arc-indicator)

(define (right-arc-indicator #:style (style (lambda args (style))))
  (status-element
    (lambda (view-id focused?)
      (list (span "" (resolve-style style view-id focused?))))))
