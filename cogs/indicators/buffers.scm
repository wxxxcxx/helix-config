;; cogs/indicators/buffers.scm

(require "helix/components.scm")
(require "helix/editor.scm")
(require "cogs/indicators/core.scm")

(provide buffers-indicator)

(define (buffers-indicator #:fg (fg-fn (lambda () Color/Reset))
                            #:bg (bg-fn (lambda () Color/Reset)))
  (status-element
    (lambda (view-id focused?)
      (define docs (editor-all-documents))
      (define total (length docs))
      (define dirty-count
        (length (filter (lambda (d) (editor-document-dirty? d)) docs)))
      (define bg (resolve-color bg-fn))
      (define fg (resolve-color fg-fn))
      (define text
        (if (> dirty-count 0)
            (string-append "  " (number->string total) " ~ " (number->string dirty-count) " ")
            (string-append "  " (number->string total) " ")))
      (list
        (span text
              (~> (style)
                  (style-fg fg)
                  (style-bg bg)))))))
