(require (only-in "helix/misc.scm" set-warning!))
(require (only-in "cogs/ivy/core.scm"
                  IvyCandidate
                  IvyCandidate-value))
(require (only-in "cogs/ivy/ivy.scm" ivy-read))
(require (only-in "cogs/ivy/search.scm" ivy-search))
(require (only-in "cogs/ivy/find-file.scm" ivy-find-file))
(require (only-in "cogs/ivy/command-catalog.scm" ivy-native-command-bindings))

(provide ivy-commands)

(define (ivy-commands-unique-bindings values)
  (let loop ([remaining values] [seen (hash)] [result '()])
    (if (null? remaining)
        (reverse result)
        (let* ([value (car remaining)] [name (car value)])
          (if (hash-contains? seen name)
              (loop (cdr remaining) seen result)
              (loop (cdr remaining) (hash-insert seen name #t) (cons value result)))))))

(define (ivy-commands-command-documentation handler)
  (with-handler
    (lambda (_) #f)
    (#%function-ptr-table-get #%function-ptr-table handler)))

(define (ivy-commands-first-doc-line value)
  (if (not (string? value))
      "Command"
      (let loop ([lines (split-many value "\n")])
        (cond [(null? lines) "Command"]
              [(string=? (trim (car lines)) "") (loop (cdr lines))]
              [else (trim (car lines))]))))

(define (ivy-commands-candidates)
  (define bindings
    (ivy-commands-unique-bindings
      (append (list (cons 'ivy-search ivy-search)
                    (cons 'ivy-find-file ivy-find-file)
                    (cons 'ivy-commands ivy-commands))
              ivy-native-command-bindings)))
  (map (lambda (binding)
         (define name (car binding))
         (define handler (cdr binding))
         (define label (symbol->string name))
         (define description
           (ivy-commands-first-doc-line
             (ivy-commands-command-documentation handler)))
         (IvyCandidate label description handler
                       (string-append label " " description)))
       bindings))

(define (ivy-commands-run-command candidate)
  (with-handler
    (lambda (error-value)
      (set-warning! (string-append "Command failed: " (to-string error-value))))
    ((IvyCandidate-value candidate))))

;; Execute a command from the active keymap plus essential typable commands.
(define (ivy-commands)
  (ivy-read "Commands  " (ivy-commands-candidates)
            #:accept ivy-commands-run-command))
