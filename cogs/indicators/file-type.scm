;; cogs/indicators/file-type.scm

(require "helix/components.scm")
(require "helix/editor.scm")
(require "cogs/indicators/core.scm")

(provide file-type-indicator)

(define (file-type-indicator #:style (style (lambda args (style))))
  (status-element
    (lambda (view-id focused?)
      (define s (resolve-style style view-id focused?))
      (define doc-id (editor->doc-id view-id))
      (define lang (or (editor-document->language doc-id) ""))
      (list
        (span " <" s)
        (span lang s)
        (span "> " s)))))
