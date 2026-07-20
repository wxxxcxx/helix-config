;; statusline.scm
;; Statusline layout configuration and mode indicator

(require "helix/configuration.scm")
(require "helix/components.scm")
(require "helix/editor.scm")
(require "helix/misc.scm")
(require (only-in "helix/themes.scm" string->color))

;; ── Mode indicator ───────────────────────────────────────────────

(define *current-mode* "normal")

(define mode-labels
  (hash
    "normal" "❖ NORMAL"
    "insert" "❖ INSERT"
    "select" "❖ SELECT"))

(define insert-mode (string->editor-mode "insert"))
(define select-mode (string->editor-mode "select"))

(register-hook 'on-mode-switch
  (lambda (event)
    (define new-mode (mode-switch-new event))
    (cond
      [(equal? new-mode insert-mode) (set! *current-mode* "insert")]
      [(equal? new-mode select-mode) (set! *current-mode* "select")]
      [else (set! *current-mode* "normal")])))

(provide mode-indicator)

(define mode-indicator
  (status-element
    (lambda (doc-id focused?)
      (define scope (string-append "ui.statusline." *current-mode*))
      (define mode-style (theme-scope-ref scope))
      (define bg (or (style->bg mode-style) (style->fg mode-style)))
      (define label (string-append " " (hash-ref mode-labels *current-mode*) " "))
      (list (span "" (~> (style) (style-fg bg)))
            (span label
                  (~> (style)
                      (style-fg (string->color "#2E3440"))
                      (style-bg bg)
                      style-with-bold))
            (span "" (~> (style) (style-fg bg)))))))


;; ── Statusline layout ────────────────────────────────────────────

(provide init)

(define (init)
  (statusline
    #:left (list mode-indicator 'file-name 'file-modification-indicator)
    #:right (list 'diagnostics 'selections 'position 'file-indent-style
                  'position-percentage 'total-line-numbers 'version-control 'file-type)))
