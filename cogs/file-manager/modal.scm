(require "helix/components.scm")
(require "helix/misc.scm")
(require "cogs/file-manager/files.scm")

(provide fm-prompt!)

(struct FeModalState ())

(define *fe-modal-mode* 'input)
(define *fe-modal-label* "")
(define *fe-modal-buffer* "")
(define *fe-modal-callback* #f)

(define (fe-modal-origin rect)
  (define content-len (+ (fe-display-width *fe-modal-label*) (fe-display-width *fe-modal-buffer*)))
  (define width (min (- (area-width rect) 4) (max 40 (+ content-len 4))))
  (list (quotient (- (area-width rect) width) 2)
        (quotient (- (area-height rect) 3) 2)
        width))

(define (fe-modal-render state rect frame)
  (define origin (fe-modal-origin rect))
  (define x (list-ref origin 0))
  (define y (list-ref origin 1))
  (define width (list-ref origin 2))
  (define bg-style (theme-scope-ref "ui.background"))
  (buffer/clear-with frame (area x y width 3) bg-style)
  (block/render frame (area x y width 3) (make-block bg-style bg-style "all" "rounded"))
  (frame-set-string! frame (+ x 1) (+ y 1)
                     (fe-fit-text (string-append *fe-modal-label* *fe-modal-buffer*) (- width 2))
                     (theme-scope-ref "ui.text")))

(define (fe-modal-cursor state rect)
  (if (equal? *fe-modal-mode* 'confirm)
      #f
      (let ([origin (fe-modal-origin rect)])
        (position (+ (list-ref origin 1) 1)
                  (+ (list-ref origin 0) 1
                     (fe-display-width *fe-modal-label*)
                     (fe-display-width *fe-modal-buffer*))))))

(define (fe-modal-handle-event state event)
  (define ch (key-event-char event))
  (cond
    [(equal? *fe-modal-mode* 'confirm)
     (define callback *fe-modal-callback*)
     (set! *fe-modal-callback* #f)
     (when callback
       (enqueue-thread-local-callback
         (lambda () (callback (and (char? ch) (equal? ch #\y))))))
     event-result/close]
    [(key-event-enter? event)
     (define result *fe-modal-buffer*)
     (define callback *fe-modal-callback*)
     (set! *fe-modal-callback* #f)
     (when callback
       (enqueue-thread-local-callback (lambda () (callback result))))
     event-result/close]
    [(key-event-escape? event)
     (set! *fe-modal-callback* #f)
     event-result/close]
    [(key-event-backspace? event)
     (define length (string-length *fe-modal-buffer*))
     (when (> length 0)
       (set! *fe-modal-buffer* (substring *fe-modal-buffer* 0 (- length 1))))
     event-result/consume]
    [(char? ch)
     (set! *fe-modal-buffer* (string-append *fe-modal-buffer* (string ch)))
     event-result/consume]
    [else event-result/consume]))

(define (fe-show-modal! mode label initial-value callback)
  (set! *fe-modal-mode* mode)
  (set! *fe-modal-label* label)
  (set! *fe-modal-buffer* initial-value)
  (set! *fe-modal-callback* callback)
  (push-component! (new-component! "file-manager-modal"
                                  (FeModalState)
                                  fe-modal-render
                                  (hash "handle_event" fe-modal-handle-event
                                        "cursor" fe-modal-cursor))))

(define (fm-prompt! mode label initial-value callback)
  (enqueue-thread-local-callback
    (lambda () (fe-show-modal! mode label initial-value callback))))
