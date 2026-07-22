;; cogs/indicators/position.scm

(require "helix/components.scm")
(require "helix/editor.scm")
(require "helix/misc.scm")
(require "helix/static.scm")
(require-builtin helix/core/text as text.)

(require "cogs/color.scm")

(provide position-indicator)

(define (position-indicator #:style (style (lambda args (style))))
  (status-element
    (lambda (view-id focused?)
      (define s (if (procedure? style) (style view-id focused?) style))
      (if focused?
          (let* ([doc-id (editor->doc-id view-id)]
                 [rope (editor->text doc-id)]
                 [total (max 1 (text.rope-len-lines rope))]
                 [line (+ 1 (get-current-line-number))]
                 [col (+ 1 (get-current-column-number))]
                 [pct (if (> total 1)
                          (clamp (inexact->exact
                                   (round (* 100.0 (/ (- line 1) (- total 1)))))
                                 0 100)
                          0)])
            (list (span (string-append " " (number->string line)
                                       ":" (number->string col)
                                       "/" (number->string total)
                                       ", " (number->string pct) "% ") s)))
          '()))))
