(require "features/file-manager/core/keymap.scm")
(require (only-in "features/file-manager/core/file-style.scm" file-icon-style?))
(require (only-in "features/file-manager/file-explorer/defaults.scm"
                  file-explorer-default-keybindings))

(provide file-explorer-configure! fe-config-ref)

(define *fe-config*
  (hash 'width-pct 80 'height-pct 70
        'col-ratios '(20 40 40)
        'show-hidden #f
        'icon-style 'full
        'keybindings file-explorer-default-keybindings))

(define (file-explorer-configure!
         #:key [keybindings #f]
         #:width-pct [width-pct #f]
         #:height-pct [height-pct #f]
         #:show-hidden [show-hidden 'unset]
         #:icon-style [icon-style 'unset])
  (when width-pct
    (unless (and (number? width-pct) (> width-pct 0) (<= width-pct 100))
      (error! "file-explorer: width-pct must be between 1 and 100"))
    (set! *fe-config* (hash-insert *fe-config* 'width-pct width-pct)))
  (when height-pct
    (unless (and (number? height-pct) (> height-pct 0) (<= height-pct 100))
      (error! "file-explorer: height-pct must be between 1 and 100"))
    (set! *fe-config* (hash-insert *fe-config* 'height-pct height-pct)))
  (unless (equal? show-hidden 'unset)
    (unless (boolean? show-hidden)
      (error! "file-explorer: show-hidden must be a boolean"))
    (set! *fe-config* (hash-insert *fe-config* 'show-hidden show-hidden)))
  (unless (equal? icon-style 'unset)
    (unless (file-icon-style? icon-style)
      (error! "file-explorer: icon-style must be 'simple, 'icons, or 'full"))
    (set! *fe-config* (hash-insert *fe-config* 'icon-style icon-style)))
  (when keybindings
    (define old (hash-get *fe-config* 'keybindings))
    (set! *fe-config* (hash-insert *fe-config* 'keybindings
                                   (fm-keymap-merge old keybindings)))))

(define (fe-config-ref key)
  (hash-get *fe-config* key))
