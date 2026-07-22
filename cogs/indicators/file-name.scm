;; cogs/indicators/file-name.scm

(require "helix/components.scm")
(require "helix/editor.scm")
(require "cogs/indicators/core.scm")
(require (only-in "helix/themes.scm" string->color))

(define (basename path)
  (let loop ([i (- (string-length path) 1)])
    (cond
      [(< i 0) path]
      [(char=? (string-ref path i) #\/)
       (substring path (+ i 1) (string-length path))]
      [else (loop (- i 1))])))

(define dirty-color (string->color "#BF616A"))

(provide file-name-indicator)

(define (file-name-indicator #:style (style (lambda args (style))))
  (status-element
    (lambda (view-id focused?)
      (define s (resolve-style style view-id focused?))
      (define doc-id (editor->doc-id view-id))
      (define name
        (let ([path (editor-document->path doc-id)])
          (and path (basename path))))
      (define dirty? (and name (editor-document-dirty? doc-id)))
      (apply append
        (list
          (list
            (span "  " s)
            (span (or name "[no name]") s))
          (if dirty?
              (list (span "*" (style-fg s dirty-color))
                    (span " " s))
              (list (span " " s))))))))
