(require "cogs/file-manager/keymap.scm")

(provide file-explorer-configure! fe-config-ref)

(define *fe-config*
  (hash 'width-pct 80 'height-pct 70
        'col-ratios '(20 40 40)
        'show-hidden #f
        'keybindings
        (hash
          "k" '("up" "Previous entry")
          "up" '("up" "Previous entry")
          "j" '("down" "Next entry")
          "down" '("down" "Next entry")
          "h" '("parent" "Parent directory")
          "u" '("parent" "Parent directory")
          "l" '("open" "Open selected entry")
          "enter" '("open" "Open selected entry")
          "space" '("mark" "Mark entry")
          "\"" '("copy-register" "Select copy register")
          "b" '("bookmarks" "Bookmarks")
          "m" '("move" "Stage filesystem move")
          "Y" '("unyank" "Clear staged operation")
          "X" '("unyank" "Clear staged operation")
          "d" '("trash" "Move to trash")
          "D" '("delete" "Delete permanently")
          "R" '("rename" "Rename")
          "q" '("quit" "Close file explorer")
          "." '("toggle-hidden" "Toggle hidden files")
          "f" '("filter" "Live filter")
          "/" '("find" "Find")
          "n" '("find-next" "Find next")
          "N" '("find-previous" "Find previous")
          "s" '("sort" "Sort")
          "r" '("refresh" "Refresh")
          "?" '("help" "Show key bindings")
          "o" (list
                (hash
                  "o" '("open-normal" "Open")
                  "v" '("open-vsplit" "Open in vertical split")
                  "h" '("open-hsplit" "Open in horizontal split")
                  "c" '("open-close" "Open and close explorer"))
                "Open")
          "y" (list
                (hash
                  "y" '("copy" "Stage filesystem copy")
                  "a" '("copy-absolute" "Copy absolute path")
                  "r" '("copy-relative" "Copy relative path")
                  "n" '("copy-filename" "Copy filename"))
                "Yank")
          "p" (list
                (hash
                  "p" '("paste" "Paste")
                  "!" '("paste-force" "Paste and overwrite"))
                "Paste")
          "c" (list
                (hash
                  "f" '("create-file" "Create file")
                  "d" '("create-dir" "Create directory"))
                "Create")
          "t" (list
                (hash
                  "h" '("toggle-hidden" "Toggle hidden files"))
                "Toggle")
          "g" (list
                (hash
                  "r" '("refresh" "Refresh"))
                "Goto / Action"))))

(define (file-explorer-configure!
         #:key [keybindings #f]
         #:width-pct [width-pct #f]
         #:height-pct [height-pct #f]
         #:show-hidden [show-hidden #f])
  (when width-pct
    (set! *fe-config* (hash-insert *fe-config* 'width-pct width-pct)))
  (when height-pct
    (set! *fe-config* (hash-insert *fe-config* 'height-pct height-pct)))
  (when show-hidden
    (set! *fe-config* (hash-insert *fe-config* 'show-hidden show-hidden)))
  (when keybindings
    (define old (hash-get *fe-config* 'keybindings))
    (set! *fe-config* (hash-insert *fe-config* 'keybindings
                                   (fm-keymap-merge old keybindings)))))

(define (fe-config-ref key)
  (hash-get *fe-config* key))
