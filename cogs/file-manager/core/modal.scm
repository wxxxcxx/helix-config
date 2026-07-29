(require "helix/components.scm")
(require "helix/misc.scm")
(require "cogs/file-manager/core/files.scm")

(provide fm-prompt!)

(struct FmModalState ())

(define *fm-modal-mode* 'input)
(define *fm-modal-label* "")
(define *fm-modal-buffer* "")
(define *fm-modal-callback* #f)

(define (fm-modal-origin rect)
  (define content-len (+ (fm-display-width *fm-modal-label*) (fm-display-width *fm-modal-buffer*)))
  (define available (max 1 (- (area-width rect) 2)))
  (define width (min available (max 20 (+ content-len 4))))
  (list (quotient (- (area-width rect) width) 2)
        (quotient (- (area-height rect) 3) 2)
        width))

(define (fm-modal-render state rect frame)
  (define origin (fm-modal-origin rect))
  (define x (list-ref origin 0))
  (define y (list-ref origin 1))
  (define width (list-ref origin 2))
  (define bg-style (theme-scope-ref "ui.background"))
  (buffer/clear-with frame (area x y width 3) bg-style)
  (block/render frame (area x y width 3) (make-block bg-style bg-style "all" "rounded"))
  (frame-set-string! frame (+ x 1) (+ y 1)
                     (fm-fit-text (string-append *fm-modal-label* *fm-modal-buffer*) (- width 2))
                     (theme-scope-ref "ui.text")))

(define (fm-modal-cursor state rect)
  (if (equal? *fm-modal-mode* 'confirm)
      #f
      (let ([origin (fm-modal-origin rect)])
        (position (+ (list-ref origin 1) 1)
                  (+ (list-ref origin 0) 1
                     (fm-display-width *fm-modal-label*)
                     (fm-display-width *fm-modal-buffer*))))))

(define (fm-modal-handle-event state event)
  (define ch (key-event-char event))
  (cond
    [(equal? *fm-modal-mode* 'confirm)
     (define callback *fm-modal-callback*)
     (set! *fm-modal-callback* #f)
     (when callback
       (enqueue-thread-local-callback
         (lambda () (callback (and (char? ch)
                                   (or (equal? ch #\y) (equal? ch #\Y)))))))
     event-result/close]
    [(key-event-enter? event)
     (define result *fm-modal-buffer*)
     (define callback *fm-modal-callback*)
     (set! *fm-modal-callback* #f)
     (when callback
       (enqueue-thread-local-callback (lambda () (callback result))))
     event-result/close]
    [(key-event-escape? event)
     (set! *fm-modal-callback* #f)
     event-result/close]
    [(key-event-backspace? event)
     (define length (string-length *fm-modal-buffer*))
     (when (> length 0)
       (set! *fm-modal-buffer* (substring *fm-modal-buffer* 0 (- length 1))))
     event-result/consume]
    [(char? ch)
     (set! *fm-modal-buffer* (string-append *fm-modal-buffer* (string ch)))
     event-result/consume]
    [else event-result/consume]))

(define (fm-show-modal! mode label initial-value callback)
  (set! *fm-modal-mode* mode)
  (set! *fm-modal-label* label)
  (set! *fm-modal-buffer* initial-value)
  (set! *fm-modal-callback* callback)
  (push-component! (new-component! "file-manager-modal"
                                  (FmModalState)
                                  fm-modal-render
                                  (hash "handle_event" fm-modal-handle-event
                                        "cursor" fm-modal-cursor))))

(define (fm-prompt! mode label initial-value callback)
  (enqueue-thread-local-callback
    (lambda () (fm-show-modal! mode label initial-value callback))))
