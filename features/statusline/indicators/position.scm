;; features/statusline/indicators/position.scm

(require "helix/components.scm")
(require "helix/editor.scm")
(require "helix/misc.scm")
(require "helix/static.scm")
(require-builtin helix/core/text as text.)

(require (only-in "features/ui/color.scm" clamp))
(require "features/ui/style.scm")

(provide position-indicator)

(define (position-indicator #:fg (fg #f) #:bg (bg #f)
                            #:placeholder (placeholder " --/--░-- 󰄰 ")
                            #:min-width (min-width #f)
                            #:left-separator? (left-separator? #f) #:left-separator-fg (left-separator-fg #f) #:left-separator-bg (left-separator-bg #f)
                            #:left-separator-char (left-separator-char "")
                            #:right-separator? (right-separator? #f) #:right-separator-fg (right-separator-fg #f) #:right-separator-bg (right-separator-bg #f)
                            #:right-separator-char (right-separator-char ""))
  (make-indicator
    (lambda (view-id focused? s)
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
                          0)]
                 [progress (cond
                             [(= pct 0) "󰄰"]
                             [(< pct 13) "󰪞"]
                             [(< pct 26) "󰪟"]
                             [(< pct 39) "󰪠"]
                             [(< pct 52) "󰪡"]
                             [(< pct 65) "󰪢"]
                             [(< pct 78) "󰪣"]
                             [(< pct 91) "󰪤"]
                             [(< pct 100) "󰪥"]
                             [else "󰄯"])])
            (list (span (string-append " " (number->string line)
                                       "/" (number->string total)
                                       "," (number->string col)
                                       " " progress " ") s)))
          '()))
    #:fg fg #:bg bg #:placeholder placeholder #:min-width min-width
    #:left-separator? left-separator? #:left-separator-fg left-separator-fg #:left-separator-bg left-separator-bg #:left-separator-char left-separator-char
    #:right-separator? right-separator? #:right-separator-fg right-separator-fg #:right-separator-bg right-separator-bg #:right-separator-char right-separator-char))
