(require "helix/components.scm")

(provide fm-keymap-merge
         fm-key-token fm-key-step fm-key-result-kind fm-key-result-value
         fm-prefix-menu-entries fm-key-overview-entries
         fm-prefix-description)

;; Leaf: "action" or '(action description). Prefix: (list child-keymap description).

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

(define (fm-node-description value)
  (if (string? value) value (list-ref value 1)))

(define (fm-node-action value)
  (if (string? value) value (car value)))

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

(define (fm-node-entries node)
  (sort
    (map (lambda (key)
           (list key (fm-node-description (hash-get node key))))
         (hash-keys->list node))
    fm-entry<?))

(define (fm-prefix-menu-entries keymap prefix)
  (define value (fm-keymap-value keymap prefix))
  (if (and value (fm-prefix-node? value))
      (fm-node-entries (car value))
      '()))

(define (fm-key-overview-entries keymap)
  (fm-node-entries keymap))

(define (fm-prefix-description keymap prefix)
  (define value (fm-keymap-value keymap prefix))
  (if (and value (fm-prefix-node? value))
      (fm-node-description value)
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
                          (fm-node-description override))
                    override)])
          (loop (cdr keys) (hash-insert result key value))))))

(define (fm-keymap-merge base overrides)
  (fm-merge-keymap-node base overrides))

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
