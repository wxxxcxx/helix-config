(provide FilesystemPathSnapshot?
         FilesystemPathSnapshot-path
         FilesystemPathSnapshot-state
         FilesystemPathSnapshot-directory?
         FilesystemPathSnapshot-modified
         FilesystemPathSnapshot-size
         FilesystemPathSnapshot-error
         filesystem-path-snapshot
         filesystem-paths-snapshot
         filesystem-directory-snapshot
         filesystem-directories-snapshot
         filesystem-snapshot-changed?)

(struct FilesystemPathSnapshot (path state directory? modified size error))

;; Captures shallow metadata while normalizing missing paths and inspection errors.
(define (filesystem-path-snapshot path)
  (if (not (path-exists? path))
      (FilesystemPathSnapshot path 'missing #f #f #f #f)
      (with-handler
        (lambda (error-value)
          (FilesystemPathSnapshot path 'error #f #f #f
                                  (error-object-message error-value)))
        (let ([metadata (file-metadata path)])
          (FilesystemPathSnapshot path
                                  'present
                                  (fs-metadata-is-dir? metadata)
                                  (fs-metadata-modified metadata)
                                  (fs-metadata-len metadata)
                                  #f)))))

;; Captures paths in lexical order so the result can be compared structurally.
(define (filesystem-paths-snapshot paths)
  (map filesystem-path-snapshot (sort paths string<?)))

;; Captures a directory and the shallow metadata of each immediate child.
(define (filesystem-directory-snapshot path)
  (define root (filesystem-path-snapshot path))
  (if (and (equal? (FilesystemPathSnapshot-state root) 'present)
           (FilesystemPathSnapshot-directory? root))
      (with-handler
        (lambda (error-value)
          (list root 'error (error-object-message error-value)))
        (list root 'entries
              (filesystem-paths-snapshot (read-dir path))))
      (list root 'entries '())))

;; Captures multiple directories in lexical order for stable watcher comparisons.
(define (filesystem-directories-snapshot paths)
  (map filesystem-directory-snapshot (sort paths string<?)))

;; Reports whether two snapshots differ according to structural equality.
(define (filesystem-snapshot-changed? previous current)
  (not (equal? previous current)))
