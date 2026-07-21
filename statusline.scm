;; statusline.scm
;; Statusline — color definitions + default layout

(require "helix/configuration.scm")
(require (only-in "helix/themes.scm" string->color))
(require "cogs/indicators.scm")
(require "cogs/color.scm")

;; ── Color thunks ─────────────────────────────────────────────────

(provide major-bg minor-bg text-color accent)

(define (major-bg)
  (or (style->bg (mode-style)) (style->fg (mode-style))))

(define (minor-bg)
  (darken (desaturate (major-bg) 0.3) 0.4))

(define (text-color) (string->color "#D8DEE9"))

(define (accent) (string->color "#88C0D0"))

;; ── Statusline layout ────────────────────────────────────────────

(provide init)

(define (init)
  (bufferline "never")
  (statusline
    #:center (list 'primary-selection-length 'file-indent-style 'file-line-ending 'file-encoding
                   'read-only-indicator 'diagnostics 'workspace-diagnostics 'spinner)
    #:left (list
      (left-arc-indicator #:fg major-bg)
      (mode-indicator #:fg (auto-fg major-bg) #:bg major-bg)
      (right-arc-indicator #:fg major-bg #:bg minor-bg)
      (version-control-indicator #:fg (auto-fg minor-bg) #:bg minor-bg)
      (file-name-indicator #:fg (auto-fg minor-bg) #:bg minor-bg)
      (right-arc-indicator #:fg minor-bg))
    #:right (list
      (left-arc-indicator #:fg minor-bg)
      (selections-indicator #:fg (auto-fg minor-bg) #:bg minor-bg)
      (position-indicator #:fg (auto-fg minor-bg) #:bg minor-bg)
      (buffers-indicator #:fg (auto-fg minor-bg) #:bg minor-bg)
      (left-arc-indicator #:fg major-bg #:bg minor-bg)
      (file-type-indicator #:fg (auto-fg major-bg) #:bg major-bg)
      (right-arc-indicator #:fg major-bg))))
