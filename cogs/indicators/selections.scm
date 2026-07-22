;; cogs/indicators/selections.scm

(require "helix/components.scm")
(require "helix/static.scm")
(require "cogs/indicators/core.scm")

(provide selections-indicator)

(define (selections-indicator #:fg (fg-fn (lambda args Color/Reset))
                               #:bg (bg-fn (lambda args Color/Reset)))
  (status-element
    (lambda (view-id focused?)
      (define sel (current-selection-object))
      (define count (length (selection->ranges sel)))
      (define bg (resolve-color bg-fn focused?))
      (define fg (resolve-color fg-fn focused?))
      (if (> count 1)
          (list
            (span " 󰕢 " (named-style fg bg))
            (span (number->string count) (named-style fg bg))
            (span " " (named-style fg bg)))
          '()))))
