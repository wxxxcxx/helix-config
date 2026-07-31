;; Import all so newer steel-pty can expose the optional ignored-event hook
;; without making this adapter fail to load against older installs.
(require "steel-pty/panel.scm")
(require (only-in "helix/misc.scm" set-warning!))
(require (only-in "features/panel/panel.scm"
                  panel-handle-ignored-event
                  panel-fullscreen-mode
                  panel-mode
                  panel-show!
                  panel-toggle-fullscreen!))

;; Run `steel setup.scm` once before initializing the embedded terminal.

(provide terminal-init
         terminal-kill-active
         terminal-new
         terminal-open
         terminal-panel-mode
         terminal-raise-if-active!
         terminal-set-horizontal-insets!
         terminal-switch-next
         terminal-switch-previous
         terminal-toggle-fullscreen)

(define terminal-raise-if-active! raise-terminal-if-active!)
(define terminal-set-horizontal-insets! set-terminal-horizontal-insets!)
;;@doc
;; Switch to the next terminal.
(define terminal-switch-next switch-term)
;;@doc
;; Switch to the previous terminal.
(define terminal-switch-previous switch-term-previous)

;;@doc
;; Kill the currently active embedded terminal.
(define (terminal-kill-active)
  ;; `steel-pty` assumes a terminal exists. Keep this command safe as a user
  ;; binding so pressing it without an active terminal does not break the flow.
  (with-handler
    (lambda (error-value)
      (set-warning! (string-append "terminal: no active terminal to kill: "
                                   (to-string error-value))))
    (kill-active-terminal)))

(define (terminal-panel-layout! slot size left right bottom)
  (unless (equal? slot 'bottom)
    (error! "terminal: panel mode must use the bottom slot"))
  (set-terminal-fraction size)
  (set-terminal-horizontal-insets! left right)
  (when (or (> bottom 0) (equal? (panel-fullscreen-mode) 'terminal))
    (raise-terminal-if-active!)))

(define (terminal-panel-mode)
  (panel-mode
    #:open (lambda (_slot _size) (open-term))
    #:close hide-terminal
    #:layout terminal-panel-layout!
    #:fullscreen (lambda (_enabled?) (toggle-terminal-fullscreen))))

;;@doc
;; Open a new embedded terminal in the bottom panel.
(define (terminal-new)
  (panel-show! 'terminal (lambda (_slot _size) (new-term))))

;;@doc
;; Open or focus the embedded terminal in the bottom panel.
(define (terminal-open)
  (panel-show! 'terminal))

;;@doc
;; Toggle terminal fullscreen mode.
(define (terminal-toggle-fullscreen)
  (panel-show! 'terminal)
  (panel-toggle-fullscreen!))

(define (terminal-configure-shell!)
  (define user-shell (with-handler (lambda (_) #f) (env-var "SHELL")))
  (when (and user-shell (path-exists? user-shell))
    (set-default-shell! user-shell)))

(define (terminal-install-panel-fallback!)
  (with-handler
    (lambda (_)
      (set-warning! "terminal: panel fallback hook unavailable; update steel-pty")
      void)
    ((eval 'set-terminal-ignored-event-handler!)
     (lambda (event fallback)
       (panel-handle-ignored-event event fallback)))))

(define (terminal-init)
  (terminal-install-panel-fallback!)
  (terminal-configure-shell!))
