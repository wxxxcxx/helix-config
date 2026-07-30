(require (only-in "cogs/ivy/commands.scm"
                  ivy-buffer-init
                  ivy-recent-file-init))
(require (only-in "cogs/file-manager/file-tree/file-tree.scm"
                  file-tree-init
                  file-tree-set-layout-hooks!))
(require (only-in "cogs/terminal.scm"
                  terminal-raise-if-active!
                  terminal-set-horizontal-insets!))

(provide workflows-init)

(define (workflows-init-pickers!)
  (ivy-buffer-init)
  (ivy-recent-file-init))

(define (workflows-init-file-tree!)
  ;; The terminal is repushed only to preserve component z-order; its own
  ;; focused flag is intentionally left unchanged by raise-terminal-if-active!.
  (file-tree-set-layout-hooks!
    (lambda (side width)
      (if (equal? side 'right)
          (terminal-set-horizontal-insets! 0 width)
          (terminal-set-horizontal-insets! width 0))
      (terminal-raise-if-active!))
    (lambda () (terminal-set-horizontal-insets! 0 0)))
  (file-tree-init))

(define (workflows-init)
  (workflows-init-pickers!)
  (workflows-init-file-tree!))
