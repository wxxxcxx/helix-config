(require (only-in "helix/editor.scm"
                  set-editor-clip-bottom!
                  set-editor-clip-left!
                  set-editor-clip-right!))
(require (only-in "helix/components.scm"
                  area
                  area-height
                  area-width
                  area-x
                  area-y
                  event-result/consume
                  event-result/ignore
                  event->key-event
                  key-event?
                  string->key-event
                  new-component!))
(require (only-in "helix/misc.scm"
                  enqueue-thread-local-callback
                  pop-last-component-by-name!
                  push-component!))

(provide panel-active-mode
         panel-close!
         panel-configure!
         panel-focus!
         panel-focus-editor!
         panel-focused-mode
         panel-fullscreen-mode
         panel-init
         panel-component-mode
         panel-mode
         panel-register-key!
         panel-register-mode!
         panel-show!
         panel-size
         panel-slot-area
         panel-toggle-fullscreen!
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
(define *panel-focused-mode* #f)
(define *panel-fullscreen-mode* #f)
(define *panel-key-handlers* '())

;; A panel mode is a lifecycle contract. Components own their own Helix surface
;; and input handling; Panel only coordinates layout, focus and fullscreen state.
(define (panel-mode #:open open #:close close
                    #:layout [layout (lambda (_slot _size _left _right _bottom) void)]
                    #:focus [focus (lambda () void)]
                    #:blur [blur (lambda () void)]
                    #:fullscreen [fullscreen (lambda (_enabled?) void)])
  (hash 'open open
        'close close
        'layout layout
        'focus focus
        'blur blur
        'fullscreen fullscreen))

(define (panel-remove-key-handler key-event handlers)
  (cond [(null? handlers) '()]
        [(equal? key-event (car (car handlers)))
         (panel-remove-key-handler key-event (cdr handlers))]
        [else
         (cons (car handlers)
               (panel-remove-key-handler key-event (cdr handlers)))]))

(define (panel-normalize-key key)
  (if (string? key) (string->key-event key) key))

(define (panel-register-key! key handler)
  (unless (procedure? handler)
    (error! "panel: key handler must be a procedure"))
  (define key-event (panel-normalize-key key))
  (set! *panel-key-handlers*
        (cons (list key-event handler)
              (panel-remove-key-handler key-event *panel-key-handlers*))))

(define (panel-key-handler event)
  (and (key-event? event)
       (let ([key-event (event->key-event event)])
         (let loop ([handlers *panel-key-handlers*])
           (cond [(null? handlers) #f]
                 [(equal? key-event (car (car handlers))) (list-ref (car handlers) 1)]
                 [else (loop (cdr handlers))])))))

(define (panel-handle-ignored-event event fallback)
  (define handler (panel-key-handler event))
  (if handler
      (begin (handler) event-result/consume)
      fallback))

(define (panel-component-mode #:name component-name
                              #:open open
                              #:close close
                              #:render render
                              #:handle-event handle-event
                              #:layout [layout (lambda (_slot _size _left _right _bottom) void)]
                              #:focus [focus (lambda () void)]
                              #:blur [blur (lambda () void)]
                              #:fullscreen [fullscreen (lambda (_enabled?) void)])
  (define active? #f)
  (define current-slot #f)
  (define (component-render _state root frame)
    (define slot-area (and current-slot (panel-slot-area current-slot root)))
    (when slot-area
      (render slot-area root frame)))
  (define (component-handle-event state event)
    (define result (handle-event state event))
    (if (equal? result event-result/ignore)
        (panel-handle-ignored-event event result)
        result))
  (define (push-self!)
    (pop-last-component-by-name! component-name)
    (push-component!
      (new-component! component-name (hash) component-render
                      (hash "handle_event" component-handle-event))))
  (define (raise-self!)
    (when active?
      (enqueue-thread-local-callback
        (lambda ()
          (when active?
            (push-self!))))))
  (panel-mode
    #:open (lambda (slot size)
             (set! current-slot slot)
             (set! active? #t)
             (open slot size)
             (push-self!))
    #:close (lambda ()
              (set! active? #f)
              (close)
              (pop-last-component-by-name! component-name))
    #:layout (lambda (slot size left right bottom)
               (set! current-slot slot)
               (layout slot size left right bottom))
    #:focus (lambda ()
              (focus)
              (raise-self!))
    #:blur blur
    #:fullscreen (lambda (enabled?)
                   (fullscreen enabled?)
                   (when enabled?
                     (raise-self!)))))

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

(define (panel-focused-mode)
  *panel-focused-mode*)

(define (panel-fullscreen-mode)
  *panel-fullscreen-mode*)

(define (panel-set-mode-fullscreen! name enabled?)
  (define slot (panel-slot-for-mode! name))
  ((hash-get (panel-mode-ref slot name) 'fullscreen) enabled?))

(define (panel-exit-fullscreen!)
  (when *panel-fullscreen-mode*
    (define name *panel-fullscreen-mode*)
    (set! *panel-fullscreen-mode* #f)
    (panel-set-mode-fullscreen! name #f)
    (panel-apply-layout!)))

;;@doc
;; Toggle fullscreen for the focused panel mode.
(define (panel-toggle-fullscreen!)
  (when *panel-focused-mode*
    (define name *panel-focused-mode*)
    (if (equal? *panel-fullscreen-mode* name)
        (panel-exit-fullscreen!)
        (begin
          (panel-exit-fullscreen!)
          (set! *panel-fullscreen-mode* name)
          (panel-set-mode-fullscreen! name #t)
          (panel-apply-layout!)))))

(define (panel-blur-current!)
  (when *panel-focused-mode*
    (define slot (panel-find-slot *panel-focused-mode*))
    (when slot
      ((hash-get (panel-mode-ref slot *panel-focused-mode*) 'blur)))))

(define (panel-focus! name)
  (define slot (panel-slot-for-mode! name))
  (unless (equal? (panel-active-mode slot) name)
    (error! (string-append "panel: cannot focus hidden mode " (to-string name))))
  (when (and *panel-fullscreen-mode*
             (not (equal? *panel-fullscreen-mode* name)))
    (panel-exit-fullscreen!))
  (unless (equal? *panel-focused-mode* name)
    (panel-blur-current!)
    (set! *panel-focused-mode* name)
    ((hash-get (panel-mode-ref slot name) 'focus))))

(define (panel-focus-editor!)
  (panel-exit-fullscreen!)
  (panel-blur-current!)
  (set! *panel-focused-mode* #f))

(define (panel-call-layout! slot left right bottom)
  (define active (panel-active-mode slot))
  (when active
    (define mode (panel-mode-ref slot active))
    ((hash-get mode 'layout) slot (panel-size slot) left right bottom)))

(define (panel-apply-layout!)
  (define left (if *panel-fullscreen-mode* 0 (panel-active-size 'left)))
  (define right (if *panel-fullscreen-mode* 0 (panel-active-size 'right)))
  (define bottom (if *panel-fullscreen-mode* 0 (panel-active-size 'bottom)))
  (set-editor-clip-left! left)
  (set-editor-clip-right! right)
  ;; Pixel height is known during rendering. Clear stale clipping immediately
  ;; whenever the bottom slot becomes empty.
  (when (or *panel-fullscreen-mode* (not (panel-active-mode 'bottom)))
    (set-editor-clip-bottom! 0))
  (for-each (lambda (slot) (panel-call-layout! slot left right bottom))
            *panel-slots*))

(define (panel-side-width slot total-width reserved)
  (if (panel-active-mode slot)
      (min (panel-size slot) (max 1 (- total-width reserved 1)))
      0))

(define (panel-calc-left-width total-width)
  (panel-side-width 'left total-width 0))

(define (panel-calc-right-width total-width left-width)
  (panel-side-width 'right total-width left-width))

(define (panel-calc-bottom-height total-height)
  (if (panel-active-mode 'bottom)
      (max 1 (min total-height (round (* total-height (panel-size 'bottom)))))
      0))

(define (panel-slot-area slot root)
  (panel-assert-slot! slot)
  (define x (area-x root))
  (define y (area-y root))
  (define width (area-width root))
  (define height (area-height root))
  (define left (panel-calc-left-width width))
  (define right (panel-calc-right-width width left))
  (define bottom (panel-calc-bottom-height height))
  (cond [(and *panel-fullscreen-mode*
              (equal? slot (panel-slot-for-mode! *panel-fullscreen-mode*)))
         root]
        [*panel-fullscreen-mode* #f]
        [(equal? slot 'left)
         (and (> left 0) (area x y left height))]
        [(equal? slot 'right)
         (and (> right 0) (area (+ x (- width right)) y right height))]
        [(equal? slot 'bottom)
         (and (> bottom 0)
              (area (+ x left)
                    (+ y (- height bottom))
                    (max 1 (- width left right))
                    bottom))]
        [else #f]))

(define (panel-close-slot! slot [name #f])
  (panel-assert-slot! slot)
  (define active (panel-active-mode slot))
  (when (and active (or (not name) (equal? active name)))
    (define mode (panel-mode-ref slot active))
    (when (equal? *panel-fullscreen-mode* active)
      (panel-exit-fullscreen!))
    (when (equal? *panel-focused-mode* active)
      (panel-focus-editor!))
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
  ;; Apply geometry before opening so the first component frame uses current slot
  ;; sizes, then again after opening in case lifecycle state changed.
  (panel-apply-layout!)
  ((or open-override (hash-get mode 'open)) slot (panel-size slot))
  (panel-focus! name)
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
      (if (equal? *panel-focused-mode* name)
          (panel-close-slot! slot name)
          (panel-focus! name))
      (panel-show-in-slot! slot name)))

(define (panel-close! name)
  (define slot (panel-find-slot name))
  (when slot (panel-close-slot! slot name)))

(define (panel-init)
  (panel-apply-layout!))
