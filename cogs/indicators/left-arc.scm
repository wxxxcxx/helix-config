(require "helix/components.scm")
(require "cogs/indicators/style.scm")

(provide left-arc-indicator)

(define (left-arc-indicator #:fg (fg #f) #:bg (bg #f))
  (status-element
    (lambda (view-id focused?)
      (list (span "" (make-arc-style fg bg))))))
