;; cogs/indicators/selections.scm

(require "helix/components.scm")
(require "helix/static.scm")
(require "cogs/indicators/core.scm")

(provide selections-indicator)

(define (selections-indicator #:style (style (lambda args (style))))
  (status-element
    (lambda (view-id focused?)
      (define s (resolve-style style view-id focused?))
      (define sel (current-selection-object))
      (define count (length (selection->ranges sel)))
      (if (> count 1)
          (list
            (span " 󰕢 " s)
            (span (number->string count) s)
            (span " " s))
          '()))))
