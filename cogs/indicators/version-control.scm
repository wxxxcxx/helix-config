;; cogs/indicators/version-control.scm

(require "helix/components.scm")
(require "helix/editor.scm")
(require "helix/misc.scm")
(require "cogs/indicators/style.scm")

(define *git-cache-dir* #f)
(define *git-cache-stale?* #t)
(define *git-cache-branch* #f)
(define *git-cache-staged* 0)
(define *git-cache-unstaged* 0)
(define *git-cache-untracked* 0)

(define (git-output dir args)
  (with-handler
    (lambda (err) #f)
    (let* ([proc (~> (command "git" (append (list "-C" dir) args))
                     with-stdout-piped
                     spawn-process)])
      (and (Ok? proc)
           (read-port-to-string (child-stdout (Ok->value proc)))))))

(define (git-stats dir)
  (let ([raw (git-output dir (list "status" "--porcelain"))])
    (if raw
        (let ([lines (filter (lambda (l) (> (string-length l) 0)) (split-many raw "\n"))])
            (let loop ([xs lines] [staged 0] [unstaged 0] [untracked 0])
              (if (null? xs)
                  (list staged unstaged untracked)
                  (let ([line (car xs)])
                    (cond
                      [(and (>= (string-length line) 3)
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
        (list 0 0 0))))

(define (git-refresh! dir)
  (set! *git-cache-dir* dir)
  (set! *git-cache-branch*
    (let ([raw (git-output dir (list "rev-parse" "--abbrev-ref" "HEAD"))])
      (and raw
           (let ([branch (trim raw)])
             (and (not (string=? branch "")) branch)))))
  (define stats (git-stats dir))
  (set! *git-cache-staged* (car stats))
  (set! *git-cache-unstaged* (cadr stats))
  (set! *git-cache-untracked* (caddr stats))
  (set! *git-cache-stale?* #f))

(define (invalidate-version-control-cache!)
  (set! *git-cache-stale?* #t))

;; Git only observes saved documents, so invalidation happens after a save.
(define (version-control-init)
  (register-hook 'document-saved
                 (lambda (doc-id) (invalidate-version-control-cache!)))
  (register-hook 'terminal-focus-gained
                 (lambda () (invalidate-version-control-cache!))))

(provide version-control-init version-control-indicator)

(define (version-control-indicator #:fg (fg #f) #:bg (bg #f)
                                  #:placeholder (placeholder "  - ")
                                  #:left-arc? (left-arc? #f) #:left-arc-fg (left-arc-fg #f) #:left-arc-bg (left-arc-bg #f)
                                  #:left-arc-char (left-arc-char "")
                                  #:right-arc? (right-arc? #f) #:right-arc-fg (right-arc-fg #f) #:right-arc-bg (right-arc-bg #f)
                                  #:right-arc-char (right-arc-char ""))
  (status-element
    (lambda (view-id focused?)
      (define s (make-style fg bg focused?))
      (define doc-id (editor->doc-id view-id))
      (define path (editor-document->path doc-id))
      (define frame
        (make-indicator-frame s focused? #:placeholder placeholder
                              #:left? left-arc? #:left-fg left-arc-fg #:left-bg left-arc-bg #:left-char left-arc-char
                              #:right? right-arc? #:right-fg right-arc-fg #:right-bg right-arc-bg #:right-char right-arc-char))
      (if path
          (let ([dir (parent-name path)])
            (unless (and (not *git-cache-stale?*)
                         *git-cache-dir*
                         (string=? dir *git-cache-dir*))
              (git-refresh! dir))
            (if *git-cache-branch*
                (frame
                  (apply append
                    (list
                      (list
                        (span "  " s)
                        (span *git-cache-branch* s))
                      (if (> *git-cache-staged* 0)
                          (list
                            (span " +" s)
                            (span (number->string *git-cache-staged*) s))
                          '())
                      (if (> *git-cache-unstaged* 0)
                          (list
                            (span " ~" s)
                            (span (number->string *git-cache-unstaged*) s))
                          '())
                      (if (> *git-cache-untracked* 0)
                          (list
                            (span " ?" s)
                            (span (number->string *git-cache-untracked*) s))
                          '())
                      (list (span " " s)))))
              (frame '())))
          (frame '())))))
