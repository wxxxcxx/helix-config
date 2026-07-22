;; cogs/indicators/selections.scm

(require "helix/components.scm")
(require "helix/static.scm")

(provide selections-indicator)

(define (selections-indicator #:style (style (lambda args (style))))
  (status-element
    (lambda (view-id focused?)
      (if focused?
          (let* ([s (if (procedure? style) (style view-id focused?) style)]
                 [sel (current-selection-object)]
                 [count (length (selection->ranges sel))])
            (if (> count 1)
                (list
                  (span " 󰕢 " s)
                  (span (number->string count) s)
                  (span " " s))
                '()))
          '()))))
