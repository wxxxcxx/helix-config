;; cogs/indicators/version-control.scm

(require "helix/components.scm")
(require "helix/editor.scm")
(require "helix/misc.scm")

(define (parent-dir path)
  (let loop ([i (- (string-length path) 1)])
    (cond
      [(< i 0) "."]
      [(char=? (string-ref path i) #\/)
       (substring path 0 i)]
      [else (loop (- i 1))])))

(define *git-cache-dir* #f)
(define *git-cache-branch* #f)
(define *git-cache-staged* 0)
(define *git-cache-unstaged* 0)
(define *git-cache-untracked* 0)

(define (git-stats dir)
  (with-handler
    (lambda (err) (list 0 0 0))
    (let* ([proc (~> (command "git" (list "-C" dir "status" "--porcelain"))
                     with-stdout-piped
                     spawn-process)]
           [ok? (Ok? proc)])
      (if ok?
          (let* ([raw (read-port-to-string (child-stdout (Ok->value proc)))]
                 [lines (filter (lambda (l) (> (string-length l) 0)) (split-many raw "\n"))])
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
          (list 0 0 0)))))

(define (git-refresh! dir)
  (set! *git-cache-dir* dir)
  (set! *git-cache-branch*
    (with-handler
      (lambda (err) #f)
      (let* ([proc (~> (command "git" (list "-C" dir "rev-parse" "--abbrev-ref" "HEAD"))
                       with-stdout-piped
                       spawn-process)]
             [ok? (Ok? proc)])
        (and ok?
             (let ([raw (read-port-to-string (child-stdout (Ok->value proc)))])
               (and (string? raw)
                    (let ([t (trim raw)])
                      (and (not (string=? t "")) t))))))))
  (define stats (git-stats dir))
  (set! *git-cache-staged* (car stats))
  (set! *git-cache-unstaged* (cadr stats))
  (set! *git-cache-untracked* (caddr stats)))

(provide version-control-indicator)

(define (version-control-indicator #:style (style (lambda args (style))))
  (status-element
    (lambda (view-id focused?)
      (define s (if (procedure? style) (style view-id focused?) style))
      (define doc-id (editor->doc-id view-id))
      (define path (editor-document->path doc-id))
      (if path
          (let ([dir (parent-dir path)])
            (unless (and *git-cache-dir* (string=? dir *git-cache-dir*))
              (git-refresh! dir))
            (if *git-cache-branch*
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
                    (list (span " " s))))
              '()))
          '()))))
