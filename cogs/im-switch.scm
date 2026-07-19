;; cogs/im-switch.scm
;; Smart input source switching for Helix
;;
;; Pure utility module — provides functions to query and change the OS
;; keyboard input method.  No hooks are registered here; wire them up
;; in your config file (see im-switch-config.scm for an example).

(require "helix/misc.scm")

;; ── Internal State ──────────────────────────────────────────────

(define *normal-source* #f)
(define *previous-source* #f)
(define *get-cmd* '("macism"))
(define *set-cmd* '("macism"))

;; ── Platform Auto-Detection ─────────────────────────────────────

(provide im-switch-auto-detect!)
;;@doc
;; Scan PATH for a known input-method tool and set *get-cmd* / *set-cmd*
;; accordingly.  Returns 'macos, 'linux/fcitx5, 'linux/ibus, or #f.
(define (im-switch-auto-detect!)
  (cond
    [(which "macism")
     (set! *get-cmd* '("macism"))
     (set! *set-cmd* '("macism"))
     'macos]
    [(which "fcitx5-remote")
     (set! *get-cmd* '("fcitx5-remote" "-n"))
     (set! *set-cmd* '("fcitx5-remote" "-s"))
     'linux/fcitx5]
    [(which "ibus")
     (set! *get-cmd* '("ibus" "engine"))
     (set! *set-cmd* '("ibus" "engine"))
     'linux/ibus]
    [else
     (set-warning! (string-append
                     "im-switch: no supported tool found "
                     "(tried macism, fcitx5-remote, ibus). "
                     "Configure manually with im-switch-configure!."))
     #f]))

;; ── Configuration ───────────────────────────────────────────────

(provide im-switch-configure!)
;;@doc
;; Set normal-source and optionally override the get/set commands.
;;
;;   #:normal-source - English input source ID (required).
;;   #:get-cmd       - Get-current-source command list (default '("macism")).
;;   #:set-cmd       - Set-source command list (default '("macism")).
(define (im-switch-configure!
         #:normal-source [normal-source #f]
         #:get-cmd [get-cmd '("macism")]
         #:set-cmd [set-cmd '("macism")])

  (when (and normal-source (not (string? normal-source)))
    (error! (string-append "im-switch-configure!: #:normal-source must be a string, got "
                           (to-string normal-source))))
  (unless (and (list? get-cmd) (not (null? get-cmd)) (string? (car get-cmd)))
    (error! (string-append "im-switch-configure!: #:get-cmd must be a non-empty list, got "
                           (to-string get-cmd))))
  (unless (and (list? set-cmd) (not (null? set-cmd)) (string? (car set-cmd)))
    (error! (string-append "im-switch-configure!: #:set-cmd must be a non-empty list, got "
                           (to-string set-cmd))))

  (set! *normal-source* normal-source)
  (set! *get-cmd* get-cmd)
  (set! *set-cmd* set-cmd))

(provide im-switch-autoconfigure!)
;;@doc
;; Auto-detect + configure in one step.  Optional #:get-cmd / #:set-cmd
;; override auto-detected values.
(define (im-switch-autoconfigure!
         #:normal-source [normal-source #f]
         #:get-cmd [get-cmd #f]
         #:set-cmd [set-cmd #f])
  (im-switch-auto-detect!)
  (when get-cmd (set! *get-cmd* get-cmd))
  (when set-cmd (set! *set-cmd* set-cmd))
  (im-switch-configure! #:normal-source normal-source
                        #:get-cmd *get-cmd*
                        #:set-cmd *set-cmd*))

;; ── Low-level API ───────────────────────────────────────────────

(provide im-switch-get)
;;@doc
;; Return the current input source ID as a string, or #f on failure.
(define (im-switch-get)
  (with-handler
    (lambda (err)
      (set-warning! (string-append "im-switch-get: " (to-string err)))
      #f)
    (let* ([proc (~> (command (car *get-cmd*) (cdr *get-cmd*))
                     with-stdout-piped
                     spawn-process)]
           [ok? (Ok? proc)]
           [result (if ok?
                       (let* ([handle (Ok->value proc)]
                              [raw (read-port-to-string (child-stdout handle))])
                         (and (string? raw) (trim raw)))
                       #f)])
      (when (and result (string=? result ""))
        #f)
      result)))

(provide im-switch-set)
;;@doc
;; Switch to source-id (a string like "com.apple.keylayout.US").
(define (im-switch-set source-id)
  (unless (string? source-id)
    (error! (string-append "im-switch-set: expected a string, got " (to-string source-id))))

  (with-handler
    (lambda (err)
      (set-warning! (string-append "im-switch-set: " (to-string err))))
    (spawn-process (command (car *set-cmd*) (append (cdr *set-cmd*) (list source-id))))))

;; ── High-level API ──────────────────────────────────────────────

(provide im-switch-to-normal)
;;@doc
;; Save the current input source and switch to normal-source.
;; No-op if already on the normal source.
(define (im-switch-to-normal)
  (unless *normal-source*
    (error! (string-append "im-switch-to-normal: normal-source not configured. "
                           "Call im-switch-configure! first.")))

  (define current (im-switch-get))
  (cond
    [(not current) void]              ;; get failed — warning already shown
    [(string=? current *normal-source*) void]  ;; already English
    [else
     (set! *previous-source* current)
     (im-switch-set *normal-source*)]))

(provide im-switch-back)
;;@doc
;; Restore the source saved by the last im-switch-to-normal call.
;; No-op if no source was saved.
(define (im-switch-back)
  (when *previous-source*
    (im-switch-set *previous-source*)
    (set! *previous-source* #f)))

(provide im-switch-reset!)
;;@doc
;; Forget the saved previous source without switching.
(define (im-switch-reset!)
  (set! *previous-source* #f))
