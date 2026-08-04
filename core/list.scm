(provide list-take
         list-drop)

;; Returns at most count leading values; non-positive counts produce an empty list.
(define (list-take values count)
  (if (or (null? values) (<= count 0))
      '()
      (cons (car values) (list-take (cdr values) (- count 1)))))

;; Skips at most count leading values; non-positive counts preserve the input list.
(define (list-drop values count)
  (if (or (null? values) (<= count 0))
      values
      (list-drop (cdr values) (- count 1))))
