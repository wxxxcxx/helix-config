(provide file-explorer-configure! fe-config-ref)

(define *fe-config*
  (hash 'width-pct 80 'height-pct 70
        'col-ratios '(20 40 40)
        'show-hidden #f
        'keybindings
        (hash "up"          '("k" "up")
              "down"        '("j" "down")
              "parent"      "h"
              "open"        '("l" "enter")
              "mark"        " "
              "copy"        "y"
              "copy-value"  "c"
              "copy-register" "\""
              "move"        "x"
              "paste"       "p"
              "paste-force" "P"
              "unyank"      '("Y" "X")
              "trash"       "d"
              "delete"      "D"
              "rename"      "r"
              "create"      "a"
              "quit"        "q"
              "toggle-hidden" "."
              "filter"      "f"
              "find"        "/"
              "find-prev"   "?"
              "find-next"   "n"
              "find-previous" "N"
              "sort"        ","
              "refresh"     "R")))

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
                                   (hash-union old keybindings)))))

(define (fe-config-ref key)
  (hash-get *fe-config* key))
