;; cogs/indicators/buffers.scm

(require "helix/components.scm")
(require "helix/editor.scm")
(require "cogs/indicators/style.scm")

(provide buffers-indicator)

(define (buffers-indicator #:fg (fg #f) #:bg (bg #f)
                           #:placeholder (placeholder "  0 ")
                           #:min-width (min-width #f)
                           #:left-separator? (left-separator? #f) #:left-separator-fg (left-separator-fg #f) #:left-separator-bg (left-separator-bg #f)
                           #:left-separator-char (left-separator-char "")
                           #:right-separator? (right-separator? #f) #:right-separator-fg (right-separator-fg #f) #:right-separator-bg (right-separator-bg #f)
                           #:right-separator-char (right-separator-char ""))
  (make-indicator
    (lambda (view-id focused? s)
      (define docs (editor-all-documents))
      (define total (length docs))
      (define dirty-count
        (length (filter (lambda (d) (editor-document-dirty? d)) docs)))
      (define text
        (if (> dirty-count 0)
            (string-append "  " (number->string total) " ~ " (number->string dirty-count) " ")
            (string-append "  " (number->string total) " ")))
      (if (> total 0)
          (list (span text s))
          '()))
    #:fg fg #:bg bg #:placeholder placeholder #:min-width min-width
    #:left-separator? left-separator? #:left-separator-fg left-separator-fg #:left-separator-bg left-separator-bg #:left-separator-char left-separator-char
    #:right-separator? right-separator? #:right-separator-fg right-separator-fg #:right-separator-bg right-separator-bg #:right-separator-char right-separator-char))
