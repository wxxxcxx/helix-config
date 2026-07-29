;; cogs/color.scm
;; Color manipulation utilities

(require "helix/components.scm")
(require (only-in "helix/themes.scm" string->color))

(provide clamp
         terminal-color-mode
         color-terminal?
         indexed-terminal?
         ansi->hex
         closest-ansi
         safe-color
         ->color
         terminal-color
         color->hex)


(define (clamp v min max)
  (cond
    [(< v min) min]
    [(> v max) max]
    [else v]))

(define (clamp-f v)
  (clamp v 0.0 1.0))

(define (color-env name)
  (with-handler (lambda (_) "") (or (env-var name) "")))

(define *terminal-color-mode* #f)

(define (detect-terminal-color-mode)
  (define override (string-downcase (color-env "HELIX_COLOR_MODE")))
  (define colorterm (string-downcase (color-env "COLORTERM")))
  (define term (string-downcase (color-env "TERM")))
  (cond [(equal? override "direct") 'direct]
        [(equal? override "indexed") 'indexed]
        [(equal? override "ansi") 'ansi]
        [(or (equal? (current-os!) "windows")
             (equal? colorterm "truecolor")
             (equal? colorterm "24bit")
             (not (string=? (color-env "WSL_DISTRO_NAME") ""))
             (string-contains? term "truecolor")
             (string-contains? term "direct"))
         'direct]
        [(string-contains? term "256color") 'indexed]
        [else 'ansi]))

(define (terminal-color-mode)
  (unless *terminal-color-mode*
    (set! *terminal-color-mode* (detect-terminal-color-mode)))
  *terminal-color-mode*)

(define (color-terminal?) (equal? (terminal-color-mode) 'direct))
(define (indexed-terminal?) (equal? (terminal-color-mode) 'indexed))

;; ── ANSI named colors ────────────────────────────────────────────

(define *ansi-colors*
  (list (list "black"         "#000000" 0)
        (list "red"           "#800000" 1)
        (list "green"         "#008000" 2)
        (list "yellow"        "#808000" 3)
        (list "blue"          "#000080" 4)
        (list "magenta"       "#800080" 5)
        (list "cyan"          "#008080" 6)
        (list "light-gray"    "#C0C0C0" 7)
        (list "gray"          "#808080" 8)
        (list "light-red"     "#FF0000" 9)
        (list "light-green"   "#00FF00" 10)
        (list "light-yellow"  "#FFFF00" 11)
        (list "light-blue"    "#0000FF" 12)
        (list "light-magenta" "#FF00FF" 13)
        (list "light-cyan"    "#00FFFF" 14)
        (list "white"         "#FFFFFF" 15)))

(define (ansi->hex name)
  (define entry (assoc name *ansi-colors*))
  (if entry (cadr entry) #f))

(define (ansi-index name)
  (define entry (assoc name *ansi-colors*))
  (and entry (list-ref entry 2)))

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

(define (xterm-channel index)
  (if (= index 0) 0 (+ 55 (* index 40))))

(define (xterm-index-rgb index)
  (if (< index 232)
      (let* ([offset (- index 16)]
             [r (quotient offset 36)]
             [g (quotient (modulo offset 36) 6)]
             [b (modulo offset 6)])
        (list (xterm-channel r) (xterm-channel g) (xterm-channel b)))
      (let ([gray (+ 8 (* (- index 232) 10))])
        (list gray gray gray))))

(define (closest-indexed-index hex)
  (define target (parse-hex hex))
  (let loop ([index 17] [best 16]
             [best-distance (color-dist target (xterm-index-rgb 16))])
    (if (> index 255)
        best
        (let ([distance (color-dist target (xterm-index-rgb index))])
          (if (< distance best-distance)
              (loop (+ index 1) index distance)
              (loop (+ index 1) best best-distance))))))

(define *indexed-color-cache* (hash))
(define *ansi-color-cache* (hash))
(define *ansi-semantic-overrides*
  (hash "#2e3440" 0
        "#4c566a" 8
        "#464f62" 8
        "#546075" 8
        "#d8dee9" 7
        "#eceff4" 15
        "#5e81ac" 12
        "#81a1c1" 12
        "#88c0d0" 14
        "#8fbcbb" 14
        "#a3be8c" 10
        "#d08770" 9
        "#bf616a" 9
        "#b48ead" 13
        "#ebcb8b" 11))

(define (cached-indexed-color hex)
  (define cached (hash-try-get *indexed-color-cache* hex))
  (if cached
      cached
      (let ([color (Color/Indexed (closest-indexed-index hex))])
        (set! *indexed-color-cache* (hash-insert *indexed-color-cache* hex color))
        color)))

(define (cached-ansi-color hex)
  (define cached (hash-try-get *ansi-color-cache* hex))
  (if cached
      cached
      (let* ([semantic-index
               (hash-try-get *ansi-semantic-overrides* (string-downcase hex))]
             [color
               (Color/Indexed
                 (or semantic-index (ansi-index (closest-ansi hex)) 7))])
        (set! *ansi-color-cache* (hash-insert *ansi-color-cache* hex color))
        color)))

(define (safe-color color)
  (cond
    [(not color) #f]
    [(color-terminal?) color]
    [else
     (define hex
       (if (string? color)
           (if (starts-with? color "#") color (ansi->hex color))
           (with-handler (lambda (_) #f) (color->hex color))))
     (and hex
          (if (indexed-terminal?)
              (cached-indexed-color hex)
              (cached-ansi-color hex)))]))

(define (->color c)
  (if (string? c)
      (if (starts-with? c "#")
          (string->color c)
          (let ([index (ansi-index c)])
            (if index (Color/Indexed index) (string->color c))))
      c))

(define (terminal-color color)
  (->color (safe-color color)))

(define hex-digits "0123456789ABCDEF")

(define (byte->hex n)
  (let loop ([i 0])
    (if (< (- n (* i 16)) 16)
        (string (string-ref hex-digits i)
                (string-ref hex-digits (- n (* i 16))))
        (loop (+ i 1)))))

(define (color->hex c)
  (with-handler
    (lambda (_) "#5E81AC")
    (let ([r (Color-red c)]
          [g (Color-green c)]
          [b (Color-blue c)])
      (if (and (number? r) (number? g) (number? b))
          (string-append "#"
            (byte->hex r)
            (byte->hex g)
            (byte->hex b))
          "#5E81AC"))))

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
