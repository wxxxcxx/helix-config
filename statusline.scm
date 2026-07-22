;; statusline.scm
;; Statusline — color definitions + default layout

(require "helix/configuration.scm")
(require (only-in "helix/themes.scm" string->color))
(require "cogs/indicators/indicators.scm")
(require "cogs/color.scm")
(require "cogs/file-tree.scm")

(provide major-bg minor-bg text-color accent statusline-init)

;; ── Base color functions ─────────────────────────────────────────

(define (major-bg focused?)
  (define base (or (style->bg (mode-style)) (style->fg (mode-style))))
  (if (and focused? (not (file-tree-focused?))) base (desaturate base 0.05)))

(define (minor-bg n focused?)
  (darken (desaturate (major-bg focused?) 0.3) n))

(define (text-color) (string->color "#D8DEE9"))
(define (accent) (string->color "#88C0D0"))

;; ── Style factories (view-id focused?) -> Style ─────────────────

(define (content bg-fn)
  (lambda (v f)
    (define bg (bg-fn f))
    (named-style (contrast-text bg) bg)))

(define (arc fg-fn)
  (lambda (v f)
    (style-fg (style) (fg-fn f))))

(define (arc2 fg-fn bg-fn)
  (lambda (v f)
    (~> (style) (style-fg (fg-fn f)) (style-bg (bg-fn f)))))

;; Pre-curried minor levels
(define minor-0.4 (lambda (f) (minor-bg 0.4 f)))
(define minor-0.3 (lambda (f) (minor-bg 0.3 f)))
(define minor-0.2 (lambda (f) (minor-bg 0.2 f)))

;; ── Statusline layout ────────────────────────────────────────────

(define (statusline-init)
  (bufferline "never")
  (statusline
    #:center (list 'primary-selection-length 'file-indent-style 'file-line-ending 'file-encoding
                   'read-only-indicator 'diagnostics 'workspace-diagnostics 'spinner)
    #:left (list
      (left-arc-indicator #:style (arc major-bg))
      (mode-indicator #:style (content major-bg))
      (right-arc-indicator #:style (arc2 major-bg minor-0.4))
      (version-control-indicator #:style (content minor-0.4))
      (right-arc-indicator #:style (arc2 minor-0.4 minor-0.3))
      (file-name-indicator #:style (content minor-0.3))
      (right-arc-indicator #:style (arc minor-0.3)))
    #:right (list
      (left-arc-indicator #:style (arc minor-0.2))
      (selections-indicator #:style (content minor-0.2))
      (left-arc-indicator #:style (arc2 minor-0.3 minor-0.2))
      (position-indicator #:style (content minor-0.3))
      (left-arc-indicator #:style (arc2 minor-0.4 minor-0.3))
      (buffers-indicator #:style (content minor-0.4))
      (left-arc-indicator #:style (arc2 major-bg minor-0.4))
      (file-type-indicator #:style (content major-bg))
      (right-arc-indicator #:style (arc major-bg)))))
