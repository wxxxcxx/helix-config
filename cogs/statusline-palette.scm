;; cogs/statusline-palette.scm
;; Dynamic colors used by the statusline layout.

(require "helix/components.scm")
(require "helix/editor.scm")
(require "cogs/color.scm")

(provide major-bg
         minor
         contrast-bg)

(define default-major-bg "#5E81AC")

(define (mode-name)
  (define mode (editor-mode))
  (cond
    [(equal? mode (string->editor-mode "insert")) "insert"]
    [(equal? mode (string->editor-mode "select")) "select"]
    [else "normal"]))

(define (major-bg)
  (let* ([style (theme-scope-ref (string-append "ui.statusline." (mode-name)))]
         [color (or (style->bg style) (style->fg style))])
    (if color (color->hex color) default-major-bg)))

(define (minor-bg factor)
  (darken (desaturate (major-bg) 0.3) factor))

(define (minor factor)
  (lambda () (minor-bg factor)))

(define (contrast-bg bg)
  (lambda ()
    (color->hex (contrast-text (if (procedure? bg) (bg) bg)))))
