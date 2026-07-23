(require "helix/components.scm")
(require "helix/misc.scm")
(require "helix/editor.scm")
(require (prefix-in helix. "helix/commands.scm"))
(require "cogs/glyph.scm")
(require "cogs/file-colors.scm")

(provide file-explorer-configure!
         file-explorer-open
         file-explorer-close)

;; ── Configuration ──────────────────────────────────────────────

(define *fe-config*
  (hash 'width-pct 80 'height-pct 70
        'col-ratios '(20 40 40)
        'show-hidden #f
        'keybindings
        (hash "up"       '("k" "up")
              "down"     '("j" "down")
              "parent"   "h"
              "open"     '("l" "enter")
              "preview"  "l"
              "quit"     '("q" "escape")
              "toggle-hidden" "."
              "refresh"  "R"
              "next-col" "tab")))

(define (file-explorer-configure!
         #:key [keybindings #f]
         #:width-pct [width-pct #f]
         #:height-pct [height-pct #f]
         #:show-hidden [show-hidden #f])
  (when width-pct
    (set! *fe-config* (hash-insert *fe-config* 'width-pct width-pct)))
  (when height-pct
    (set! *fe-config* (hash-insert *fe-config* 'height-pct height-pct)))
  (when show-hidden
    (set! *fe-config* (hash-insert *fe-config* 'show-hidden show-hidden)))
  (when keybindings
    (define old (hash-get *fe-config* 'keybindings))
    (set! *fe-config* (hash-insert *fe-config* 'keybindings
                                   (hash-union old keybindings)))))

;; ── State ──────────────────────────────────────────────────────

(define *fe-active* #f)
(define *fe-path* "")
(define *fe-parent-files* '())
(define *fe-files* '())
(define *fe-cursor-col* 1)
(define *fe-cursor-row* 0)
(define *fe-col-scroll* (vector 0 0 0))
(define *fe-show-hidden* #f)
(define *fe-width* 0)
(define *fe-height* 0)
(define *fe-content-h* 0)
(define *fe-parent-cursor* 0)
(define *fe-scrolls* (hash))

;; ── List helpers (Steel may not have take/drop built-in) ───────

(define (fe-take lst n)
  (if (or (null? lst) (<= n 0)) '() (cons (car lst) (fe-take (cdr lst) (- n 1)))))

(define (fe-drop lst n)
  (if (or (null? lst) (<= n 0)) lst (fe-drop (cdr lst) (- n 1))))

;; ── File helpers ───────────────────────────────────────────────

(define (fe-base-name path) (file-name path))

(define (fe-parent-dir path) (parent-name path))

(define (fe-read-dir path)
  (with-handler (lambda (_) '()) (read-dir path)))

(define (fe-dotfile? name)
  (and (> (string-length name) 0) (char=? (string-ref name 0) #\.)))

(define (fe-sort-files entries)
  (define dirs (sort (filter is-dir? entries) string<?))
  (define files (sort (filter (lambda (p) (not (is-dir? p))) entries) string<?))
  (append dirs files))

(define (fe-read-dir-names path)
  (define entries (fe-read-dir path))
  (define show-hidden (or *fe-show-hidden* (hash-get *fe-config* 'show-hidden)))
  (fe-sort-files
    (filter (lambda (p)
              (let ([n (fe-base-name p)])
                (or show-hidden (not (fe-dotfile? n)))))
            entries)))

(define (fe-format-size path)
  (define meta (with-handler (lambda (_) #f) (file-metadata path)))
  (if meta
      (let ([len (fs-metadata-len meta)])
        (cond [(< len 1024)       (string-append (int->string len) " B")]
              [(< len 1048576)    (string-append (int->string (quotient len 1024)) " KiB")]
              [else               (string-append (int->string (quotient len 1048576)) " MiB")]))
      ""))

(define (fe-file-ext path)
  (define parts (split-many path "."))
  (if (> (length parts) 1)
      (list-ref parts (- (length parts) 1))
      ""))

(define (fe-is-text-ext? path)
  (define text-exts '("txt" "md" "rs" "py" "js" "ts" "tsx" "jsx" "css"
                      "html" "json" "toml" "yaml" "yml" "lua" "scm"
                      "c" "h" "cpp" "hpp" "java" "go" "rb" "sh" "zsh"
                      "bash" "fish" "el" "ex" "exs" "hs" "scala" "kt"
                      "swift" "zig" "clj" "cljs" "dart" "svelte" "vue"
                      "sass" "scss" "less" "ps1" "tf" "sql" "r" "jl"
                      "nix" "prisma" "php" "pl" "diff" "vim" "org"
                      "lock" "toml" "xml" "conf" "ini" "cfg"))
  (define ext (fe-file-ext path))
  (define (fe-member x lst)
    (cond [(null? lst) #f]
          [(equal? x (car lst)) #t]
          [else (fe-member x (cdr lst))]))
  (fe-member ext text-exts))

(define (fe-read-preview path max-lines max-width)
  (cond
    [(is-dir? path)
     (define children (fe-read-dir-names path))
     (fe-take children (min max-lines (length children)))]
    [(fe-is-text-ext? path)
     (with-handler
       (lambda (_) (list (string-append "  [" (fe-format-size path) "]")))
       (define content (with-handler
                         (lambda (_) "")
                         (read-port-to-string (open-input-file path))))
       (define lines (split-many content "\n"))
       (define display-lines (fe-take lines (min max-lines (length lines))))
        (map (lambda (l)
               (if (> (string-length l) (- max-width 1))
                   (string-append (substring l 0 (- max-width 2)) "…")
                   l))
            display-lines))]
    [else
     (list (string-append "  [" (fe-format-size path) "]" ))]))

;; ── Layout ─────────────────────────────────────────────────────

(define (fe-calc-layout w h)
  (define w-pct (hash-get *fe-config* 'width-pct))
  (define h-pct (hash-get *fe-config* 'height-pct))
  (define box-w (min (max (quotient (* w w-pct) 100) 40) 120))
  (define box-h (min (max (quotient (* h h-pct) 100) 10) (- h 2)))
  (define box-x (quotient (- w box-w) 2))
  (define box-y (quotient (- h box-h) 2))
  (list box-x box-y box-w box-h))

(define (fe-calc-col-widths inner-w)
  (define ratios (hash-get *fe-config* 'col-ratios))
  (define total (apply + ratios))
  (define avail (- inner-w 2))
  (define lw (quotient (* avail (list-ref ratios 0)) total))
  (define mw (quotient (* avail (list-ref ratios 1)) total))
  (define rw (- avail lw mw))
  (list lw mw rw))

;; ── Border chars ───────────────────────────────────────────────

(define BORDER-H  "─")
(define BORDER-V  "│")
(define BORDER-TL "╭")
(define BORDER-TR "╮")
(define BORDER-BL "╰")
(define BORDER-BR "╯")
(define BORDER-LT "├")
(define BORDER-RT "┤")
(define BORDER-TC "┬")

(define (border-h n)
  (if (<= n 0) "" (string-append BORDER-H (border-h (- n 1)))))

;; ── Rendering ──────────────────────────────────────────────────

(define (fe-hl-style)   (theme-scope-ref "ui.menu.selected"))
(define (fe-text-style) (theme-scope-ref "ui.text"))
(define (fe-dir-style)  (theme-scope-ref "ui.text.info"))
(define (fe-col-style)  (theme-scope-ref "ui.background"))
(define (fe-border-style) (theme-scope-ref "ui.help"))

(define (fe-render state rect frame)
  (let* ([area-w (area-width rect)]
         [area-h (area-height rect)]
         [layout (fe-calc-layout area-w area-h)]
         [box-x (list-ref layout 0)]
         [box-y (list-ref layout 1)]
         [box-w (list-ref layout 2)]
         [box-h (list-ref layout 3)]
         [col-widths (fe-calc-col-widths (- box-w 2))]
         [lw (list-ref col-widths 0)]
         [mw (list-ref col-widths 1)]
         [rw (list-ref col-widths 2)])
        (let* ([bg-style (fe-col-style)]
               [text-style (fe-text-style)]
               [dir-style (fe-dir-style)]
               [hl-style (fe-hl-style)]
               [border-style (fe-border-style)]
               [sep-x1 (+ box-x 1 lw)]
               [sep-x2 (+ sep-x1 1 mw)]
               [content-y (+ box-y 1)]
               [content-h (- box-h 2)]
               [_ (set! *fe-content-h* content-h)]
               [bottom-y (- (+ box-y box-h) 1)])

          (buffer/clear-with frame (area box-x box-y box-w box-h) bg-style)

          ;; Top border:  ╭─ path ───────────╮
          (let* ([title (string-append BORDER-TL BORDER-H " " *fe-path* " ")]
                 [title-len (string-length title)]
                 [fill-len (- box-w title-len 1)])
            (frame-set-string! frame box-x box-y title border-style)
            (frame-set-string! frame (+ box-x title-len) box-y
                              (border-h fill-len) border-style)
            (frame-set-string! frame (- (+ box-x box-w) 1) box-y BORDER-TR border-style))

          ;; Bottom border:  ╰───┴──────┴────╯
          (frame-set-string! frame box-x bottom-y BORDER-BL border-style)
          (frame-set-string! frame (+ box-x 1) bottom-y (border-h lw) border-style)
          (frame-set-string! frame sep-x1 bottom-y "┴" border-style)
          (frame-set-string! frame (+ sep-x1 1) bottom-y (border-h mw) border-style)
          (frame-set-string! frame sep-x2 bottom-y "┴" border-style)
          (frame-set-string! frame (+ sep-x2 1) bottom-y (border-h rw) border-style)
          (frame-set-string! frame (- (+ box-x box-w) 1) bottom-y BORDER-BR border-style)

          ;; Side borders + column separators
          (do [(i 0 (+ i 1))] [(>= i content-h)]
            (frame-set-string! frame box-x (+ content-y i) BORDER-V border-style)
            (frame-set-string! frame (- (+ box-x box-w) 1) (+ content-y i) BORDER-V border-style)
            (frame-set-string! frame sep-x1 (+ content-y i) BORDER-V border-style)
            (frame-set-string! frame sep-x2 (+ content-y i) BORDER-V border-style))

          ;; ── Render each column ──

          (letrec ([render-col
                     (lambda (col-x col-w files cursor-col cursor-pos scroll)
                       (do [(i 0 (+ i 1))] [(>= i content-h)]
                         (let* ([file-idx (+ scroll i)]
                                [row-y (+ content-y i)]
                                [cursor? (if (= cursor-col 0)
                                             (= cursor-pos file-idx)
                                             (and (= *fe-cursor-col* cursor-col) (= *fe-cursor-row* file-idx)))]
                               [entry (if (< file-idx (length files)) (list-ref files file-idx) #f)])
                          (cond
                            [(and entry (is-dir? entry))
                             (let* ([name (fe-base-name entry)]
                                     [display (if (> (string-length name) (- col-w 4))
                                                  (string-append (substring name 0 (- col-w 7)) "…")
                                                  name)])
                                (when cursor?
                                  (frame-set-string! frame col-x row-y (make-string col-w #\space) hl-style))
                                (frame-set-string! frame col-x row-y (string-append (glyph-dir-closed) " ") (if cursor? hl-style dir-style))
                                (frame-set-string! frame (+ col-x 2) row-y display (if cursor? hl-style dir-style)))]
                             [entry
                              (let* ([name (fe-base-name entry)]
                                     [display (if (> (string-length name) (- col-w 4))
                                                  (string-append (substring name 0 (- col-w 7)) "…")
                                                  name)]
                                    [icon (glyph-icon name)]
                                    [icon-str (string-append icon " ")]
                                    [icon-color (style-fg (style) (glyph-hex->color (file-color name)))]
                                    [icon-style (if cursor? hl-style icon-color)])
                               (when cursor?
                                 (frame-set-string! frame col-x row-y (make-string col-w #\space) hl-style))
                               (frame-set-string! frame col-x row-y icon-str icon-style)
                               (frame-set-string! frame (+ col-x (string-length icon-str)) row-y display (if cursor? hl-style text-style)))]
                            [else
                             (frame-set-string! frame col-x row-y (make-string col-w #\space) bg-style)]))))])
            (render-col (+ box-x 1) lw *fe-parent-files* 0 *fe-parent-cursor* (vector-ref *fe-col-scroll* 0))
            (render-col (+ sep-x1 1) mw *fe-files* 1 *fe-cursor-row* (vector-ref *fe-col-scroll* 1)))

          ;; ── Right column: preview ──
          (let ([preview-path
                 (if (< *fe-cursor-row* (length *fe-files*))
                     (list-ref *fe-files* *fe-cursor-row*)
                     #f)])
            (if preview-path
                (cond
                  [(is-dir? preview-path)
                   (let ([children (fe-read-dir-names preview-path)])
                     (do [(i 0 (+ i 1))] [(>= i content-h)]
                       (let ([row-y (+ content-y i)])
                         (if (< i (length children))
                             (let* ([child (list-ref children i)]
                                    [name (fe-base-name child)]
                                     [display (if (> (string-length name) (- rw 3))
                                                  (string-append (substring name 0 (- rw 4)) "…")
                                                  name)]
                                    [c-style (if (is-dir? child) dir-style text-style)]
                                    [i-glyph (glyph-icon (if (is-dir? child) "" name))])
                               (frame-set-string! frame (+ sep-x2 1) row-y (string-append i-glyph " " display) c-style))
                             (frame-set-string! frame (+ sep-x2 1) row-y (make-string rw #\space) bg-style)))))]
                  [(fe-is-text-ext? preview-path)
                   (let ([lines (fe-read-preview preview-path content-h rw)])
                     (do [(i 0 (+ i 1))] [(>= i content-h)]
                       (let ([row-y (+ content-y i)])
                         (if (< i (length lines))
                             (frame-set-string! frame (+ sep-x2 1) row-y (list-ref lines i) text-style)
                             (frame-set-string! frame (+ sep-x2 1) row-y (make-string rw #\space) bg-style)))))]
                  [else
                   (frame-set-string! frame (+ sep-x2 1) content-y
                                     (string-append "  [" (fe-format-size preview-path) "]") text-style)])
                (do [(i 0 (+ i 1))] [(>= i content-h)]
                  (frame-set-string! frame (+ sep-x2 1) (+ content-y i) (make-string rw #\space) bg-style)))))))

;; ── Keybinding dispatch ────────────────────────────────────────

(define (fe-kb-string event)
  (define ch (key-event-char event))
  (cond
    [(key-event-down? event)   "down"]
    [(key-event-up? event)     "up"]
    [(key-event-enter? event)  "enter"]
    [(key-event-tab? event)    "tab"]
    [(key-event-escape? event) "escape"]
    [(char? ch)                (string ch)]
    [else                      ""]))

(define (fe-match? action event)
  (define triggers (hash-try-get (hash-get *fe-config* 'keybindings) action))
  (define event-str (fe-kb-string event))
  (define (fe-list-member x lst)
    (cond [(null? lst) #f]
          [(equal? x (car lst)) #t]
          [else (fe-list-member x (cdr lst))]))
  (cond
    [(not triggers) #f]
    [(string? triggers) (string=? triggers event-str)]
    [(list? triggers) (fe-list-member event-str triggers)]
    [else #f]))

;; ── Event handling ─────────────────────────────────────────────

(define (fe-clamp-cursor)
  (define files (if (= *fe-cursor-col* 1) *fe-files* *fe-parent-files*))
  (when (>= *fe-cursor-row* (length files))
    (set! *fe-cursor-row* (max 0 (- (length files) 1)))))

(define (fe-parent-idx)
  (define dir-name (fe-base-name *fe-path*))
  (define (search lst i)
    (cond [(null? lst) 0]
          [(equal? dir-name (fe-base-name (car lst))) i]
          [else (search (cdr lst) (+ i 1))]))
  (search *fe-parent-files* 0))

(define (fe-save-scrolls!)
  (set! *fe-scrolls* (hash-insert *fe-scrolls* *fe-path* (cons (vector-ref *fe-col-scroll* 1) *fe-cursor-row*)))
  (set! *fe-scrolls* (hash-insert *fe-scrolls* (string-append *fe-path* "/parent") (vector-ref *fe-col-scroll* 0))))

(define (fe-load-scroll dir)
  (define saved (hash-try-get *fe-scrolls* dir))
  (if (pair? saved) (car saved) (if saved saved 0)))

(define (fe-load-cursor dir)
  (define saved (hash-try-get *fe-scrolls* dir))
  (if (pair? saved) (cdr saved) 0))

(define (fe-enter-dir dir)
  (let ([old-path *fe-path*])
    (when (and (not (equal? dir old-path)) (> (string-length old-path) 0))
      (fe-save-scrolls!)))
  (set! *fe-path* dir)
  (set! *fe-parent-files* (fe-read-dir-names (fe-parent-dir *fe-path*)))
  (set! *fe-files* (fe-read-dir-names *fe-path*))
  (set! *fe-parent-cursor* (fe-parent-idx))
  (set! *fe-cursor-col* 1)
  (define saved-row (fe-load-cursor dir))
  (set! *fe-cursor-row* (min saved-row (max 0 (- (length *fe-files*) 1))))
  (define soff (with-handler (lambda (_) 3) (car (helix.get-option '(scrolloff)))))
  (define m-scroll (fe-load-scroll dir))
  (define parent-path (fe-parent-dir *fe-path*))
  (define p-scroll (fe-load-scroll parent-path))
  (when (and (= p-scroll 0) (not (hash-contains? *fe-scrolls* parent-path)))
    (set! p-scroll (max 0 (- *fe-parent-cursor* soff))))
  ;; Ensure cursor is visible in scroll
  (when (< *fe-cursor-row* (+ m-scroll soff))
    (set! m-scroll (max 0 (- *fe-cursor-row* soff))))
  (when (> *fe-cursor-row* (- (+ m-scroll *fe-content-h*) soff 1))
    (set! m-scroll (max 0 (- *fe-cursor-row* (- *fe-content-h* soff 1)))))
  (set! *fe-col-scroll* (vector p-scroll m-scroll 0)))

(define (fe-do-open)
  (define cursor-row (if (= *fe-cursor-col* 0) *fe-parent-cursor* *fe-cursor-row*))
  (define files (if (= *fe-cursor-col* 0) *fe-parent-files* *fe-files*))
  (define entry (if (< cursor-row (length files))
                    (list-ref files cursor-row)
                    #f))
  (cond
    [(not entry) event-result/consume]
    [(is-dir? entry) (fe-enter-dir entry) event-result/consume]
    [(is-file? entry)
     (enqueue-thread-local-callback (lambda () (helix.open entry)))
     (file-explorer-close)
     event-result/consume]
    [else event-result/consume]))

(define (fe-do-parent)
  (cond
    ((or (= *fe-cursor-col* 0) (= *fe-cursor-col* 1))
     (let ([parent (fe-parent-dir *fe-path*)])
       (if (equal? parent *fe-path*)
           event-result/consume
           (let ([prev-name (fe-base-name *fe-path*)])
             (fe-save-scrolls!)
             (fe-enter-dir parent)
             (letrec ([search
                       (lambda (lst i)
                         (cond ((null? lst) 0)
                               ((equal? prev-name (fe-base-name (car lst))) i)
                               (else (search (cdr lst) (+ i 1)))))])
               (set! *fe-cursor-row* (search *fe-files* 0))
               (vector-set! *fe-col-scroll* 1 (fe-load-scroll *fe-path*))
                event-result/consume)))))
    (else
     (set! *fe-cursor-col* 1)
     (set! *fe-cursor-row* 0)
     event-result/consume)))

(define (fe-do-preview)
  (cond
    [(= *fe-cursor-col* 0)
     (define entry (if (< *fe-parent-cursor* (length *fe-parent-files*))
                       (list-ref *fe-parent-files* *fe-parent-cursor*)
                       #f))
     (when (and entry (is-dir? entry))
       (fe-enter-dir entry))]
    [(= *fe-cursor-col* 1) (set! *fe-cursor-col* 2)]
    [(= *fe-cursor-col* 2) (set! *fe-cursor-col* 1)])
  event-result/consume)

(define (fe-move-down files cur scroll-col)
  (define max-idx (max 0 (- (length files) 1)))
  (if (< cur max-idx)
       (let ([new-cur (+ cur 1)]
             [scroll (vector-ref *fe-col-scroll* scroll-col)]
             [soff (with-handler (lambda (_) 3) (car (helix.get-option '(scrolloff))))])
        (define bottom (- (+ scroll *fe-content-h*) soff 1))
        (when (> new-cur bottom)
          (vector-set! *fe-col-scroll* scroll-col (+ scroll 1)))
        new-cur)
      cur))

(define (fe-move-up files cur scroll-col)
  (if (> cur 0)
       (let ([new-cur (- cur 1)]
             [scroll (vector-ref *fe-col-scroll* scroll-col)]
             [soff (with-handler (lambda (_) 3) (car (helix.get-option '(scrolloff))))])
        (when (< new-cur (+ scroll soff))
          (vector-set! *fe-col-scroll* scroll-col (max 0 (- scroll 1))))
        new-cur)
      cur))

(define (fe-do-down)
  (if (= *fe-cursor-col* 0)
      (set! *fe-parent-cursor* (fe-move-down *fe-parent-files* *fe-parent-cursor* 0))
      (set! *fe-cursor-row* (fe-move-down *fe-files* *fe-cursor-row* 1)))
  event-result/consume)

(define (fe-do-up)
  (if (= *fe-cursor-col* 0)
      (set! *fe-parent-cursor* (fe-move-up *fe-parent-files* *fe-parent-cursor* 0))
      (set! *fe-cursor-row* (fe-move-up *fe-files* *fe-cursor-row* 1)))
  event-result/consume)

(define (fe-do-next-col)
  (set! *fe-cursor-col* (modulo (+ *fe-cursor-col* 1) 3))
  (set! *fe-cursor-row* 0)
  event-result/consume)

(define (fe-do-toggle-hidden)
  (set! *fe-show-hidden* (not *fe-show-hidden*))
  (set! *fe-parent-files* (fe-read-dir-names (fe-parent-dir *fe-path*)))
  (set! *fe-files* (fe-read-dir-names *fe-path*))
  (set! *fe-cursor-row* 0)
  (set! *fe-col-scroll* (vector 0 0 0))
  event-result/consume)

(define (fe-do-refresh)
  (set! *fe-parent-files* (fe-read-dir-names (fe-parent-dir *fe-path*)))
  (set! *fe-files* (fe-read-dir-names *fe-path*))
  (set! *fe-cursor-row* 0)
  (set! *fe-col-scroll* (vector 0 0 0))
  event-result/consume)

(define (fe-handle-event state event)
  (cond
    [(fe-match? "quit" event)  (file-explorer-close) event-result/close]
    [(fe-match? "down" event)  (fe-do-down)]
    [(fe-match? "up" event)    (fe-do-up)]
    [(fe-match? "open" event)  (fe-do-open)]
    [(fe-match? "parent" event) (fe-do-parent)]
    [(fe-match? "preview" event) (fe-do-preview)]
    [(fe-match? "next-col" event) (fe-do-next-col)]
    [(fe-match? "toggle-hidden" event) (fe-do-toggle-hidden)]
    [(fe-match? "refresh" event) (fe-do-refresh)]
    [else event-result/consume]))

;; ── Public API ─────────────────────────────────────────────────

(define (file-explorer-open)
  (when *fe-active* (file-explorer-close))
  (set! *fe-active* #t)
  (set! *fe-path* (helix-find-workspace))
  (set! *fe-parent-files* (fe-read-dir-names (fe-parent-dir *fe-path*)))
  (set! *fe-files* (fe-read-dir-names *fe-path*))
  (set! *fe-parent-cursor* (fe-parent-idx))
  (set! *fe-cursor-col* 1)
  (define saved-row (fe-load-cursor *fe-path*))
  (set! *fe-cursor-row* (min saved-row (max 0 (- (length *fe-files*) 1))))
  (define m-scroll (fe-load-scroll *fe-path*))
  (define parent-path (fe-parent-dir *fe-path*))
  (define p-scroll (fe-load-scroll parent-path))
  (define soff (with-handler (lambda (_) 3) (car (helix.get-option '(scrolloff)))))
  (when (and (= p-scroll 0) (not (hash-contains? *fe-scrolls* parent-path)))
    (set! p-scroll (max 0 (- *fe-parent-cursor* soff))))
  (set! *fe-col-scroll* (vector p-scroll m-scroll 0))
  (push-component! (new-component! "file-explorer"
                                    (hash)
                                    fe-render
                                    (hash "handle_event" fe-handle-event))))

(define (file-explorer-close)
  (set! *fe-active* #f)
  (pop-last-component-by-name! "file-explorer"))
