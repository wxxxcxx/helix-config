;; cogs/indicators/left-arc.scm

(require "helix/components.scm")
(require "cogs/indicators/core.scm")

(provide left-arc-indicator)

(define (left-arc-indicator #:fg (fg-fn (lambda () Color/Reset))
                             #:bg (bg-fn (lambda () Color/Reset)))
  (status-element
    (lambda (view-id focused?)
      (list (span "" (~> (style) (style-fg (resolve-color fg-fn)) (style-bg (resolve-color bg-fn))))))))
