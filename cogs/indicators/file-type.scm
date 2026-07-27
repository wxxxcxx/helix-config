;; cogs/indicators/file-type.scm

(require "helix/components.scm")
(require "helix/editor.scm")
(require "cogs/indicators/style.scm")

(provide file-type-indicator)

(define (file-type-indicator #:fg (fg #f) #:bg (bg #f)
                             #:placeholder (placeholder " <none> ")
                             #:left-separator? (left-separator? #f) #:left-separator-fg (left-separator-fg #f) #:left-separator-bg (left-separator-bg #f)
                             #:left-separator-char (left-separator-char "")
                             #:right-separator? (right-separator? #f) #:right-separator-fg (right-separator-fg #f) #:right-separator-bg (right-separator-bg #f)
                             #:right-separator-char (right-separator-char ""))
  (make-indicator
    (lambda (view-id focused? s)
      (define doc-id (editor->doc-id view-id))
      (define lang (editor-document->language doc-id))
      (if (and lang (not (string=? lang "")))
          (list
            (span " <" s)
            (span lang s)
            (span "> " s))
          '()))
    #:fg fg #:bg bg #:placeholder placeholder
    #:left-separator? left-separator? #:left-separator-fg left-separator-fg #:left-separator-bg left-separator-bg #:left-separator-char left-separator-char
    #:right-separator? right-separator? #:right-separator-fg right-separator-fg #:right-separator-bg right-separator-bg #:right-separator-char right-separator-char))
