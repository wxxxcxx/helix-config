;; cogs/indicators/buffers.scm

(require "helix/components.scm")
(require "helix/editor.scm")

(provide buffers-indicator)

(define (buffers-indicator #:style (style (lambda args (style))))
  (status-element
    (lambda (view-id focused?)
      (define s (if (procedure? style) (style view-id focused?) style))
      (define docs (editor-all-documents))
      (define total (length docs))
      (define dirty-count
        (length (filter (lambda (d) (editor-document-dirty? d)) docs)))
      (define text
        (if (> dirty-count 0)
            (string-append "  " (number->string total) " ~ " (number->string dirty-count) " ")
            (string-append "  " (number->string total) " ")))
      (list
        (span text s)))))
