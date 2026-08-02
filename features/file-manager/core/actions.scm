(require "helix/misc.scm")
(require "features/file-manager/core/files.scm")

(provide fm-run! fm-copy! fm-move! fm-trash! fm-delete! fm-paste! fm-rename! fm-create! fm-valid-name?)

(define (fm-run! program args)
  ;; Never let child output inherit Helix's TUI. Some successful commands,
  ;; notably osascript, print a result that otherwise remains on the editor.
  (let ([proc (~> (command program args)
                  with-stdout-piped
                  with-stderr-piped
                  spawn-process)])
    (if (Ok? proc)
        (let* ([child (Ok->value proc)]
               [_stdout (read-port-to-string (child-stdout child))]
               [stderr (trim (read-port-to-string (child-stderr child)))]
               [status (wait child)])
          (cond [(not (Ok? status))
                 (error (string-append program ": could not wait for process"))]
                [(not (= (Ok->value status) 0))
                 (error (if (string=? stderr "")
                            (string-append program ": exited with status "
                                           (int->string (Ok->value status)))
                            stderr))]))
        (error (string-append program ": could not spawn process")))))

(define (fm-windows-command! script args)
  (fm-run! "powershell.exe" (append (list "-NoProfile" "-Command" script) args)))

(define (fm-copy! source target)
  (if (equal? (current-os!) "windows")
      (fm-windows-command! "Copy-Item -LiteralPath $args[0] -Destination $args[1] -Recurse" (list source target))
      (fm-run! "cp" (list "-R" "--" source target))))

(define (fm-move! source target)
  (if (equal? (current-os!) "windows")
      (fm-windows-command! "Move-Item -LiteralPath $args[0] -Destination $args[1]" (list source target))
      (fm-run! "mv" (list "--" source target))))

(define (fm-trash! path)
  (cond
    [(equal? (current-os!) "windows")
     (fm-windows-command!
       (string-append
         "Add-Type -AssemblyName Microsoft.VisualBasic; "
         "if (Test-Path -LiteralPath $args[0] -PathType Container) { "
         "[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($args[0], 'OnlyErrorDialogs', 'SendToRecycleBin') "
         "} else { "
         "[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($args[0], 'OnlyErrorDialogs', 'SendToRecycleBin') }")
       (list path))]
    [(equal? (current-os!) "macos")
     (fm-run! "osascript"
              (list "-e"
                    "on run argv\nset itemToDelete to POSIX file (item 1 of argv) as alias\ntell application \"Finder\" to delete itemToDelete\nend run"
                    path))]
    [else (fm-run! "gio" (list "trash" "--" path))]))

(define (fm-delete! path)
  (if (equal? (current-os!) "windows")
      (fm-windows-command! "Remove-Item -LiteralPath $args[0] -Recurse -Force" (list path))
      (fm-run! "rm" (list "-rf" "--" path))))

(define (fm-target-path destination source)
  (string-append destination (path-separator) (fm-base-name source)))

(define (fm-unused-sibling path suffix)
  (let loop ([index 0])
    (define candidate
      (string-append path suffix (if (= index 0) "" (string-append "-" (int->string index)))))
    (if (path-exists? candidate) (loop (+ index 1)) candidate)))

(define (fm-restore-backup! target backup)
  (when (path-exists? target) (fm-delete! target))
  (when (path-exists? backup) (fm-move! backup target)))

(define (fm-replace-target! mode source target)
  (define backup (fm-unused-sibling target ".helix-fm-backup"))
  (define staging (and (equal? mode 'copy)
                       (fm-unused-sibling target ".helix-fm-copy")))
  ;; Copy first so a failed read never disturbs the existing target.
  (when staging (fm-copy! source staging))
  (with-handler
    (lambda (err)
      (with-handler (lambda (_) #f) (fm-restore-backup! target backup))
      (when (and staging (path-exists? staging))
        (with-handler (lambda (_) #f) (fm-delete! staging)))
      (error (error-object-message err)))
    (begin
      (fm-move! target backup)
      (if staging
          (fm-move! staging target)
          (fm-move! source target))))
  ;; The replacement is already committed. A cleanup failure must not roll it
  ;; back, especially for move operations where the source no longer exists.
  (with-handler
    (lambda (err)
      (set-warning! (string-append "file-manager: backup retained at " backup)))
    (fm-delete! backup)))

(define (fm-paste! mode paths destination force?)
  (for-each
    (lambda (source)
      (define target (fm-target-path destination source))
      (when (and (path-exists? target) (not force?))
        (error (string-append "destination exists: " (fm-entry-label target))))
      (unless (equal? source target)
        (if (and force? (path-exists? target))
            (fm-replace-target! mode source target)
            (if (equal? mode 'copy)
                (fm-copy! source target)
                (fm-move! source target)))))
    paths))

(define (fm-valid-name? name)
  (and (> (string-length name) 0)
       (equal? name (fm-base-name name))
       (not (string=? name "."))
       (not (string=? name ".."))))

(define (fm-rename! path new-name)
  (unless (fm-valid-name? new-name) (error "invalid filename"))
  (define target (string-append (fm-parent-dir path) (path-separator) new-name))
  (when (path-exists? target) (error (string-append "already exists: " new-name)))
  (fm-move! path target)
  target)

(define (fm-create! directory name)
  (unless (> (string-length name) 0) (error "filename is empty"))
  (define target (string-append directory (path-separator) name))
  (when (path-exists? target) (error (string-append "already exists: " name)))
  (if (ends-with? name (path-separator))
      (if (equal? (current-os!) "windows")
          (fm-windows-command! "New-Item -ItemType Directory -Path $args[0]" (list target))
          (fm-run! "mkdir" (list "-p" target)))
      (if (equal? (current-os!) "windows")
          (fm-windows-command! "New-Item -ItemType File -Path $args[0]" (list target))
          (fm-run! "touch" (list "--" target))))
  target)
