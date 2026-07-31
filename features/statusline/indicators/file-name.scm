;; features/statusline/indicators/file-name.scm

(require "helix/components.scm")
(require "helix/editor.scm")
(require "features/ui/style.scm")

(provide file-name-indicator)

(define (file-name-indicator #:fg (fg #f) #:bg (bg #f)
                             #:placeholder (placeholder "  [no name] ")
                             #:left-separator? (left-separator? #f) #:left-separator-fg (left-separator-fg #f) #:left-separator-bg (left-separator-bg #f)
                             #:left-separator-char (left-separator-char "")
                             #:right-separator? (right-separator? #f) #:right-separator-fg (right-separator-fg #f) #:right-separator-bg (right-separator-bg #f)
                             #:right-separator-char (right-separator-char ""))
  (make-indicator
    (lambda (view-id focused? s)
      (define doc-id (editor->doc-id view-id))
      (define name
        (let ([path (editor-document->path doc-id)])
          (and path (file-name path))))
      (if name
          (let* ([dirty? (editor-document-dirty? doc-id)]
                 [dirty-style (and dirty? (make-style "#BF616A" #f focused?))])
            (apply append
              (list
                (list
                  (span "  " s)
                  (span name s))
                (if dirty?
                    (list (span "*" dirty-style)
                          (span " " s))
                    (list (span " " s))))))
          '()))
    #:fg fg #:bg bg #:placeholder placeholder
    #:left-separator? left-separator? #:left-separator-fg left-separator-fg #:left-separator-bg left-separator-bg #:left-separator-char left-separator-char
    #:right-separator? right-separator? #:right-separator-fg right-separator-fg #:right-separator-bg right-separator-bg #:right-separator-char right-separator-char))
