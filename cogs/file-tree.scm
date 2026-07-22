(require "helix/components.scm")
(require "helix/misc.scm")
(require "helix/editor.scm")
(require (prefix-in helix. "helix/commands.scm"))


(provide file-tree-open file-tree-close file-tree-toggle file-tree-configure! file-tree-focused?)

;; ── Configuration ──────────────────────────────────────────────

(define *ft-width* 32)
(define *ft-side* 'left)
(define *ft-ignore-set* (hashset ".git" "target" "node_modules" "__pycache__"))
(define *ft-show-hidden* #f)

;; ── State ──────────────────────────────────────────────────────

(define *ft-active* #f)
(define *ft-focused* #f)
(define *ft-tree* '())
(define *ft-cursor* 0)
(define *ft-window-start* 0)
(define *ft-visible-height* 30)
(define *ft-dirs* (hash))

;; ── List Helpers ───────────────────────────────────────────────

(define (ft-take lst n)
  (if (or (null? lst) (<= n 0)) '() (cons (car lst) (ft-take (cdr lst) (- n 1)))))

(define (ft-drop lst n)
  (if (or (null? lst) (<= n 0)) lst (ft-drop (cdr lst) (- n 1))))

(define (ft-count) (length *ft-tree*))

;; ── Tree Building ──────────────────────────────────────────────

(define (ft-sort lst)
  (define dirs (sort (filter is-dir? lst) string<?))
  (define files (sort (filter (lambda (p) (not (is-dir? p))) lst) string<?))
  (append dirs files))

(define (ft-dotfile? name)
  (and (> (string-length name) 0) (char=? (string-ref name 0) #\.)))

(define (ft-build-tree!)
  (define result '())
  (define (walk path depth)
    (define name (file-name path))
    (unless (or (hashset-contains? *ft-ignore-set* name)
                (and (not *ft-show-hidden*) (ft-dotfile? name)))
      (define indent (make-string (* depth 2) #\space))
      (define marker (if (is-dir? path)
                         (if (hash-contains? *ft-dirs* path)
                             (if (hash-try-get *ft-dirs* path) "▶ " "▼ ")
                             "▶ ")
                         "  "))
      (set! result (cons (list path indent marker name) result))
      (when (is-dir? path)
        (unless (hash-contains? *ft-dirs* path)
          (set! *ft-dirs* (hash-insert *ft-dirs* path (> depth 0))))
        (unless (hash-try-get *ft-dirs* path)
          (for-each (lambda (child) (walk child (+ depth 1)))
                    (ft-sort (read-dir path)))))))
  (walk (helix-find-workspace) 0)
  (set! *ft-tree* (reverse result)))

;; ── Navigation ─────────────────────────────────────────────────

(define (ft-clamp-cursor!)
  (set! *ft-cursor* (max 0 (min *ft-cursor* (max 0 (- (ft-count) 1))))))

(define (ft-scrolloff)
  (with-handler (lambda (_) 3) (helix.get-option 'scrolloff)))

(define (ft-cursor-down!)
  (define soff (ft-scrolloff))
  (when (< *ft-cursor* (max 0 (- (ft-count) 1)))
    (set! *ft-cursor* (+ *ft-cursor* 1))
    (when (> *ft-cursor* (- (+ *ft-window-start* *ft-visible-height*) soff 1))
      (set! *ft-window-start* (+ *ft-window-start* 1)))))

(define (ft-cursor-up!)
  (define soff (ft-scrolloff))
  (when (> *ft-cursor* 0)
    (set! *ft-cursor* (- *ft-cursor* 1))
    (when (< *ft-cursor* (+ *ft-window-start* soff))
      (set! *ft-window-start* (- *ft-window-start* 1)))))

(define (ft-current)
  (and (not (null? *ft-tree*))
       (list-ref *ft-tree* *ft-cursor*)))

(define (ft-toggle-dir! path)
  (set! *ft-dirs* (hash-insert *ft-dirs* path
                                (not (hash-try-get *ft-dirs* path))))
  (define old *ft-cursor*)
  (ft-build-tree!)
  (set! *ft-cursor* (min old (max 0 (- (ft-count) 1)))))

(define (ft-activate!)
  (define entry (ft-current))
  (cond
    [(not entry) event-result/consume]
    [(is-file? (car entry))
      (set! *ft-focused* #f)
      (enqueue-thread-local-callback (lambda () (helix.open (car entry))))
     event-result/close]
    [(is-dir? (car entry))
     (ft-toggle-dir! (car entry))
     event-result/consume]
    [else event-result/consume]))

;; ── Rendering ──────────────────────────────────────────────────

(define (ft-panel-x0 rect w)
  (if (equal? *ft-side* 'right) (- (area-width rect) w) 0))

(define (ft-truncate s max-w)
  (if (<= (string-length s) max-w) s
      (string-append (substring s 0 (max 0 (- max-w 1))) "…")))

(struct FtBgState ())

(define (ft-render-bg state rect frame)
  (define w (min *ft-width* (area-width rect)))
  (define h (area-height rect))
  (define x0 (ft-panel-x0 rect w))
  (define panel-area (area x0 0 w h))
  (set! *ft-visible-height* h)

  (if (equal? *ft-side* 'right)
      (set-editor-clip-right! w)
      (set-editor-clip-left! w))

  (define bg-style (theme-scope-ref "ui.background"))
  (define text-style (theme-scope-ref "ui.text"))
  (define hl-style (theme-scope-ref "ui.menu.selected"))
  (define dir-style (theme-scope-ref "ui.text.info"))

  (buffer/clear-with frame panel-area bg-style)

  (define list-y0 1)
  (define max-h (- h list-y0))
  (define visible (ft-take (ft-drop *ft-tree* *ft-window-start*) max-h))

  (let loop ([items visible] [row 0])
    (when (and (not (null? items)) (< row max-h))
      (define entry (car items))
      (define abs-idx (+ *ft-window-start* row))
      (define path (list-ref entry 0))
      (define indent (list-ref entry 1))
      (define marker (list-ref entry 2))
      (define name (list-ref entry 3))
      (define prefix (string-append indent marker))
      (define hl? (= abs-idx *ft-cursor*))
      (define row-style (if hl? hl-style
                           (if (is-dir? path) dir-style text-style)))
      (define y (+ list-y0 row))
      (when hl?
        (frame-set-string! frame x0 y (make-string w #\space) hl-style))
      (frame-set-string! frame x0 y prefix row-style)
      (frame-set-string! frame (+ x0 (string-length prefix)) y
                          (ft-truncate name (- w (string-length prefix))) row-style)
      (loop (cdr items) (+ row 1)))))

(define (ft-handle-event-bg state event)
  event-result/ignore)

;; ── Foreground ─────────────────────────────────────────────────

(struct FtFgState ())

(define (ft-render-fg state rect frame) void)

(define (ft-handle-event-fg state event)
  (define ch (key-event-char event))
  (cond
    [(key-event-down? event) (ft-cursor-down!) event-result/consume]
    [(key-event-up? event) (ft-cursor-up!) event-result/consume]
    [(key-event-enter? event) (ft-activate!)]
    [(key-event-tab? event)
     (define entry (ft-current))
     (when (and entry (is-dir? (car entry))) (ft-toggle-dir! (car entry)))
     event-result/consume]
    [(key-event-escape? event) (file-tree-close) event-result/close]
    [(and (char? ch) (equal? ch #\q)) (file-tree-close) event-result/close]
    [(and (char? ch) (equal? ch #\j)) (ft-cursor-down!) event-result/consume]
    [(and (char? ch) (equal? ch #\k)) (ft-cursor-up!) event-result/consume]
    [(and (char? ch) (equal? ch #\l)) (ft-activate!)]
    [(and (char? ch) (equal? ch #\h))
     (define entry (ft-current))
     (when (and entry (is-dir? (car entry))
                     (hash-contains? *ft-dirs* (car entry))
                     (not (hash-try-get *ft-dirs* (car entry))))
       (ft-toggle-dir! (car entry)))
     event-result/consume]
    [(and (char? ch) (equal? ch #\.))
     (set! *ft-show-hidden* (not *ft-show-hidden*))
     (set-status! (if *ft-show-hidden* "file-tree: showing hidden"
                     "file-tree: hiding hidden"))
     (ft-build-tree!)
     (ft-clamp-cursor!)
     event-result/consume]
     [(and (char? ch) (equal? ch #\R))
     (ft-build-tree!)
     (ft-clamp-cursor!)
     event-result/consume]
    [else event-result/consume]))

;; ── Public API ─────────────────────────────────────────────────

(define (file-tree-focused?)
  *ft-focused*)

(define (file-tree-configure! #:width [width 32]
                               #:side [side 'left]
                               #:ignore [ignore '(".git" "target"
                                                   "node_modules" "__pycache__")])
  (set! *ft-width* width)
  (set! *ft-side* side)
  (set! *ft-ignore-set* (apply hashset ignore)))

(define (file-tree-close)
  (set! *ft-active* #f)
  (set! *ft-focused* #f)
  (pop-last-component-by-name! "file-tree-fg")
  (pop-last-component-by-name! "file-tree-bg")
  (enqueue-thread-local-callback
   (lambda ()
     (if (equal? *ft-side* 'right)
         (set-editor-clip-right! 0)
         (set-editor-clip-left! 0)))))

(define (file-tree-open)
  (cond
    [(not *ft-active*)
     (set! *ft-active* #t)
     (set! *ft-focused* #t)
     (set! *ft-cursor* 0)
     (set! *ft-window-start* 0)
     (ft-build-tree!)
     (push-component! (new-component! "file-tree-bg"
                                       (FtBgState)
                                       ft-render-bg
                                       (hash "handle_event" ft-handle-event-bg)))
     (push-component! (new-component! "file-tree-fg"
                                       (FtFgState)
                                       ft-render-fg
                                       (hash "handle_event" ft-handle-event-fg)))]
    [*ft-focused*
     (file-tree-close)]
    [else
     (set! *ft-focused* #t)
     (push-component! (new-component! "file-tree-fg"
                                       (FtFgState)
                                       ft-render-fg
                                       (hash "handle_event" ft-handle-event-fg)))]))

(define file-tree-toggle file-tree-open)
