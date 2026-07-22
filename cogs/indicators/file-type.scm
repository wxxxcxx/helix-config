;; cogs/indicators/file-type.scm

(require "helix/components.scm")
(require "helix/editor.scm")

(provide file-type-indicator)

(define (file-type-indicator #:style (style (lambda args (style))))
  (status-element
    (lambda (view-id focused?)
      (define s (if (procedure? style) (style view-id focused?) style))
      (define doc-id (editor->doc-id view-id))
      (define lang (or (editor-document->language doc-id) ""))
      (list
        (span " <" s)
        (span lang s)
        (span "> " s)))))
