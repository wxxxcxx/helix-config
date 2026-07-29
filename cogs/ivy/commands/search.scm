(require "helix/editor.scm")
(require (only-in "helix/commands.scm" goto-line))
(require (only-in "helix/static.scm"
                  get-current-line-number
                  current-selection->string))
(require (only-in "cogs/ivy/core.scm"
                  IvyCandidate
                  IvyCandidate-value))
(require (only-in "cogs/ivy/ivy.scm" ivy-read))
(require-builtin helix/core/text as text.)

(provide ivy-search)

(define (ivy-search-document-lines)
  (define focus (editor-focus))
  (define text-value (text.rope->string (editor->text (editor->doc-id focus))))
  (let loop ([lines (split-many text-value "\n")] [line-number 1] [result '()])
    (if (null? lines)
        (reverse result)
        (let ([content (car lines)])
          (loop (cdr lines) (+ line-number 1)
                (if (string=? (trim content) "")
                    result
                    (cons (IvyCandidate (trim content)
                                        (string-append "L" (number->string line-number))
                                        line-number
                                        content)
                          result)))))))

;; Search the current buffer with an overview and live line preview.
(define (ivy-search)
  (define origin (get-current-line-number))
  (define selection (current-selection->string))
  (define initial (if (and (equal? (editor-mode) (string->editor-mode "select"))
                           (string? selection)
                           (not (string-contains? selection "\n")))
                      selection
                      ""))
  (ivy-read "Search  " (ivy-search-document-lines)
            #:initial initial
            #:history 'buffer-search
            #:preview (lambda (candidate) (goto-line (IvyCandidate-value candidate)))
            #:accept (lambda (candidate) (goto-line (IvyCandidate-value candidate)))
            #:cancel (lambda (_) (goto-line origin))))
