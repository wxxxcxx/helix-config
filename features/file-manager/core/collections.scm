(require "../../../core/collections.scm")

(provide fm-member? fm-add-unique)

;; File-manager collections contain strings, symbols, and Helix value objects,
;; so membership must preserve the existing structural-equality semantics.
(define (fm-member? value values)
  (core-member? value values))

(define (fm-add-unique value values)
  (core-add-unique value values))
