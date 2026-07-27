;; cogs/indicators/file-type.scm

(require "helix/components.scm")
(require "helix/editor.scm")
(require "cogs/indicators/style.scm")

(provide file-type-indicator)

(define (file-type-indicator #:fg (fg #f) #:bg (bg #f))
  (status-element
    (lambda (view-id focused?)
      (define s (make-style fg bg focused?))
      (define doc-id (editor->doc-id view-id))
      (define lang (or (editor-document->language doc-id) ""))
      (list
        (span " <" s)
        (span lang s)
        (span "> " s)))))
