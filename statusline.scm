;; statusline.scm
;; Statusline — color definitions + default layout

(require "helix/configuration.scm")
(require (only-in "helix/themes.scm" string->color))
(require "cogs/indicators/indicators.scm")
(require "cogs/color.scm")
(require "cogs/file-tree.scm")

;; ── Color thunks ─────────────────────────────────────────────────

(provide major-bg minor-bg text-color accent)

(define (major-bg . args)
  (define focused? (if (null? args) #t (car args)))
  (define base (or (style->bg (mode-style)) (style->fg (mode-style))))
  (if (and focused? (not (file-tree-focused?))) base (desaturate base 0.05)))

(define (minor-bg factor . args)
  (define focused? (if (null? args) #t (car args)))
  (darken (desaturate (major-bg focused?) 0.3) factor))

(define (text-color) (string->color "#D8DEE9"))

(define (accent) (string->color "#88C0D0"))

;; ── Shorthand helpers ────────────────────────────────────────────

(define (m n)
  (lambda args (apply minor-bg n args)))
(define (a n)
  (auto-fg (lambda args (apply minor-bg n args))))

;; ── Statusline layout ────────────────────────────────────────────

(provide statusline-init)

(define (statusline-init)
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
