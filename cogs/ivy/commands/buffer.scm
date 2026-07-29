(require (only-in "helix/editor.scm"
                  Action/Replace
                  editor-all-documents
                  editor-document->path
                  editor-document-dirty?
                  editor-focus
                  editor-switch-action!
                  editor->doc-id
                  register-hook))
(require (only-in "cogs/file-manager/core/files.scm"
                  fm-entry-label
                  fm-parent-dir))
(require (only-in "cogs/ivy/core.scm"
                  IvyCandidate
                  IvyCandidate-value))
(require (only-in "cogs/ivy/ivy.scm" ivy-read))

(provide ivy-buffer
         ivy-buffer-init)

(define *ivy-buffer-history* '())
(define *ivy-buffer-initialized?* #f)

(define (ivy-buffer-member? values target)
  (cond [(null? values) #f]
        [(equal? (car values) target) #t]
        [else (ivy-buffer-member? (cdr values) target)]))

(define (ivy-buffer-remember! doc-id)
  (set! *ivy-buffer-history*
        (cons doc-id
              (filter (lambda (value) (not (equal? value doc-id)))
                      *ivy-buffer-history*))))

(define (ivy-buffer-live-history documents current)
  (filter (lambda (doc-id)
            (and (not (equal? doc-id current))
                 (ivy-buffer-member? documents doc-id)))
          *ivy-buffer-history*))

(define (ivy-buffer-order documents current)
  (define recent (ivy-buffer-live-history documents current))
  (define remaining
    (filter (lambda (doc-id)
              (and (not (equal? doc-id current))
                   (not (ivy-buffer-member? recent doc-id))))
            documents))
  (append recent remaining
          (if (ivy-buffer-member? documents current) (list current) '())))

(define (ivy-buffer-status current? dirty?)
  (cond [(and current? dirty?) "current, modified"]
        [current? "current"]
        [dirty? "modified"]
        [else ""]))

(define (ivy-buffer-annotation path current? dirty?)
  (define status (ivy-buffer-status current? dirty?))
  (define parent (and path (fm-parent-dir path)))
  (cond [(and parent (not (string=? status "")))
         (string-append status "  " parent)]
        [parent parent]
        [(not (string=? status "")) status]
        [else "scratch"]))

(define (ivy-buffer-candidates)
  (define documents (editor-all-documents))
  (define current (editor->doc-id (editor-focus)))
  (let loop ([remaining (ivy-buffer-order documents current)]
             [scratch-index 1]
             [result '()])
    (if (null? remaining)
        (reverse result)
        (let* ([doc-id (car remaining)]
               [path (with-handler (lambda (_) #f)
                       (editor-document->path doc-id))]
               [dirty? (with-handler (lambda (_) #f)
                         (editor-document-dirty? doc-id))]
               [current? (equal? doc-id current)]
               [label (if path
                          (fm-entry-label path)
                          (string-append "[scratch "
                                         (number->string scratch-index)
                                         "]"))]
               [shown-label (if dirty? (string-append label " *") label)]
               [annotation (ivy-buffer-annotation path current? dirty?)]
               [search (if path
                           (string-append shown-label " " path)
                           shown-label)])
          (loop (cdr remaining)
                (if path scratch-index (+ scratch-index 1))
                (cons (IvyCandidate shown-label annotation doc-id search)
                      result))))))

(define (ivy-buffer)
  (ivy-read "Buffer  " (ivy-buffer-candidates)
            #:history 'buffer
            #:accept
            (lambda (candidate)
              (editor-switch-action! (IvyCandidate-value candidate)
                                     (Action/Replace)))))

(define (ivy-buffer-init)
  (unless *ivy-buffer-initialized?*
    (set! *ivy-buffer-initialized?* #t)
    (register-hook 'document-focus-lost ivy-buffer-remember!)))
