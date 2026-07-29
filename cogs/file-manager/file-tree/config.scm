(require "cogs/file-manager/core/keymap.scm")

(provide file-tree-configure! ft-config-ref)

(define *ft-config*
  (hash
    'side 'left
    'width 38
    'hide-on-open #f
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

(define (file-tree-configure! #:side [side #f] #:width [width #f]
                             #:hide-on-open [hide-on-open 'unset]
                             #:key [keybindings #f])
  (when side
    (unless (or (equal? side 'left) (equal? side 'right))
      (error! "file-tree: side must be 'left or 'right"))
    (set! *ft-config* (hash-insert *ft-config* 'side side)))
  (when width
    (unless (and (number? width) (>= width 24))
      (error! "file-tree: width must be at least 24"))
    (set! *ft-config* (hash-insert *ft-config* 'width width)))
  (unless (equal? hide-on-open 'unset)
    (unless (boolean? hide-on-open)
      (error! "file-tree: hide-on-open must be a boolean"))
    (set! *ft-config* (hash-insert *ft-config* 'hide-on-open hide-on-open)))
  (when keybindings
    (set! *ft-config*
          (hash-insert *ft-config* 'keybindings
                       (fm-keymap-merge (hash-get *ft-config* 'keybindings)
                                        keybindings)))))

(define (ft-config-ref key)
  (hash-get *ft-config* key))
