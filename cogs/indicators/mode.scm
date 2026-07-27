;; cogs/indicators/mode.scm
;; — mode indicator

(require "helix/components.scm")
(require "cogs/indicators/style.scm")
(require (only-in "cogs/statusline-palette.scm" statusline-mode-name))

(provide mode-indicator)

(define mode-labels
  (hash
    "normal" "❖ NORMAL "
    "insert" "❖ INSERT "
    "select" "❖ SELECT "))

(define (mode-indicator #:fg (fg #f) #:bg (bg #f)
                        #:placeholder (placeholder "❖ INACTIVE ")
                        #:left-separator? (left-separator? #f) #:left-separator-fg (left-separator-fg #f) #:left-separator-bg (left-separator-bg #f)
                        #:left-separator-char (left-separator-char "")
                        #:right-separator? (right-separator? #f) #:right-separator-fg (right-separator-fg #f) #:right-separator-bg (right-separator-bg #f)
                        #:right-separator-char (right-separator-char ""))
  (make-indicator
    (lambda (view-id focused? s)
      (if focused?
          (list (span (hash-ref mode-labels (statusline-mode-name)) s))
          '()))
    #:fg fg #:bg bg #:placeholder placeholder #:style-transform style-with-bold
    #:left-separator? left-separator? #:left-separator-fg left-separator-fg #:left-separator-bg left-separator-bg #:left-separator-char left-separator-char
    #:right-separator? right-separator? #:right-separator-fg right-separator-fg #:right-separator-bg right-separator-bg #:right-separator-char right-separator-char))
