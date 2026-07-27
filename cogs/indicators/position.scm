;; cogs/indicators/position.scm

(require "helix/components.scm")
(require "helix/editor.scm")
(require "helix/misc.scm")
(require "helix/static.scm")
(require-builtin helix/core/text as text.)

(require (only-in "cogs/color.scm" clamp))
(require "cogs/indicators/style.scm")

(provide position-indicator)

(define (position-indicator #:fg (fg #f) #:bg (bg #f)
                            #:placeholder (placeholder " --:--/--, --% ")
                            #:left-arc? (left-arc? #f) #:left-arc-fg (left-arc-fg #f) #:left-arc-bg (left-arc-bg #f)
                            #:left-arc-char (left-arc-char "")
                            #:right-arc? (right-arc? #f) #:right-arc-fg (right-arc-fg #f) #:right-arc-bg (right-arc-bg #f)
                            #:right-arc-char (right-arc-char ""))
  (status-element
    (lambda (view-id focused?)
      (define s (make-style fg bg focused?))
      (define (frame spans)
        (with-arcs spans #:placeholder placeholder #:placeholder-style s #:focused? focused?
                   #:left? left-arc? #:left-fg left-arc-fg #:left-bg left-arc-bg #:left-char left-arc-char
                   #:right? right-arc? #:right-fg right-arc-fg #:right-bg right-arc-bg #:right-char right-arc-char))
      (if focused?
          (let* ([doc-id (editor->doc-id view-id)]
                 [rope (editor->text doc-id)]
                 [total (max 1 (text.rope-len-lines rope))]
                 [line (+ 1 (get-current-line-number))]
                 [col (+ 1 (get-current-column-number))]
                 [pct (if (> total 1)
                          (clamp (inexact->exact
                                   (round (* 100.0 (/ (- line 1) (- total 1)))))
                                 0 100)
                          0)])
            (frame
              (list (span (string-append " " (number->string line)
                                         ":" (number->string col)
                                         "/" (number->string total)
                                         ", " (number->string pct) "% ") s))))
          (frame '())))))
