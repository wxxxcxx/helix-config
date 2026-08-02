(provide core-member?
         core-add-unique)

(define (core-member? value values)
  (cond [(null? values) #f]
        [(equal? value (car values)) #t]
        [else (core-member? value (cdr values))]))

(define (core-add-unique value values)
  (if (core-member? value values) values (cons value values)))
