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

(define (file-name-indicator #:fg (fg #f) #:bg (bg #f))
  (status-element
    (lambda (view-id focused?)
      (define s (make-style fg bg focused?))
      (define doc-id (editor->doc-id view-id))
      (define name
        (let ([path (editor-document->path doc-id)])
          (and path (basename path))))
      (define dirty? (and name (editor-document-dirty? doc-id)))
      (define dirty-style (and dirty? (make-style "#BF616A" #f focused?)))
      (apply append
        (list
          (list
            (span "  " s)
            (span (or name "[no name]") s))
          (if dirty?
              (list (span "*" dirty-style)
                    (span " " s))
              (list (span " " s))))))))
