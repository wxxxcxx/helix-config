(require "features/file-manager/core/keymap.scm")
(require (only-in "features/file-manager/core/file-style.scm" file-icon-style?))

(provide file-tree-configure! ft-config-ref ft-set-panel-layout!)

(define *ft-config*
  (hash
    'side 'left
    'width 38
    'hide-on-open #f
    'icon-style 'full
    'keybindings
    (hash
      "q" 'quit "k" 'up "up" 'up "j" 'down "down" 'down
      "l" 'open "enter" 'open "h" 'collapse "H" 'collapse-parent
      "space" 'mark "\"" 'copy-register "m" 'move
      "Y" 'unyank "X" 'unyank "d" 'trash "D" 'delete "R" 'rename
      "." 'toggle-hidden "r" 'refresh "A-L" 'root-selected
      "A-H" 'root-parent "?" 'help
      "o" (list (hash "o" 'open-normal "v" 'open-vsplit
                       "h" 'open-hsplit "c" 'open-close)
                "Open")
      "y" (list (hash "y" 'copy "a" 'copy-absolute
                       "r" 'copy-relative "n" 'copy-filename)
                "Yank")
      "p" (list (hash "p" 'paste "!" 'paste-force) "Paste")
      "c" (list (hash "f" 'create-file "d" 'create-dir) "Create")
      "t" (list (hash "h" 'toggle-hidden "f" 'follow) "Toggle")
      "g" (list (hash "r" 'refresh "s" 'root-selected "p" 'root-parent
                       "w" 'root-workspace "f" 'root-file
                       "[" 'root-back "]" 'root-forward "/" 'root-prompt)
                "Goto / Action"))))

(define (ft-set-panel-layout! side width)
  ;; Placement belongs to Panel; this internal adapter only updates the values
  ;; consumed by the existing File Tree renderer.
  (unless (or (equal? side 'left) (equal? side 'right))
    (error! "file-tree: panel slot must be 'left or 'right"))
  (unless (and (number? width) (>= width 16))
    (error! "file-tree: panel width must be at least 16"))
  (set! *ft-config* (hash-insert *ft-config* 'side side))
  (set! *ft-config* (hash-insert *ft-config* 'width width)))

(define (file-tree-configure! #:hide-on-open [hide-on-open 'unset]
                             #:icon-style [icon-style 'unset]
                             #:key [keybindings #f])
  (unless (equal? hide-on-open 'unset)
    (unless (boolean? hide-on-open)
      (error! "file-tree: hide-on-open must be a boolean"))
    (set! *ft-config* (hash-insert *ft-config* 'hide-on-open hide-on-open)))
  (unless (equal? icon-style 'unset)
    (unless (file-icon-style? icon-style)
      (error! "file-tree: icon-style must be 'simple, 'icons, or 'full"))
    (set! *ft-config* (hash-insert *ft-config* 'icon-style icon-style)))
  (when keybindings
    (set! *ft-config*
          (hash-insert *ft-config* 'keybindings
                       (fm-keymap-merge (hash-get *ft-config* 'keybindings)
                                        keybindings)))))

(define (ft-config-ref key)
  (hash-get *ft-config* key))
