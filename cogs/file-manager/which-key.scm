(require "helix/components.scm")
(require "cogs/file-manager/files.scm")
(require "cogs/file-manager/keymap.scm")

(provide fm-which-key-active? fm-which-key-render!
         fm-which-key-help-render!)

(define (fm-which-key-active? bindings prefix)
  (and (not (string=? prefix ""))
       (not (null? (fm-prefix-menu-entries bindings prefix)))))

(define (fm-which-key-max-key-width entries)
  (if (null? entries)
      0
      (max (fe-display-width (car (car entries)))
           (fm-which-key-max-key-width (cdr entries)))))

(define (fm-which-key-max-description-width entries)
  (if (null? entries)
      0
      (max (fe-display-width (list-ref (car entries) 1))
           (fm-which-key-max-description-width (cdr entries)))))

(define (fm-which-key-render-entries! title entries rect frame)
  (when (not (null? entries))
    (define key-width (fm-which-key-max-key-width entries))
    (define description-width (fm-which-key-max-description-width entries))
    (define max-rows (max 1 (- (area-height rect) 4)))
    (define columns (max 1 (quotient (+ (length entries) max-rows -1) max-rows)))
    (define rows (max 1 (quotient (+ (length entries) columns -1) columns)))
    (define column-width (+ key-width description-width 2))
    (define width (max 8 (min (- (area-width rect) 2)
                              (max (+ (fe-display-width title) 4)
                                   (+ (* columns column-width) 2)))))
    (define height (max 3 (min (- (area-height rect) 2) (+ rows 2))))
    (define x (max 0 (- (area-width rect) width 1)))
    (define y (max 0 (- (area-height rect) height 1)))
    (define visible-column-width (max 1 (quotient (- width 2) columns)))
    (define bg (theme-scope-ref "ui.popup.info"))
    (define key-style (theme-scope-ref "ui.text.info"))
    (define text (theme-scope-ref "ui.text"))
    (buffer/clear-with frame (area x y width height) bg)
    (block/render frame (area x y width height)
                  (make-block bg bg "all" "plain"))
    (frame-set-string! frame (+ x 1) y (fe-fit-text title (- width 2)) text)
    (do [(index 0 (+ index 1))]
        [(>= index (length entries))]
      (define column (quotient index rows))
      (define row (modulo index rows))
      (define column-x (+ x 1 (* column visible-column-width)))
      (define entry (list-ref entries index))
      (define key (car entry))
      (define description (list-ref entry 1))
      (frame-set-string! frame column-x (+ y row 1) key key-style)
      (frame-set-string! frame (+ column-x key-width 2) (+ y row 1)
                         (fe-fit-text description
                                      (max 0 (- visible-column-width key-width 2)))
                         text))))

;; Render-only overlay: the owning component continues to receive input.
(define (fm-which-key-render! bindings prefix rect frame)
  (define entries (fm-prefix-menu-entries bindings prefix))
  (when (not (null? entries))
    (fm-which-key-render-entries! (fm-prefix-description bindings prefix)
                                  entries rect frame)))

(define (fm-which-key-help-render! title bindings rect frame)
  (fm-which-key-render-entries! title (fm-key-overview-entries bindings) rect frame))
