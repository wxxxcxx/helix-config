(require (only-in "features/ivy/commands/search.scm" ivy-search))
(require (only-in "features/ivy/commands/find-file.scm" ivy-find-file))
(require (only-in "features/ivy/commands/buffer.scm" ivy-buffer ivy-buffer-init))
(require (only-in "features/ivy/commands/project-search.scm" ivy-project-search))
(require (only-in "features/ivy/commands/recent-file.scm" ivy-recent-file ivy-recent-file-init))
(require (only-in "features/ivy/commands/theme.scm" ivy-theme))
(require (only-in "features/ivy/commands/execute.scm" ivy-commands))

(provide ivy-init
         ivy-search
         ivy-find-file
         ivy-buffer
         ivy-buffer-init
         ivy-project-search
         ivy-recent-file
         ivy-recent-file-init
         ivy-theme
         ivy-commands)

(define (ivy-init)
  (ivy-buffer-init)
  (ivy-recent-file-init))
