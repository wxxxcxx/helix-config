;; cogs/indicators/style.scm
;; Reusable style helpers for indicators

(require "helix/components.scm")
(require "cogs/color.scm")

(provide make-style with-arcs)

(define (resolve-color color)
  (and color
       (->color (safe-color (if (procedure? color) (color) color)))))

(define (focus-color color focused?)
  (if (or focused? (not color))
      color
      (desaturate color 0.0)))

(define (resolve-focused-color color focused?)
  (resolve-color
    (focus-color (if (procedure? color) (color) color) focused?)))

(define (make-style fg bg focused?)
  (let* ([fg-color (resolve-focused-color fg focused?)]
         [bg-color (resolve-focused-color bg focused?)]
         [s (if fg-color (style-fg (style) fg-color) (style))]
         [s (if bg-color (style-bg s bg-color) s)])
    s))

;; Empty indicators render their configured placeholder inside the same boundaries.
(define (with-arcs spans
                   #:placeholder (placeholder #f)
                   #:placeholder-style (placeholder-style (style))
                   #:focused? (focused? #t)
                   #:left? (left? #f)
                   #:left-fg (left-fg #f)
                   #:left-bg (left-bg #f)
                   #:left-char (left-char "")
                   #:right? (right? #f)
                   #:right-fg (right-fg #f)
                   #:right-bg (right-bg #f)
                   #:right-char (right-char ""))
  (define content
    (if (and (null? spans) placeholder)
        (list (span placeholder placeholder-style))
        spans))
  (if (null? content)
      '()
      (append
        (if (and left? left-fg) (list (span left-char (make-style left-fg left-bg focused?))) '())
        content
        (if (and right? right-fg) (list (span right-char (make-style right-fg right-bg focused?))) '()))))
