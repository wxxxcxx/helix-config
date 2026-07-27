;; statusline.scm
;; Statusline — layout

(require "helix/configuration.scm")
(require "helix/components.scm")
(require "helix/editor.scm")
(require "cogs/indicators/indicators.scm")
(require "cogs/color.scm")
(provide statusline-init)

(define (major-bg)
  (define mode (editor-mode))
  (define mode-name
    (cond
      [(equal? mode (string->editor-mode "insert")) "insert"]
      [(equal? mode (string->editor-mode "select")) "select"]
      [else "normal"]))
  (let ([color (or (style->bg (theme-scope-ref (string-append "ui.statusline." mode-name)))
                   (style->fg (theme-scope-ref (string-append "ui.statusline." mode-name))))])
    (if color (color->hex color) "#5E81AC")))

(define (minor-bg n)
  (darken (desaturate (major-bg) 0.3) n))

(define (minor n) (lambda () (minor-bg n)))

(define (contrast-bg bg)
  (lambda ()
    (color->hex (contrast-text (if (procedure? bg) (bg) bg)))))

(define (statusline-init)
  (bufferline "never")
  (statusline
    #:center (list 'primary-selection-length 'file-indent-style 'file-line-ending 'file-encoding
                   'read-only-indicator 'diagnostics 'workspace-diagnostics 'spinner)
    #:left (list
      (left-arc-indicator #:fg major-bg)
      (mode-indicator #:fg (contrast-bg major-bg) #:bg major-bg)
      (right-arc-indicator #:fg major-bg #:bg (minor 0.4))
      (version-control-indicator #:fg (contrast-bg (minor 0.4)) #:bg (minor 0.4))
      (right-arc-indicator #:fg (contrast-bg (minor 0.3)) #:bg (minor 0.3))
      (file-name-indicator #:fg (contrast-bg (minor 0.3)) #:bg (minor 0.3))
      (right-arc-indicator #:fg (minor 0.3)))
    #:right (list
      (left-arc-indicator #:fg (minor 0.2))
      (selections-indicator #:fg (contrast-bg (minor 0.2)) #:bg (minor 0.2))
      (left-arc-indicator #:fg (contrast-bg (minor 0.3)) #:bg (minor 0.3))
      (position-indicator #:fg (contrast-bg (minor 0.3)) #:bg (minor 0.3))
      (left-arc-indicator #:fg (contrast-bg (minor 0.4)) #:bg (minor 0.4))
      (buffers-indicator #:fg (contrast-bg (minor 0.4)) #:bg (minor 0.4))
      (left-arc-indicator #:fg major-bg #:bg (minor 0.4))
      (file-type-indicator #:fg (contrast-bg major-bg) #:bg major-bg)
      (right-arc-indicator #:fg major-bg))))
