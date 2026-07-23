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

;; Rainbow brackets
(rainbow-brackets #t)



;; Statusline config
(require "statusline.scm")
(statusline-init)

;; Synchronize after every smith-plugin declaration has been evaluated.
(smith-init)

;; ── Keybindings ─────────────────────────────────────────────────
(require "cogs/file-explorer.scm")
(helix.keymaps.keymap (global)
  (normal (space (e ":file-explorer-open"))))

;; ── Input source switching ──────────────────────────────────────
(require "cogs/input-source/input-source.scm")
(input-source-init)

;; ── Splash screen (only on blank startup) ───────────────────────
(require "cogs/splash.scm")
(splash-smart-show)
