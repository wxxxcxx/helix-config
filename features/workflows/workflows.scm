(require (only-in "features/file-manager/file-manager.scm"
                  file-tree-set-layout-hooks!))
(require (only-in "features/terminal/terminal.scm"
                  terminal-raise-if-active!
                  terminal-set-horizontal-insets!))

(provide workflows-init)

(define (workflows-init-file-tree!)
  ;; The terminal is repushed only to preserve component z-order; its own
  ;; focused flag is intentionally left unchanged by raise-terminal-if-active!.
  (file-tree-set-layout-hooks!
    (lambda (side width)
      (if (equal? side 'right)
          (terminal-set-horizontal-insets! 0 width)
          (terminal-set-horizontal-insets! width 0))
      (terminal-raise-if-active!))
    (lambda () (terminal-set-horizontal-insets! 0 0))))

(define (workflows-init)
  (workflows-init-file-tree!))
