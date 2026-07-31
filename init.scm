;; Run at startup. Helix context is bound to *helix.cx*.
(require-builtin steel/meta as steel.meta.)
(require (only-in "helix/configuration.scm" rainbow-brackets))
(require (prefix-in helix.keymaps. "helix/keymaps.scm"))
(require (only-in "helix/misc.scm" set-warning!))
(require (only-in "use-feature.scm"
                  use-feature
                  use-feature-report-failures!))

;; steel/meta bindings must be evaluated in the startup module.
(when (string=? (or (with-handler (lambda (_) #f) (env-var "TERM")) "") "")
  (steel.meta.set-env-var! "TERM" "xterm-256color"))
(when (string=? (or (with-handler (lambda (_) #f) (env-var "COLORTERM")) "") "")
  (steel.meta.set-env-var! "COLORTERM" "truecolor"))

(rainbow-brackets #t)

(use-feature editor
  (:load "features/editor/editor.scm")
  (:config (editor-init)))

(use-feature statusline
  (:load "features/statusline/statusline.scm")
  (:config (statusline-init)))

(use-feature panel
  (:load "features/panel/panel.scm")
  (:config (panel-init)))

(use-feature terminal
  (:depends panel)
  (:load "features/terminal/terminal.scm")
  (:config
    (panel-register-mode! 'bottom 'terminal (terminal-panel-mode))
    (terminal-init)
    (helix.keymaps.keymap (global)
      (normal ("C-`" terminal-open)
              ("C-S-`" terminal-new)
              ("C-ret" terminal-toggle-fullscreen)
              ("C-pageup" terminal-switch-previous)
              ("C-pagedown" terminal-switch-next))
      (insert ("C-`" terminal-open)
              ("C-S-`" terminal-new)
              ("C-ret" terminal-toggle-fullscreen)
              ("C-pageup" terminal-switch-previous)
              ("C-pagedown" terminal-switch-next)))))

(use-feature ivy
  (:load "features/ivy/commands.scm")
  (:config
    (ivy-init)
    (helix.keymaps.keymap (global)
      (normal ("/" ivy-search)
              (space (f ivy-find-file)
                     (b ivy-buffer)
                     ("/" ivy-project-search)
                     (r ivy-recent-file)
                     (T ivy-theme)
                     ("?" ivy-commands))))))

(use-feature file-manager
  (:depends panel)
  (:load "features/file-manager/file-manager.scm")
  (:config
    (panel-register-mode! 'left 'file-tree (file-tree-panel-mode))
    (file-manager-init)
    (helix.keymaps.keymap (global)
      (normal (space (e file-explorer-open)
                     ;; Space t is an open/focus command. File Tree owns `q`
                     ;; for explicit close while it has focus.
                     (t file-tree-open))))))

;; Loading a command-only feature makes it available to the command palette.
(use-feature lsp-status
  (:load "features/lsp-status/lsp-status.scm"))

(use-feature input-source
  (:load "features/input-source/input-source.scm")
  (:config (input-source-init)))

(use-feature splash
  (:load "features/splash/splash.scm")
  (:config (splash-smart-show)))

;; Apply after all user language configuration so existing LSP definitions and
;; ordering are preserved; color-swatches is appended as the final server.
(use-feature color-swatches
  (:load "features/color-swatches/color-swatches.scm")
  (:config (color-swatches-init)))

(use-feature-report-failures! set-warning!)
