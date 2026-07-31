(require (only-in "helix/commands.scm" open))
(require (only-in "helix/editor.scm"
                  doc-closed-path
                  editor-all-documents
                  editor-document->path
                  register-hook))
(require (only-in "features/file-manager/core/files.scm"
                  fm-entry-label
                  fm-parent-dir))
(require (only-in "features/ivy/core.scm"
                  IvyCandidate
                  IvyCandidate-value
                  ivy-take))
(require (only-in "features/ivy/ivy.scm" ivy-read))

(provide ivy-recent-file
         ivy-recent-file-init)

(define *ivy-recent-files* '())
(define *ivy-recent-file-initialized?* #f)

(define (ivy-recent-file-remember! path)
  (when (and path (string? path) (not (string=? path "")))
    (set! *ivy-recent-files*
          (ivy-take
            (cons path
                  (filter (lambda (value) (not (string=? value path)))
                          *ivy-recent-files*))
            100))))

(define (ivy-recent-file-remember-document! doc-id)
  (ivy-recent-file-remember!
    (with-handler (lambda (_) #f) (editor-document->path doc-id))))

(define (ivy-recent-file-candidates)
  (map (lambda (path)
         (IvyCandidate (fm-entry-label path)
                       (fm-parent-dir path)
                       path
                       path))
       (filter path-exists? *ivy-recent-files*)))

;;@doc
;; Open a recently used file.
(define (ivy-recent-file)
  (ivy-read "Recent file  " (ivy-recent-file-candidates)
            #:accept (lambda (candidate) (open (IvyCandidate-value candidate)))
            #:history 'recent-file))

(define (ivy-recent-file-init)
  (unless *ivy-recent-file-initialized?*
    (set! *ivy-recent-file-initialized?* #t)
    (for-each ivy-recent-file-remember-document! (editor-all-documents))
    (register-hook 'document-opened ivy-recent-file-remember-document!)
    (register-hook 'document-closed
                   (lambda (event)
                     (ivy-recent-file-remember! (doc-closed-path event))))))
