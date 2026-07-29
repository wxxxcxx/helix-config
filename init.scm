;; Run at startup. Helix context is bound to *helix.cx*
(require (prefix-in helix. "helix/commands.scm"))
(require (prefix-in helix.static. "helix/static.scm"))
(require (prefix-in helix.keymaps. "helix/keymaps.scm"))
(require "helix/configuration.scm")
(require "helix/components.scm")
(require "helix/misc.scm")

(require "cogs/smith.scm")

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

;; Synchronize after every smith-plugin declaration has been evaluated.
(smith-init)

;; ── Keybindings ─────────────────────────────────────────────────
(require "cogs/file-manager/file-explorer/file-explorer.scm")
(require "cogs/file-manager/file-tree/file-tree.scm")
(file-tree-init)
(helix.keymaps.keymap (global)
  (normal (space (e ":file-explorer-open")
                 (t ":file-tree-open"))))

;; ── Input source switching ──────────────────────────────────────
(require "cogs/input-source/input-source.scm")
(input-source-init)

;; ── Splash screen (only on blank startup) ───────────────────────
(require "cogs/splash.scm")
(splash-smart-show)

;; Apply after all user language configuration so existing LSP definitions and
;; ordering are preserved; color-swatches is appended as the final server.
(color-swatches-init)
