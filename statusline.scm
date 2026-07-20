;; statusline.scm
;; Statusline — default layout

(require "helix/configuration.scm")
(require "cogs/indicators.scm")

(provide init)

(define (init)
  (statusline
    #:left (list
      (make-left-arc #:fg major-bg)
      (make-mode-indicator #:fg text-color #:bg major-bg)
      (make-right-arc #:fg major-bg #:bg minor-bg)
      (make-file-name #:fg text-color #:bg minor-bg)
      (make-modification-indicator #:fg text-color #:bg minor-bg)
      (make-version-control #:fg text-color #:bg minor-bg)
      (make-right-arc #:fg minor-bg))
    #:right (list
      (make-left-arc #:fg minor-bg)
      (make-selections #:fg text-color #:bg minor-bg)
      (make-file-type #:fg text-color #:bg minor-bg)
      (make-left-arc #:fg major-bg #:bg minor-bg)
      (make-position #:fg text-color #:bg major-bg)
      (make-right-arc #:fg major-bg))))
