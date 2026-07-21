(require "helix/editor.scm")
(require "helix/misc.scm")
(require "helix/static.scm")

(provide configure! autoconfigure!
         get switch to-default back reset!
         hooks-enabled? enable-hooks! disable-hooks!)

;; ── Internal State ──────────────────────────────────────────────

(define *input-source-default-source* #f)
(define *input-source-previous-source* #f)
(define *input-source-get-cmd* #f)
(define *input-source-set-cmd* #f)
(define *input-source-hooks-enabled* #t)
(define *input-source-initialized* #f)
(define *detected* #f)
(define *detected?* #f)

(define *input-source-insert-mode* (string->editor-mode "insert"))

(define (insert-mode? mode)
  (equal? mode *input-source-insert-mode*))

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
  (if (procedure? *input-source-get-cmd*)
      (*input-source-get-cmd*)
      *input-source-get-cmd*))

(define (resolve-set-cmd)
  (if (procedure? *input-source-set-cmd*)
      (*input-source-set-cmd*)
      *input-source-set-cmd*))

(define (resolve-default)
  (if (procedure? *input-source-default-source*)
      (*input-source-default-source*)
      *input-source-default-source*))

;; ── Configuration ───────────────────────────────────────────────

(define (configure! #:default-source default-source
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
  (set! *input-source-default-source* default-source)
  (set! *input-source-get-cmd* get-cmd)
  (set! *input-source-set-cmd* set-cmd))

;; ── Public API ──────────────────────────────────────────────────

(define (get)
  (capture-output (resolve-get-cmd)))

(define (switch source-id)
  (unless (string? source-id)
    (error! (string-append "switch: expected a string, got " (to-string source-id))))
  (with-handler
    (lambda (err)
      (set-warning! (string-append "switch: " (to-string err))))
    (run-command (resolve-set-cmd) source-id)))

(define (to-default)
  (define default-source (resolve-default))
  (unless default-source
    (error! "to-default: default-source not configured. Call configure! first."))
  (define current (get))
  (when (and current (not (string=? current default-source)))
    (set! *input-source-previous-source* current)
    (switch default-source)))

(define (back)
  (when *input-source-previous-source*
    (switch *input-source-previous-source*)
    (set! *input-source-previous-source* #f)))

(define (reset!)
  (set! *input-source-previous-source* #f))

(define (hooks-enabled?)
  *input-source-hooks-enabled*)

(define (enable-hooks!)
  (set! *input-source-hooks-enabled* #t))

(define (disable-hooks!)
  (set! *input-source-hooks-enabled* #f))

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

(define (autoconfigure!)
  (unless *input-source-initialized*
    (let ([default (detect-default-source)]
          [get-cmd (detect-get-cmd)]
          [set-cmd (detect-set-cmd)])
      (if get-cmd
          (begin
            (configure! #:default-source default
                        #:get-cmd get-cmd
                        #:set-cmd set-cmd)
            (register-hook 'on-mode-switch
              (lambda (event)
                (when *input-source-hooks-enabled*
                  (let ([old (mode-switch-old event)]
                        [new (mode-switch-new event)])
                    (when (and (insert-mode? old) (not (insert-mode? new)))
                      (to-default))))))
            (register-hook 'terminal-focus-gained
              (lambda ()
                (when *input-source-hooks-enabled*
                  (unless (insert-mode? (editor-mode))
                    (to-default))))))
          (set-warning! (string-append
                           "im-switch: no supported tool found "
                           "(tried macism, fcitx5-remote, ibus, and Windows). "
                           "Configure manually with configure!."))))
    (set! *input-source-initialized* #t)))
