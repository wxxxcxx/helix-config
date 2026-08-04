(require "../../../core/filesystem/snapshot.scm")

(define (assert-equal! expected actual message)
  (unless (equal? expected actual)
    (error! (string-append message
                           ": expected " (to-string expected)
                           ", got " (to-string actual)))))

(define fixture-path "tests/core/filesystem")
(define file-path (string-append fixture-path "/snapshot.scm"))
(define missing-path (string-append fixture-path "/missing.scm"))

(define file-snapshot (filesystem-path-snapshot file-path))
(assert-equal! file-path
               (FilesystemPathSnapshot-path file-snapshot)
               "snapshot preserves its path")
(assert-equal! 'present
               (FilesystemPathSnapshot-state file-snapshot)
               "existing file is present")
(assert-equal! #f
               (FilesystemPathSnapshot-directory? file-snapshot)
               "file is not a directory")

(define missing-snapshot (filesystem-path-snapshot missing-path))
(assert-equal! 'missing
               (FilesystemPathSnapshot-state missing-snapshot)
               "missing path is normalized")

(define first-directory-snapshot
  (filesystem-directory-snapshot fixture-path))
(define second-directory-snapshot
  (filesystem-directory-snapshot fixture-path))
(assert-equal! first-directory-snapshot
               second-directory-snapshot
               "unchanged directory snapshots are stable")
(assert-equal! #f
               (filesystem-snapshot-changed? first-directory-snapshot
                                             second-directory-snapshot)
               "equal snapshots are unchanged")
(assert-equal! #t
               (filesystem-snapshot-changed? file-snapshot missing-snapshot)
               "different path states are detected")
