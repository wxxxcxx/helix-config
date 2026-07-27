;; cogs/indicators/register.scm

(require "helix/components.scm")
(require "helix/editor.scm")
(require "cogs/indicators/style.scm")

(provide register-indicator)

(define (register-indicator #:fg (fg #f) #:bg (bg #f)
                            #:placeholder (placeholder " \"- ")
                            #:left-arc? (left-arc? #f) #:left-arc-fg (left-arc-fg #f) #:left-arc-bg (left-arc-bg #f)
                            #:left-arc-char (left-arc-char "")
                            #:right-arc? (right-arc? #f) #:right-arc-fg (right-arc-fg #f) #:right-arc-bg (right-arc-bg #f)
                            #:right-arc-char (right-arc-char ""))
  (status-element
    (lambda (view-id focused?)
      (define s (make-style fg bg focused?))
      (define reg (selected-register!))
      (define frame
        (make-indicator-frame s focused? #:placeholder placeholder
                              #:left? left-arc? #:left-fg left-arc-fg #:left-bg left-arc-bg #:left-char left-arc-char
                              #:right? right-arc? #:right-fg right-arc-fg #:right-bg right-arc-bg #:right-char right-arc-char))
      (if (and reg (not (equal? reg #\")))
          (frame
            (list
              (span " \"" s)
              (span (string reg) s)
              (span " " s)))
          (frame '())))))
