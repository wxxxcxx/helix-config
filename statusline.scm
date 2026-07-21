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

(define (minor-bg factor)
  (darken (desaturate (major-bg) 0.3) factor))

(define (text-color) (string->color "#D8DEE9"))

(define (accent) (string->color "#88C0D0"))

;; ── Shorthand helpers ────────────────────────────────────────────

(define (m n) (lambda () (minor-bg n)))
(define (a n) (auto-fg (m n)))

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
      (right-arc-indicator #:fg major-bg #:bg (m 0.4))
      (version-control-indicator #:fg (a 0.4) #:bg (m 0.4))
      (right-arc-indicator #:fg (m 0.4) #:bg (m 0.3))
      (file-name-indicator #:fg (a 0.3) #:bg (m 0.3))
      (right-arc-indicator #:fg (m 0.3)))
    #:right (list
      (left-arc-indicator #:fg (m 0.2))
      (selections-indicator #:fg (a 0.2) #:bg (m 0.2))
      (left-arc-indicator #:fg (m 0.3) #:bg (m 0.2))
      (position-indicator #:fg (a 0.3) #:bg (m 0.3))
      (left-arc-indicator #:fg (m 0.4) #:bg (m 0.3))
      (buffers-indicator #:fg (a 0.4) #:bg (m 0.4))
      (left-arc-indicator #:fg major-bg #:bg (m 0.4))
      (file-type-indicator #:fg (auto-fg major-bg) #:bg major-bg)
      (right-arc-indicator #:fg major-bg))))
