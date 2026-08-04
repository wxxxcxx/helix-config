(require (only-in "../../../core/process.scm"
                  core-process-trimmed-output))

(provide fe-bookmarks-load fe-bookmarks-save!
         fe-bookmark-ref fe-bookmark-set fe-bookmark-remove fe-bookmark-replace
         fe-bookmark-paths fe-bookmark-prune fe-bookmark-key-for-path)

(define (fe-capture-output program args)
  (with-handler
    (lambda (_) #f)
    (core-process-trimmed-output program args)))

(define (fe-bookmarks-state-dir)
  ;; Mirrors helix_loader::cache_dir(), which uses the XDG cache strategy
  ;; on Unix-like systems and LOCALAPPDATA on Windows.
  (define path
    (if (equal? (current-os!) "windows")
        (fe-capture-output
          "powershell.exe"
          (list "-NoProfile" "-Command"
                "[Environment]::GetFolderPath('LocalApplicationData') + '\\helix'"))
        (fe-capture-output
          "sh"
          (list "-c" "printf %s \"${XDG_CACHE_HOME:-$HOME/.cache}/helix\""))))
  (if (and path (not (string=? path "")))
      path
      (error! "file explorer: could not determine Helix cache directory")))

(define (fe-bookmarks-path)
  (string-append (fe-bookmarks-state-dir)
                 (path-separator)
                 "file-explorer-bookmarks.scm"))

(define (fe-bookmark-entry? entry)
  (and (list? entry)
       (= (length entry) 2)
       (char? (car entry))
       (string? (list-ref entry 1))))

(define (fe-valid-bookmarks entries)
  (filter fe-bookmark-entry? entries))

(define (fe-bookmarks-load)
  (define path (fe-bookmarks-path))
  (if (path-exists? path)
      (with-handler
        (lambda (_) '())
        (let ([port (open-input-file path)])
          (let ([entries (read port)])
            (close-port port)
            (if (list? entries) (fe-valid-bookmarks entries) '()))))
      '()))

(define (fe-bookmarks-save! entries)
  (define state-dir (fe-bookmarks-state-dir))
  (unless (path-exists? state-dir)
    (create-directory! state-dir))
  (let ([port (open-output-file (fe-bookmarks-path) #:exists 'truncate)])
    (write entries port)
    (display "\n" port)
    (close-port port)))

(define (fe-bookmark-ref entries key)
  (cond [(null? entries) #f]
        [(equal? key (car (car entries))) (list-ref (car entries) 1)]
        [else (fe-bookmark-ref (cdr entries) key)]))

(define (fe-bookmark-set entries key path)
  (cond [(null? entries) (list (list key path))]
        [(equal? key (car (car entries)))
         (cons (list key path) (cdr entries))]
        [else (cons (car entries) (fe-bookmark-set (cdr entries) key path))]))

(define (fe-bookmark-remove entries key)
  (cond [(null? entries) '()]
        [(equal? key (car (car entries))) (cdr entries)]
        [else (cons (car entries) (fe-bookmark-remove (cdr entries) key))]))

(define (fe-bookmark-replace entries old-path new-path)
  (map (lambda (entry)
         (if (string=? (list-ref entry 1) old-path)
             (list (car entry) new-path)
             entry))
       entries))

(define (fe-bookmark-paths entries)
  (map (lambda (entry) (list-ref entry 1)) entries))

(define (fe-bookmark-key-for-path entries path)
  (cond [(null? entries) #f]
        [(string=? (list-ref (car entries) 1) path) (car (car entries))]
        [else (fe-bookmark-key-for-path (cdr entries) path)]))

(define (fe-bookmark-prune entries)
  (filter (lambda (entry) (path-exists? (list-ref entry 1))) entries))
