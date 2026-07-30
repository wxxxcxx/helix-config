;; Run at startup. Helix context is bound to *helix.cx*.
(require-builtin steel/meta as steel.meta.)
(require (only-in "helix/configuration.scm" rainbow-brackets))
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

(use-feature default
  (:load "default.scm")
  (:config (default-init)))

(use-feature statusline
  (:load "statusline.scm")
  (:config (statusline-init)))

(use-feature terminal
  (:load "cogs/terminal.scm")
  (:config (terminal-init)))

(use-feature workflows
  (:load "cogs/workflows.scm")
  (:config (workflows-init)))

(use-feature keybindings
  (:load "cogs/keybindings.scm")
  (:config (keybindings-init)))

;; Loading a command-only feature makes it available to the command palette.
(use-feature lsp-status
  (:load "cogs/lsp-status.scm"))

(use-feature input-source
  (:load "cogs/input-source/input-source.scm")
  (:config (input-source-init)))

(use-feature splash
  (:load "cogs/splash.scm")
  (:config (splash-smart-show)))

;; Apply after all user language configuration so existing LSP definitions and
;; ordering are preserved; color-swatches is appended as the final server.
(use-feature color-swatches
  (:load "cogs/color-swatches/color-swatches.scm")
  (:config (color-swatches-init)))

(use-feature-report-failures! set-warning!)
