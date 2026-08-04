(require (only-in "process.scm"
                  core-process-trimmed-output))

(provide core-path-base-name
         core-path-directory-entries
         core-path-ensure-trailing-separator
         core-path-entry-label
         core-path-join
         core-path-label
         core-path-parent
         core-path-parent-or-self
         core-path-read-directory
         core-path-root?
         core-path-windows-drive-root?
         core-path-windows-drives-root?)

;; Returns the final path component using the platform filesystem rules.
(define (core-path-base-name path)
  (file-name path))

;; Returns the lexical parent supplied by Steel without imposing a root boundary.
(define (core-path-parent path)
  (parent-name path))

;; Recognizes the empty virtual root used to list Windows filesystem drives.
(define (core-path-windows-drives-root? path)
  (and (equal? (current-os!) "windows") (string=? path "")))

;; Recognizes both bare and separator-terminated Windows drive roots.
(define (core-path-windows-drive-root? path)
  (and (equal? (current-os!) "windows")
       (>= (string-length path) 2)
       (char=? (string-ref path 1) #\:)
       (or (= (string-length path) 2)
           (and (= (string-length path) 3)
                (or (char=? (string-ref path 2) #\\)
                    (char=? (string-ref path 2) #\/))))))

;; Recognizes the platform root, including Windows drive and virtual drive roots.
(define (core-path-root? path)
  (or (string=? path (path-separator))
      (core-path-windows-drive-root? path)
      (core-path-windows-drives-root? path)))

;; Returns path unchanged at a root so callers cannot navigate above it.
(define (core-path-parent-or-self path)
  (if (core-path-root? path) path (core-path-parent path)))

;; Produces the short label shown for a directory entry or Windows drive.
(define (core-path-entry-label path)
  (if (core-path-windows-drive-root? path)
      (substring path 0 2)
      (core-path-base-name path)))

;; Replaces the Windows virtual-root sentinel with a user-facing label.
(define (core-path-label path)
  (if (core-path-windows-drives-root? path) "Drives" path))

;; Joins one child name while avoiding duplicate trailing separators.
(define (core-path-join directory name)
  (define separator (path-separator))
  (if (string=? name "")
      directory
      (string-append (trim-end-matches directory separator) separator name)))

;; Appends the platform separator only when path does not already end with it.
(define (core-path-ensure-trailing-separator path)
  (define separator (path-separator))
  (if (ends-with? path separator) path (string-append path separator)))

;; Reads a directory and normalizes filesystem errors to an empty result.
(define (core-path-read-directory path)
  (with-handler (lambda (_) '()) (read-dir path)))

;; Queries Windows filesystem drive roots and normalizes command failures to empty.
(define (core-path-windows-drive-paths)
  (define output
    (with-handler
      (lambda (_) #f)
      (core-process-trimmed-output
        "powershell.exe"
        (list "-NoProfile" "-Command"
              "Get-PSDrive -PSProvider FileSystem | ForEach-Object { $_.Root }"))))
  (if output
      (filter (lambda (path) (not (string=? path "")))
              (map trim (split-many output "\n")))
      '()))

;; Checks the displayed entry name so the rule also works for full paths.
(define (core-path-dotfile? path)
  (define name (core-path-entry-label path))
  (and (> (string-length name) 0) (char=? (string-ref name 0) #\.)))

;; Sorts directories before files, ordering each group lexically by full path.
(define (core-path-sort-directory-entries entries)
  (define directories (sort (filter is-dir? entries) string<?))
  (define files (sort (filter (lambda (path) (not (is-dir? path))) entries) string<?))
  (append directories files))

;; Lists sorted entries, optionally filtering hidden names, across platform roots.
(define (core-path-directory-entries path show-hidden?)
  (define entries
    (if (core-path-windows-drives-root? path)
        (core-path-windows-drive-paths)
        (core-path-read-directory path)))
  (core-path-sort-directory-entries
    (if show-hidden?
        entries
        (filter (lambda (entry) (not (core-path-dotfile? entry))) entries))))
