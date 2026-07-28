(require "helix/misc.scm")
(require "cogs/file-manager/files.scm")

(provide fm-run! fm-copy! fm-move! fm-trash! fm-delete! fm-paste! fm-rename! fm-create! fm-valid-name?)

(define (fm-run! program args)
  (let ([proc (~> (command program args) with-stdout-piped with-stderr-piped spawn-process)])
    (if (Ok? proc)
        (let ([stderr (trim (read-port-to-string (child-stderr (Ok->value proc))))])
          (when (not (string=? stderr "")) (error stderr)))
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
                    "on run argv\ntell application \"Finder\" to delete POSIX file (item 1 of argv)\nend run"
                    path))]
    [else (fm-run! "gio" (list "trash" "--" path))]))

(define (fm-delete! path)
  (if (equal? (current-os!) "windows")
      (fm-windows-command! "Remove-Item -LiteralPath $args[0] -Recurse -Force" (list path))
      (fm-run! "rm" (list "-rf" "--" path))))

(define (fm-target-path destination source)
  (string-append destination (path-separator) (fe-base-name source)))

(define (fm-paste! mode paths destination force?)
  (for-each
    (lambda (source)
      (define target (fm-target-path destination source))
      (when (and (path-exists? target) (not force?))
        (error (string-append "destination exists: " (fe-entry-label target))))
      (unless (equal? source target)
        (when (and force? (path-exists? target)) (fm-delete! target))
        (if (equal? mode 'copy)
            (fm-copy! source target)
            (fm-move! source target))))
    paths))

(define (fm-valid-name? name)
  (and (> (string-length name) 0)
       (equal? name (fe-base-name name))
       (not (string=? name "."))
       (not (string=? name ".."))))

(define (fm-rename! path new-name)
  (unless (fm-valid-name? new-name) (error "invalid filename"))
  (define target (string-append (fe-parent-dir path) (path-separator) new-name))
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
