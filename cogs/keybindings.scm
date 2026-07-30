(require (prefix-in helix.keymaps. "helix/keymaps.scm"))
(require (only-in "cogs/ivy/commands.scm"
                  ivy-buffer
                  ivy-commands
                  ivy-find-file
                  ivy-project-search
                  ivy-recent-file
                  ivy-search
                  ivy-theme))
(require (only-in "cogs/file-manager/file-explorer/file-explorer.scm"
                  file-explorer-open))
(require (only-in "cogs/file-manager/file-tree/file-tree.scm"
                  file-tree-open))
(require (only-in "cogs/terminal.scm"
                  terminal-new
                  terminal-open
                  terminal-switch-next
                  terminal-switch-previous
                  terminal-toggle-fullscreen))

(provide keybindings-init)

(define (keybindings-init)
  (helix.keymaps.keymap (global)
    (normal ("/" ivy-search)
            ("C-`" terminal-open)
            ("C-S-`" terminal-new)
            ("C-ret" terminal-toggle-fullscreen)
            ("C-pageup" terminal-switch-previous)
            ("C-pagedown" terminal-switch-next)
            (space (f ivy-find-file)
                   (b ivy-buffer)
                   ("/" ivy-project-search)
                   (r ivy-recent-file)
                   (T ivy-theme)
                   ("?" ivy-commands)
                   (e file-explorer-open)
                   (t file-tree-open)))
    (insert ("C-`" terminal-open)
            ("C-S-`" terminal-new)
            ("C-ret" terminal-toggle-fullscreen)
            ("C-pageup" terminal-switch-previous)
            ("C-pagedown" terminal-switch-next))))
