;; cogs/indicators/style.scm
;; Reusable style helpers for indicators

(require "helix/components.scm")
(require (only-in "helix/editor.scm" editor-focused-buffer-area))
(require "cogs/color.scm")

(provide make-style make-indicator with-separators statusline-width-at-least?)

(define (statusline-width-at-least? min-width)
  (let ([area (editor-focused-buffer-area)])
    (or (not area) (>= (area-width area) min-width))))

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

(define identity-style (lambda (s) s))

(define (make-indicator render
                        #:fg (fg #f)
                        #:bg (bg #f)
                        #:placeholder (placeholder #f)
                        #:min-width (min-width #f)
                        #:style-transform (style-transform identity-style)
                        #:left-separator? (left? #f)
                        #:left-separator-fg (left-fg #f)
                        #:left-separator-bg (left-bg #f)
                        #:left-separator-char (left-char "")
                        #:right-separator? (right? #f)
                        #:right-separator-fg (right-fg #f)
                        #:right-separator-bg (right-bg #f)
                        #:right-separator-char (right-char ""))
  (status-element
    (lambda (view-id focused?)
      (if (and min-width (not (statusline-width-at-least? min-width)))
          '()
          (let ([s (style-transform (make-style fg bg focused?))])
            (with-separators (render view-id focused? s)
                             #:placeholder placeholder #:placeholder-style s #:focused? focused?
                             #:left? left? #:left-fg (or left-fg bg) #:left-bg left-bg #:left-char left-char
                             #:right? right? #:right-fg (or right-fg bg) #:right-bg right-bg #:right-char right-char))))))

;; Empty indicators render their configured placeholder inside the same boundaries.
(define (with-separators spans
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
