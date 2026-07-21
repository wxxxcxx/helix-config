;; cogs/indicators/position.scm

(require "helix/components.scm")
(require "helix/editor.scm")
(require "helix/misc.scm")
(require-builtin helix/core/text as text.)
(require "cogs/indicators/core.scm")
(require "cogs/color.scm")

(define (count-newlines s)
  (let loop ([i 0] [n 0])
    (if (>= i (string-length s))
        n
        (loop (+ i 1) (if (char=? (string-ref s i) #\newline) (+ n 1) n)))))

(define (buffer-text doc-id)
  (with-handler (lambda (err) "") (text.rope->string (editor->text doc-id))))

(provide position-indicator)

(define (position-indicator #:fg (fg-fn (lambda () Color/Reset))
                        #:bg (bg-fn (lambda () Color/Reset)))
  (status-element
    (lambda (view-id focused?)
      (define doc-id (editor->doc-id view-id))
      (define offset (cursor-position))
      (define text (buffer-text doc-id))
      (define total (max 1 (+ (count-newlines text) 1)))
      (define line (+ (count-newlines (substring text 0 offset)) 1))
      (define col
        (let ([ls
               (let loop ([i (- offset 1)])
                 (if (or (< i 0) (char=? (string-ref text i) #\newline))
                     (+ i 1)
                     (loop (- i 1))))])
          (+ 1 (- offset ls))))
      (define pct
        (if (> total 1)
            (clamp (inexact->exact (round (* 100.0 (/ (- line 1) (- total 1))))) 0 100)
            0))
      (define display (string-append " " (number->string line)
                                     ":" (number->string col)
                                     "/" (number->string total)
                                     "," (number->string pct) "% "))
      (define bg (resolve-color bg-fn))
      (define fg (resolve-color fg-fn))
      (list
        (span display
              (~> (style)
                  (style-fg fg)
                  (style-bg bg)))))))
