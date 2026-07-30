(require "cogs/file-manager/core/files.scm")
(require (only-in "cogs/file-manager/core/collections.scm"
                  fm-add-unique
                  fm-member?))

(provide ft-git-read ft-git-parse-output ft-git-path-kinds
         ft-git-read-ignored ft-git-parse-ignored ft-git-ignored?)

(define *ft-git-kind-order* (list 'conflict 'deleted 'renamed 'modified 'added))

(define (ft-git-normalize-kinds kinds)
  (filter (lambda (kind) (fm-member? kind kinds)) *ft-git-kind-order*))

(define (ft-git-merge-kinds left right)
  (ft-git-normalize-kinds (append left right)))

(define (ft-git-kinds-for-code code)
  (cond [(or (string-contains? code "U")
             (string=? code "AA")
             (string=? code "DD"))
         (list 'conflict)]
        [(string-contains? code "?") (list 'added)]
        [else
         (define kinds '())
         (when (string-contains? code "D") (set! kinds (fm-add-unique 'deleted kinds)))
         (when (string-contains? code "R") (set! kinds (fm-add-unique 'renamed kinds)))
         (when (string-contains? code "M") (set! kinds (fm-add-unique 'modified kinds)))
         (when (or (string-contains? code "A") (string-contains? code "C"))
           (set! kinds (fm-add-unique 'added kinds)))
         (if (null? kinds) (list 'modified) (ft-git-normalize-kinds kinds))]))

(define (ft-git-add-status root code relative-path table)
  (define current (string-append root (path-separator) relative-path))
  (define result table)
  (define kinds (ft-git-kinds-for-code code))
  (let loop ()
    (when (not (string=? current ""))
      (define existing (or (hash-try-get result current) '()))
      (set! result (hash-insert result current (ft-git-merge-kinds existing kinds))))
    (when (and (not (string=? current root))
               (not (string=? current (fm-parent-dir current))))
      (set! current (fm-parent-dir current))
      (loop)))
  result)

;; Porcelain -z emits `XY path\0`; rename/copy records add the old path as the
;; following NUL-delimited field. Paths are unquoted in this form.
(define (ft-git-parse-output root output)
  (define records (split-many output (string (integer->char 0))))
  (let loop ([remaining records] [statuses (hash)])
    (if (null? remaining)
        statuses
        (let ([record (car remaining)])
          (if (< (string-length record) 4)
              (loop (cdr remaining) statuses)
              (let* ([code (substring record 0 2)]
                     [path (substring record 3 (string-length record))]
                     [rename? (or (string-contains? code "R")
                                  (string-contains? code "C"))]
                     [rest (if (and rename? (not (null? (cdr remaining))))
                               (cdr (cdr remaining))
                               (cdr remaining))])
                (loop rest (ft-git-add-status root code path statuses))))))))

(define (ft-git-output root)
  (with-handler
    (lambda (_) "")
    (let ([proc (~> (command "git" (list "-C" root "status" "--porcelain=v1" "-z"))
                    with-stdout-piped
                    with-stderr-piped
                    spawn-process)])
      (if (not (Ok? proc))
          ""
          (let* ([child (Ok->value proc)]
                 [output (read-port-to-string (child-stdout child))]
                 [_ (read-port-to-string (child-stderr child))]
                 [status (wait child)])
            (if (and (Ok? status) (= (Ok->value status) 0)) output ""))))))

(define (ft-git-read root)
  (ft-git-parse-output root (ft-git-output root)))

(define (ft-git-path-kinds statuses root path)
  (if (string=? path root) '() (or (hash-try-get statuses path) '())))

(define (ft-git-ignored-output root)
  (with-handler
    (lambda (_) "")
    (let ([proc (~> (command "git"
                             (list "-C" root "ls-files" "--others" "--ignored"
                                   "--exclude-standard" "--directory" "-z"))
                    with-stdout-piped
                    with-stderr-piped
                    spawn-process)])
      (if (not (Ok? proc))
          ""
          (let* ([child (Ok->value proc)]
                 [output (read-port-to-string (child-stdout child))]
                 [_ (read-port-to-string (child-stderr child))]
                 [status (wait child)])
            (if (and (Ok? status) (= (Ok->value status) 0)) output ""))))))

(define (ft-git-relative-path path)
  (define without-trailing-slash
    (if (ends-with? path "/")
        (substring path 0 (- (string-length path) 1))
        path))
  (string-join (split-many without-trailing-slash "/") (path-separator)))

(define (ft-git-parse-ignored root output)
  (foldl
    (lambda (relative-path ignored)
      (if (string=? relative-path "")
          ignored
          (hash-insert
            ignored
            (string-append root (path-separator)
                           (ft-git-relative-path relative-path))
            #t)))
    (hash)
    (split-many output (string (integer->char 0)))))

(define (ft-git-read-ignored root)
  (ft-git-parse-ignored root (ft-git-ignored-output root)))

(define (ft-git-ignored? ignored path)
  (let loop ([current path])
    (cond [(hash-contains? ignored current) #t]
          [(string=? current (fm-parent-dir current)) #f]
          [else (loop (fm-parent-dir current))])))
