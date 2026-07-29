(require "helix/components.scm")
(require (only-in "helix/misc.scm"
                  get-active-lsp-clients
                  lsp-client-initialized?
                  lsp-client-name
                  lsp-client-offset-encoding))

(provide lsp-status)

(struct LspStatusState ())

(define *lsp-status-rows* '())
(define *lsp-status-scroll* 0)
(define *lsp-status-visible-count* 1)

(define (lsp-status-fit text width)
  (cond [(<= width 0) ""]
        [(<= (string-length text) width) text]
        [(= width 1) "…"]
        [else (string-append (substring text 0 (- width 1)) "…")]))

(define (lsp-status-client-rows client)
  (define initialized? (lsp-client-initialized? client))
  (define name (or (lsp-client-name client) "<unnamed>"))
  (define encoding (and initialized? (lsp-client-offset-encoding client)))
  (define summary
    (string-append
      "● " name "  "
      (if initialized? "ready" "starting")
      (if encoding (string-append " · " encoding) "")))
  (list (cons summary "ui.text.info")))

(define (lsp-status-build-rows clients)
  (if (null? clients)
      (list (cons "No language servers are attached to the current buffer."
                  "ui.text.inactive"))
      (let loop ([remaining clients] [rows '()])
        (if (null? remaining)
            rows
            (loop (cdr remaining)
                  (append rows
                          (if (null? rows) '() (list (cons "" "ui.text")))
                          (lsp-status-client-rows (car remaining))))))))

(define (lsp-status-content-width rows)
  (apply max 44 (map (lambda (row) (+ 2 (string-length (car row)))) rows)))

(define (lsp-status-clamp-scroll!)
  (set! *lsp-status-scroll*
        (min (max 0 *lsp-status-scroll*)
             (max 0 (- (length *lsp-status-rows*)
                       *lsp-status-visible-count*)))))

(define (lsp-status-render state rect frame)
  (define width
    (min (max 1 (area-width rect))
         (min 88 (lsp-status-content-width *lsp-status-rows*))))
  (define height
    (min (max 1 (area-height rect))
         (max 5 (min 28 (+ 3 (length *lsp-status-rows*))))))
  (define x (quotient (- (area-width rect) width) 2))
  (define y (quotient (- (area-height rect) height) 2))
  (define popup-style (theme-scope-ref "ui.popup"))
  (define border-style (theme-scope-ref "ui.window"))
  (set! *lsp-status-visible-count* (max 1 (- height 3)))
  (lsp-status-clamp-scroll!)
  (buffer/clear-with frame (area x y width height) popup-style)
  (block/render frame (area x y width height)
                (make-block popup-style border-style "all" "rounded"))
  (frame-set-string! frame (+ x 2) y " LSP Clients "
                     (theme-scope-ref "ui.text.info"))
  (do [(row-index 0 (+ row-index 1))]
      [(>= row-index *lsp-status-visible-count*)]
    (define entry-index (+ *lsp-status-scroll* row-index))
    (when (< entry-index (length *lsp-status-rows*))
      (define row (list-ref *lsp-status-rows* entry-index))
      (frame-set-string! frame (+ x 1) (+ y 1 row-index)
                         (lsp-status-fit (car row) (- width 2))
                         (theme-scope-ref (cdr row)))))
  (define footer
    (if (> (length *lsp-status-rows*) *lsp-status-visible-count*)
        (string-append " "
                       (number->string (+ *lsp-status-scroll* 1))
                       "-"
                       (number->string
                         (min (length *lsp-status-rows*)
                              (+ *lsp-status-scroll*
                                 *lsp-status-visible-count*)))
                       "/"
                       (number->string (length *lsp-status-rows*))
                       "  j/k scroll · q close ")
        " q/Esc close "))
  (frame-set-string! frame (+ x 2) (+ y height -2)
                     (lsp-status-fit footer (- width 4))
                     (theme-scope-ref "ui.text.inactive")))

(define (lsp-status-scroll! delta)
  (set! *lsp-status-scroll* (+ *lsp-status-scroll* delta))
  (lsp-status-clamp-scroll!))

(define (lsp-status-handle-event state event)
  (define ch (key-event-char event))
  (cond [(or (key-event-escape? event)
             (and (char? ch) (equal? ch #\q)))
         event-result/close]
        [(or (key-event-down? event)
             (and (char? ch) (equal? ch #\j)))
         (lsp-status-scroll! 1)
         event-result/consume]
        [(or (key-event-up? event)
             (and (char? ch) (equal? ch #\k)))
         (lsp-status-scroll! -1)
         event-result/consume]
        [(key-event-page-down? event)
         (lsp-status-scroll! *lsp-status-visible-count*)
         event-result/consume]
        [(key-event-page-up? event)
         (lsp-status-scroll! (- *lsp-status-visible-count*))
         event-result/consume]
        [(or (key-event-home? event)
             (and (char? ch) (equal? ch #\g)))
         (set! *lsp-status-scroll* 0)
         event-result/consume]
        [(or (key-event-end? event)
             (and (char? ch) (equal? ch #\G)))
         (set! *lsp-status-scroll* (length *lsp-status-rows*))
         (lsp-status-clamp-scroll!)
         event-result/consume]
        [else event-result/consume]))

;;@doc
;; Show language servers attached to the current buffer.
(define (lsp-status)
  (set! *lsp-status-rows*
        (lsp-status-build-rows (get-active-lsp-clients)))
  (set! *lsp-status-scroll* 0)
  (enqueue-thread-local-callback
    (lambda ()
      (push-component!
        (new-component! "lsp-status"
                        (LspStatusState)
                        lsp-status-render
                        (hash "handle_event" lsp-status-handle-event))))))
