(require "helix/components.scm")
(require "helix/misc.scm")
(require (only-in "helix/static.scm" cx->current-file))
(require (prefix-in helix. "helix/commands.scm"))
(require "features/file-manager/file-explorer/config.scm")
(require (only-in "features/file-manager/file-explorer/defaults.scm"
                  file-explorer-action-specifications))
(require "features/file-manager/file-explorer/bookmarks.scm")
(require "features/file-manager/file-explorer/navigation.scm")
(require "features/file-manager/file-explorer/operations.scm")
(require "features/file-manager/file-explorer/state.scm")
(require "features/file-manager/core/files.scm")
(require "features/file-manager/core/session.scm")
(require "features/file-manager/core/action-registry.scm")
(require "features/file-manager/core/keymap.scm")
(require "features/file-manager/core/which-key.scm")
(require "features/file-manager/file-explorer/render.scm")

(provide file-explorer-configure!
         file-explorer-open
         file-explorer-close)

(define fe-render-base
  (make-file-explorer-render fe-state-ref fe-state-set! fe-config-ref))

(define (fe-render state rect frame)
  (fe-render-base state rect frame)
  (if (fe-ref 'help-visible?)
      (fm-which-key-help-render! "File Explorer" (fe-config-ref 'keybindings)
                                 *fe-actions* rect frame)
      (fm-which-key-render! (fe-config-ref 'keybindings) *fe-actions*
                            (fe-ref 'key-prefix) rect frame)))

(define (fe-open-file! entry mode)
  (enqueue-thread-local-callback
    (lambda ()
      (cond [(equal? mode 'vsplit) (helix.vsplit entry)]
            [(equal? mode 'hsplit) (helix.hsplit entry)]
            [else (helix.open entry)])))
  (file-explorer-close))

(define (fe-do-open-as mode)
  (define entry (fe-current-entry))
  (cond [(not entry) event-result/consume]
        [(is-dir? entry) (fe-enter-dir entry) event-result/consume]
        [(is-file? entry)
         (fe-open-file! entry mode)
         event-result/consume]
        [else event-result/consume]))

(define (fe-do-open) (fe-do-open-as 'normal))
(define (fe-do-open-vsplit) (fe-do-open-as 'vsplit))
(define (fe-do-open-hsplit) (fe-do-open-as 'hsplit))

;; ── Component lifecycle ────────────────────────────────────────

(define (fe-show-help)
  (fe-set! 'help-visible? #t)
  event-result/consume)

;;@doc
;; Close file explorer.
(define (fe-do-quit)
  (file-explorer-close)
  event-result/close)

(define (fe-action-handler name)
  (cond [(equal? name 'quit) fe-do-quit]
        [(equal? name 'down) fe-do-down]
        [(equal? name 'up) fe-do-up]
        [(equal? name 'open) fe-do-open]
        [(equal? name 'open-normal) fe-do-open]
        [(equal? name 'open-close) fe-do-open]
        [(equal? name 'open-vsplit) fe-do-open-vsplit]
        [(equal? name 'open-hsplit) fe-do-open-hsplit]
        [(equal? name 'parent) fe-do-parent]
        [(equal? name 'mark) fe-do-mark]
        [(equal? name 'copy) fe-do-copy]
        [(equal? name 'copy-absolute) fe-do-copy-absolute]
        [(equal? name 'copy-relative) fe-do-copy-relative]
        [(equal? name 'copy-filename) fe-do-copy-filename]
        [(equal? name 'copy-register) fe-do-copy-register]
        [(equal? name 'bookmarks) fe-do-bookmarks]
        [(equal? name 'move) fe-do-move]
        [(equal? name 'paste) fe-do-paste]
        [(equal? name 'paste-force) fe-do-paste-force]
        [(equal? name 'unyank) fe-do-unyank]
        [(equal? name 'trash) fe-do-trash]
        [(equal? name 'delete) fe-do-delete]
        [(equal? name 'rename) fe-do-rename]
        [(equal? name 'create-file) fe-do-create-file]
        [(equal? name 'create-dir) fe-do-create-dir]
        [(equal? name 'toggle-hidden) fe-do-toggle-hidden]
        [(equal? name 'filter) fe-do-filter]
        [(equal? name 'find) fe-do-find]
        [(equal? name 'find-next) fe-do-find-next]
        [(equal? name 'find-previous) fe-do-find-previous]
        [(equal? name 'sort) fe-do-sort]
        [(equal? name 'refresh) fe-do-refresh]
        [(equal? name 'help) fe-show-help]
        [else (error! (string-append "file-explorer: missing action handler: "
                                     (symbol->string name)))]))

(define *fe-actions*
  (fm-make-action-registry
    (file-explorer-action-specifications fe-action-handler)))

(define (fe-run-action action)
  (fm-action-run *fe-actions* action event-result/consume))

(define (fe-handle-mapped-key event)
  (define result (fm-key-step (fe-config-ref 'keybindings) (fe-ref 'key-prefix) event))
  (define kind (fm-key-result-kind result))
  (define value (fm-key-result-value result))
  (cond [(equal? kind 'action)
         (fe-set! 'key-prefix "")
         (fe-run-action value)]
        [(equal? kind 'prefix)
         (fe-set! 'key-prefix value)
         event-result/consume]
        [(equal? kind 'cancel)
         (fe-set! 'key-prefix "")
         event-result/consume]
        [else
         (when (and (not (string=? (fe-ref 'key-prefix) ""))
                    (not (fm-which-key-active? (fe-config-ref 'keybindings) *fe-actions*
                                               (fe-ref 'key-prefix))))
           (set-warning! (string-append "unknown key sequence: " value)))
         (fe-set! 'key-prefix "")
         event-result/consume]))

(define (fe-handle-event state event)
  (cond
    [(focus-lost-event? event) event-result/ignore]
    [(focus-gained-event? event)
     (fe-reload!)
     event-result/ignore]
    [(and (fe-ref 'help-visible?) (key-event-escape? event))
     (fe-set! 'help-visible? #f)
     event-result/consume]
    [(fe-ref 'help-visible?)
     (fe-set! 'help-visible? #f)
     (fe-handle-mapped-key event)]
    [(key-event-escape? event)
     (cond
       [(equal? (fe-ref 'pending-action) 'filter)
        (fe-update-filter! (fe-ref 'filter-before-input))
        (fe-set! 'pending-action #f)
        (fe-set! 'session (fm-session-reset-register (fe-ref 'session)))
        event-result/consume]
       [(fe-ref 'pending-action)
        (fe-set! 'pending-action #f)
        (fe-set! 'session (fm-session-reset-register (fe-ref 'session)))
        event-result/consume]
       [(not (string=? (fe-ref 'key-prefix) ""))
        (fe-set! 'key-prefix "")
        event-result/consume]
       [(not (null? (fm-session-marked (fe-ref 'session))))
        (fe-set! 'session (fm-session-clear-marks (fe-ref 'session)))
        (fe-set! 'session (fm-session-reset-register (fe-ref 'session)))
        event-result/consume]
       [else (fe-do-quit)])]
    [(equal? (fe-ref 'pending-action) 'filter) (fe-do-filter-key event)]
    [(equal? (fe-ref 'pending-action) 'sort) (fe-do-sort-key event)]
    [(equal? (fe-ref 'pending-action) 'copy-register) (fe-do-copy-register-key event)]
    [else (fe-handle-mapped-key event)]))

;;@doc
;; Open the three-column file explorer.
(define (file-explorer-open)
  (when (fe-ref 'active) (file-explorer-close))
  (fe-reset-open-state!)
  (fe-set! 'show-hidden (fe-config-ref 'show-hidden))
  (fe-set! 'bookmarks (fe-bookmarks-load))
  (fe-prune-bookmarks!)
  (fe-set! 'workspace-root (helix-find-workspace))
  (fm-keymap-validate! (fe-config-ref 'keybindings) *fe-actions*)
  (define current-file (with-handler (lambda (_) #f) (cx->current-file)))
  (fe-load-directory! (if current-file (fm-parent-dir current-file) (fe-ref 'workspace-root)))
  (when current-file (fe-select-entry! current-file))
  (push-component! (new-component! "file-explorer" (hash) fe-render
                                  (hash "handle_event" fe-handle-event))))

(define (file-explorer-close)
  (fe-set! 'active #f)
  (fe-set! 'help-visible? #f)
  (pop-last-component-by-name! "file-explorer"))
