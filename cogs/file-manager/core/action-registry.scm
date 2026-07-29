(provide fm-make-action-registry
         fm-action-description
         fm-action-known?
         fm-action-run)

(struct FmAction (handler description))

(define (fm-action-symbol name)
  (cond [(symbol? name) name]
        [(string? name) (string->symbol name)]
        [else (error! (string-append "file-manager: invalid action name: "
                                    (to-string name)))]))

(define (fm-first-doc-line documentation)
  (if (not (string? documentation))
      #f
      (let loop ([lines (split-many documentation "\n")])
        (cond [(null? lines) #f]
              [(string=? (trim (car lines)) "") (loop (cdr lines))]
              [else (trim (car lines))]))))

(define (fm-handler-doc handler)
  (with-handler
    (lambda (_) #f)
    (fm-first-doc-line
      (#%function-ptr-table-get #%function-ptr-table handler))))

(define (fm-default-action-description name)
  (define label
    (string-replace (symbol->string (fm-action-symbol name)) "-" " "))
  (if (string=? label "")
      label
      (string-append (string (char-upcase (string-ref label 0)))
                     (substring label 1 (string-length label)))))

;; A specification is '(name handler) or '(name handler description).
(define (fm-register-action registry specification)
  (unless (and (list? specification)
               (or (= (length specification) 2)
                   (= (length specification) 3)))
    (error! (string-append "file-manager: invalid action specification: "
                          (to-string specification))))
  (define name (fm-action-symbol (car specification)))
  (define handler (list-ref specification 1))
  (unless (function? handler)
    (error! (string-append "file-manager: action handler is not a function: "
                          (symbol->string name))))
  (define explicit (and (= (length specification) 3)
                        (list-ref specification 2)))
  (define description
    (or explicit
        (fm-handler-doc handler)
        (fm-default-action-description name)))
  (unless (string? description)
    (error! (string-append "file-manager: action description is not a string: "
                          (symbol->string name))))
  (hash-insert registry name (FmAction handler description)))

(define (fm-make-action-registry specifications)
  (let loop ([remaining specifications] [registry (hash)])
    (if (null? remaining)
        registry
        (loop (cdr remaining)
              (fm-register-action registry (car remaining))))))

(define (fm-action-ref registry name)
  (hash-try-get registry (fm-action-symbol name)))

(define (fm-action-known? registry name)
  (if (fm-action-ref registry name) #t #f))

(define (fm-action-description registry name)
  (define action (fm-action-ref registry name))
  (if action
      (FmAction-description action)
      (fm-default-action-description name)))

(define (fm-action-run registry name fallback)
  (define action (fm-action-ref registry name))
  (if action
      ((FmAction-handler action))
      (begin
        (set-warning! (string-append "file-manager: unknown action: "
                                     (symbol->string (fm-action-symbol name))))
        fallback)))
