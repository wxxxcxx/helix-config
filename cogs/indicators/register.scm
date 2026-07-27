;; cogs/indicators/register.scm

(require "helix/components.scm")
(require "helix/editor.scm")
(require "cogs/indicators/style.scm")

(provide register-indicator)

(define (register-indicator #:fg (fg #f) #:bg (bg #f)
                            #:placeholder (placeholder " \"- ")
                            #:left-separator? (left-separator? #f) #:left-separator-fg (left-separator-fg #f) #:left-separator-bg (left-separator-bg #f)
                            #:left-separator-char (left-separator-char "")
                            #:right-separator? (right-separator? #f) #:right-separator-fg (right-separator-fg #f) #:right-separator-bg (right-separator-bg #f)
                            #:right-separator-char (right-separator-char ""))
  (make-indicator
    (lambda (view-id focused? s)
      (define reg (selected-register!))
      (if (and reg (not (equal? reg #\")))
          (list
            (span " \"" s)
            (span (string reg) s)
            (span " " s))
          '()))
    #:fg fg #:bg bg #:placeholder placeholder
    #:left-separator? left-separator? #:left-separator-fg left-separator-fg #:left-separator-bg left-separator-bg #:left-separator-char left-separator-char
    #:right-separator? right-separator? #:right-separator-fg right-separator-fg #:right-separator-bg right-separator-bg #:right-separator-char right-separator-char))
