;; Run at startup. Helix context is bound to *helix.cx*
(require-builtin steel/meta as steel.meta.)
(require (prefix-in helix. "helix/commands.scm"))
(require (prefix-in helix.static. "helix/static.scm"))
(require (prefix-in helix.keymaps. "helix/keymaps.scm"))
(require "helix/configuration.scm")
(require "helix/components.scm")
(require "helix/misc.scm")

;; Base config
(require "default.scm")
(default-init)

;; LSP status command
(require "cogs/lsp-status.scm")

;; Scheme color swatches
(require "cogs/color-swatches/color-swatches.scm")

;; Rainbow brackets
(rainbow-brackets #t)



;; Statusline config
(require "statusline.scm")
(statusline-init)

;; Embedded terminal. Run ./setup.sh once before loading this configuration.
(when (string=? (or (with-handler (lambda (_) #f) (env-var "TERM")) "") "")
  (steel.meta.set-env-var! "TERM" "xterm-256color"))
(when (string=? (or (with-handler (lambda (_) #f) (env-var "COLORTERM")) "") "")
  (steel.meta.set-env-var! "COLORTERM" "truecolor"))
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
(set-terminal-fraction 2/5)
(let ([user-shell (with-handler (lambda (_) #f) (env-var "SHELL"))])
  (when (and user-shell (path-exists? user-shell))
    (set-default-shell! user-shell)))

;; ── Keybindings ─────────────────────────────────────────────────
(require (only-in "cogs/ivy/commands.scm"
                  ivy-search
                  ivy-find-file
                  ivy-buffer
                  ivy-buffer-init
                  ivy-project-search
                  ivy-recent-file
                  ivy-recent-file-init
                  ivy-theme
                  ivy-commands))
(ivy-buffer-init)
(ivy-recent-file-init)

(require "cogs/file-manager/file-explorer/file-explorer.scm")
(require "cogs/file-manager/file-tree/file-tree.scm")
(file-tree-set-layout-hooks!
  (lambda (side width)
    (if (equal? side 'right)
        (set-terminal-horizontal-insets! 0 width)
        (set-terminal-horizontal-insets! width 0))
    (raise-terminal-if-active!))
  (lambda () (set-terminal-horizontal-insets! 0 0)))
(file-tree-init)
(helix.keymaps.keymap (global)
  (normal ("/" ivy-search)
          ("C-`" open-term)
          ("C-S-`" new-term)
          ("C-ret" toggle-terminal-fullscreen)
          ("C-pageup" switch-term-previous)
          ("C-pagedown" switch-term)
          (space (f ivy-find-file)
                 (b ivy-buffer)
                 ("/" ivy-project-search)
                 (r ivy-recent-file)
                 (T ivy-theme)
                 ("?" ivy-commands)
                 (e ":file-explorer-open")
                 (t ":file-tree-open")))
  (insert ("C-`" open-term)
          ("C-S-`" new-term)
          ("C-ret" toggle-terminal-fullscreen)
          ("C-pageup" switch-term-previous)
          ("C-pagedown" switch-term)))

;; ── Input source switching ──────────────────────────────────────
(require "cogs/input-source/input-source.scm")
(input-source-init)

;; ── Splash screen (only on blank startup) ───────────────────────
(require "cogs/splash.scm")
(splash-smart-show)

;; Apply after all user language configuration so existing LSP definitions and
;; ordering are preserved; color-swatches is appended as the final server.
(color-swatches-init)
