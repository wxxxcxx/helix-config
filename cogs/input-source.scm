;; cogs/input-source.scm
;; Smart input source switching for Helix
;;
;; Provides functions to query and change the OS keyboard input method.
;; Call (autoconfigure!) to configure and register input-switch hooks.
;; Use (disable-hooks!) to temporarily disable hooks at runtime.

(require "helix/editor.scm")
(require "helix/misc.scm")

;; ── Internal State ──────────────────────────────────────────────

(define *default-source-fn* #f)
(define *previous-source* #f)
(define *get-cmd* #f)
(define *set-cmd* #f)
(define *hooks-enabled* #t)
(define *initialized* #f)

(define *insert-mode* (string->editor-mode "insert"))

(define (insert-mode? mode)
  (equal? mode *insert-mode*))

;; ── Private helpers ─────────────────────────────────────────────

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

;; ── Configuration ───────────────────────────────────────────────

(provide configure!)

(define (configure!
         #:default-source-fn [default-source-fn #f]
         #:get-cmd [get-cmd '("macism")]
         #:set-cmd [set-cmd '("macism")])
  (unless (and default-source-fn (procedure? default-source-fn))
    (error! (string-append "configure!: #:default-source-fn must be a procedure, got "
                              (to-string default-source-fn))))
  (unless (and (list? get-cmd) (not (null? get-cmd)) (string? (car get-cmd)))
    (error! (string-append "configure!: #:get-cmd must be a non-empty list, got "
                              (to-string get-cmd))))
  (unless (and (list? set-cmd) (not (null? set-cmd)) (string? (car set-cmd)))
    (error! (string-append "configure!: #:set-cmd must be a non-empty list, got "
                              (to-string set-cmd))))
  (set! *default-source-fn* default-source-fn)
  (set! *get-cmd* get-cmd)
  (set! *set-cmd* set-cmd))

(provide autoconfigure!)

(define (detect-tool!)
  (cond
    [(which "macism")
     (set! *default-source-fn* (lambda () "com.apple.keylayout.ABC"))
     (set! *get-cmd* '("macism"))
     (set! *set-cmd* '("macism"))]
    [(which "fcitx5-remote")
     (set! *default-source-fn* (lambda () "keyboard-us"))
     (set! *get-cmd* '("fcitx5-remote" "-n"))
     (set! *set-cmd* '("fcitx5-remote" "-s"))]
    [(which "ibus")
     (set! *default-source-fn* (lambda () "xkb:us::eng"))
     (set! *get-cmd* '("ibus" "engine"))
     (set! *set-cmd* '("ibus" "engine"))]
    [else
     (set-warning! (string-append
                       "im-switch: no supported tool found "
                       "(tried macism, fcitx5-remote, ibus). "
                       "Configure manually with configure!."))]))

(define (autoconfigure!)
  (detect-tool!)
  (unless *initialized*
    (register-hook 'on-mode-switch
      (lambda (event)
        (when *hooks-enabled*
          (let ([old-mode (mode-switch-old event)]
                [new-mode (mode-switch-new event)])
            (when (and (insert-mode? old-mode) (not (insert-mode? new-mode)))
              (to-default))))))
    (register-hook 'terminal-focus-gained
      (lambda ()
        (when *hooks-enabled*
          (unless (insert-mode? (editor-mode))
            (to-default)))))
    (set! *initialized* #t)))

;; ── Low-level API ───────────────────────────────────────────────

(provide get)

(define (get)
  (capture-output *get-cmd*))

(provide set)

(define (set source-id)
  (unless (string? source-id)
    (error! (string-append "set: expected a string, got " (to-string source-id))))
  (with-handler
    (lambda (err)
      (set-warning! (string-append "set: " (to-string err))))
    (run-command *set-cmd* source-id)))

;; ── High-level API ──────────────────────────────────────────────

(provide to-default)

(define (to-default)
  (define default-source (*default-source-fn*))
  (unless default-source
    (error! (string-append "to-default: default-source not configured. "
                              "Call configure! first.")))
  (define current (get))
  (when (and current (not (string=? current default-source)))
    (set! *previous-source* current)
    (set default-source)))

(provide back)

(define (back)
  (when *previous-source*
    (set *previous-source*)
    (set! *previous-source* #f)))

(provide reset!)

(define (reset!)
  (set! *previous-source* #f))

;; ── Hook Control ────────────────────────────────────────────

(provide hooks-enabled? enable-hooks! disable-hooks!)

(define (hooks-enabled?)
  *hooks-enabled*)

(define (enable-hooks!)
  (set! *hooks-enabled* #t))

(define (disable-hooks!)
  (set! *hooks-enabled* #f))
