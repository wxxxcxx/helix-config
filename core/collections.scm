(provide core-member?
         core-add-unique)

;; Tests membership with structural equality so lists and Helix value objects
;; follow the same semantics as primitive values.
(define (core-member? value values)
  (cond [(null? values) #f]
        [(equal? value (car values)) #t]
        [else (core-member? value (cdr values))]))

;; Prepends value only when it is absent; an existing list is returned unchanged.
(define (core-add-unique value values)
  (if (core-member? value values) values (cons value values)))
