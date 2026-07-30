(provide fixture-init fixture-value)

(define *fixture-value* 0)

(define (fixture-init)
  (set! *fixture-value* 42))

(define (fixture-value)
  *fixture-value*)
