;; statusline.scm
;; Statusline — true-color layout with 256-color/ANSI fallback

(require "helix/configuration.scm")
(require (only-in "helix/themes.scm" string->color))
(require "cogs/indicators/indicators.scm")
(require "cogs/color.scm")
(provide statusline-init)

;; ── True-color helpers ───────────────────────────────────────────

(define (named-style fg bg)
  (~> (style) (style-fg fg) (style-bg bg)))

(define (major-bg)
  (or (style->bg (mode-style)) (style->fg (mode-style))))

(define (minor-bg n)
  (darken (desaturate (major-bg) 0.3) n))

(define (maybe-gray thunk focused?)
  (define base (thunk))
  (if focused? base (desaturate base 0.05)))

(define (content-style color-thunk)
  (lambda (v f)
    (define bg (maybe-gray color-thunk f))
    (named-style (contrast-text bg) bg)))

(define (edge-style color-thunk)
  (lambda (v f)
    (style-fg (style) (maybe-gray color-thunk f))))

(define (link-style fg-thunk bg-thunk)
  (lambda (v f)
    (~> (style) (style-fg (maybe-gray fg-thunk f)) (style-bg (maybe-gray bg-thunk f)))))

(define (minor n) (lambda () (minor-bg n)))

;; ── Fallback helpers (no true color) ─────────────────────────────

(define fallback-statusline-style
  (lambda (v f)
    (if f
        (theme-scope-ref "ui.statusline")
        (theme-scope-ref "ui.statusline"))))

(define (fallback-mode-indicator)
  (mode-indicator #:style fallback-statusline-style))

;; ── Statusline layout ────────────────────────────────────────────

(define (statusline-init)
  (bufferline "never")
  (if (color-terminal?)
      (tc-statusline)
      (fallback-statusline)))

(define (tc-statusline)
  (statusline
    #:center (list 'primary-selection-length 'file-indent-style 'file-line-ending 'file-encoding
                   'read-only-indicator 'diagnostics 'workspace-diagnostics 'spinner)
    #:left (list
      (left-arc-indicator #:style (edge-style major-bg))
      (mode-indicator #:style (content-style major-bg))
      (right-arc-indicator #:style (link-style major-bg (minor 0.4)))
      (version-control-indicator #:style (content-style (minor 0.4)))
      (right-arc-indicator #:style (link-style (minor 0.4) (minor 0.3)))
      (file-name-indicator #:style (content-style (minor 0.3)))
      (right-arc-indicator #:style (edge-style (minor 0.3))))
    #:right (list
      (left-arc-indicator #:style (edge-style (minor 0.2)))
      (selections-indicator #:style (content-style (minor 0.2)))
      (left-arc-indicator #:style (link-style (minor 0.3) (minor 0.2)))
      (position-indicator #:style (content-style (minor 0.3)))
      (left-arc-indicator #:style (link-style (minor 0.4) (minor 0.3)))
      (buffers-indicator #:style (content-style (minor 0.4)))
      (left-arc-indicator #:style (link-style major-bg (minor 0.4)))
      (file-type-indicator #:style (content-style major-bg))
      (right-arc-indicator #:style (edge-style major-bg)))))

(define (fallback-statusline)
  (statusline
    #:center (list 'primary-selection-length 'file-indent-style 'file-line-ending 'file-encoding
                   'read-only-indicator 'diagnostics 'workspace-diagnostics 'spinner)
    #:left (list
      (left-arc-indicator #:style fallback-statusline-style)
      (mode-indicator #:style fallback-statusline-style)
      (right-arc-indicator #:style fallback-statusline-style)
      (version-control-indicator #:style fallback-statusline-style)
      (file-name-indicator #:style fallback-statusline-style)
      (right-arc-indicator #:style fallback-statusline-style))
    #:right (list
      (left-arc-indicator #:style fallback-statusline-style)
      (selections-indicator #:style fallback-statusline-style)
      (position-indicator #:style fallback-statusline-style)
      (buffers-indicator #:style fallback-statusline-style)
      (file-type-indicator #:style fallback-statusline-style)
      (right-arc-indicator #:style fallback-statusline-style))))
