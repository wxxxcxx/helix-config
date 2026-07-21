(require "helix/editor.scm")
(require "helix/misc.scm")
(require "helix/static.scm")

(provide input-source-configure! input-source-autoconfigure! input-source-init
         input-source-get input-source-switch input-source-to-default input-source-back input-source-reset!)

;; ── Internal State ──────────────────────────────────────────────

(define *default-source* #f)
(define *previous-source* #f)
(define *get-cmd* #f)
(define *set-cmd* #f)
(define *initialized* #f)
(define *detected* #f)
(define *detected?* #f)

(define *insert-mode* (string->editor-mode "insert"))

(define (insert-mode? mode)
  (equal? mode *insert-mode*))

;; ── Private Helpers ─────────────────────────────────────────────

(define (capture-output cmd)
  (with-handler
    (lambda (err)
      (set-warning! (string-append "capture-output: " (to-string err)))
      #f)
    (let* ([proc (~> (command (car cmd) (cdr cmd))
                     with-stdout-piped
                     spawn-process)]
           [ok? (Ok? proc)])
      (and ok?
           (let* ([handle (Ok->value proc)]
                  [raw (read-port-to-string (child-stdout handle))])
             (and (string? raw)
                  (let ([trimmed (trim raw)])
                    (and (not (string=? trimmed ""))
                         trimmed))))))))

(define (run-command cmd . extra-args)
  (spawn-process
    (command (car cmd)
             (append (cdr cmd) extra-args))))

(define (resolve-get-cmd)
  (if (procedure? *get-cmd*)
      (*get-cmd*)
      *get-cmd*))

(define (resolve-set-cmd)
  (if (procedure? *set-cmd*)
      (*set-cmd*)
      *set-cmd*))

(define (resolve-default)
  (if (procedure? *default-source*)
      (*default-source*)
      *default-source*))

;; ── Configuration ───────────────────────────────────────────────

(define (input-source-configure! #:default-source default-source
                    #:get-cmd get-cmd
                    #:set-cmd set-cmd)
  (unless (and default-source
               (or (string? default-source) (procedure? default-source)))
    (error! (string-append "configure!: #:default-source must be a string or procedure, got "
                           (to-string default-source))))
  (unless (and get-cmd
               (or (procedure? get-cmd)
                   (and (list? get-cmd) (not (null? get-cmd)) (string? (car get-cmd)))))
    (error! (string-append "configure!: #:get-cmd must be a list or procedure, got "
                           (to-string get-cmd))))
  (unless (and set-cmd
               (or (procedure? set-cmd)
                   (and (list? set-cmd) (not (null? set-cmd)) (string? (car set-cmd)))))
    (error! (string-append "configure!: #:set-cmd must be a list or procedure, got "
                           (to-string set-cmd))))
  (set! *default-source* default-source)
  (set! *get-cmd* get-cmd)
  (set! *set-cmd* set-cmd))

;; ── Public API ──────────────────────────────────────────────────

(define (input-source-get)
  (capture-output (resolve-get-cmd)))

(define (input-source-switch source-id)
  (unless (string? source-id)
    (error! (string-append "input-source-switch: expected a string, got " (to-string source-id))))
  (with-handler
    (lambda (err)
      (set-warning! (string-append "input-source-switch: " (to-string err))))
    (run-command (resolve-set-cmd) source-id)))

(define (input-source-to-default)
  (define default-source (resolve-default))
  (unless default-source
    (error! "input-source-to-default: not configured. Call input-source-configure! first."))
  (define current (input-source-get))
  (when (and current (not (string=? current default-source)))
    (set! *previous-source* current)
    (input-source-switch default-source)))

(define (input-source-back)
  (when *previous-source*
    (input-source-switch *previous-source*)
    (set! *previous-source* #f)))

(define (input-source-reset!)
  (set! *previous-source* #f))

;; ── Platform Detection ──────────────────────────────────────────

(define (config-dir)
  (let ([path (get-init-scm-path)]
        [len (string-length (get-init-scm-path))])
    (if (>= len 8)
        (substring path 0 (- len 8))
        path)))

(define (windows-ps1-path)
  (string-append (config-dir)
                 "cogs/input-source/input-source.ps1"))

(define (detect)
  (unless *detected?*
    (set! *detected?* #t)
    (set! *detected*
          (cond
            [(which "macism") (list "com.apple.keylayout.ABC" '("macism") '("macism"))]
            [(which "fcitx5-remote") (list "keyboard-us" '("fcitx5-remote" "-n") '("fcitx5-remote" "-s"))]
            [(which "ibus") (list "xkb:us::eng" '("ibus" "engine") '("ibus" "engine"))]
            [else
             (let ([get (list "powershell.exe" "-NoProfile" "-File" (windows-ps1-path) "get")]
                   [set (list "powershell.exe" "-NoProfile" "-File" (windows-ps1-path) "set")])
               (and (capture-output get) (list "00000409" get set)))])))
  *detected*)

(define (detect-default-source)
  (let ([r (detect)])
    (and r (car r))))

(define (detect-get-cmd)
  (let ([r (detect)])
    (and r (cadr r))))

(define (detect-set-cmd)
  (let ([r (detect)])
    (and r (caddr r))))

(define (input-source-autoconfigure!)
  (unless *initialized*
    (let ([default (detect-default-source)]
          [get-cmd (detect-get-cmd)]
          [set-cmd (detect-set-cmd)])
      (if get-cmd
          (begin
            (input-source-configure! #:default-source default
                                     #:get-cmd get-cmd
                                     #:set-cmd set-cmd)
            (register-hook 'on-mode-switch
              (lambda (event)
                (let ([old (mode-switch-old event)]
                      [new (mode-switch-new event)])
                  (when (and (insert-mode? old) (not (insert-mode? new)))
                    (input-source-to-default)))))
            (register-hook 'terminal-focus-gained
              (lambda ()
                (unless (insert-mode? (editor-mode))
                   (input-source-to-default)))))
          (set-warning! (string-append
                           "im-switch: no supported tool found "
                           "(tried macism, fcitx5-remote, ibus, and Windows). "
                           "Configure manually with input-source-configure!."))))
    (set! *initialized* #t)))

(define (input-source-init)
  (input-source-autoconfigure!))
