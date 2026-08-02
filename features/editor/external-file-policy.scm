(provide external-file-action)

(define (external-file-action state dirty?)
  (cond [(equal? state 'changed) (if dirty? 'warn-dirty 'reload)]
        [(equal? state 'missing) 'warn-missing]
        [(equal? state 'error) 'warn-error]
        [else 'ignore]))
