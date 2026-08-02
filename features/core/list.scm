(provide list-take
         list-drop)

(define (list-take values count)
  (if (or (null? values) (<= count 0))
      '()
      (cons (car values) (list-take (cdr values) (- count 1)))))

(define (list-drop values count)
  (if (or (null? values) (<= count 0))
      values
      (list-drop (cdr values) (- count 1))))
