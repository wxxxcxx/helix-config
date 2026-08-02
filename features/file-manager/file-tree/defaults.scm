(provide file-tree-default-keybindings
         file-tree-action-definitions
         file-tree-action-names
         file-tree-action-specifications)

(define file-tree-default-keybindings
  (hash
    "q" 'quit
    "k" 'up
    "up" 'up
    "j" 'down
    "down" 'down
    "l" 'open
    "enter" 'open
    "h" 'collapse
    "H" 'collapse-parent
    "space" 'mark
    "\"" 'copy-register
    "m" 'move
    "Y" 'unyank
    "X" 'unyank
    "d" 'trash
    "D" 'delete
    "R" 'rename
    "." 'toggle-hidden
    "r" 'refresh
    "A-L" 'root-selected
    "A-H" 'root-parent
    "?" 'help
    "o" (list (hash "o" 'open-normal
                    "v" 'open-vsplit
                    "h" 'open-hsplit
                    "c" 'open-close)
              "Open")
    "y" (list (hash "y" 'copy
                    "a" 'copy-absolute
                    "r" 'copy-relative
                    "n" 'copy-filename)
              "Yank")
    "p" (list (hash "p" 'paste
                    "!" 'paste-force)
              "Paste")
    "c" (list (hash "f" 'create-file
                    "d" 'create-dir)
              "Create")
    "t" (list (hash "h" 'toggle-hidden
                    "f" 'follow)
              "Toggle")
    "g" (list (hash "r" 'refresh
                    "s" 'root-selected
                    "p" 'root-parent
                    "w" 'root-workspace
                    "f" 'root-file
                    "[" 'root-back
                    "]" 'root-forward
                    "/" 'root-prompt)
              "Goto / Action")))

(define file-tree-action-definitions
  (list
    (list 'quit "Close file tree.")
    (list 'down "Next entry")
    (list 'up "Previous entry")
    (list 'open "Open selected entry")
    (list 'open-normal "Open")
    (list 'open-vsplit "Open in vertical split")
    (list 'open-hsplit "Open in horizontal split")
    (list 'open-close "Open and close tree")
    (list 'collapse "Collapse or select parent")
    (list 'collapse-parent "Collapse parent directory")
    (list 'mark "Mark entry")
    (list 'copy "Stage filesystem copy")
    (list 'copy-absolute "Copy absolute path")
    (list 'copy-relative "Copy relative path")
    (list 'copy-filename "Copy filename")
    (list 'copy-register "Select copy register")
    (list 'move "Stage filesystem move")
    (list 'paste "Paste")
    (list 'paste-force "Paste and overwrite")
    (list 'unyank "Clear staged operation")
    (list 'trash "Move to trash")
    (list 'delete "Delete permanently")
    (list 'rename "Rename")
    (list 'create-file "Create file")
    (list 'create-dir "Create directory")
    (list 'toggle-hidden "Toggle hidden files")
    (list 'follow "Follow current file")
    (list 'refresh "Refresh")
    (list 'root-selected "Selected directory as root")
    (list 'root-parent "Parent directory as root")
    (list 'root-workspace "Workspace root")
    (list 'root-file "Current file directory")
    (list 'root-back "Previous root")
    (list 'root-forward "Next root")
    (list 'root-prompt "Enter root path")
    (list 'help "Show key bindings")))

(define (file-tree-action-names)
  (map car file-tree-action-definitions))

(define (file-tree-action-specifications handler-ref)
  (map (lambda (definition)
         (list (car definition)
               (handler-ref (car definition))
               (list-ref definition 1)))
       file-tree-action-definitions))
