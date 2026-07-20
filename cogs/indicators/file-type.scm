;; cogs/indicators/file-type.scm

(require "helix/components.scm")
(require "helix/editor.scm")
(require "cogs/indicators/core.scm")

(provide file-type-indicator)

(define (file-type-indicator #:fg (fg-fn (lambda () Color/Reset))
                              #:bg (bg-fn (lambda () Color/Reset)))
  (status-element
    (lambda (view-id focused?)
      (define doc-id (editor->doc-id view-id))
      (define lang (or (editor-document->language doc-id) ""))
      (define bg (resolve-color bg-fn))
      (define fg (resolve-color fg-fn))
      (list
        (span " " (named-style fg bg))
        (span lang (named-style fg bg))
        (span " " (named-style fg bg))))))
