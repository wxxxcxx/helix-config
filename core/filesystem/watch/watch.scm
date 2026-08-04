(require (only-in "helix/editor.scm" register-hook))
(require (only-in "registry.scm"
                  filesystem-watch-clear!
                  filesystem-watch-refresh!
                  filesystem-watch-refresh-all!
                  filesystem-watch-register!
                  filesystem-watch-unregister!))

(provide filesystem-watch-init
         filesystem-watch-clear!
         filesystem-watch-refresh!
         filesystem-watch-refresh-all!
         filesystem-watch-register!
         filesystem-watch-unregister!)

(define *filesystem-watch-initialized?* #f)

;; Installs the shared focus trigger once; callers own their subscriptions.
(define (filesystem-watch-init)
  (unless *filesystem-watch-initialized?*
    (register-hook 'terminal-focus-gained filesystem-watch-refresh-all!)
    (set! *filesystem-watch-initialized?* #t)))
