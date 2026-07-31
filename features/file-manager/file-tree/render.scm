(require "helix/components.scm")
(require (only-in "helix/editor.scm"
                  editor-all-documents
                  editor-document->path))
(require (only-in "features/ui/color.scm" terminal-color))
(require (only-in "features/file-manager/core/file-style.scm" file-icon file-color))
(require (only-in "features/ui/style.scm" make-style))
(require (only-in "features/ui/indent-guides.scm" indent-guide-string))
(require "features/file-manager/core/files.scm")
(require (only-in "features/file-manager/core/collections.scm" fm-member?))
(require "features/file-manager/file-tree/git.scm")

(provide make-file-tree-render)

(define (ft-render-row-path row) (list-ref row 1))
(define (ft-render-row-depth row) (car row))

(define (ft-render-git-icon kind)
  (cond [(equal? kind 'added) ""]
        [(equal? kind 'deleted) ""]
        [(equal? kind 'renamed) ""]
        [(equal? kind 'conflict) ""]
        [(equal? kind 'modified) ""]
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

(define (ft-render-file-style-on-row foreground row-style selected? open?)
  (define row-style-applied (ft-render-style-on-row foreground row-style))
  (define open-style
    (if open? (style-with-italics row-style-applied) row-style-applied))
  (if selected? (style-with-bold open-style) open-style))

(define (ft-render-document-path doc-id)
  (with-handler (lambda (_) #f) (editor-document->path doc-id)))

(define (ft-render-open-document-paths)
  (filter (lambda (path) (and path (string? path)))
          (map ft-render-document-path (editor-all-documents))))

(define (ft-render-indent depth)
  (if (<= depth 0)
      ""
      (string-append indent-guide-string " " (ft-render-indent (- depth 1)))))

(define (ft-render-directory-icon root? expanded?)
  (cond [root? (if expanded? "" "")]
        [expanded? ""]
        [else ""]))

(define (ft-render-row-mark row marked)
  (define path (ft-render-row-path row))
  (if (fm-member? path marked) "* " "  "))

(define (ft-render-row-icon row root expanded icon-style)
  (define path (ft-render-row-path row))
  (define root? (string=? path root))
  (define dir? (is-dir? path))
  (define expanded? (and dir? (fm-member? path expanded)))
  (if dir?
      (ft-render-directory-icon root? expanded?)
      (file-icon (fm-entry-label path) #:icon-style icon-style)))

(define (ft-render-clipboard-status content-x status-y content-w clipboard mode frame)
  (define base-style (theme-scope-ref "ui.statusline"))
  (frame-set-string! frame content-x status-y (make-string content-w #\space) base-style)
  (when (and mode (not (null? clipboard)))
    (define copy? (equal? mode 'copy))
    (define indicator
      (string-append " " (if copy? "" "") " "
                     (if copy? "copy " "cut ") (int->string (length clipboard))))
    (define indicator-style
      (theme-scope-ref (if copy? "ui.statusline.insert" "ui.statusline.select")))
    (frame-set-string! frame content-x status-y
                       (fm-fit-text indicator content-w) indicator-style)))

(define (make-file-tree-render state-ref state-set! config-ref)
  (lambda (state rect frame)
    ;; Panel resolves the configured side and width; File Tree owns the Helix
    ;; component that renders into the supplied rectangle.
    (define side (config-ref 'side))
    (define width (max 1 (area-width rect)))
    (define height (max 1 (area-height rect)))
    (define x (area-x rect))
    (define y (area-y rect))
    (define has-divider? (> width 1))
    (define content-x (if (and has-divider? (equal? side 'right)) (+ x 1) x))
    (define content-w (if has-divider? (- width 1) width))
    (define divider-x (if (equal? side 'right) x (+ x width -1)))
    (define content-h (max 1 (- height 2)))
    (define status-y (max y (- (+ y height) 2)))
    (state-set! 'layout (list width content-h))
    (state-set! 'bounds
                (list x y width height content-x y content-w content-h))
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
    (define git-ignored (state-ref 'git-ignored))
    (define bg (theme-scope-ref "ui.background"))
    (define text (theme-scope-ref "ui.text"))
    (define inactive (theme-scope-ref "ui.text.inactive"))
    (define selected (if focused?
                         (theme-scope-ref "ui.menu.selected")
                         text))
    (define dir-style (theme-scope-ref "ui.text.info"))
    (define indent-guide (theme-scope-ref "ui.virtual.indent-guide"))
    (define divider (theme-scope-ref "ui.window"))
    (define open-document-paths (ft-render-open-document-paths))
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
      (define ignored? (and path (ft-git-ignored? git-ignored path)))
      (define open? (and path
                         (not (is-dir? path))
                         (fm-member? path open-document-paths)))
      (define style (if selected? selected text))
      (frame-set-string! frame content-x row-y (make-string content-w #\space) style)
      (when entry
        (define icon-style-option (config-ref 'icon-style))
        (define mark (ft-render-row-mark entry marked))
        (define indent (ft-render-indent (ft-render-row-depth entry)))
        (define leading (string-append mark indent))
        (define icon (ft-render-row-icon entry root expanded icon-style-option))
        (define prefix (string-append leading icon " "))
        (define mark-w (fm-display-width mark))
        (define leading-w (fm-display-width leading))
        (define prefix-w (fm-display-width prefix))
        (define git-kinds (ft-git-path-kinds git-status root path))
        (define git-kind (and (not (null? git-kinds)) (car git-kinds)))
        (define git-icon (ft-render-git-icon git-kind))
        (define git-w (fm-display-width git-icon))
        (define right-padding (if (> content-w 1) 1 0))
        (define label-w (max 0 (- content-w prefix-w right-padding git-w
                                  (if git-kind 1 0))))
        (define mark-style
          (ft-render-style-on-row (if ignored? inactive text) style))
        (define indent-style
          (ft-render-style-on-row indent-guide style))
        (define icon-style
          (ft-render-file-style-on-row
            (cond [ignored? inactive]
                  [(is-dir? path) dir-style]
                  [(equal? icon-style-option 'full)
                   (style-fg text
                             (terminal-color
                               (file-color (fm-entry-label path))))]
                  [else text])
            style
            selected?
            open?))
        (define name-style
          (ft-render-file-style-on-row
            (cond [ignored? inactive]
                  [git-kind (ft-render-git-style git-kind)]
                  [(and selected? focused?) selected]
                  [(is-dir? path) dir-style]
                  [else text])
            style
            selected?
            open?))
        (frame-set-string! frame content-x row-y mark mark-style)
        (frame-set-string! frame (+ content-x mark-w) row-y indent indent-style)
        (frame-set-string! frame (+ content-x leading-w) row-y icon icon-style)
        (frame-set-string! frame (+ content-x prefix-w) row-y
                           (fm-fit-text (fm-entry-label path) label-w) name-style)
        (when git-kind
          (frame-set-string! frame (+ content-x (- content-w right-padding git-w))
                             row-y git-icon
                             (ft-render-file-style-on-row
                               (if ignored?
                                   inactive
                                   (ft-render-git-style git-kind))
                               style
                               selected?
                               open?)))))
    (ft-render-clipboard-status content-x status-y content-w
                                clipboard clipboard-mode frame)))
