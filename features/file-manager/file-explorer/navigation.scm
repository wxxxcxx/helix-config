(require "helix/components.scm")
(require "helix/misc.scm")
(require (prefix-in helix. "helix/commands.scm"))
(require "features/file-manager/file-explorer/config.scm")
(require "features/file-manager/file-explorer/preview.scm")
(require "features/file-manager/file-explorer/state.scm")
(require "features/file-manager/core/files.scm")
(require "features/file-manager/core/keymap.scm")
(require "features/file-manager/core/modal.scm")

(provide fe-current-entry
         fe-enter-dir
         fe-load-directory!
         fe-move-selection
         fe-select-entry!
         fe-refresh-preview!
         fe-reload!
         fe-do-parent
         fe-do-down
         fe-do-up
         fe-do-toggle-hidden
         fe-do-refresh
         fe-do-filter
         fe-update-filter!
         fe-do-filter-key
         fe-do-find
         fe-do-find-prev
         fe-do-find-next
         fe-do-find-previous
         fe-do-sort
         fe-do-sort-key)

(define (fe-col-scroll-ref index)
  (vector-ref (fe-ref 'col-scroll) index))

(define (fe-col-scroll-set! index value)
  (vector-set! (fe-ref 'col-scroll) index value))

(define (fe-entry-index entries name)
  (let loop ([items entries] [index 0])
    (cond [(null? items) 0]
          [(string=? (fm-entry-label (car items)) name) index]
          [else (loop (cdr items) (+ index 1))])))

(define (fe-path-index entries path)
  (let loop ([items entries] [index 0])
    (cond [(null? items) #f]
          [(string=? (car items) path) index]
          [else (loop (cdr items) (+ index 1))])))

(define (fe-parent-idx)
  (fe-entry-index (fe-ref 'parent-files) (fm-entry-label (fe-ref 'path))))

(define (fe-scrolloff)
  (define configured (with-handler (lambda (_) 3) (car (helix.get-option '(scrolloff)))))
  (min (max configured 0) (quotient (max 0 (- (fe-ref 'content-h) 1)) 2)))

(define (fe-scroll-to-visible scroll row count)
  (define height (max 1 (fe-ref 'content-h)))
  (define max-scroll (max 0 (- count height)))
  (define current-scroll (min (max 0 scroll) max-scroll))
  (define offset (fe-scrolloff))
  (define top (+ current-scroll offset))
  (define bottom (- (+ current-scroll height) offset 1))
  (cond [(< row top) (max 0 (- row offset))]
        [(> row bottom) (min max-scroll (max 0 (- row (- height offset 1))))]
        [else current-scroll]))

(define (fe-save-scrolls!)
  (fe-set! 'scrolls
           (hash-insert (fe-ref 'scrolls)
                        (fe-ref 'path)
                        (cons (fe-col-scroll-ref 1) (fe-ref 'cursor-row))))
  (fe-set! 'parent-scrolls
           (hash-insert (fe-ref 'parent-scrolls)
                        (fe-ref 'path)
                        (fe-col-scroll-ref 0))))

(define (fe-load-scroll dir)
  (define saved (hash-try-get (fe-ref 'scrolls) dir))
  (if saved (car saved) 0))

(define (fe-load-cursor dir)
  (define saved (hash-try-get (fe-ref 'scrolls) dir))
  (if saved (cdr saved) 0))

(define (fe-load-parent-scroll dir)
  (or (hash-try-get (fe-ref 'parent-scrolls) dir) 0))

(define (fe-show-hidden?)
  (fe-ref 'show-hidden))

(define (fe-rebuild-visible-files!)
  (fe-set! 'parent-files
           (fm-sort-entries (fe-ref 'all-parent-files)
                            (fe-ref 'sort-mode)
                            (fe-ref 'sort-reverse?)))
  (fe-set! 'files
           (fm-sort-entries (fm-filter-entries (fe-ref 'all-files)
                                               (fe-ref 'filter-query))
                            (fe-ref 'sort-mode)
                            (fe-ref 'sort-reverse?))))

(define (fe-restore-selection! selected-path)
  (fe-set! 'parent-cursor (fe-parent-idx))
  (define selected-index (and selected-path (fe-path-index (fe-ref 'files) selected-path)))
  (fe-set! 'cursor-row
           (if selected-index
               selected-index
               (min (fe-ref 'cursor-row) (max 0 (- (length (fe-ref 'files)) 1)))))
  (fe-col-scroll-set! 0
                      (fe-scroll-to-visible (fe-col-scroll-ref 0)
                                            (fe-ref 'parent-cursor)
                                            (length (fe-ref 'parent-files))))
  (fe-col-scroll-set! 1
                      (fe-scroll-to-visible (fe-col-scroll-ref 1)
                                            (fe-ref 'cursor-row)
                                            (length (fe-ref 'files)))))

(define (fe-load-directory! dir)
  (fe-set! 'path dir)
  (fe-set! 'all-parent-files
           (if (fm-windows-drives-root? dir)
               '()
               (fm-read-dir-names (fm-parent-dir dir) (fe-show-hidden?))))
  (fe-set! 'all-files (fm-read-dir-names dir (fe-show-hidden?)))
  (fe-rebuild-visible-files!)
  (fe-set! 'parent-cursor (fe-parent-idx))
  (fe-set! 'cursor-row
           (min (fe-load-cursor dir) (max 0 (- (length (fe-ref 'files)) 1))))
  (fe-set! 'col-scroll
           (vector
             (fe-scroll-to-visible (fe-load-parent-scroll dir)
                                   (fe-ref 'parent-cursor)
                                   (length (fe-ref 'parent-files)))
             (fe-scroll-to-visible (fe-load-scroll dir)
                                   (fe-ref 'cursor-row)
                                   (length (fe-ref 'files)))))
  (fe-refresh-preview!))

(define (fe-enter-dir dir)
  (let ([old-path (fe-ref 'path)])
    (when (and (not (string=? old-path dir)) (> (string-length old-path) 0))
      (fe-save-scrolls!)))
  (fe-set! 'filter-query "")
  (fe-load-directory! dir))

(define (fe-current-entry)
  (if (< (fe-ref 'cursor-row) (length (fe-ref 'files)))
      (list-ref (fe-ref 'files) (fe-ref 'cursor-row))
      #f))

(define (fe-refresh-preview!)
  (fe-set! 'preview (fe-preview-load (fe-current-entry) (fe-show-hidden?))))

(define (fe-select-entry! path)
  (define index (fe-path-index (fe-ref 'files) path))
  (when index
    (fe-set! 'cursor-row index)
    (fe-col-scroll-set! 1
                        (fe-scroll-to-visible (fe-col-scroll-ref 1)
                                              index
                                              (length (fe-ref 'files))))
    (fe-refresh-preview!)))

(define (fe-do-parent)
  (define current-path (fe-ref 'path))
  (define parent (fm-parent-dir current-path))
  (cond
    [(fm-windows-drive-root? current-path)
     (fe-enter-dir "")
     event-result/consume]
    [(or (fm-windows-drives-root? current-path)
         (string=? parent "")
         (equal? parent current-path))
     event-result/consume]
    [else
     (let ([child-name (fm-entry-label current-path)])
       (fe-enter-dir parent)
       (fe-set! 'cursor-row (fe-entry-index (fe-ref 'files) child-name))
       (fe-col-scroll-set! 1
                           (fe-scroll-to-visible (fe-col-scroll-ref 1)
                                                 (fe-ref 'cursor-row)
                                                 (length (fe-ref 'files))))
       (fe-refresh-preview!)
       event-result/consume)]))

(define (fe-move-selection delta)
  (define max-index (max 0 (- (length (fe-ref 'files)) 1)))
  (define next (min max-index (max 0 (+ (fe-ref 'cursor-row) delta))))
  (fe-set! 'cursor-row next)
  (fe-col-scroll-set! 1
                      (fe-scroll-to-visible (fe-col-scroll-ref 1)
                                            next
                                            (length (fe-ref 'files))))
  (fe-refresh-preview!))

(define (fe-do-down) (fe-move-selection 1) event-result/consume)
(define (fe-do-up) (fe-move-selection -1) event-result/consume)

(define (fe-reload!)
  (define selected-path (fe-current-entry))
  (fm-clear-preview-footer-cache!)
  (fe-set! 'all-parent-files
           (fm-read-dir-names (fm-parent-dir (fe-ref 'path)) (fe-show-hidden?)))
  (fe-set! 'all-files (fm-read-dir-names (fe-ref 'path) (fe-show-hidden?)))
  (fe-rebuild-visible-files!)
  (fe-restore-selection! selected-path)
  (fe-refresh-preview!))

(define (fe-do-toggle-hidden)
  (fe-set! 'show-hidden (not (fe-ref 'show-hidden)))
  (fe-reload!)
  (set-warning! (string-append "hidden files: "
                               (if (fe-ref 'show-hidden) "shown" "hidden")))
  event-result/consume)

(define (fe-do-refresh) (fe-reload!) event-result/consume)

(define (fe-apply-visible-list!)
  (define selected-path (fe-current-entry))
  (fe-rebuild-visible-files!)
  (fe-restore-selection! selected-path)
  (fe-refresh-preview!))

(define (fe-do-filter)
  (fe-set! 'filter-before-input (fe-ref 'filter-query))
  (fe-set! 'pending-action 'filter)
  event-result/consume)

(define (fe-update-filter! query)
  (fe-set! 'filter-query query)
  (fe-apply-visible-list!))

(define (fe-do-filter-key event)
  (define ch (key-event-char event))
  (cond
    [(key-event-enter? event)
     (fe-set! 'pending-action #f)]
    [(key-event-backspace? event)
     (define length (string-length (fe-ref 'filter-query)))
     (when (> length 0)
       (fe-update-filter! (substring (fe-ref 'filter-query) 0 (- length 1))))]
    [(char? ch)
     (fe-update-filter! (string-append (fe-ref 'filter-query) (string ch)))]
    [else #f])
  event-result/consume)

(define (fe-entry-matches? entry query)
  (not (null? (fm-filter-entries (list entry) query))))

(define (fe-wrapped-index index count)
  (cond [(< index 0) (+ index count)]
        [(>= index count) (- index count)]
        [else index]))

(define (fe-find! direction)
  (when (and (not (string=? (fe-ref 'find-query) "")) (not (null? (fe-ref 'files))))
    (let loop ([index (fe-wrapped-index (+ (fe-ref 'cursor-row) direction)
                                        (length (fe-ref 'files)))]
               [remaining (length (fe-ref 'files))])
      (cond [(= remaining 0)
             (set-warning! (string-append "not found: " (fe-ref 'find-query)))]
            [(fe-entry-matches? (list-ref (fe-ref 'files) index) (fe-ref 'find-query))
             (fe-set! 'cursor-row index)
             (fe-col-scroll-set! 1
                                 (fe-scroll-to-visible (fe-col-scroll-ref 1)
                                                       index
                                                       (length (fe-ref 'files))))
             (fe-refresh-preview!)]
            [else
             (loop (fe-wrapped-index (+ index direction) (length (fe-ref 'files)))
                   (- remaining 1))]))))

(define (fe-do-find)
  (fm-prompt! 'input "Find: " (fe-ref 'find-query)
              (lambda (query)
                (fe-set! 'find-query query)
                (fe-find! 1)))
  event-result/consume)

(define (fe-do-find-prev)
  (fm-prompt! 'input "Find: " (fe-ref 'find-query)
              (lambda (query)
                (fe-set! 'find-query query)
                (fe-find! -1)))
  event-result/consume)

(define (fe-do-find-next) (fe-find! 1) event-result/consume)
(define (fe-do-find-previous) (fe-find! -1) event-result/consume)

(define (fe-sort-label)
  (string-append (cond [(equal? (fe-ref 'sort-mode) 'extension) "extension"]
                       [(equal? (fe-ref 'sort-mode) 'size) "size"]
                       [else "name"])
                 (if (fe-ref 'sort-reverse?) " descending" " ascending")))

(define (fe-do-sort-key event)
  (define key (fm-key-token event))
  (fe-set! 'pending-action #f)
  (cond
    [(or (string=? key "a") (string=? key "A"))
     (fe-set! 'sort-mode 'name)
     (fe-set! 'sort-reverse? (string=? key "A"))]
    [(or (string=? key "e") (string=? key "E"))
     (fe-set! 'sort-mode 'extension)
     (fe-set! 'sort-reverse? (string=? key "E"))]
    [(or (string=? key "s") (string=? key "S"))
     (fe-set! 'sort-mode 'size)
     (fe-set! 'sort-reverse? (string=? key "S"))]
    [else (set-warning! "sort: a=name, e=extension, s=size")])
  (when (or (string=? key "a") (string=? key "A")
            (string=? key "e") (string=? key "E")
            (string=? key "s") (string=? key "S"))
    (fe-apply-visible-list!)
    (set-warning! (string-append "sort: " (fe-sort-label))))
  event-result/consume)

(define (fe-do-sort)
  (fe-set! 'pending-action 'sort)
  (set-warning! "sort: a=name, e=extension, s=size; uppercase reverses")
  event-result/consume)
