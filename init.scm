;; Run at startup. Helix context is bound to *helix.cx*
(require (prefix-in helix. "helix/commands.scm"))
(require (prefix-in helix.static. "helix/static.scm"))

(require (only-in "smith.hx/smith.scm"
                  smith-plugin
                  smith-prune
                  smith-init))
;; forest.hx: file tree explorer
;; https://github.com/Ra77a3l3-jar/forest.hx
(smith-plugin "https://github.com/Ra77a3l3-jar/forest.hx.git"
  (config
   ;; Side ('left or 'right) and entries to always hide
   (forest-configure! 'left #:ignore (list ".git" "target" "__pycache__"))

   ;; UI style: 'snacks (persistent sidebar) or 'mini (floating columns)
   (forest-set-style! 'snacks))

  ;; Keybindings: open forest with Space e in normal mode
  (bind
   ("normal" ("space" "e") ":forest-open")))

;; Synchronize plugin declarations: install missing, prune removed, load enabled
(smith-init)
