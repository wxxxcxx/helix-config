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

(define (file-name-indicator #:fg (fg-fn (lambda () Color/Reset))
                              #:bg (bg-fn (lambda () Color/Reset)))
  (status-element
    (lambda (view-id focused?)
      (define doc-id (editor->doc-id view-id))
      (define name
        (let ([path (editor-document->path doc-id)])
          (and path (basename path))))
      (define dirty? (and name (editor-document-dirty? doc-id)))
      (define bg (resolve-color bg-fn))
      (define fg (resolve-color fg-fn))
      (apply append
        (list
          (list
            (span "  " (named-style fg bg))
            (span (or name "[no name]") (named-style fg bg)))
          (if dirty?
              (list (span "*" (named-style dirty-color bg))
                    (span " " (named-style fg bg)))
              (list (span " " (named-style fg bg)))))))))
