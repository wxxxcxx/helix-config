;; Dynamic mode-aware colors shared by editor components.

(require "helix/components.scm")
(require "helix/editor.scm")
(require "features/ui/color.scm")

(provide major-bg
         minor
         contrast-bg
         statusline-mode-name)

(define default-major-bg "#5E81AC")
(define insert-major-bg "#B48EAD")
(define select-major-bg "#A3BE8C")

(define (statusline-mode-name)
  (define mode (editor-mode))
  (cond
    [(equal? mode (string->editor-mode "insert")) "insert"]
    [(equal? mode (string->editor-mode "select")) "select"]
    [else "normal"]))

(define (major-bg)
  (define mode-name (statusline-mode-name))
  (if (color-terminal?)
      (let* ([style (theme-scope-ref (string-append "ui.statusline." mode-name))]
             [color (or (style->bg style) (style->fg style))])
        (if color (color->hex color) default-major-bg))
      (cond [(equal? mode-name "insert") insert-major-bg]
            [(equal? mode-name "select") select-major-bg]
            [else default-major-bg])))

(define (minor-bg factor)
  (darken (desaturate (major-bg) 0.3) factor))

(define (minor factor)
  (lambda () (minor-bg factor)))

(define (contrast-bg bg)
  (lambda ()
    (color->hex (contrast-text (if (procedure? bg) (bg) bg)))))
