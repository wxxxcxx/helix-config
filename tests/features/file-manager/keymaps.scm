(require "../../../features/core/collections.scm")
(require "../../../features/file-manager/file-explorer/defaults.scm")
(require "../../../features/file-manager/file-tree/defaults.scm")

(define (assert-true! value message)
  (unless value (error! message)))

(define (assert-equal! expected actual message)
  (unless (equal? expected actual)
    (error! (string-append message
                           ": expected " (to-string expected)
                           ", got " (to-string actual)))))

(define (prefix-node? value)
  (and (list? value) (not (null? value)) (hash? (car value))))

(define (action-node? value)
  (or (symbol? value)
      (string? value)
      (and (list? value)
           (= (length value) 2)
           (or (symbol? (car value)) (string? (car value)))
           (string? (list-ref value 1)))))

(define (node-action value)
  (if (or (symbol? value) (string? value)) value (car value)))

(define (key-sequence prefix key)
  (if (string=? prefix "") key (string-append prefix " " key)))

(define (collect-keymap-actions keymap)
  (define (collect-node node prefix result)
    (let loop ([keys (hash-keys->list node)] [actions result])
      (if (null? keys)
          actions
          (let* ([key (car keys)]
                 [value (hash-get node key)]
                 [sequence (key-sequence prefix key)])
            (cond [(prefix-node? value)
                   (assert-true! (and (= (length value) 2) (string? (list-ref value 1)))
                                 (string-append "invalid prefix: " sequence))
                   (loop (cdr keys) (collect-node (car value) sequence actions))]
                  [(action-node? value)
                   (loop (cdr keys) (cons (node-action value) actions))]
                  [else
                   (error! (string-append "invalid key binding: " sequence))])))))
  (collect-node keymap "" '()))

(define (assert-no-duplicates! label values)
  (let loop ([remaining values] [seen '()])
    (unless (null? remaining)
      (assert-true! (not (core-member? (car remaining) seen))
                    (string-append label " duplicate action: " (to-string (car remaining))))
      (loop (cdr remaining) (cons (car remaining) seen)))))

(define (assert-keymap-actions-known! label keymap action-names)
  (assert-no-duplicates! label action-names)
  (for-each
    (lambda (action)
      (assert-true! (core-member? action action-names)
                    (string-append label " unknown keymap action: "
                                   (to-string action))))
    (collect-keymap-actions keymap)))

(define (dummy-handler name)
  (lambda () name))

(define (specification-names specifications)
  (map car specifications))

(define (assert-action-specifications! label action-names specifications)
  (assert-equal! action-names
                 (specification-names specifications)
                 (string-append label " action specifications"))
  (for-each
    (lambda (specification)
      (assert-true! (and (= (length specification) 3)
                         (function? (list-ref specification 1))
                         (string? (list-ref specification 2)))
                    (string-append label " invalid action specification: "
                                   (to-string specification))))
    specifications))

(assert-keymap-actions-known!
  "file-explorer"
  file-explorer-default-keybindings
  (file-explorer-action-names))

(assert-action-specifications!
  "file-explorer"
  (file-explorer-action-names)
  (file-explorer-action-specifications dummy-handler))

(assert-keymap-actions-known!
  "file-tree"
  file-tree-default-keybindings
  (file-tree-action-names))

(assert-action-specifications!
  "file-tree"
  (file-tree-action-names)
  (file-tree-action-specifications dummy-handler))
