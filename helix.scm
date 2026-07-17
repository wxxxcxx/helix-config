(require "helix/editor.scm")
(require (prefix-in helix. "helix/commands.scm"))
(require (prefix-in helix.static. "helix/static.scm"))

(require (only-in "smith.hx/smith.scm"
                  smith-install
                  smith-init
                  smith-self-update
                  smith-ensure
                  smith-configure!
                  smith-lock
                  smith-restore
                  smith-prune
                  smith-update
                  smith-remove
                  smith-enable
                  smith-disable
                  smith-load
                  smith-load-all
                  smith-list))

(provide smith-install
         smith-init
         smith-self-update
         smith-ensure
         smith-configure!
         smith-lock
         smith-restore
         smith-prune
         smith-update
         smith-remove
         smith-enable
         smith-disable
         smith-load
         smith-load-all
         smith-list)
