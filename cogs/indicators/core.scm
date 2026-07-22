;; cogs/indicators/core.scm
;; — helpers used by indicator factories

(require "helix/components.scm")
(require "cogs/color.scm")

(provide named-style)

(define (named-style fg bg)
  (~> (style) (style-fg fg) (style-bg bg)))

(provide resolve-color resolve-style)

(define (resolve-color arg . args)
  (if (procedure? arg) (apply arg args) arg))

(define (resolve-style style . args)
  (if (procedure? style) (apply style args) style))

(provide auto-fg)

(define (auto-fg bg-fn)
  (lambda args (contrast-text (apply resolve-color bg-fn args))))
