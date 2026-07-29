(require "helix/components.scm")
(require (only-in "cogs/color.scm" terminal-color))
(require (only-in "cogs/file-manager/core/file-style.scm" file-icon file-color))
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

(define (ft-render-indent depth)
  (if (<= depth 0) "" (string-append "  " (ft-render-indent (- depth 1)))))

(define (ft-render-directory-icon root? expanded?)
  (cond [root? (if expanded? "" "")]
        [expanded? ""]
        [else ""]))

(define (ft-render-row-leading row marked)
  (define path (ft-render-row-path row))
  (define depth (ft-render-row-depth row))
  (string-append (if (ft-render-member? path marked) "* " "  ")
                 (ft-render-indent depth)))

(define (ft-render-row-icon row root expanded icon-style)
  (define path (ft-render-row-path row))
  (define root? (string=? path root))
  (define dir? (is-dir? path))
  (define expanded? (and dir? (ft-render-member? path expanded)))
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
      (define ignored? (and path (ft-git-ignored? git-ignored path)))
      (define style (if selected? selected text))
      (frame-set-string! frame content-x row-y (make-string content-w #\space) style)
      (when entry
        (define icon-style-option (config-ref 'icon-style))
        (define leading (ft-render-row-leading entry marked))
        (define icon (ft-render-row-icon entry root expanded icon-style-option))
        (define prefix (string-append leading icon " "))
        (define leading-w (fm-display-width leading))
        (define prefix-w (fm-display-width prefix))
        (define git-kinds (ft-git-path-kinds git-status root path))
        (define git-kind (and (not (null? git-kinds)) (car git-kinds)))
        (define git-icon (ft-render-git-icon git-kind))
        (define git-w (fm-display-width git-icon))
        (define right-padding (if (> content-w 1) 1 0))
        (define label-w (max 0 (- content-w prefix-w right-padding git-w
                                  (if git-kind 1 0))))
        (define leading-style
          (ft-render-style-on-row (if ignored? inactive text) style))
        (define icon-style
          (ft-render-style-on-row
            (cond [root? root-style]
                  [ignored? inactive]
                  [(is-dir? path) dir-style]
                  [(equal? icon-style-option 'full)
                   (style-fg text
                             (terminal-color
                               (file-color (fm-entry-label path))))]
                  [else text])
            style))
        (define name-style
          (ft-render-style-on-row
            (cond [root? root-style]
                  [ignored? inactive]
                  [git-kind (ft-render-git-style git-kind)]
                  [selected? selected]
                  [(is-dir? path) dir-style]
                  [else text])
            style))
        (frame-set-string! frame content-x row-y leading leading-style)
        (frame-set-string! frame (+ content-x leading-w) row-y icon icon-style)
        (frame-set-string! frame (+ content-x prefix-w) row-y
                           (fm-fit-text (fm-entry-label path) label-w) name-style)
        (when git-kind
          (frame-set-string! frame (+ content-x (- content-w right-padding git-w))
                             row-y git-icon
                             (ft-render-style-on-row
                               (if ignored?
                                   inactive
                                   (ft-render-git-style git-kind))
                               style)))))
    (ft-render-clipboard-status content-x status-y content-w
                                clipboard clipboard-mode frame)))
