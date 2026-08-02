(require "helix/components.scm")
(require (only-in "helix/editor.scm" set-register!))
(require "helix/misc.scm")
(require "features/file-manager/core/actions.scm")
(require "features/file-manager/core/files.scm")
(require "features/file-manager/core/modal.scm")
(require "features/file-manager/core/session.scm")

(provide fm-operation-count
         fm-relative-path
         fm-operation-stage!
         fm-operation-copy-value!
         fm-operation-select-copy-register!
         fm-operation-handle-copy-register!
         fm-operation-paste!
         fm-operation-rename-paths!
         fm-operation-create-kind!
         fm-operation-confirm-trash!
         fm-operation-confirm-delete!)

(define (fm-operation-count paths)
  (int->string (length paths)))

(define (fm-relative-path workspace-root path)
  (define prefix (string-append workspace-root (path-separator)))
  (cond [(string=? path workspace-root) "."]
        [(starts-with? path prefix) (substring path (string-length prefix) (string-length path))]
        [else path]))

(define (fm-operation-stage! session paths set-session! mode #:notify [notify? #f])
  (when (not (null? paths))
    (set-session! (fm-session-stage session mode paths))
    (when notify?
      (set-warning! (string-append (if (equal? mode 'copy) "yank" "cut")
                                   ": " (fm-operation-count paths) " item(s) ready")))))

(define (fm-operation-copy-value! session set-session! selected value label)
  (if selected
      (with-handler
        (lambda (err)
          (set-warning! (string-append "copy " label " failed: " (error-object-message err))))
        (begin
          (set-register! (fm-session-register session) (list value))
          (set-warning! (string-append "copied " label ": " value))))
      (set-warning! "copy: no entry selected"))
  (set-session! (fm-session-reset-register session)))

(define (fm-operation-select-copy-register! set-pending!)
  (set-pending! 'copy-register)
  (set-warning! "register: enter a register name"))

(define (fm-operation-handle-copy-register! session set-session! set-pending! event)
  (define register (key-event-char event))
  (set-pending! #f)
  (if (char? register)
      (begin
        (set-session! (fm-session-with-register session register))
        (set-warning! (string-append "register " (string register) ": ya=absolute yr=relative yn=filename")))
      (set-warning! "register: enter a register name")))

(define (fm-operation-paste! session set-session! destination force? reload!)
  (when (and destination
             (fm-session-mode session)
             (not (null? (fm-session-clipboard session))))
    (with-handler
      (lambda (err) (set-warning! (string-append "paste failed: " (error-object-message err))))
      (begin
        (fm-paste! (fm-session-mode session)
                   (fm-session-clipboard session)
                   destination
                   force?)
        (when (equal? (fm-session-mode session) 'move)
          (set-session! (fm-session-clear-clipboard session)))
        (reload!)))))

(define (fm-operation-rename-paths! paths path-label after-rename! reload!)
  (when (not (null? paths))
    (define path (car paths))
    (define old-name (path-label path))
    (fm-prompt! 'input "Rename: " old-name
                (lambda (new-name)
                  (when (and (not (string=? new-name old-name)) (fm-valid-name? new-name))
                    (with-handler
                      (lambda (err) (set-warning! (string-append "rename failed: " (error-object-message err))))
                      (let ([target (fm-rename! path new-name)])
                        (after-rename! path target)
                        (reload!))))
                  (fm-operation-rename-paths! (cdr paths) path-label after-rename! reload!)))))

(define (fm-operation-create-kind! directory directory? reload!)
  (when directory
    (fm-prompt! 'input (if directory? "New directory: " "New file: ") ""
                (lambda (name)
                  (when (> (string-length name) 0)
                    (with-handler
                      (lambda (err) (set-warning! (string-append "create failed: " (error-object-message err))))
                      (begin
                        (fm-create! directory
                                    (if (and directory? (not (ends-with? name (path-separator))))
                                        (string-append name (path-separator))
                                        name))
                        (reload!))))))))

(define (fm-operation-confirm-paths! paths prompt failure-label action! after-success!)
  (when (not (null? paths))
    (fm-prompt! 'confirm prompt ""
                (lambda (confirmed?)
                  (when confirmed?
                    (with-handler
                      (lambda (err)
                        (set-warning! (string-append failure-label " failed: "
                                                     (error-object-message err))))
                      (begin
                        (for-each action! paths)
                        (after-success!))))))))

(define (fm-operation-confirm-trash! paths after-success!)
  (fm-operation-confirm-paths!
    paths
    (string-append "Move " (fm-operation-count paths) " item(s) to Trash? (y/N) ")
    "trash"
    fm-trash!
    after-success!))

(define (fm-operation-confirm-delete! paths after-success!)
  (fm-operation-confirm-paths!
    paths
    (string-append "Permanently delete " (fm-operation-count paths) " item(s)? (y/N) ")
    "delete"
    fm-delete!
    after-success!))
