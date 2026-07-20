;; cogs/indicators/core.scm
;; — helpers used by indicator factories

(require "helix/components.scm")
(require "cogs/color.scm")

(provide named-style)

(define (named-style fg bg)
  (~> (style) (style-fg fg) (style-bg bg)))

(provide resolve-color)

(define (resolve-color arg)
  (if (procedure? arg) (arg) arg))

(provide auto-fg)

(define (auto-fg bg-fn)
  (lambda () (contrast-text (resolve-color bg-fn))))
