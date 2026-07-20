;; cogs/indicators/version-control.scm

(require "helix/components.scm")
(require "helix/editor.scm")
(require "helix/misc.scm")
(require "cogs/indicators/core.scm")

(define (parent-dir path)
  (let loop ([i (- (string-length path) 1)])
    (cond
      [(< i 0) "."]
      [(char=? (string-ref path i) #\/)
       (substring path 0 i)]
      [else (loop (- i 1))])))

(define *git-cache-dir* #f)
(define *git-cache-branch* #f)

(define (git-branch doc-id)
  (define path (editor-document->path doc-id))
  (if path
      (let ([dir (parent-dir path)])
        (unless (and *git-cache-dir* (string=? dir *git-cache-dir*))
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
                              (and (not (string=? t "")) t)))))))))
        *git-cache-branch*)
      #f))

(provide version-control-indicator)

(define (version-control-indicator #:fg (fg-fn (lambda () Color/Reset))
                                    #:bg (bg-fn (lambda () Color/Reset)))
  (status-element
    (lambda (view-id focused?)
      (define doc-id (editor->doc-id view-id))
      (define branch (git-branch doc-id))
      (define bg (resolve-color bg-fn))
      (define fg (resolve-color fg-fn))
      (if branch
          (list
            (span "  " (named-style fg bg))
            (span branch (named-style fg bg))
            (span " " (named-style fg bg)))
          '()))))
