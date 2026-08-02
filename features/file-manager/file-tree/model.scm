(provide ft-model-build-rows
         ft-model-remove
         ft-model-row-index
         ft-model-row-path)

(define (ft-model-remove value values)
  (cond [(null? values) '()]
        [(equal? value (car values)) (cdr values)]
        [else (cons (car values) (ft-model-remove value (cdr values)))]))

(define (ft-model-append left right)
  (if (null? left)
      right
      (cons (car left) (ft-model-append (cdr left) right))))

(define (ft-model-flatten lists)
  (if (null? lists)
      '()
      (ft-model-append (car lists) (ft-model-flatten (cdr lists)))))

(define (ft-model-build-rows root expanded directory? children)
  (define (node-rows path depth)
    (define row (list depth path))
    (if (and (directory? path) (member path expanded))
        (cons row
              (ft-model-flatten
                (map (lambda (child) (node-rows child (+ depth 1)))
                     (children path))))
        (list row)))
  (if (string=? root "") '() (node-rows root 0)))

(define (ft-model-row-path row)
  (list-ref row 1))

(define (ft-model-row-index rows path)
  (let loop ([remaining rows] [index 0])
    (cond [(null? remaining) #f]
          [(string=? path (ft-model-row-path (car remaining))) index]
          [else (loop (cdr remaining) (+ index 1))])))
