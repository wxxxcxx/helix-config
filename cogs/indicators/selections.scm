;; cogs/indicators/selections.scm

(require "helix/components.scm")
(require "helix/static.scm")
(require "cogs/indicators/style.scm")

(provide selections-indicator)

(define (selections-indicator #:fg (fg #f) #:bg (bg #f))
  (status-element
    (lambda (view-id focused?)
      (if focused?
          (let* ([s (make-style fg bg focused?)]
                 [sel (current-selection-object)]
                 [count (length (selection->ranges sel))])
            (if (> count 1)
                (list
                  (span " 󰕢 " s)
                  (span (number->string count) s)
                  (span " " s))
                '()))
          '()))))
