(provide fm-member? fm-add-unique)

;; File-manager collections contain strings, symbols, and Helix value objects,
;; so membership must preserve the existing structural-equality semantics.
(define (fm-member? value values)
  (cond [(null? values) #f]
        [(equal? value (car values)) #t]
        [else (fm-member? value (cdr values))]))

(define (fm-add-unique value values)
  (if (fm-member? value values) values (cons value values)))
