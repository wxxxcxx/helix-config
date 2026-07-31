;; features/statusline/indicators/version-control.scm

(require "helix/components.scm")
(require "helix/editor.scm")
(require "helix/misc.scm")
(require "features/ui/style.scm")

(define *git-root-by-dir* (hash))
(define *git-cache-by-root* (hash))
(define *git-cache-generation* 0)

(define (git-output dir args)
  (with-handler
    (lambda (err) #f)
    (let* ([proc (~> (command "git" (append (list "-C" dir) args))
                     with-stdout-piped
                     spawn-process)])
      (and (Ok? proc)
           (read-port-to-string (child-stdout (Ok->value proc)))))))

(define (non-empty-output raw)
  (and raw
       (let ([value (trim raw)])
         (and (not (string=? value "")) value))))

(define (git-root dir)
  (if (hash-contains? *git-root-by-dir* dir)
      (hash-get *git-root-by-dir* dir)
      (let ([root (non-empty-output (git-output dir (list "rev-parse" "--show-toplevel")))])
        (set! *git-root-by-dir* (hash-insert *git-root-by-dir* dir root))
        root)))

(define (git-branch header)
  (and header
       (let ([summary (substring header 3 (string-length header))])
         (cond
           [(starts-with? summary "No commits yet on ")
            (substring summary (string-length "No commits yet on ") (string-length summary))]
           [(starts-with? summary "HEAD") #f]
           [else (car (split-many summary "..."))]))))

(define (git-stats lines)
  (let loop ([xs lines] [staged 0] [unstaged 0] [untracked 0])
    (if (null? xs)
        (list staged unstaged untracked)
        (let ([line (car xs)])
          (cond
            [(and (>= (string-length line) 2)
                  (char=? (string-ref line 0) #\?)
                  (char=? (string-ref line 1) #\?))
             (loop (cdr xs) staged unstaged (+ untracked 1))]
            [(and (>= (string-length line) 2)
                  (not (char=? (string-ref line 0) #\space)))
             (loop (cdr xs) (+ staged 1) unstaged untracked)]
            [(and (>= (string-length line) 2)
                  (not (char=? (string-ref line 1) #\space)))
             (loop (cdr xs) staged (+ unstaged 1) untracked)]
            [else
             (loop (cdr xs) staged unstaged untracked)])))))

(define (git-status root)
  (let ([raw (git-output root (list "status" "--porcelain=v1" "--branch"))])
    (if raw
        (let* ([lines (filter (lambda (line) (> (string-length line) 0)) (split-many raw "\n"))]
               [header (and (pair? lines) (car lines))]
               [stats (git-stats (if header (cdr lines) '()))])
          (list (git-branch header) (car stats) (cadr stats) (caddr stats)))
        (list #f 0 0 0))))

(define (git-refresh! root)
  (let ([status (git-status root)])
    (set! *git-cache-by-root*
          (hash-insert *git-cache-by-root* root (cons *git-cache-generation* status)))
    status))

(define (git-cache-entry root)
  (if (hash-contains? *git-cache-by-root* root)
      (let ([entry (hash-get *git-cache-by-root* root)])
        (if (= (car entry) *git-cache-generation*)
            (cdr entry)
            (git-refresh! root)))
      (git-refresh! root)))

(define (invalidate-version-control-cache!)
  (set! *git-cache-generation* (+ *git-cache-generation* 1)))

;; Git only observes saved documents, so invalidation happens after a save.
(define (version-control-init)
  (register-hook 'document-saved
                 (lambda (doc-id) (invalidate-version-control-cache!)))
  (register-hook 'terminal-focus-gained
                 (lambda () (invalidate-version-control-cache!))))

(provide version-control-init version-control-indicator)

(define (version-control-indicator #:fg (fg #f) #:bg (bg #f)
                                  #:placeholder (placeholder "  - ")
                                  #:min-width (min-width #f)
                                  #:left-separator? (left-separator? #f) #:left-separator-fg (left-separator-fg #f) #:left-separator-bg (left-separator-bg #f)
                                  #:left-separator-char (left-separator-char "")
                                  #:right-separator? (right-separator? #f) #:right-separator-fg (right-separator-fg #f) #:right-separator-bg (right-separator-bg #f)
                                  #:right-separator-char (right-separator-char ""))
  (make-indicator
    (lambda (view-id focused? s)
      (define doc-id (editor->doc-id view-id))
      (define path (editor-document->path doc-id))
      (if path
          (let ([root (git-root (parent-name path))])
            (if root
                (let* ([status (git-cache-entry root)]
                       [branch (car status)]
                       [staged (cadr status)]
                       [unstaged (caddr status)]
                       [untracked (cadddr status)])
                  (if branch
                      (apply append
                        (list
                          (list
                            (span "  " s)
                            (span branch s))
                          (if (> staged 0)
                              (list
                                (span " +" s)
                                (span (number->string staged) s))
                              '())
                          (if (> unstaged 0)
                              (list
                                (span " ~" s)
                                (span (number->string unstaged) s))
                              '())
                          (if (> untracked 0)
                              (list
                                (span " ?" s)
                                (span (number->string untracked) s))
                              '())
                          (list (span " " s))))
                      '()))
                '()))
          '()))
    #:fg fg #:bg bg #:placeholder placeholder #:min-width min-width
    #:left-separator? left-separator? #:left-separator-fg left-separator-fg #:left-separator-bg left-separator-bg #:left-separator-char left-separator-char
    #:right-separator? right-separator? #:right-separator-fg right-separator-fg #:right-separator-bg right-separator-bg #:right-separator-char right-separator-char))
