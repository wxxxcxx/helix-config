;; cogs/indicators/file-name.scm

(require "helix/components.scm")
(require "helix/editor.scm")
(require "cogs/indicators/style.scm")

(define (basename path)
  (let loop ([i (- (string-length path) 1)])
    (cond
      [(< i 0) path]
      [(char=? (string-ref path i) #\/)
       (substring path (+ i 1) (string-length path))]
      [else (loop (- i 1))])))

(provide file-name-indicator)

(define (file-name-indicator #:fg (fg #f) #:bg (bg #f)
                             #:placeholder (placeholder "  [no name] ")
                             #:left-arc? (left-arc? #f) #:left-arc-fg (left-arc-fg #f) #:left-arc-bg (left-arc-bg #f)
                             #:left-arc-char (left-arc-char "")
                             #:right-arc? (right-arc? #f) #:right-arc-fg (right-arc-fg #f) #:right-arc-bg (right-arc-bg #f)
                             #:right-arc-char (right-arc-char ""))
  (status-element
    (lambda (view-id focused?)
      (define doc-id (editor->doc-id view-id))
      (define name
        (let ([path (editor-document->path doc-id)])
          (and path (basename path))))
      (define s (make-style fg bg focused?))
      (define (frame spans)
        (with-arcs spans #:placeholder placeholder #:placeholder-style s #:focused? focused?
                   #:left? left-arc? #:left-fg left-arc-fg #:left-bg left-arc-bg #:left-char left-arc-char
                   #:right? right-arc? #:right-fg right-arc-fg #:right-bg right-arc-bg #:right-char right-arc-char))
      (if name
          (let* ([dirty? (editor-document-dirty? doc-id)]
                 [dirty-style (and dirty? (make-style "#BF616A" #f focused?))])
            (frame
              (apply append
                (list
                  (list
                    (span "  " s)
                    (span name s))
                  (if dirty?
                      (list (span "*" dirty-style)
                            (span " " s))
                      (list (span " " s)))))))
          (frame '())))))
