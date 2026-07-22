;; cogs/indicators/file-type.scm

(require "helix/components.scm")
(require "helix/editor.scm")
(require "cogs/indicators/core.scm")

(provide file-type-indicator)

(define (file-type-indicator #:fg (fg-fn (lambda args Color/Reset))
                              #:bg (bg-fn (lambda args Color/Reset)))
  (status-element
    (lambda (view-id focused?)
      (define doc-id (editor->doc-id view-id))
      (define lang (or (editor-document->language doc-id) ""))
      (define bg (resolve-color bg-fn focused?))
      (define fg (resolve-color fg-fn focused?))
      (list
        (span " <" (named-style fg bg))
        (span lang (named-style fg bg))
        (span "> " (named-style fg bg))))))
