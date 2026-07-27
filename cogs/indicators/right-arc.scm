(require "helix/components.scm")
(require "cogs/indicators/style.scm")

(provide right-arc-indicator)

(define (right-arc-indicator #:fg (fg #f) #:bg (bg #f))
  (status-element
    (lambda (view-id focused?)
      (list (span "" (make-arc-style fg bg))))))
