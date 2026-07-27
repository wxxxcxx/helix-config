;; cogs/indicators/buffers.scm

(require "helix/components.scm")
(require "helix/editor.scm")
(require "cogs/indicators/style.scm")

(provide buffers-indicator)

(define (buffers-indicator #:fg (fg #f) #:bg (bg #f)
                           #:placeholder (placeholder "  0 ")
                           #:left-arc? (left-arc? #f) #:left-arc-fg (left-arc-fg #f) #:left-arc-bg (left-arc-bg #f)
                           #:left-arc-char (left-arc-char "")
                           #:right-arc? (right-arc? #f) #:right-arc-fg (right-arc-fg #f) #:right-arc-bg (right-arc-bg #f)
                           #:right-arc-char (right-arc-char ""))
  (status-element
    (lambda (view-id focused?)
      (define s (make-style fg bg focused?))
      (define frame
        (make-indicator-frame s focused? #:placeholder placeholder
                              #:left? left-arc? #:left-fg left-arc-fg #:left-bg left-arc-bg #:left-char left-arc-char
                              #:right? right-arc? #:right-fg right-arc-fg #:right-bg right-arc-bg #:right-char right-arc-char))
      (define docs (editor-all-documents))
      (define total (length docs))
      (define dirty-count
        (length (filter (lambda (d) (editor-document-dirty? d)) docs)))
      (define text
        (if (> dirty-count 0)
            (string-append "  " (number->string total) " ~ " (number->string dirty-count) " ")
            (string-append "  " (number->string total) " ")))
      (frame (if (> total 0)
                 (list (span text s))
                 '())))))
