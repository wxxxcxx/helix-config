;; cogs/color.scm
;; Color manipulation utilities

(require "helix/components.scm")
(require (only-in "helix/themes.scm" string->color))

(provide clamp)

(define (clamp v min max)
  (cond
    [(< v min) min]
    [(> v max) max]
    [else v]))

(define (clamp-f v)
  (clamp v 0.0 1.0))

;; ── RGB ↔ HSL conversion ────────────────────────────────────────

(define (rgb->hsl color)
  (define r (/ (Color-red color) 255.0))
  (define g (/ (Color-green color) 255.0))
  (define b (/ (Color-blue color) 255.0))
  (define mx (max r g b))
  (define mn (min r g b))
  (define delta (- mx mn))
  (define h
    (if (= delta 0.0)
        0.0
        (cond
          [(= mx r) (/ (- g b) delta)]
          [(= mx g) (+ 2.0 (/ (- b r) delta))]
          [else     (+ 4.0 (/ (- r g) delta))])))
  (define hue (* 60.0 (if (< h 0.0) (+ h 6.0) h)))
  (define lightness (/ (+ mx mn) 2.0))
  (define saturation
    (if (= delta 0.0)
        0.0
        (/ delta (- 1.0 (abs (- (* 2.0 lightness) 1.0))))))
  (list hue saturation lightness))

(define (hsl->rgb h s l)
  (define (hue-step p q t)
    (cond
      [(< t 0.0) (hue-step p q (+ t 1.0))]
      [(> t 1.0) (hue-step p q (- t 1.0))]
      [(< t (/ 1.0 6.0)) (+ p (* (- q p) 6.0 t))]
      [(< t 0.5) q]
      [(< t (/ 2.0 3.0)) (+ p (* (- q p) 6.0 (- (/ 2.0 3.0) t)))]
      [else p]))
  (define q (if (< l 0.5) (* l (+ 1.0 s)) (+ l s (- (* l s)))))
  (define p (- (* 2.0 l) q))
  (define (to255 v)
    (inexact->exact (round (* 255.0 v))))
  (cond
    [(= s 0.0) (Color/rgb (to255 l) (to255 l) (to255 l))]
    [else
     (Color/rgb
       (to255 (hue-step p q (+ (/ h 360.0) (/ 1.0 3.0))))
       (to255 (hue-step p q (/ h 360.0)))
       (to255 (hue-step p q (- (/ h 360.0) (/ 1.0 3.0)))))]))
;; ── Brightness ───────────────────────────────────────────────────

(provide darken)

(define (darken color factor)
  (Color/rgb
    (inexact->exact (round (* (Color-red color) factor)))
    (inexact->exact (round (* (Color-green color) factor)))
    (inexact->exact (round (* (Color-blue color) factor)))))

(provide lighten)

(define (lighten color factor)
  (Color/rgb
    (clamp (inexact->exact (round (* (Color-red color) factor))) 0 255)
    (clamp (inexact->exact (round (* (Color-green color) factor))) 0 255)
    (clamp (inexact->exact (round (* (Color-blue color) factor))) 0 255)))

;; ── Saturation ───────────────────────────────────────────────────

(provide saturate)

(define (saturate color factor)
  (define hsl (rgb->hsl color))
  (hsl->rgb (car hsl) (clamp-f (* (cadr hsl) factor)) (caddr hsl)))

(provide desaturate)

(define (desaturate color factor)
  (define hsl (rgb->hsl color))
  (hsl->rgb (car hsl) (clamp-f (* (cadr hsl) factor)) (caddr hsl)))

;; ── Luminance ────────────────────────────────────────────────────

(provide luminance)
;;@doc
;; Relative luminance (BT.601), 0.0 (dark) ~ 1.0 (light).
(define (luminance color)
  (+ (* 0.299 (/ (Color-red color) 255.0))
     (* 0.587 (/ (Color-green color) 255.0))
     (* 0.114 (/ (Color-blue color) 255.0))))

(provide contrast-text)
;;@doc
;; Returns light (#D8DEE9) or dark (#2E3440) text color
;; depending on whether bg is dark or light.
(define (contrast-text bg)
  (if (> (luminance bg) 0.5)
      (string->color "#2E3440")
      (string->color "#D8DEE9")))
