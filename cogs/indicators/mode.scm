;; cogs/indicators/mode.scm
;; — mode tracking + mode indicator

(require "helix/components.scm")
(require "helix/editor.scm")
(require "helix/misc.scm")
(require "cogs/indicators/core.scm")

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

(define (mode-indicator #:fg (fg-fn (lambda args Color/Reset))
                          #:bg (bg-fn (lambda args Color/Reset)))
  (status-element
    (lambda (view-id focused?)
      (list
        (span (hash-ref mode-labels *current-mode*)
              (~> (style)
                  (style-fg (resolve-color fg-fn focused?))
                  (style-bg (resolve-color bg-fn focused?))
                  style-with-bold))))))
