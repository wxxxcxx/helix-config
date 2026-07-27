;; cogs/indicators/mode.scm
;; — mode indicator

(require "helix/components.scm")
(require "helix/editor.scm")

(provide mode-style mode-indicator)

(define mode-labels
  (hash
    "normal" "❖ NORMAL "
    "insert" "❖ INSERT "
    "select" "❖ SELECT "))

(define (mode-name)
  (define mode (editor-mode))
  (cond
    [(equal? mode (string->editor-mode "insert")) "insert"]
    [(equal? mode (string->editor-mode "select")) "select"]
    [else "normal"]))

(define (mode-style)
  (theme-scope-ref (string-append "ui.statusline." (mode-name))))

(define (mode-indicator #:style (style (lambda args (style))))
  (status-element
    (lambda (view-id focused?)
      (define s (if (procedure? style) (style view-id focused?) style))
      (define label (if focused? (hash-ref mode-labels (mode-name)) "         "))
      (list (span label (~> s style-with-bold))))))
