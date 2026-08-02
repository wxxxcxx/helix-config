(require "features/file-manager/core/keymap.scm")
(require (only-in "features/file-manager/core/file-style.scm" file-icon-style?))
(require (only-in "features/file-manager/file-tree/defaults.scm"
                  file-tree-default-keybindings))

(provide file-tree-configure! ft-config-ref ft-set-panel-layout!)

(define *ft-config*
  (hash
    'side 'left
    'width 38
    'hide-on-open #f
    'icon-style 'full
    'keybindings file-tree-default-keybindings))

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
