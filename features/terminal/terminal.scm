(require (only-in "steel-pty/term.scm"
                  new-term
                  open-term
                  raise-terminal-if-active!
                  set-default-shell!
                  set-terminal-horizontal-insets!
                  set-terminal-fraction
                  switch-term
                  switch-term-previous
                  toggle-terminal-fullscreen))

;; Run `steel setup.scm` once before initializing the embedded terminal.

(provide terminal-init
         terminal-new
         terminal-open
         terminal-raise-if-active!
         terminal-set-horizontal-insets!
         terminal-switch-next
         terminal-switch-previous
         terminal-toggle-fullscreen)

;;@doc
;; Open a new embedded terminal.
(define terminal-new new-term)
;;@doc
;; Open or focus the embedded terminal.
(define terminal-open open-term)
(define terminal-raise-if-active! raise-terminal-if-active!)
(define terminal-set-horizontal-insets! set-terminal-horizontal-insets!)
;;@doc
;; Switch to the next terminal.
(define terminal-switch-next switch-term)
;;@doc
;; Switch to the previous terminal.
(define terminal-switch-previous switch-term-previous)
;;@doc
;; Toggle terminal fullscreen mode.
(define terminal-toggle-fullscreen toggle-terminal-fullscreen)

(define (terminal-configure-shell!)
  (define user-shell (with-handler (lambda (_) #f) (env-var "SHELL")))
  (when (and user-shell (path-exists? user-shell))
    (set-default-shell! user-shell)))

(define (terminal-init)
  (set-terminal-fraction 2/5)
  (terminal-configure-shell!))
