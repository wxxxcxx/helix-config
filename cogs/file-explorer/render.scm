(require "helix/components.scm")
(require "cogs/glyph/glyph.scm")
(require "cogs/file-colors.scm")
(require "cogs/file-manager/files.scm")
(require "cogs/file-manager/bookmarks.scm")

(provide make-file-explorer-render)

(define (fe-hl-style) (theme-scope-ref "ui.menu.selected"))
(define (fe-text-style) (theme-scope-ref "ui.text"))
(define (fe-dir-style) (theme-scope-ref "ui.text.info"))
(define (fe-staged-style) (theme-scope-ref "ui.statusline.insert"))
(define (fe-col-style) (theme-scope-ref "ui.background"))
(define (fe-border-style) (theme-scope-ref "ui.help"))

(define (fe-member? value values)
  (cond [(null? values) #f]
        [(equal? value (car values)) #t]
        [else (fe-member? value (cdr values))]))

(define (make-file-explorer-render state-ref state-set! config-ref)
  (lambda (state rect frame)
    (let* ([area-w (area-width rect)]
           [area-h (area-height rect)]
           [layout (fe-calc-layout area-w area-h (config-ref 'width-pct) (config-ref 'height-pct))]
           [box-x (list-ref layout 0)]
           [box-y (list-ref layout 1)]
           [box-w (list-ref layout 2)]
           [box-h (list-ref layout 3)]
           [col-widths (fe-calc-col-widths (- box-w 2) (config-ref 'col-ratios))]
           [lw (list-ref col-widths 0)]
           [mw (list-ref col-widths 1)]
           [rw (list-ref col-widths 2)])
      (let* ([bg-style (fe-col-style)]
             [text-style (fe-text-style)]
             [dir-style (fe-dir-style)]
             [staged-style (fe-staged-style)]
             [hl-style (fe-hl-style)]
             [parent-hl-style (style-fg hl-style (or (style->fg dir-style) (style->fg hl-style)))]
             [border-style (fe-border-style)]
             [sep-x1 (+ box-x 1 lw)]
             [sep-x2 (+ sep-x1 1 mw)]
             [content-y (+ box-y 1)]
             [content-h (- box-h 2)]
             [_ (state-set! 'content-h content-h)]
             [bottom-y (- (+ box-y box-h) 1)]
             [files (state-ref 'files)]
             [parent-files (state-ref 'parent-files)]
             [cursor-row (state-ref 'cursor-row)]
             [parent-cursor (state-ref 'parent-cursor)]
             [scrolls (state-ref 'col-scroll)]
             [marked (state-ref 'marked)]
             [bookmarks (state-ref 'bookmarks)]
             [clipboard (state-ref 'clipboard)]
             [clipboard-mode (state-ref 'clipboard-mode)]
             [filter-query (state-ref 'filter-query)]
             [filtering? (state-ref 'filtering?)]
             [sort-mode (state-ref 'sort-mode)]
             [sort-reverse? (state-ref 'sort-reverse?)]
             [show-hidden? (or (state-ref 'show-hidden) (config-ref 'show-hidden))])
        (buffer/clear-with frame (area box-x box-y box-w box-h) bg-style)
        (let* ([queue-title (if clipboard-mode
                                (string-append "[" (if (equal? clipboard-mode 'copy) "yank " "cut ")
                                               (int->string (length clipboard)) "] ")
                                "")]
               [filter-title (if (or filtering? (not (string=? filter-query "")))
                                 (string-append "[filter: " filter-query (if filtering? "|] " "] "))
                                 "")]
               [sort-title (if (and (equal? sort-mode 'name) (not sort-reverse?))
                               ""
                               (string-append "[sort: "
                                              (cond [(equal? sort-mode 'extension) "ext"]
                                                    [(equal? sort-mode 'size) "size"]
                                                    [else "name"])
                                              (if sort-reverse? " desc] " "] ")))]
               [status-title (fe-fit-text (string-append queue-title filter-title sort-title)
                                          (max 0 (- box-w 5)))]
               [path-title (fe-fit-text (fe-path-label (state-ref 'path)) (max 0 (- box-w 5 (fe-display-width status-title))))]
               [title-prefix (string-append BORDER-TL BORDER-H " " path-title " ")]
               [title (string-append title-prefix status-title)]
               [title-len (fe-display-width title)]
               [fill-len (- box-w title-len 1)])
          (frame-set-string! frame box-x box-y title-prefix border-style)
          (when (not (string=? status-title ""))
            (frame-set-string! frame (+ box-x (fe-display-width title-prefix)) box-y status-title staged-style))
          (frame-set-string! frame (+ box-x title-len) box-y (border-h fill-len) border-style)
          (frame-set-string! frame (- (+ box-x box-w) 1) box-y BORDER-TR border-style))
        (frame-set-string! frame box-x bottom-y BORDER-BL border-style)
        (frame-set-string! frame (+ box-x 1) bottom-y (border-h lw) border-style)
        (frame-set-string! frame sep-x1 bottom-y "┴" border-style)
        (frame-set-string! frame (+ sep-x1 1) bottom-y (border-h mw) border-style)
        (frame-set-string! frame sep-x2 bottom-y "┴" border-style)
        (frame-set-string! frame (+ sep-x2 1) bottom-y (border-h rw) border-style)
        (frame-set-string! frame (- (+ box-x box-w) 1) bottom-y BORDER-BR border-style)
        (do [(i 0 (+ i 1))] [(>= i content-h)]
          (frame-set-string! frame box-x (+ content-y i) BORDER-V border-style)
          (frame-set-string! frame (- (+ box-x box-w) 1) (+ content-y i) BORDER-V border-style)
          (frame-set-string! frame sep-x1 (+ content-y i) BORDER-V border-style)
          (frame-set-string! frame sep-x2 (+ content-y i) BORDER-V border-style))
        (letrec ([render-col
                   (lambda (col-x col-w entries selected-row scroll markable? parent-column?)
                     (do [(i 0 (+ i 1))] [(>= i content-h)]
                       (let* ([file-idx (+ scroll i)]
                              [row-y (+ content-y i)]
                              [selected? (= selected-row file-idx)]
                              [active-style (if parent-column? parent-hl-style hl-style)]
                              [entry (if (< file-idx (length entries)) (list-ref entries file-idx) #f)])
                         (cond
                           [(and entry (is-dir? entry))
                            (let* ([name (fe-entry-label entry)]
                                   [staged? (and markable? (and clipboard-mode (fe-member? entry clipboard)))]
                                   [bookmark-key (fe-bookmark-key-for-path bookmarks entry)]
                                   [mark (cond [(and markable? (fe-member? entry marked)) "* "]
                                               [bookmark-key (string-append (string bookmark-key) " ")]
                                               [else "  "])]
                                   [icon-str (string-append (glyph-dir-closed) " ")]
                                   [display (fe-fit-text name (- col-w (fe-display-width mark) (fe-display-width icon-str)))]
                                   [row-style (if selected? active-style (if staged? staged-style dir-style))])
                              (when selected?
                                (frame-set-string! frame col-x row-y (make-string col-w #\space) active-style))
                              (frame-set-string! frame col-x row-y mark (if selected? active-style (if staged? staged-style text-style)))
                              (frame-set-string! frame (+ col-x (fe-display-width mark)) row-y icon-str row-style)
                              (frame-set-string! frame (+ col-x (fe-display-width mark) (fe-display-width icon-str)) row-y display row-style))]
                           [entry
                            (let* ([name (fe-entry-label entry)]
                                   [staged? (and markable? (and clipboard-mode (fe-member? entry clipboard)))]
                                   [bookmark-key (fe-bookmark-key-for-path bookmarks entry)]
                                   [mark (cond [(and markable? (fe-member? entry marked)) "* "]
                                               [bookmark-key (string-append (string bookmark-key) " ")]
                                               [else "  "])]
                                   [icon (glyph-icon name)]
                                   [icon-str (string-append icon " ")]
                                   [icon-color (style-fg (style) (glyph-hex->color (file-color name)))]
                                   [row-style (if selected? active-style (if staged? staged-style text-style))]
                                   [icon-style (if selected? active-style (if staged? staged-style icon-color))]
                                   [display (fe-fit-text name (- col-w (fe-display-width mark) (fe-display-width icon-str)))])
                              (when selected?
                                (frame-set-string! frame col-x row-y (make-string col-w #\space) active-style))
                              (frame-set-string! frame col-x row-y mark (if selected? active-style (if staged? staged-style text-style)))
                              (frame-set-string! frame (+ col-x (fe-display-width mark)) row-y icon-str icon-style)
                              (frame-set-string! frame (+ col-x (fe-display-width mark) (fe-display-width icon-str)) row-y display row-style))]
                           [else (frame-set-string! frame col-x row-y (make-string col-w #\space) bg-style)]))))])
          (render-col (+ box-x 1) lw parent-files parent-cursor (vector-ref scrolls 0) #f #t)
          (render-col (+ sep-x1 1) mw files cursor-row (vector-ref scrolls 1) #t #f))
        (let ([preview-path (if (< cursor-row (length files)) (list-ref files cursor-row) #f)])
          (if preview-path
              (begin
                (cond
                  [(is-dir? preview-path)
                   (let ([children (fe-read-dir-names preview-path show-hidden?)])
                     (do [(i 0 (+ i 1))] [(>= i content-h)]
                     (let ([row-y (+ content-y i)])
                       (if (< i (length children))
                           (let* ([child (list-ref children i)]
                                  [name (fe-entry-label child)]
                                  [child-style (if (is-dir? child) dir-style text-style)]
                                  [icon-str (string-append (glyph-icon (if (is-dir? child) "" name)) " ")]
                                  [display (fe-fit-text name (- rw (fe-display-width icon-str)))])
                             (frame-set-string! frame (+ sep-x2 1) row-y (string-append icon-str display) child-style))
                           (frame-set-string! frame (+ sep-x2 1) row-y (make-string rw #\space) bg-style)))))]
                  [(fe-is-text-ext? preview-path)
                   (let ([lines (fe-read-preview preview-path content-h rw)])
                     (do [(i 0 (+ i 1))] [(>= i content-h)]
                     (let ([row-y (+ content-y i)])
                       (if (< i (length lines))
                           (frame-set-string! frame (+ sep-x2 1) row-y (list-ref lines i) text-style)
                           (frame-set-string! frame (+ sep-x2 1) row-y (make-string rw #\space) bg-style)))))]
                  [else
                   (do [(i 0 (+ i 1))] [(>= i content-h)]
                     (frame-set-string! frame (+ sep-x2 1) (+ content-y i) (make-string rw #\space) bg-style))])
                (let* ([footer (fe-fit-text (fe-preview-footer preview-path) rw)]
                       [footer-width (fe-display-width footer)]
                       [footer-x (+ sep-x2 1 (- rw footer-width))])
                  (frame-set-string! frame (+ sep-x2 1) bottom-y (border-h (- rw footer-width)) border-style)
                  (frame-set-string! frame footer-x bottom-y footer text-style)))
              (do [(i 0 (+ i 1))] [(>= i content-h)]
                (frame-set-string! frame (+ sep-x2 1) (+ content-y i) (make-string rw #\space) bg-style))))))))
