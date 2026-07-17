;; Run at startup. Helix context is bound to *helix.cx*
(require (prefix-in helix. "helix/commands.scm"))
(require (prefix-in helix.static. "helix/static.scm"))
(require (prefix-in helix.keymaps. "helix/keymaps.scm"))

(require (only-in "smith.hx/smith.scm"
                  smith-ensure
                  smith-configure!
                  smith-init
                  smith-apply-bindings!))

;; forest.hx: file tree explorer
;; https://github.com/Ra77a3l3-jar/forest.hx
;;
;; Ensure it's installed
(smith-ensure "https://github.com/Ra77a3l3-jar/forest.hx.git")

;; Load and configure
(require "forest/forest.scm")
(forest-configure! 'left #:ignore (list ".git" "target" "__pycache__"))
(forest-set-style! 'snacks)

;; Apply bindings
(smith-apply-bindings! '(("normal" ("space" "e") ":forest-open")))

;; Synchronize plugin declarations: install missing, prune removed
(smith-init)
