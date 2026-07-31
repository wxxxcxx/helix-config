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
                  event-result/ignore
                  mouse-event?
                  mouse-event-within-area?
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
(define *panel-areas*
  (hash 'left #f 'right #f 'bottom #f))
(define *panel-focused-mode* #f)
(define *panel-host-mounted?* #f)

;; Hosted modes render inside PanelHost. Native modes such as steel-pty keep
;; their own Helix component and use only the lifecycle/layout callbacks.
(define (panel-mode #:open open #:close close
                    #:layout [layout (lambda (_slot _size _left _right _bottom) void)]
                    #:hosted [hosted #f]
                    #:render [render (lambda (_slot-area _root-area _frame) void)]
                    #:handle-event [handle-event (lambda (_event) event-result/ignore)]
                    #:focus [focus (lambda () void)]
                    #:blur [blur (lambda () void)])
  (hash 'open open
        'close close
        'layout layout
        'hosted hosted
        'render render
        'handle-event handle-event
        'focus focus
        'blur blur))

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

(define (panel-mode-hosted? mode)
  (hash-get mode 'hosted))

(define (panel-active-hosted-mode slot)
  (define active (panel-active-mode slot))
  (and active
       (let ([mode (panel-mode-ref slot active)])
         (and (panel-mode-hosted? mode) mode))))

(define (panel-any-hosted-mode-active?)
  (or (panel-active-hosted-mode 'left)
      (panel-active-hosted-mode 'right)
      (panel-active-hosted-mode 'bottom)))

(define (panel-sync-host!)
  (define needed? (not (not (panel-any-hosted-mode-active?))))
  (cond [(and needed? (not *panel-host-mounted?*))
         (set! *panel-host-mounted?* #t)
         (enqueue-thread-local-callback
           (lambda ()
             (when *panel-host-mounted?*
               (pop-last-component-by-name! "panel-host")
               (push-component!
                 (new-component! "panel-host" (hash)
                                 panel-host-render
                                 (hash "handle_event" panel-host-handle-event))))))]
        [(and (not needed?) *panel-host-mounted?*)
         (set! *panel-host-mounted?* #f)
         (enqueue-thread-local-callback
           (lambda ()
             (unless *panel-host-mounted?*
               (pop-last-component-by-name! "panel-host"))))]))

(define (panel-focused-mode)
  *panel-focused-mode*)

(define (panel-blur-current!)
  (when *panel-focused-mode*
    (define slot (panel-find-slot *panel-focused-mode*))
    (when slot
      ((hash-get (panel-mode-ref slot *panel-focused-mode*) 'blur)))))

(define (panel-focus! name)
  (define slot (panel-slot-for-mode! name))
  (unless (equal? (panel-active-mode slot) name)
    (error! (string-append "panel: cannot focus hidden mode " (to-string name))))
  (unless (equal? *panel-focused-mode* name)
    (panel-blur-current!)
    (set! *panel-focused-mode* name)
    ((hash-get (panel-mode-ref slot name) 'focus))))

(define (panel-focus-editor!)
  (panel-blur-current!)
  (set! *panel-focused-mode* #f))

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

(define (panel-side-width slot total-width reserved)
  (if (panel-active-mode slot)
      (min (panel-size slot) (max 1 (- total-width reserved 1)))
      0))

(define (panel-calculate-areas root)
  (define x (area-x root))
  (define y (area-y root))
  (define width (area-width root))
  (define height (area-height root))
  (define left (panel-side-width 'left width 0))
  (define right (panel-side-width 'right width left))
  (define bottom
    (if (panel-active-mode 'bottom)
        (max 1 (min height (round (* height (panel-size 'bottom)))))
        0))
  (set! *panel-areas*
        (hash
          'left (and (> left 0) (area x y left height))
          'right (and (> right 0)
                      (area (+ x (- width right)) y right height))
          'bottom (and (> bottom 0)
                       (area (+ x left)
                             (+ y (- height bottom))
                             (max 1 (- width left right))
                             bottom)))))

(define (panel-render-slot! slot root frame)
  (define mode (panel-active-hosted-mode slot))
  (define slot-area (hash-get *panel-areas* slot))
  (when (and mode slot-area)
    ((hash-get mode 'render) slot-area root frame)))

(define (panel-host-render _state root frame)
  (panel-calculate-areas root)
  (for-each (lambda (slot) (panel-render-slot! slot root frame))
            *panel-slots*))

(define (panel-mouse-target event)
  (cond [(and (panel-active-hosted-mode 'left)
              (hash-get *panel-areas* 'left)
              (mouse-event-within-area? event (hash-get *panel-areas* 'left)))
         (panel-active-mode 'left)]
        [(and (panel-active-hosted-mode 'right)
              (hash-get *panel-areas* 'right)
              (mouse-event-within-area? event (hash-get *panel-areas* 'right)))
         (panel-active-mode 'right)]
        [(and (panel-active-hosted-mode 'bottom)
              (hash-get *panel-areas* 'bottom)
              (mouse-event-within-area? event (hash-get *panel-areas* 'bottom)))
         (panel-active-mode 'bottom)]
        [else #f]))

(define (panel-dispatch-event name event)
  (define slot (panel-find-slot name))
  (if (and slot (equal? (panel-active-mode slot) name))
      ((hash-get (panel-mode-ref slot name) 'handle-event) event)
      event-result/ignore))

(define (panel-host-handle-event _state event)
  (if (mouse-event? event)
      (let ([target (panel-mouse-target event)])
        (if target
            (begin
              (panel-focus! target)
              (panel-dispatch-event target event))
            (begin
              (panel-focus-editor!)
              event-result/ignore)))
      (if *panel-focused-mode*
          (panel-dispatch-event *panel-focused-mode* event)
          event-result/ignore)))

(define (panel-close-slot! slot [name #f])
  (panel-assert-slot! slot)
  (define active (panel-active-mode slot))
  (when (and active (or (not name) (equal? active name)))
    (define mode (panel-mode-ref slot active))
    (when (equal? *panel-focused-mode* active)
      (panel-focus-editor!))
    ((hash-get mode 'close))
    (set! *panel-active* (hash-insert *panel-active* slot #f))
    (panel-apply-layout!)
    (panel-sync-host!)))

(define (panel-show-in-slot! slot name [open-override #f])
  (panel-assert-slot! slot)
  (define mode (panel-mode-ref slot name))
  (define active (panel-active-mode slot))
  (when (and active (not (equal? active name)))
    (panel-close-slot! slot active))
  (set! *panel-active* (hash-insert *panel-active* slot name))
  (panel-sync-host!)
  ;; Apply geometry before opening so native modes use the current slot sizes
  ;; on their first frame, then again after opening to repair component order.
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
      (panel-close-slot! slot name)
      (panel-show-in-slot! slot name)))

(define (panel-close! name)
  (define slot (panel-find-slot name))
  (when slot (panel-close-slot! slot name)))

(define (panel-init)
  (panel-apply-layout!))
