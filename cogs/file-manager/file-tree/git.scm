(require "cogs/file-manager/core/files.scm")

(provide ft-git-read ft-git-parse-output ft-git-path-kinds)

(define *ft-git-kind-order* (list 'conflict 'deleted 'renamed 'modified 'added))

(define (ft-git-member? value values)
  (cond [(null? values) #f]
        [(equal? value (car values)) #t]
        [else (ft-git-member? value (cdr values))]))

(define (ft-git-add value values)
  (if (ft-git-member? value values) values (cons value values)))

(define (ft-git-normalize-kinds kinds)
  (filter (lambda (kind) (ft-git-member? kind kinds)) *ft-git-kind-order*))

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
         (when (string-contains? code "D") (set! kinds (ft-git-add 'deleted kinds)))
         (when (string-contains? code "R") (set! kinds (ft-git-add 'renamed kinds)))
         (when (string-contains? code "M") (set! kinds (ft-git-add 'modified kinds)))
         (when (or (string-contains? code "A") (string-contains? code "C"))
           (set! kinds (ft-git-add 'added kinds)))
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
