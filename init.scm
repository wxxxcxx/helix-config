;; Run at startup. Helix context is bound to *helix.cx*
(require (prefix-in helix. "helix/commands.scm"))
(require (prefix-in helix.static. "helix/static.scm"))
(require (prefix-in helix.keymaps. "helix/keymaps.scm"))

(require (only-in "smith.hx/smith.scm"
                  smith-plugin
                  smith-prune
                  smith-init))

(smith-plugin "https://github.com/Ra77a3l3-jar/forest.hx.git"
  (config
   ;; Use 'right instead of 'left to move the sidebar.
   (forest-configure! 'left #:ignore (list ".git" "target" "__pycache__"))

   ;; Select 'snacks (persistent sidebar) or 'mini (floating).
   (forest-set-style! 'snacks))

  ;; Open or focus forest.hx with Space e in normal mode. Bindings are data,
  ;; so the keymap macro does not cross Smith's delayed evaluation boundary.
  (bind
   ("normal" ("space" "e") ":forest-open")))

;; Synchronize after every smith-plugin declaration has been evaluated.
(smith-init)
