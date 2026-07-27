;; cogs/indicators/mode.scm
;; — mode indicator

(require "helix/components.scm")
(require "helix/editor.scm")
(require "cogs/indicators/style.scm")

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

(define (mode-indicator #:fg (fg #f) #:bg (bg #f))
  (status-element
    (lambda (view-id focused?)
      (define label (if focused? (hash-ref mode-labels (mode-name)) "         "))
      (list (span label (~> (make-style fg bg focused?) style-with-bold))))))
