;; cogs/color.scm
;; Color manipulation utilities

(require "helix/components.scm")
(require (only-in "helix/themes.scm" string->color))

(provide clamp
         color-terminal?
         ansi->hex
         closest-ansi
         safe-color
         ->color
          color->hex)


(define (clamp v min max)
  (cond
    [(< v min) min]
    [(> v max) max]
    [else v]))

(define (clamp-f v)
  (clamp v 0.0 1.0))

(define (color-terminal?)
  (with-handler
    (lambda (_) #f)
    (let ([ct (env-var "COLORTERM")])
      (or (equal? ct "truecolor")
          (equal? ct "24bit")))))

;; ── ANSI named colors ────────────────────────────────────────────

(define *ansi-colors*
  (list (list "black"         "#000000")
        (list "maroon"        "#800000")
        (list "green"         "#008000")
        (list "olive"         "#808000")
        (list "navy"          "#000080")
        (list "purple"        "#800080")
        (list "teal"          "#008080")
        (list "silver"        "#C0C0C0")
        (list "gray"          "#808080")
        (list "red"           "#FF0000")
        (list "lime"          "#00FF00")
        (list "yellow"        "#FFFF00")
        (list "blue"          "#0000FF")
        (list "fuchsia"       "#FF00FF")
        (list "aqua"          "#00FFFF")
        (list "white"         "#FFFFFF")
        (list "grey"          "#808080")
        (list "darkgray"      "#555555")
        (list "darkgrey"      "#555555")
        (list "darkslategray" "#2F4F4F")
        (list "darkslategrey" "#2F4F4F")
        (list "dimgray"       "#696969")
        (list "dimgrey"       "#696969")
        (list "lightgray"     "#D3D3D3")
        (list "lightgrey"     "#D3D3D3")
        (list "gainsboro"     "#DCDCDC")
        (list "whitesmoke"    "#F5F5F5")
        (list "slategray"     "#708090")
        (list "slategrey"     "#708090")
        (list "lightslategray" "#778899")
        (list "lightslategrey" "#778899")
        (list "darkcyan"      "#008B8B")
        (list "darkgreen"     "#006400")
        (list "darkred"       "#8B0000")
        (list "darkblue"      "#00008B")
        (list "darkmagenta"   "#8B008B")
        (list "darkyellow"    "#BDB76B")
        (list "cadetblue"     "#5F9EA0")
        (list "lightsteelblue" "#B0C4DE")
        (list "steelblue"     "#4682B4")
        (list "mediumaquamarine" "#66CDAA")
        (list "darkseagreen"  "#8FBC8F")
        (list "lightsalmon"   "#FFA07A")
        (list "indianred"     "#CD5C5C")
        (list "orchid"        "#DA70D6")
        (list "khaki"         "#F0E68C")
        (list "cyan"          "#00FFFF")
        (list "magenta"       "#FF00FF")
        (list "coral"         "#FF7F50")
        (list "tomato"        "#FF6347")
        (list "gold"          "#FFD700")
        (list "orange"        "#FFA500")
        (list "skyblue"       "#87CEEB")
        (list "plum"          "#DDA0DD")
        (list "tan"           "#D2B48C")
        (list "beige"         "#F5F5DC")
        (list "ivory"         "#FFFFF0")
        (list "crimson"       "#DC143C")
        (list "chocolate"     "#D2691E")
        (list "sienna"        "#A0522D")
        (list "salmon"        "#FA8072")
        (list "goldenrod"     "#DAA520")
        (list "peru"          "#CD853F")
        (list "burlywood"     "#DEB887")
        (list "navajowhite"   "#FFDEAD")
        (list "moccasin"      "#FFE4B5")
        (list "wheat"         "#F5DEB3")))

(define (ansi->hex name)
  (define entry (assoc name *ansi-colors*))
  (if entry (cadr entry) #f))

(define (parse-hex hex)
  (list (string->number (substring hex 1 3) 16)
        (string->number (substring hex 3 5) 16)
        (string->number (substring hex 5 7) 16)))

(define (color-dist c1 c2)
  (define r-diff (- (car c1) (car c2)))
  (define g-diff (- (cadr c1) (cadr c2)))
  (define b-diff (- (caddr c1) (caddr c2)))
  (+ (* r-diff r-diff) (* g-diff g-diff) (* b-diff b-diff)))

(define (closest-ansi hex)
  (define target (parse-hex hex))
  (define first-entry (car *ansi-colors*))
  (define best-name (car first-entry))
  (define best-dist (color-dist target (parse-hex (cadr first-entry))))
  (for-each (lambda (entry)
              (define d (color-dist target (parse-hex (cadr entry))))
              (when (< d best-dist)
                (set! best-name (car entry))
                (set! best-dist d)))
            *ansi-colors*)
  best-name)

(define (safe-color color)
  (cond
    [(not color) #f]
    [(string? color)
     (if (or (color-terminal?) (not (starts-with? color "#")))
         color
         (closest-ansi color))]
    [(color-terminal?) color]
    [else
     (with-handler
       (lambda (_) #f)
       (closest-ansi (color->hex color)))]))

(define (->color c)
  (if (string? c)
      (string->color (if (starts-with? c "#") c (ansi->hex c)))
      c))

(define hex-digits "0123456789ABCDEF")

(define (byte->hex n)
  (let loop ([i 0])
    (if (< (- n (* i 16)) 16)
        (string (string-ref hex-digits i)
                (string-ref hex-digits (- n (* i 16))))
        (loop (+ i 1)))))

(define (color->hex c)
  (let ([r (Color-red c)]
        [g (Color-green c)]
        [b (Color-blue c)])
    (if (and (number? r) (number? g) (number? b))
        (string-append "#"
          (byte->hex r)
          (byte->hex g)
          (byte->hex b))
        "#5E81AC")))

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
  (let ([color (->color color)])
    (Color/rgb
      (inexact->exact (round (* (Color-red color) factor)))
      (inexact->exact (round (* (Color-green color) factor)))
      (inexact->exact (round (* (Color-blue color) factor))))))

(provide lighten)

(define (lighten color factor)
  (let ([color (->color color)])
    (Color/rgb
      (clamp (inexact->exact (round (* (Color-red color) factor))) 0 255)
      (clamp (inexact->exact (round (* (Color-green color) factor))) 0 255)
      (clamp (inexact->exact (round (* (Color-blue color) factor))) 0 255))))

;; ── Saturation ───────────────────────────────────────────────────

(provide saturate)

(define (saturate color factor)
  (let ([color (->color color)])
    (define hsl (rgb->hsl color))
    (hsl->rgb (car hsl) (clamp-f (* (cadr hsl) factor)) (caddr hsl))))

(provide desaturate)

(define (desaturate color factor)
  (let ([color (->color color)])
    (define hsl (rgb->hsl color))
    (hsl->rgb (car hsl) (clamp-f (* (cadr hsl) factor)) (caddr hsl))))

;; ── Luminance ────────────────────────────────────────────────────

(provide luminance)
;;@doc
;; Relative luminance (BT.601), 0.0 (dark) ~ 1.0 (light).
(define (luminance color)
  (let ([color (->color color)])
    (+ (* 0.299 (/ (Color-red color) 255.0))
       (* 0.587 (/ (Color-green color) 255.0))
       (* 0.114 (/ (Color-blue color) 255.0)))))

(provide contrast-text)
;;@doc
;; Returns light (#D8DEE9) or dark (#2E3440) text color
;; depending on whether bg is dark or light.
(define (contrast-text bg)
  (let ([bg (->color bg)])
    (if (> (luminance bg) 0.5)
        (string->color "#2E3440")
        (string->color "#D8DEE9"))))
