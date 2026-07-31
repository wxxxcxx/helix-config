(require "helix/misc.scm")
(require (only-in "helix/commands.scm" open))
(require (only-in "helix/static.scm" cx->current-file get-helix-cwd))
(require (only-in "features/file-manager/core/files.scm"
                  fm-entry-label
                  fm-parent-dir
                  fm-read-dir-names))
(require (only-in "features/ivy/core.scm"
                  IvyCandidate
                  IvyCandidate-value))
(require (only-in "features/ivy/ivy.scm" ivy-read ivy-update!))

(provide ivy-find-file)

(define *ivy-find-file-directory* "")

(define (find-file-path-join directory name)
  (define separator (path-separator))
  (if (string=? name "")
      directory
      (string-append (trim-end-matches directory separator) separator name)))

(define (find-file-prompt directory)
  (string-append "Open  " directory (path-separator)))

(define (find-file-candidates directory)
  (define parent (fm-parent-dir directory))
  (define entries
    (map (lambda (path)
           (define directory? (is-dir? path))
           (define name (fm-entry-label path))
           (IvyCandidate (if directory? (string-append name (path-separator)) name)
                         (if directory? "dir" "file")
                         path
                         name))
         (fm-read-dir-names directory #t)))
  (if (string=? parent directory)
      entries
      (cons (IvyCandidate (string-append ".." (path-separator))
                          "dir"
                          parent
                          "..")
            entries)))

(define (find-file-enter-directory! directory)
  (set! *ivy-find-file-directory* directory)
  (ivy-update! (find-file-prompt directory)
               (find-file-candidates directory)))

;;@doc
;; Find a file from the current directory.
;; The picker stays open while navigating between directories.
(define (ivy-find-file)
  (define current-file (with-handler (lambda (_) #f) (cx->current-file)))
  (set! *ivy-find-file-directory*
        (if current-file (fm-parent-dir current-file) (get-helix-cwd)))
  (define (confirm candidate)
    (define path (IvyCandidate-value candidate))
    (if (is-dir? path)
        (begin (find-file-enter-directory! path) #t)
        #f))
  (define (open-path path)
    (unless (string=? path "") (open path)))
  (define (open-input input)
    (open-path (find-file-path-join *ivy-find-file-directory* input)))
  (define (up-directory)
    (define parent (fm-parent-dir *ivy-find-file-directory*))
    (unless (string=? parent *ivy-find-file-directory*)
      (find-file-enter-directory! parent)))
  (ivy-read (find-file-prompt *ivy-find-file-directory*)
            (find-file-candidates *ivy-find-file-directory*)
            #:confirm confirm
            #:accept (lambda (candidate) (open-path (IvyCandidate-value candidate)))
            #:raw-accept open-input
            #:empty-backspace up-directory
            #:history 'find-file
            #:tab-accept #t))
