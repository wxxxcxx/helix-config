(require "helix/components.scm")
(require "features/file-manager/core/action-registry.scm")

(provide fm-keymap-merge
         fm-key-token fm-key-step fm-key-result-kind fm-key-result-value
         fm-prefix-menu-entries fm-key-overview-entries
         fm-prefix-description fm-keymap-validate!)

;; Leaf: 'action or '(action description). Prefix: (list child-keymap description).

(define (fm-key-modifier? event modifier)
  (define value (or (key-event-modifier event) 0))
  (not (= 0 (bitwise-and value modifier))))

(define (fm-key-token event)
  (define ch (key-event-char event))
  (define prefix
    (string-append
      (if (fm-key-modifier? event key-modifier-ctrl) "C-" "")
      (if (fm-key-modifier? event key-modifier-alt) "A-" "")
      (if (fm-key-modifier? event key-modifier-super) "S-" "")))
  (define key
    (cond [(key-event-down? event) "down"]
          [(key-event-up? event) "up"]
          [(key-event-enter? event) "enter"]
          [(key-event-tab? event) "tab"]
          [(key-event-escape? event) "escape"]
          [(key-event-backspace? event) "backspace"]
          [(and (char? ch) (char=? ch #\space)) "space"]
          [(char? ch) (string ch)]
          [else ""]))
  (if (string=? key "") "" (string-append prefix key)))

(define (fm-prefix-node? value)
  (and (list? value) (not (null? value)) (hash? (car value))))

(define (fm-action-node? value)
  (or (symbol? value)
      (string? value)
      (and (list? value)
           (= (length value) 2)
           (or (symbol? (car value)) (string? (car value)))
           (string? (list-ref value 1)))))

(define (fm-node-description value actions)
  (cond [(or (symbol? value) (string? value))
         (fm-action-description actions value)]
        [else (list-ref value 1)]))

(define (fm-node-action value)
  (if (or (symbol? value) (string? value)) value (car value)))

(define (fm-string-tokens value)
  (let loop ([start 0] [index 0] [tokens '()])
    (cond [(>= index (string-length value))
           (reverse
             (if (< start index)
                 (cons (substring value start index) tokens)
                 tokens))]
          [(char=? (string-ref value index) #\space)
           (loop (+ index 1) (+ index 1)
                 (if (< start index)
                     (cons (substring value start index) tokens)
                     tokens))]
          [else (loop start (+ index 1) tokens)])))

(define (fm-keymap-value keymap sequence)
  (let loop ([node keymap] [tokens (fm-string-tokens sequence)])
    (if (null? tokens)
        #f
        (let ([value (hash-try-get node (car tokens))])
          (cond [(not value) #f]
                [(null? (cdr tokens)) value]
                [(fm-prefix-node? value) (loop (car value) (cdr tokens))]
                [else #f])))))

(define (fm-entry<? left right) (string<? (car left) (car right)))

(define (fm-node-entries node actions)
  (sort
    (map (lambda (key)
           (list key (fm-node-description (hash-get node key) actions)))
         (hash-keys->list node))
    fm-entry<?))

(define (fm-prefix-menu-entries keymap actions prefix)
  (define value (fm-keymap-value keymap prefix))
  (if (and value (fm-prefix-node? value))
      (fm-node-entries (car value) actions)
      '()))

(define (fm-key-overview-entries keymap actions)
  (fm-node-entries keymap actions))

(define (fm-prefix-description keymap prefix)
  (define value (fm-keymap-value keymap prefix))
  (if (and value (fm-prefix-node? value))
      (list-ref value 1)
      (string-append "Keys: " prefix)))

(define (fm-merge-keymap-node base overrides)
  (let loop ([keys (hash-keys->list overrides)] [result base])
    (if (null? keys)
        result
        (let* ([key (car keys)]
               [override (hash-get overrides key)]
               [current (hash-try-get result key)]
               [value
                (if (and current (fm-prefix-node? current)
                         (fm-prefix-node? override))
                    (list (fm-merge-keymap-node (car current) (car override))
                          (list-ref override 1))
                    override)])
          (loop (cdr keys) (hash-insert result key value))))))

(define (fm-keymap-merge base overrides)
  (fm-merge-keymap-node base overrides))

(define (fm-keymap-validate! keymap actions)
  (define (validate-node node prefix)
    (unless (hash? node)
      (error! (string-append "file-manager: keymap node is not a hash: " prefix)))
    (for-each
      (lambda (key)
        (define value (hash-get node key))
        (define sequence (if (string=? prefix "") key (string-append prefix " " key)))
        (cond [(fm-prefix-node? value)
               (unless (and (= (length value) 2) (string? (list-ref value 1)))
                 (error! (string-append "file-manager: invalid prefix: " sequence)))
               (validate-node (car value) sequence)]
              [(fm-action-node? value)
               (unless (fm-action-known? actions (fm-node-action value))
                 (error! (string-append "file-manager: unknown action at " sequence ": "
                                        (to-string (fm-node-action value)))))]
              [else
               (error! (string-append "file-manager: invalid key binding: " sequence))]))
      (hash-keys->list node)))
  (validate-node keymap "")
  #t)

;; Returns '(action name), '(prefix sequence), '(cancel #f), or '(invalid sequence).
(define (fm-key-step keymap prefix event)
  (define token (fm-key-token event))
  (define sequence (if (string=? prefix "") token (string-append prefix " " token)))
  (cond [(string=? token "escape") (list 'cancel #f)]
        [(string=? token "") (list 'invalid sequence)]
        [else
         (define value (fm-keymap-value keymap sequence))
         (cond [(not value) (list 'invalid sequence)]
               [(fm-prefix-node? value) (list 'prefix sequence)]
               [else (list 'action (fm-node-action value))])]))

(define (fm-key-result-kind result) (car result))
(define (fm-key-result-value result) (list-ref result 1))
