;; cogs/indicators/selections.scm

(require "helix/components.scm")
(require "helix/static.scm")
(require "cogs/indicators/style.scm")

(provide selections-indicator)

(define (selections-indicator #:fg (fg #f) #:bg (bg #f)
                             #:placeholder (placeholder " 󰕢 1 󰗧 0 ")
                             #:left-separator? (left-separator? #f) #:left-separator-fg (left-separator-fg #f) #:left-separator-bg (left-separator-bg #f)
                             #:left-separator-char (left-separator-char "")
                             #:right-separator? (right-separator? #f) #:right-separator-fg (right-separator-fg #f) #:right-separator-bg (right-separator-bg #f)
                             #:right-separator-char (right-separator-char ""))
  (make-indicator
    (lambda (view-id focused? s)
      (if focused?
          (let* ([sel (current-selection-object)]
                 [count (length (selection->ranges sel))]
                 [primary (selection->primary-range sel)]
                 [length (- (range->to primary) (range->from primary))])
            (list
              (span " 󰕢 " s)
              (span (number->string count) s)
              (span " 󰗧 " s)
              (span (string-append (number->string length) " ") s)))
          '()))
    #:fg fg #:bg bg #:placeholder placeholder
    #:left-separator? left-separator? #:left-separator-fg left-separator-fg #:left-separator-bg left-separator-bg #:left-separator-char left-separator-char
    #:right-separator? right-separator? #:right-separator-fg right-separator-fg #:right-separator-bg right-separator-bg #:right-separator-char right-separator-char))
