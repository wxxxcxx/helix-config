;; cogs/indicators/mode.scm
;; — mode tracking + mode indicator

(require "helix/components.scm")
(require "helix/editor.scm")
(require "helix/misc.scm")

(provide mode-style mode-indicator)

(define *current-mode* "normal")

(define mode-labels
  (hash
    "normal" "❖ NORMAL "
    "insert" "❖ INSERT "
    "select" "❖ SELECT "))

(define insert-mode (string->editor-mode "insert"))
(define select-mode (string->editor-mode "select"))

(register-hook 'on-mode-switch
  (lambda (event)
    (define new-mode (mode-switch-new event))
    (cond
      [(equal? new-mode insert-mode) (set! *current-mode* "insert")]
      [(equal? new-mode select-mode) (set! *current-mode* "select")]
      [else (set! *current-mode* "normal")])))

(define (mode-style)
  (theme-scope-ref (string-append "ui.statusline." *current-mode*)))

(define (mode-indicator #:style (style (lambda args (style))))
  (status-element
    (lambda (view-id focused?)
      (define s (if (procedure? style) (style view-id focused?) style))
      (list
        (span (if focused? (hash-ref mode-labels *current-mode*) "         ")
              (~> s style-with-bold))))))
