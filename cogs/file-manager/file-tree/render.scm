(require "helix/components.scm")
(require "cogs/glyph/glyph.scm")
(require (only-in "cogs/indicators/style.scm" make-style))
(require (only-in "cogs/statusline-palette.scm" major-bg))
(require "cogs/file-manager/core/files.scm")
(require "cogs/file-manager/file-tree/git.scm")

(provide make-file-tree-render)

(define (ft-render-member? value values)
  (cond [(null? values) #f]
        [(equal? value (car values)) #t]
        [else (ft-render-member? value (cdr values))]))

(define (ft-render-row-path row) (list-ref row 1))
(define (ft-render-row-depth row) (car row))

(define (ft-render-git-icon kind)
  (cond [(equal? kind 'added) (glyph "cod-diff_added")]
        [(equal? kind 'deleted) (glyph "cod-diff_removed")]
        [(equal? kind 'renamed) (glyph "cod-diff_renamed")]
        [(equal? kind 'conflict) (glyph "cod-warning")]
        [(equal? kind 'modified) (glyph "cod-diff_modified")]
        [else ""]))

(define (ft-render-git-style kind)
  (make-style
    (cond [(equal? kind 'added) "#A3BE8C"]
          [(equal? kind 'deleted) "#BF616A"]
          [(equal? kind 'renamed) "#88C0D0"]
          [(equal? kind 'conflict) "#BF616A"]
          [else "#EBCB8B"])
    #f #t))

(define (ft-render-style-on-row foreground row-style)
  (define bg (style->bg row-style))
  (if bg (style-bg foreground bg) foreground))

(define (ft-render-indent depth)
  (if (<= depth 0) "" (string-append "  " (ft-render-indent (- depth 1)))))

(define (ft-render-directory-icon root? expanded?)
  (glyph
    (cond [root? (if expanded? "cod-root_folder_opened" "cod-root_folder")]
          [expanded? "cod-folder_opened"]
          [else "cod-folder"])))

(define (ft-render-row-prefix row root expanded marked)
  (define path (ft-render-row-path row))
  (define depth (ft-render-row-depth row))
  (define root? (string=? path root))
  (define dir? (is-dir? path))
  (define expanded? (and dir? (ft-render-member? path expanded)))
  (string-append (if (ft-render-member? path marked) "* " "  ")
                 (ft-render-indent depth)
                 (if dir?
                     (string-append (ft-render-directory-icon root? expanded?) " ")
                     (string-append (glyph-icon (fm-entry-label path)) " "))))

(define (ft-render-clipboard-status content-x status-y content-w clipboard mode frame)
  (define base-style (theme-scope-ref "ui.statusline"))
  (frame-set-string! frame content-x status-y (make-string content-w #\space) base-style)
  (when (and mode (not (null? clipboard)))
    (define copy? (equal? mode 'copy))
    (define indicator
      (string-append " " (glyph (if copy? "cod-copy" "cod-arrow_swap")) " "
                     (if copy? "copy " "cut ") (int->string (length clipboard))))
    (define indicator-style
      (theme-scope-ref (if copy? "ui.statusline.insert" "ui.statusline.select")))
    (frame-set-string! frame content-x status-y
                       (fm-fit-text indicator content-w) indicator-style)))

(define (make-file-tree-render state-ref state-set! config-ref)
  (lambda (state rect frame)
    (define area-w (area-width rect))
    (define area-h (area-height rect))
    (define side (config-ref 'side))
    (define width (min (config-ref 'width) (max 1 (- area-w 2))))
    (define height area-h)
    (define x (if (equal? side 'right) (- area-w width) 0))
    (define y 0)
    (define has-divider? (> width 1))
    (define content-x (if (and has-divider? (equal? side 'right)) (+ x 1) x))
    (define content-w (if has-divider? (- width 1) width))
    (define divider-x (if (equal? side 'right) x (+ x width -1)))
    (define content-h (max 1 (- height 2)))
    (define status-y (max y (- (+ y height) 2)))
    (state-set! 'layout (list width content-h))
    (define root (state-ref 'root))
    (define focused? (state-ref 'focused?))
    (define expanded (state-ref 'expanded))
    (define rows (state-ref 'rows))
    (define selected-index (state-ref 'selected))
    (define scroll (state-ref 'scroll))
    (define marked (state-ref 'marked))
    (define clipboard (state-ref 'clipboard))
    (define clipboard-mode (state-ref 'clipboard-mode))
    (define git-status (state-ref 'git-status))
    (define bg (theme-scope-ref "ui.background"))
    (define text (theme-scope-ref "ui.text"))
    (define selected (if focused?
                         (theme-scope-ref "ui.menu.selected")
                         (theme-scope-ref "ui.selection")))
    (define root-style (style-with-bold (make-style major-bg #f focused?)))
    (define dir-style (theme-scope-ref "ui.text.info"))
    (define divider (theme-scope-ref "ui.window"))
    (buffer/clear-with frame (area x y width height) bg)
    (when has-divider?
      (do [(row 0 (+ row 1))] [(>= row height)]
        (frame-set-string! frame divider-x (+ y row) "│" divider)))
    (do [(row 0 (+ row 1))] [(>= row content-h)]
      (define index (+ scroll row))
      (define row-y (+ y row))
      (define selected? (= index selected-index))
      (define entry (and (< index (length rows)) (list-ref rows index)))
      (define path (and entry (ft-render-row-path entry)))
      (define root? (and path (string=? path root)))
      (define style (if selected? selected text))
      (frame-set-string! frame content-x row-y (make-string content-w #\space) style)
      (when entry
        (define prefix (ft-render-row-prefix entry root expanded marked))
        (define prefix-w (fm-display-width prefix))
        (define git-kinds (ft-git-path-kinds git-status root path))
        (define git-kind (and (not (null? git-kinds)) (car git-kinds)))
        (define git-icon (ft-render-git-icon git-kind))
        (define git-w (fm-display-width git-icon))
        (define right-padding (if (> content-w 1) 1 0))
        (define label-w (max 0 (- content-w prefix-w right-padding git-w
                                  (if git-kind 1 0))))
        (define icon-style
          (ft-render-style-on-row
            (cond [root? root-style] [(is-dir? path) dir-style] [else text]) style))
        (define name-style
          (ft-render-style-on-row
            (cond [root? root-style]
                  [git-kind (ft-render-git-style git-kind)]
                  [selected? selected]
                  [(is-dir? path) dir-style]
                  [else text])
            style))
        (frame-set-string! frame content-x row-y prefix icon-style)
        (frame-set-string! frame (+ content-x prefix-w) row-y
                           (fm-fit-text (fm-entry-label path) label-w) name-style)
        (when git-kind
          (frame-set-string! frame (+ content-x (- content-w right-padding git-w))
                             row-y git-icon
                             (ft-render-style-on-row
                               (ft-render-git-style git-kind) style)))))
    (ft-render-clipboard-status content-x status-y content-w
                                clipboard clipboard-mode frame)))
