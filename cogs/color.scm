;; cogs/color.scm
;; Color manipulation utilities

(require "helix/components.scm")

(define (clamp v min max)
  (cond
    [(< v min) min]
    [(> v max) max]
    [else v]))

(provide darken)
;;@doc
;; Darken color by factor (0.0 = black, 1.0 = unchanged).
;; Each RGB component is multiplied by factor, clamped to 0-255.
(define (darken color factor)
  (Color/rgb
    (inexact->exact (round (* (Color-red color) factor)))
    (inexact->exact (round (* (Color-green color) factor)))
    (inexact->exact (round (* (Color-blue color) factor)))))

(provide lighten)
;;@doc
;; Lighten color by factor (1.0 = unchanged, > 1.0 = lighter).
;; Each RGB component is multiplied by factor, clamped to 255.
(define (lighten color factor)
  (Color/rgb
    (clamp (inexact->exact (round (* (Color-red color) factor))) 0 255)
    (clamp (inexact->exact (round (* (Color-green color) factor))) 0 255)
    (clamp (inexact->exact (round (* (Color-blue color) factor))) 0 255)))
