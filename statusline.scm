;; statusline.scm
;; Statusline — default layout

(require "helix/configuration.scm")
(require "cogs/indicators.scm")

(provide init)

(define (init)
  (statusline
    #:left (list
      (make-left-arc #:fg major-bg)
      (make-mode-indicator #:fg (auto-fg major-bg) #:bg major-bg)
      (make-right-arc #:fg major-bg #:bg minor-bg)
      (make-file-name #:fg (auto-fg minor-bg) #:bg minor-bg)
      (make-modification-indicator #:fg (auto-fg minor-bg) #:bg minor-bg)
      (make-version-control #:fg (auto-fg minor-bg) #:bg minor-bg)
      (make-right-arc #:fg minor-bg))
    #:right (list
      (make-left-arc #:fg minor-bg )
      (make-selections #:fg (auto-fg minor-bg) #:bg minor-bg)
      (make-file-type #:fg (auto-fg minor-bg) #:bg minor-bg)
      ;; Ohter
      (make-left-arc #:fg major-bg #:bg minor-bg)
      (make-position #:fg (auto-fg major-bg) #:bg major-bg)
      (make-right-arc #:fg major-bg))))
