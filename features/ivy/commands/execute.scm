(require (only-in "helix/misc.scm" set-warning!))
(require (only-in "features/ivy/core.scm"
                  IvyCandidate
                  IvyCandidate-value))
(require (only-in "features/ivy/ivy.scm" ivy-read))
(require (only-in "features/ivy/commands/search.scm" ivy-search))
(require (only-in "features/ivy/commands/find-file.scm" ivy-find-file))
(require (only-in "features/ivy/commands/buffer.scm" ivy-buffer))
(require (only-in "features/ivy/commands/project-search.scm" ivy-project-search))
(require (only-in "features/ivy/commands/recent-file.scm" ivy-recent-file))
(require (only-in "features/ivy/commands/theme.scm" ivy-theme))
(require (only-in "features/ivy/command-catalog.scm" ivy-native-command-bindings))

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

(define (ivy-commands-terminal-bindings)
  ;; Terminal is optional. Resolve its public commands only after the picker is
  ;; invoked so a missing steel-pty package cannot prevent Ivy from loading.
  (with-handler
    (lambda (_) '())
    (eval
      '(require (only-in "features/terminal/terminal.scm"
                         terminal-hide
                         terminal-kill-active
                         terminal-new
                         terminal-open
                         terminal-switch-next
                         terminal-switch-previous
                         terminal-toggle-fullscreen)))
    (list (cons 'terminal-open (eval 'terminal-open))
          (cons 'terminal-new (eval 'terminal-new))
          (cons 'terminal-switch (eval 'terminal-switch-next))
          (cons 'terminal-switch-previous (eval 'terminal-switch-previous))
          (cons 'terminal-fullscreen (eval 'terminal-toggle-fullscreen))
          (cons 'terminal-hide (eval 'terminal-hide))
          (cons 'terminal-kill (eval 'terminal-kill-active)))))

(define (ivy-commands-candidates)
  (define bindings
    (ivy-commands-unique-bindings
      (append (list (cons 'ivy-search ivy-search)
                    (cons 'ivy-project-search ivy-project-search)
                    (cons 'ivy-find-file ivy-find-file)
                    (cons 'ivy-buffer ivy-buffer)
                    (cons 'ivy-recent-file ivy-recent-file)
                    (cons 'ivy-theme ivy-theme)
                    (cons 'ivy-commands ivy-commands))
              (ivy-commands-terminal-bindings)
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

;;@doc
;; Search and execute a command from the active keymap.
(define (ivy-commands)
  (ivy-read "Commands  " (ivy-commands-candidates)
            #:history 'commands
            #:accept ivy-commands-run-command))
