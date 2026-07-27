;; cogs/indicators/style.scm
;; Reusable style helpers for indicators

(require "helix/components.scm")
(require "cogs/color.scm")

(provide clamp
         make-style
         make-arc-style)

(define (resolve-color color)
  (and color
       (->color (safe-color (if (procedure? color) (color) color)))))

(define (make-style fg bg focused?)
  (let* ([raw-fg (if (procedure? fg) (fg) fg)]
         [fg-color (resolve-color (if (and raw-fg (not focused?))
                                      (desaturate raw-fg 0.05)
                                      raw-fg))]
         [bg-color (resolve-color bg)]
         [s (if fg-color (style-fg (style) fg-color) (style))]
         [s (if bg-color (style-bg s bg-color) s)])
    s))

;; Arc glyphs must use the exact adjacent background colors.
(define (make-arc-style fg bg)
  (let* ([fg-color (resolve-color fg)]
         [bg-color (resolve-color bg)]
         [s (if fg-color (style-fg (style) fg-color) (style))])
    (if bg-color (style-bg s bg-color) s)))
