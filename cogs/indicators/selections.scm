;; cogs/indicators/selections.scm

(require "helix/components.scm")
(require "helix/static.scm")
(require "cogs/indicators/style.scm")

(provide selections-indicator)

(define (selections-indicator #:fg (fg #f) #:bg (bg #f)
                             #:placeholder (placeholder " 󰕢 1 ")
                             #:left-arc? (left-arc? #f) #:left-arc-fg (left-arc-fg #f) #:left-arc-bg (left-arc-bg #f)
                             #:left-arc-char (left-arc-char "")
                             #:right-arc? (right-arc? #f) #:right-arc-fg (right-arc-fg #f) #:right-arc-bg (right-arc-bg #f)
                             #:right-arc-char (right-arc-char ""))
  (status-element
    (lambda (view-id focused?)
      (define s (make-style fg bg focused?))
      (if focused?
          (let* ([sel (current-selection-object)]
                 [count (length (selection->ranges sel))])
            (if (> count 1)
                (with-arcs
                  (list
                    (span " 󰕢 " s)
                    (span (number->string count) s)
                    (span " " s))
                  #:left? left-arc? #:left-fg left-arc-fg #:left-bg left-arc-bg #:left-char left-arc-char
                  #:right? right-arc? #:right-fg right-arc-fg #:right-bg right-arc-bg #:right-char right-arc-char #:focused? focused?)
                (with-arcs '() #:placeholder placeholder #:placeholder-style s
                           #:left? left-arc? #:left-fg left-arc-fg #:left-bg left-arc-bg #:left-char left-arc-char
                           #:right? right-arc? #:right-fg right-arc-fg #:right-bg right-arc-bg #:right-char right-arc-char #:focused? focused?)))
          (with-arcs '() #:placeholder placeholder #:placeholder-style s
                     #:left? left-arc? #:left-fg left-arc-fg #:left-bg left-arc-bg #:left-char left-arc-char
                     #:right? right-arc? #:right-fg right-arc-fg #:right-bg right-arc-bg #:right-char right-arc-char #:focused? focused?)))))
