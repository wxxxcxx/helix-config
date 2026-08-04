(require-builtin steel/time)
(require (only-in "helix/editor.scm"
                  editor-all-documents
                  editor-document->path
                  editor-document-dirty?
                  editor-document-last-saved
                  editor-document-reload))
(require (only-in "helix/misc.scm" set-status! set-warning!))
(require (only-in "../../core/filesystem/snapshot.scm"
                  FilesystemPathSnapshot-error
                  FilesystemPathSnapshot-modified
                  FilesystemPathSnapshot-state
                  filesystem-path-snapshot
                  filesystem-paths-snapshot))
(require (only-in "features/editor/external-file-policy.scm"
                  external-file-action))
(require (only-in "../../core/filesystem/watch/watch.scm"
                  filesystem-watch-register!))

(provide editor-external-files-init
         editor-refresh-external-files!)

(define (external-file-log-message operation path message)
  (displayln
    (string-append "external file " operation " failed for " path ": "
                   message)))

(define (external-file-state document-id path)
  (define snapshot (filesystem-path-snapshot path))
  (define state (FilesystemPathSnapshot-state snapshot))
  (cond [(equal? state 'missing) 'missing]
        [(equal? state 'error)
         (external-file-log-message "check" path
                                    (FilesystemPathSnapshot-error snapshot))
         'error]
        [else
         (let ([modified-time (FilesystemPathSnapshot-modified snapshot)]
               [last-saved-time (editor-document-last-saved document-id)])
           (cond [(not last-saved-time) 'error]
                 [(or (system-time>? modified-time last-saved-time)
                      (system-time<? modified-time last-saved-time))
                  'changed]
                 [else 'unchanged]))]))

(define (external-file-reload! document-id path)
  (with-handler
    (lambda (err)
      (external-file-log-message "reload" path (error-object-message err))
      #f)
    (begin (editor-document-reload document-id) #t)))

(define (editor-external-file-paths)
  (filter (lambda (path) path)
          (map editor-document->path (editor-all-documents))))

(define (editor-external-files-snapshot)
  (filesystem-paths-snapshot (editor-external-file-paths)))

(define (external-files-fragment count label)
  (and (> count 0)
       (string-append (number->string count) " " label)))

(define (external-files-report! reloaded dirty missing check-failed reload-failed)
  (define fragments
    (filter
      (lambda (fragment) fragment)
      (list (external-files-fragment reloaded "reloaded")
            (external-files-fragment dirty "dirty buffer(s) skipped")
            (external-files-fragment missing "missing")
            (external-files-fragment check-failed "check failed")
            (external-files-fragment reload-failed "reload failed"))))
  (unless (null? fragments)
    (define message
      (string-append "External files: " (string-join fragments ", ")))
    (if (> (+ dirty missing check-failed reload-failed) 0)
        (set-warning! message)
        (set-status! message))))

;; Recheck every file-backed document when the terminal regains focus. Clean
;; buffers can be refreshed safely; dirty buffers remain untouched for review.
(define (editor-refresh-external-files!)
  (define reloaded 0)
  (define dirty 0)
  (define missing 0)
  (define check-failed 0)
  (define reload-failed 0)
  (for-each
    (lambda (document-id)
      (define path (editor-document->path document-id))
      (when path
        (define action
          (external-file-action (external-file-state document-id path)
                                (editor-document-dirty? document-id)))
        (cond [(equal? action 'reload)
               (if (external-file-reload! document-id path)
                   (set! reloaded (+ reloaded 1))
                   (set! reload-failed (+ reload-failed 1)))]
              [(equal? action 'warn-dirty)
               (set! dirty (+ dirty 1))]
              [(equal? action 'warn-missing)
               (set! missing (+ missing 1))]
              [(equal? action 'warn-error)
               (set! check-failed (+ check-failed 1))])))
    (editor-all-documents))
  (external-files-report! reloaded dirty missing check-failed reload-failed))

(define (editor-external-files-init)
  (filesystem-watch-register!
    'editor-external-files
    (lambda () #t)
    editor-external-files-snapshot
    (lambda (_previous _current) (editor-refresh-external-files!))))
