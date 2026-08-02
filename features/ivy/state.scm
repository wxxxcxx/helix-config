(provide IvyState
         ivy-state-empty
         ivy-state-ref
         ivy-state-set)

(struct IvyState (values))

(define (ivy-state-empty)
  (IvyState
    (hash 'prompt ""
          'query ""
          'input-cursor 0
          'candidates '()
          'matches '()
          'selected 0
          'visible-rows 8
          'accept #f
          'confirm #f
          'preview #f
          'cancel #f
          'raw-accept #f
          'empty-backspace #f
          'tab-accept? #f
          'history-key #f
          'update-candidates #f
          'histories (hash)
          'history-index -1
          'history-draft ""
          'bounds #f)))

(define (ivy-state-ref state key)
  (hash-get (IvyState-values state) key))

(define (ivy-state-set state key value)
  (IvyState (hash-insert (IvyState-values state) key value)))
