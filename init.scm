;; Run at startup. Helix context is bound to *helix.cx*.
(require-builtin steel/meta as steel.meta.)
(require (only-in "helix/configuration.scm" rainbow-brackets))
(require (prefix-in helix.keymaps. "helix/keymaps.scm"))
(require (only-in "helix/misc.scm" set-warning!))
(require (only-in "feature.scm"
                  feature
                  feature-initialize!
                  feature-initialize-elapsed-milliseconds
                  feature-report-failures!))
(require (only-in "packages.scm" steel-pty-package))

;; steel/meta bindings must be evaluated in the startup module.
(when (string=? (or (with-handler (lambda (_) #f) (env-var "TERM")) "") "")
  (steel.meta.set-env-var! "TERM" "xterm-256color"))
(when (string=? (or (with-handler (lambda (_) #f) (env-var "COLORTERM")) "") "")
  (steel.meta.set-env-var! "COLORTERM" "truecolor"))

(rainbow-brackets #t)

(feature editor
  (:load "features/editor/editor.scm")
  (:config (editor-init)))

;; Command-only evaluation helpers, including Helix's prompt and buffer tools.
(feature eval
  (:load "features/eval/eval.scm"))

(feature statusline
  (:load "features/statusline/statusline.scm")
  (:config (statusline-init)))

(feature panel
  (:load "features/panel/panel.scm")
  (:config
    (panel-init)
    (panel-register-key! "C-ret" panel-toggle-fullscreen!)
    ;; Fullscreen belongs to the panel layout, independent of the active mode.
    (helix.keymaps.keymap (global)
      (normal ("C-ret" panel-toggle-fullscreen!))
      (insert ("C-ret" panel-toggle-fullscreen!)))))

(feature terminal
  (:depends panel)
  (:package steel-pty-package)
  (:load "features/terminal/terminal.scm")
  (:config
    (panel-register-mode! 'bottom 'terminal (terminal-panel-mode))
    (terminal-init)
    (helix.keymaps.keymap (global)
      (normal ("C-`" terminal-open)
              ("C-S-`" terminal-new)
              ("C-S-w" terminal-kill-active)
              ("C-pageup" terminal-switch-previous)
              ("C-pagedown" terminal-switch-next))
      (insert ("C-`" terminal-open)
              ("C-S-`" terminal-new)
              ("C-S-w" terminal-kill-active)
              ("C-pageup" terminal-switch-previous)
              ("C-pagedown" terminal-switch-next)))))

(feature ivy
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

(feature file-manager
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
(feature lsp-status
  (:load "features/lsp-status/lsp-status.scm"))

(feature input-source
  (:depends panel)
  (:load "features/input-source/input-source.scm")
  (:config (input-source-init)))

;; Apply after all user language configuration so existing LSP definitions and
;; ordering are preserved; color-swatches is appended as the final server.
(feature color-swatches
  (:load "features/color-swatches/color-swatches.scm")
  (:config (color-swatches-init)))

;; Initialize Splash last so its timing includes every other feature.
(feature splash
  (:load "features/splash/splash.scm")
  (:config
    (splash-smart-show (feature-initialize-elapsed-milliseconds))))

(feature-initialize!)
(feature-report-failures! set-warning!)
