(require "helix/components.scm")
(require "cogs/indicators/style.scm")

(provide left-arc-indicator)

(define (left-arc-indicator #:fg (fg #f) #:bg (bg #f))
  (status-element
    (lambda (view-id focused?)
      (define fg-color (if (procedure? fg) (fg) fg))
      (define bg-color (if (procedure? bg) (bg) bg))
      (list (span "" (make-style fg-color bg-color focused?))))))
