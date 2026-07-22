;; cogs/indicators/core.scm
;; — helpers used by indicator factories

(require "helix/components.scm")
(require "cogs/color.scm")

(provide named-style)

(define (named-style fg bg)
  (~> (style) (style-fg fg) (style-bg bg)))

(provide resolve-color)

(define (resolve-color arg . args)
  (if (procedure? arg) (apply arg args) arg))

(provide auto-fg)

(define (auto-fg bg-fn)
  (lambda args (contrast-text (apply resolve-color bg-fn args))))
