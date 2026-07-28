(require "helix/components.scm")
(require "helix/misc.scm")
(require "cogs/file-manager/files.scm")
(require "cogs/file-manager/bookmarks.scm")

(provide fe-bookmarks-view!)

(struct FeBookmarksViewState ())

(define *fe-bookmarks-view-entries* '())
(define *fe-bookmarks-view-index* 0)
(define *fe-bookmarks-view-target* #f)
(define *fe-bookmarks-view-setting?* #f)
(define *fe-bookmarks-view-jump!* #f)
(define *fe-bookmarks-view-set!* #f)
(define *fe-bookmarks-view-remove!* #f)

(define (fe-bookmarks-view-sort entries)
  (sort entries (lambda (left right)
                  (string<? (string (car left)) (string (car right))))))

(define (fe-bookmarks-view-clamp-index!)
  (set! *fe-bookmarks-view-index*
        (min *fe-bookmarks-view-index*
             (max 0 (- (length *fe-bookmarks-view-entries*) 1)))))

(define (fe-bookmarks-view-index-for-path entries path)
  (let loop ([remaining entries] [index 0])
    (cond [(null? remaining) 0]
          [(string=? (list-ref (car remaining) 1) path) index]
          [else (loop (cdr remaining) (+ index 1))])))

(define (fe-bookmarks-view-start index count visible-count)
  (min (max 0 (- count visible-count))
       (max 0 (- index (quotient visible-count 2)))))

(define (fe-bookmarks-view-render state rect frame)
  (define entries *fe-bookmarks-view-entries*)
  (define content-w
    (max 36
         (apply max 0
                (map (lambda (entry)
                       (+ 4 (fe-display-width (list-ref entry 1))))
                     entries))))
  (define width (min (- (area-width rect) 4) (min 100 content-w)))
  (define entry-count (length entries))
  (define height (min (- (area-height rect) 4) (max 3 (+ entry-count 2))))
  (define visible-count (max 1 (- height 2)))
  (define start (fe-bookmarks-view-start *fe-bookmarks-view-index* entry-count visible-count))
  (define x (quotient (- (area-width rect) width) 2))
  (define y (quotient (- (area-height rect) height) 2))
  (define text-style (theme-scope-ref "ui.text"))
  (define selected-style (theme-scope-ref "ui.menu.selected"))
  (define bg-style (theme-scope-ref "ui.background"))
  (buffer/clear-with frame (area x y width height) bg-style)
  (block/render frame (area x y width height)
                (make-block bg-style bg-style "all" "rounded"))
  (frame-set-string! frame (+ x 2) y
                     (if *fe-bookmarks-view-setting?* "Set bookmark" "Bookmarks")
                     text-style)
  (do [(row 0 (+ row 1))] [(>= row visible-count)]
    (define row-y (+ y row 1))
    (define entry-index (+ start row))
    (define selected? (= entry-index *fe-bookmarks-view-index*))
    (define row-style (if selected? selected-style text-style))
    (frame-set-string! frame (+ x 1) row-y (make-string (- width 2) #\space) row-style)
    (if (< entry-index entry-count)
        (let* ([entry (list-ref entries entry-index)]
               [label (string-append " " (string (car entry)) "  " (list-ref entry 1))])
          (frame-set-string! frame (+ x 1) row-y (fe-fit-text label (- width 2)) row-style))
        (frame-set-string! frame (+ x 2) row-y "No bookmarks" text-style))))

(define (fe-bookmarks-view-move! delta)
  (set! *fe-bookmarks-view-index*
        (min (max 0 (+ *fe-bookmarks-view-index* delta))
             (max 0 (- (length *fe-bookmarks-view-entries*) 1)))))

(define (fe-bookmarks-view-handle-event state event)
  (define ch (key-event-char event))
  (cond
    [(key-event-escape? event)
     (if *fe-bookmarks-view-setting?*
         (begin
           (set! *fe-bookmarks-view-setting?* #f)
           event-result/consume)
         event-result/close)]
    [*fe-bookmarks-view-setting?*
     (if (char? ch)
         (begin
           (define setter *fe-bookmarks-view-set!*)
           (when setter (setter ch *fe-bookmarks-view-target*))
           (set! *fe-bookmarks-view-entries*
                 (fe-bookmarks-view-sort
                   (fe-bookmark-set *fe-bookmarks-view-entries*
                                    ch
                                    *fe-bookmarks-view-target*)))
           (set! *fe-bookmarks-view-index*
                 (fe-bookmarks-view-index-for-path *fe-bookmarks-view-entries*
                                                   *fe-bookmarks-view-target*))
           (set! *fe-bookmarks-view-setting?* #f)
           event-result/close)
         event-result/consume)]
    [(key-event-down? event)
     (fe-bookmarks-view-move! 1)
     event-result/consume]
    [(key-event-up? event)
     (fe-bookmarks-view-move! -1)
     event-result/consume]
    [(key-event-enter? event)
     (when (< *fe-bookmarks-view-index* (length *fe-bookmarks-view-entries*))
       (define path (list-ref (list-ref *fe-bookmarks-view-entries* *fe-bookmarks-view-index*) 1))
       (define jump! *fe-bookmarks-view-jump!*)
       (when jump!
         (enqueue-thread-local-callback (lambda () (jump! path)))))
     event-result/close]
    [(and (char? ch) (equal? ch #\m))
     (set! *fe-bookmarks-view-setting?* #t)
     event-result/consume]
    [(or (key-event-delete? event) (key-event-backspace? event))
     (when (< *fe-bookmarks-view-index* (length *fe-bookmarks-view-entries*))
       (define key (car (list-ref *fe-bookmarks-view-entries* *fe-bookmarks-view-index*)))
       (define remove! *fe-bookmarks-view-remove!*)
       (when remove! (remove! key))
       (set! *fe-bookmarks-view-entries*
             (fe-bookmark-remove *fe-bookmarks-view-entries* key))
       (fe-bookmarks-view-clamp-index!))
     event-result/consume]
    [(char? ch)
     (let ([path (fe-bookmark-ref *fe-bookmarks-view-entries* ch)])
       (if path
           (begin
             (define jump! *fe-bookmarks-view-jump!*)
             (when jump!
               (enqueue-thread-local-callback (lambda () (jump! path))))
             event-result/close)
           event-result/consume))]
    [else event-result/consume]))

(define (fe-bookmarks-view! entries target jump! set-bookmark! remove!)
  (set! *fe-bookmarks-view-entries* (fe-bookmarks-view-sort entries))
  (set! *fe-bookmarks-view-index*
        (fe-bookmarks-view-index-for-path *fe-bookmarks-view-entries* target))
  (set! *fe-bookmarks-view-target* target)
  (set! *fe-bookmarks-view-setting?* #f)
  (set! *fe-bookmarks-view-jump!* jump!)
  (set! *fe-bookmarks-view-set!* set-bookmark!)
  (set! *fe-bookmarks-view-remove!* remove!)
  (enqueue-thread-local-callback
    (lambda ()
      (push-component!
        (new-component! "file-explorer-bookmarks"
                        (FeBookmarksViewState)
                        fe-bookmarks-view-render
                        (hash "handle_event" fe-bookmarks-view-handle-event))))))
