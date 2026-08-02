(provide file-explorer-default-keybindings
         file-explorer-action-definitions
         file-explorer-action-names
         file-explorer-action-specifications)

(define file-explorer-default-keybindings
  (hash
    "k" 'up
    "up" 'up
    "j" 'down
    "down" 'down
    "h" 'parent
    "u" 'parent
    "l" 'open
    "enter" 'open
    "space" 'mark
    "\"" 'copy-register
    "b" 'bookmarks
    "m" 'move
    "Y" 'unyank
    "X" 'unyank
    "d" 'trash
    "D" 'delete
    "R" 'rename
    "q" 'quit
    "." 'toggle-hidden
    "f" 'filter
    "/" 'find
    "n" 'find-next
    "N" 'find-previous
    "s" 'sort
    "r" 'refresh
    "?" 'help
    "o" (list
          (hash
            "o" 'open-normal
            "v" 'open-vsplit
            "h" 'open-hsplit
            "c" 'open-close)
          "Open")
    "y" (list
          (hash
            "y" 'copy
            "a" 'copy-absolute
            "r" 'copy-relative
            "n" 'copy-filename)
          "Yank")
    "p" (list
          (hash
            "p" 'paste
            "!" 'paste-force)
          "Paste")
    "c" (list
          (hash
            "f" 'create-file
            "d" 'create-dir)
          "Create")
    "t" (list
          (hash
            "h" 'toggle-hidden)
          "Toggle")
    "g" (list
          (hash
            "r" 'refresh)
          "Goto / Action")))

(define file-explorer-action-definitions
  (list
    (list 'quit "Close file explorer.")
    (list 'down "Next entry")
    (list 'up "Previous entry")
    (list 'open "Open selected entry")
    (list 'open-normal "Open")
    (list 'open-close "Open and close explorer")
    (list 'open-vsplit "Open in vertical split")
    (list 'open-hsplit "Open in horizontal split")
    (list 'parent "Parent directory")
    (list 'mark "Mark entry")
    (list 'copy "Stage filesystem copy")
    (list 'copy-absolute "Copy absolute path")
    (list 'copy-relative "Copy relative path")
    (list 'copy-filename "Copy filename")
    (list 'copy-register "Select copy register")
    (list 'bookmarks "Bookmarks")
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
    (list 'filter "Live filter")
    (list 'find "Find")
    (list 'find-next "Find next")
    (list 'find-previous "Find previous")
    (list 'sort "Sort")
    (list 'refresh "Refresh")
    (list 'help "Show key bindings")))

(define (file-explorer-action-names)
  (map car file-explorer-action-definitions))

(define (file-explorer-action-specifications handler-ref)
  (map (lambda (definition)
         (list (car definition)
               (handler-ref (car definition))
               (list-ref definition 1)))
       file-explorer-action-definitions))
