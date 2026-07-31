(require (only-in "helix/editor.scm"
                  set-editor-clip-bottom!
                  set-editor-clip-left!
                  set-editor-clip-right!))

(provide panel-active-mode
         panel-close!
         panel-configure!
         panel-init
         panel-mode
         panel-register-mode!
         panel-show!
         panel-size
         panel-toggle!)

(define *panel-slots* '(left right bottom))
(define *panel-config*
  (hash 'left (hash 'size 38)
        'right (hash 'size 38)
        'bottom (hash 'size 2/5)))
(define *panel-modes*
  (hash 'left (hash) 'right (hash) 'bottom (hash)))
(define *panel-active*
  (hash 'left #f 'right #f 'bottom #f))

;; A mode owns its behavior; Panel owns only placement and lifecycle.
(define (panel-mode #:open open #:close close
                    #:layout [layout (lambda (_slot _size _left _right _bottom) void)])
  (hash 'open open 'close close 'layout layout))

(define (panel-valid-slot? slot)
  (or (equal? slot 'left)
      (equal? slot 'right)
      (equal? slot 'bottom)))

(define (panel-assert-slot! slot)
  (unless (panel-valid-slot? slot)
    (error! (string-append "panel: unknown slot " (to-string slot)))))

(define (panel-valid-size? slot size)
  (if (equal? slot 'bottom)
      (and (number? size) (> size 0) (<= size 1))
      (and (number? size) (>= size 16))))

(define (panel-size slot)
  (panel-assert-slot! slot)
  (hash-get (hash-get *panel-config* slot) 'size))

(define (panel-configure! slot #:size [size #f])
  (panel-assert-slot! slot)
  (when size
    (unless (panel-valid-size? slot size)
      (error! (string-append "panel: invalid size for " (symbol->string slot))))
    (set! *panel-config*
          (hash-insert *panel-config* slot (hash 'size size)))
    (panel-apply-layout!)))

(define (panel-active-mode slot)
  (panel-assert-slot! slot)
  (hash-get *panel-active* slot))

(define (panel-slot-modes slot)
  (hash-get *panel-modes* slot))

(define (panel-find-slot name)
  (cond [(hash-contains? (panel-slot-modes 'left) name) 'left]
        [(hash-contains? (panel-slot-modes 'right) name) 'right]
        [(hash-contains? (panel-slot-modes 'bottom) name) 'bottom]
        [else #f]))

(define (panel-mode-ref slot name)
  (panel-assert-slot! slot)
  (define modes (panel-slot-modes slot))
  (unless (hash-contains? modes name)
    (error! (string-append "panel: mode "
                           (to-string name)
                           " is not registered in "
                           (symbol->string slot))))
  (hash-get modes name))

(define (panel-register-mode! slot name mode)
  (panel-assert-slot! slot)
  (define existing-slot (panel-find-slot name))
  (when (and existing-slot (not (equal? existing-slot slot)))
    (error! (string-append "panel: mode already registered in "
                           (symbol->string existing-slot))))
  (set! *panel-modes*
        (hash-insert *panel-modes*
                     slot
                     (hash-insert (panel-slot-modes slot) name mode))))

(define (panel-active-size slot)
  (if (panel-active-mode slot) (panel-size slot) 0))

(define (panel-call-layout! slot left right bottom)
  (define active (panel-active-mode slot))
  (when active
    (define mode (panel-mode-ref slot active))
    ((hash-get mode 'layout) slot (panel-size slot) left right bottom)))

(define (panel-apply-layout!)
  (define left (panel-active-size 'left))
  (define right (panel-active-size 'right))
  (define bottom (panel-active-size 'bottom))
  (set-editor-clip-left! left)
  (set-editor-clip-right! right)
  ;; Native bottom modes may compute their pixel height from a fraction. Panel
  ;; still clears stale clipping whenever the bottom slot becomes empty.
  (unless (panel-active-mode 'bottom)
    (set-editor-clip-bottom! 0))
  (for-each (lambda (slot) (panel-call-layout! slot left right bottom))
            *panel-slots*))

(define (panel-close-slot! slot [name #f])
  (panel-assert-slot! slot)
  (define active (panel-active-mode slot))
  (when (and active (or (not name) (equal? active name)))
    (define mode (panel-mode-ref slot active))
    ((hash-get mode 'close))
    (set! *panel-active* (hash-insert *panel-active* slot #f))
    (panel-apply-layout!)))

(define (panel-show-in-slot! slot name [open-override #f])
  (panel-assert-slot! slot)
  (define mode (panel-mode-ref slot name))
  (define active (panel-active-mode slot))
  (when (and active (not (equal? active name)))
    (panel-close-slot! slot active))
  (set! *panel-active* (hash-insert *panel-active* slot name))
  ;; Apply geometry before opening so native modes use the current slot sizes
  ;; on their first frame, then again after opening to repair component order.
  (panel-apply-layout!)
  ((or open-override (hash-get mode 'open)) slot (panel-size slot))
  (panel-apply-layout!))

(define (panel-slot-for-mode! name)
  (define slot (panel-find-slot name))
  (unless slot
    (error! (string-append "panel: unregistered mode " (to-string name))))
  slot)

(define (panel-show! name [open-override #f])
  (panel-show-in-slot! (panel-slot-for-mode! name) name open-override))

(define (panel-toggle! name)
  (define slot (panel-slot-for-mode! name))
  (if (equal? (panel-active-mode slot) name)
      (panel-close-slot! slot name)
      (panel-show-in-slot! slot name)))

(define (panel-close! name)
  (define slot (panel-find-slot name))
  (when slot (panel-close-slot! slot name)))

(define (panel-init)
  (panel-apply-layout!))
