;; Run at startup. Helix context is bound to *helix.cx*
(require (prefix-in helix. "helix/commands.scm"))
(require (prefix-in helix.static. "helix/static.scm"))
(require (prefix-in helix.keymaps. "helix/keymaps.scm"))
(require "helix/configuration.scm")
(require "helix/components.scm")

(require (only-in "smith.hx/smith.scm"
                  smith-plugin
                  smith-prune
                  smith-init))

;; Base config
(require "default.scm")
(default-init)



;; Statusline config
(require "statusline.scm")
(statusline-init)

;; Synchronize after every smith-plugin declaration has been evaluated.
(smith-init)

;; ── Input source switching ──────────────────────────────────────
(require "cogs/input-source/input-source.scm")
(input-source-init)

;; ── Splash screen (only on blank startup) ───────────────────────
(require "cogs/splash.scm")
(when (equal? (command-line) '("hx"))
  (show-splash))
