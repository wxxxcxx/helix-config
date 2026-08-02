(require "helix/components.scm")
(require "helix/misc.scm")
(require "features/file-manager/file-explorer/bookmarks.scm")
(require "features/file-manager/file-explorer/bookmarks-view.scm")
(require "features/file-manager/file-explorer/navigation.scm")
(require "features/file-manager/file-explorer/state.scm")
(require "features/file-manager/core/files.scm")
(require "features/file-manager/core/operations.scm")
(require "features/file-manager/core/session.scm")

(provide fe-prune-bookmarks!
         fe-do-bookmarks
         fe-do-mark
         fe-do-copy
         fe-do-move
         fe-do-copy-absolute
         fe-do-copy-relative
         fe-do-copy-filename
         fe-do-copy-register
         fe-do-copy-register-key
         fe-do-paste
         fe-do-paste-force
         fe-do-unyank
         fe-do-rename
         fe-do-create-file
         fe-do-create-dir
         fe-do-trash
         fe-do-delete)

(define (fe-bookmark-target)
  (or (fe-current-entry) (fe-ref 'path)))

(define (fe-bookmark-save!)
  (with-handler
    (lambda (err)
      (set-warning! (string-append "bookmark save failed: " (error-object-message err))))
    (fe-bookmarks-save! (fe-ref 'bookmarks))))

(define (fe-prune-bookmarks!)
  (define pruned (fe-bookmark-prune (fe-ref 'bookmarks)))
  (unless (= (length pruned) (length (fe-ref 'bookmarks)))
    (fe-set! 'bookmarks pruned)
    (fe-bookmark-save!)))

(define (fe-jump-to-bookmark! path)
  (cond
    [(not (path-exists? path))
     #f]
    [else
     (define parent (fm-parent-dir path))
     (fe-enter-dir parent)
     (unless (string=? parent path)
       (fe-select-entry! path))
     #t]))

(define (fe-set-bookmark! key path)
  (fe-set! 'bookmarks (fe-bookmark-set (fe-ref 'bookmarks) key path))
  (fe-bookmark-save!))

(define (fe-remove-bookmark! key)
  (fe-set! 'bookmarks (fe-bookmark-remove (fe-ref 'bookmarks) key))
  (fe-bookmark-save!))

(define (fe-do-bookmarks)
  (fe-prune-bookmarks!)
  (fe-bookmarks-view! (fe-ref 'bookmarks)
                      (fe-bookmark-target)
                      fe-jump-to-bookmark!
                      fe-set-bookmark!
                      fe-remove-bookmark!)
  event-result/consume)

(define (fe-operation-targets)
  (define current (fe-current-entry))
  (if (null? (fm-session-marked (fe-ref 'session)))
      (if current (list current) '())
      (fm-session-marked (fe-ref 'session))))

(define (fe-set-session! session)
  (fe-set! 'session session))

(define (fe-do-mark)
  (define entry (fe-current-entry))
  (when entry
    (fe-set! 'session (fm-session-toggle-mark (fe-ref 'session) entry))
    (fe-move-selection 1))
  event-result/consume)

(define (fe-clear-yank!)
  (fe-set-session! (fm-session-clear-clipboard (fe-ref 'session))))

(define (fe-remove-yanked-paths! paths)
  (fe-set-session! (fm-session-complete-paths (fe-ref 'session) paths)))

(define (fe-reconcile-renamed-path! old-path new-path)
  (fe-set! 'session (fm-session-replace-path (fe-ref 'session) old-path new-path))
  (fe-set! 'bookmarks (fe-bookmark-replace (fe-ref 'bookmarks) old-path new-path))
  (fe-bookmark-save!))

(define (fe-stage-operation! mode)
  (fm-operation-stage! (fe-ref 'session)
                       (fe-operation-targets)
                       fe-set-session!
                       mode
                       #:notify #t))

(define (fe-do-copy) (fe-stage-operation! 'copy) event-result/consume)
(define (fe-do-move) (fe-stage-operation! 'move) event-result/consume)

(define (fe-copy-current! value label)
  (fm-operation-copy-value! (fe-ref 'session)
                            fe-set-session!
                            (fe-current-entry)
                            value
                            label)
  event-result/consume)

(define (fe-relative-path path)
  (fm-relative-path (fe-ref 'workspace-root) path))

(define (fe-do-copy-absolute)
  (define entry (fe-current-entry))
  (if entry (fe-copy-current! entry "absolute path") (set-warning! "copy: no entry selected"))
  event-result/consume)

(define (fe-do-copy-relative)
  (define entry (fe-current-entry))
  (if entry
      (fe-copy-current! (fe-relative-path entry) "relative path")
      (set-warning! "copy: no entry selected"))
  event-result/consume)

(define (fe-do-copy-filename)
  (define entry (fe-current-entry))
  (if entry
      (fe-copy-current! (fm-base-name entry) "filename")
      (set-warning! "copy: no entry selected"))
  event-result/consume)

(define (fe-do-copy-register-key event)
  (fm-operation-handle-copy-register! (fe-ref 'session)
                                      fe-set-session!
                                      (lambda (value) (fe-set! 'pending-action value))
                                      event)
  event-result/consume)

(define (fe-do-copy-register)
  (fm-operation-select-copy-register! (lambda (value) (fe-set! 'pending-action value)))
  event-result/consume)

(define (fe-paste! force?)
  (fm-operation-paste! (fe-ref 'session) fe-set-session! (fe-ref 'path) force? fe-reload!))

(define (fe-do-paste) (fe-paste! #f) event-result/consume)
(define (fe-do-paste-force) (fe-paste! #t) event-result/consume)
(define (fe-do-unyank) (fe-clear-yank!) event-result/consume)

(define (fe-rename-paths! paths)
  (fm-operation-rename-paths! paths fm-base-name fe-reconcile-renamed-path! fe-reload!))

(define (fe-do-rename) (fe-rename-paths! (fe-operation-targets)) event-result/consume)

(define (fe-do-create-kind directory?)
  (fm-operation-create-kind! (fe-ref 'path) directory? fe-reload!)
  event-result/consume)

(define (fe-do-create-file) (fe-do-create-kind #f))
(define (fe-do-create-dir) (fe-do-create-kind #t))

(define (fe-do-trash)
  (define paths (fe-operation-targets))
  (fm-operation-confirm-trash!
    paths
    (lambda ()
      (fe-remove-yanked-paths! paths)
      (fe-prune-bookmarks!)
      (fe-reload!)))
  event-result/consume)

(define (fe-do-delete)
  (define paths (fe-operation-targets))
  (fm-operation-confirm-delete!
    paths
    (lambda ()
      (fe-remove-yanked-paths! paths)
      (fe-prune-bookmarks!)
      (fe-reload!)))
  event-result/consume)
