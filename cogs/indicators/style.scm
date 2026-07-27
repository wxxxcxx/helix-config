;; cogs/indicators/style.scm
;; Reusable style helpers for indicators

(require "helix/components.scm")
(require "cogs/color.scm")

(provide clamp
         make-style
         safe-style)

(define (safe-style s)
  (let ([fg (style->fg s)]
        [bg (style->bg s)])
    (let* ([s1 (if fg (style-fg s (->color (safe-color (color->hex fg)))) s)]
           [s2 (if bg (style-bg s1 (->color (safe-color (color->hex bg)))) s1)])
      s2)))

(define (make-style fg bg focused?)
  (let* ([raw-fg (if (procedure? fg) (fg) fg)]
         [raw-bg (if (procedure? bg) (bg) bg)]
         [fg-color (and raw-fg (->color (safe-color (if focused? raw-fg (desaturate raw-fg 0.05)))))]
         [bg-color (and raw-bg (->color (safe-color raw-bg)))]
         [s (if fg-color (style-fg (style) fg-color) (style))]
         [s (if bg-color (style-bg s bg-color) s)])
    s))
