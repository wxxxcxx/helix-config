(require "helix/components.scm")
(require "helix/misc.scm")
(require "helix/editor.scm")
(require (only-in "helix/static.scm" cx->current-file))
(require (prefix-in helix. "helix/commands.scm"))
(require "features/file-manager/core/files.scm")
(require (only-in "features/file-manager/core/collections.scm"
                  fm-add-unique
                  fm-member?))
(require "features/file-manager/core/actions.scm")
(require "features/file-manager/core/session.scm")
(require "features/file-manager/core/modal.scm")
(require "features/file-manager/core/action-registry.scm")
(require "features/file-manager/core/keymap.scm")
(require "features/file-manager/core/which-key.scm")
(require "features/file-manager/file-tree/git.scm")
(require "features/file-manager/file-tree/config.scm")
(require "features/file-manager/file-tree/render.scm")
(require (only-in "features/panel/panel.scm"
                  panel-close!
                  panel-component-mode
                  panel-focus!
                  panel-focus-editor!
                  panel-show!
                  panel-toggle!))

(provide file-tree-init
         file-tree-open
         file-tree-close
         file-tree-configure!
         file-tree-panel-mode
         file-tree-toggle)

(define *ft-active* #f)
(define *ft-focused?* #f)
(define *ft-mouse-pressed?* #f)
(define *ft-root* "")
(define *ft-workspace-root* "")
(define *ft-expanded* '())
(define *ft-rows* '())
(define *ft-selected* 0)
(define *ft-scroll* 0)
(define *ft-content-height* 1)
(define *ft-bounds* #f)
(define *ft-show-hidden* #f)
(define *ft-session* (fm-session-empty))
(define *ft-git-status* (hash))
(define *ft-git-ignored* (hash))
(define *ft-key-prefix* "")
(define *ft-help-visible?* #f)
(define *ft-pending-action* #f)
(define *ft-root-back* '())
(define *ft-root-forward* '())
(define *ft-root-views* (hash))

(define (ft-remove value values)
  (cond [(null? values) '()]
        [(equal? value (car values)) (cdr values)]
        [else (cons (car values) (ft-remove value (cdr values)))]))

(define (ft-append left right)
  (if (null? left) right (cons (car left) (ft-append (cdr left) right))))

(define (ft-flatten lists)
  (if (null? lists) '() (ft-append (car lists) (ft-flatten (cdr lists)))))

(define (ft-children path)
  (fm-sort-entries (fm-read-dir-names path *ft-show-hidden*) 'name #f))

(define (ft-node-rows path depth)
  (define row (list depth path))
  (if (and (is-dir? path) (fm-member? path *ft-expanded*))
      (cons row
            (ft-flatten
              (map (lambda (child) (ft-node-rows child (+ depth 1)))
                   (ft-children path))))
      (list row)))

(define (ft-rebuild!)
  (set! *ft-rows* (if (string=? *ft-root* "") '() (ft-node-rows *ft-root* 0)))
  (set! *ft-selected* (min *ft-selected* (max 0 (- (length *ft-rows*) 1))))
  (set! *ft-scroll*
        (min *ft-scroll* (max 0 (- (length *ft-rows*) *ft-content-height*)))))

(define (ft-row-path row) (list-ref row 1))
(define (ft-row-depth row) (car row))

(define (ft-selected-row)
  (if (< *ft-selected* (length *ft-rows*))
      (list-ref *ft-rows* *ft-selected*)
      #f))

(define (ft-selected-path)
  (define row (ft-selected-row))
  (and row (ft-row-path row)))

(define (ft-row-index path)
  (let loop ([rows *ft-rows*] [index 0])
    (cond [(null? rows) #f]
          [(string=? path (ft-row-path (car rows))) index]
          [else (loop (cdr rows) (+ index 1))])))

(define (ft-scroll-to-visible!)
  (define visible (max 1 *ft-content-height*))
  (define max-scroll (max 0 (- (length *ft-rows*) visible)))
  (cond [(< *ft-selected* *ft-scroll*) (set! *ft-scroll* *ft-selected*)]
        [(>= *ft-selected* (+ *ft-scroll* visible))
         (set! *ft-scroll* (- *ft-selected* visible -1))])
  (set! *ft-scroll* (min max-scroll (max 0 *ft-scroll*))))

(define (ft-select-path! path)
  (define index (ft-row-index path))
  (when index
    (set! *ft-selected* index)
    (ft-scroll-to-visible!)))

(define (ft-expand-ancestors! path)
  (define start (if (is-dir? path) path (fm-parent-dir path)))
  (let loop ([current start])
    (when (and (not (string=? current ""))
               (not (string=? current (fm-parent-dir current))))
      (set! *ft-expanded* (fm-add-unique current *ft-expanded*))
      (unless (string=? current *ft-root*)
        (loop (fm-parent-dir current)))))
  (set! *ft-expanded* (fm-add-unique *ft-root* *ft-expanded*)))

(define (ft-follow-path! path)
  (when (and path (path-exists? path) (ft-path-under-root? path))
    (ft-expand-ancestors! path)
    (ft-rebuild!)
    (ft-select-path! path)))

(define (ft-current-file)
  (with-handler (lambda (_) #f) (cx->current-file)))

(define (ft-path-under-root? path)
  (and path
       (not (string=? *ft-root* ""))
       (let loop ([current path])
         (cond [(string=? current *ft-root*) #t]
               [(string=? current (fm-parent-dir current)) #f]
               [else (loop (fm-parent-dir current))]))))

(define (ft-save-root-view!)
  (when (not (string=? *ft-root* ""))
    (set! *ft-root-views*
          (hash-insert *ft-root-views* *ft-root*
                       (list *ft-expanded* (ft-selected-path) *ft-scroll*)))))

(define (ft-restore-root-view! root)
  (define view (hash-try-get *ft-root-views* root))
  (if view
      (begin
        (set! *ft-expanded* (filter path-exists? (list-ref view 0)))
        (set! *ft-selected* 0)
        (set! *ft-scroll* (list-ref view 2))
        (list-ref view 1))
      (begin
        (set! *ft-expanded* (list root))
        (set! *ft-selected* 0)
        (set! *ft-scroll* 0)
        #f)))

(define (ft-activate-root! root)
  (define selected #f)
  (ft-save-root-view!)
  (set! *ft-root* root)
  (set! *ft-session* (fm-session-clear-marks *ft-session*))
  (set! selected (ft-restore-root-view! root))
  (ft-refresh-git!)
  (ft-rebuild!)
  (cond [(and selected (ft-path-under-root? selected) (path-exists? selected))
         (ft-expand-ancestors! selected)
         (ft-rebuild!)
         (ft-select-path! selected)]
        [(ft-path-under-root? (ft-current-file))
         (ft-follow-path! (ft-current-file))]
        [else (ft-select-path! root)]))

(define (ft-set-root! root)
  (cond [(or (not root) (not (path-exists? root)))
         (set-warning! "file-tree root does not exist")]
        [(not (is-dir? root))
         (set-warning! "file-tree root must be a directory")]
        [(string=? root *ft-root*) #f]
        [else
         (when (not (string=? *ft-root* ""))
           (set! *ft-root-back* (cons *ft-root* *ft-root-back*)))
         (set! *ft-root-forward* '())
         (ft-activate-root! root)]))

(define (ft-root-back!)
  (if (null? *ft-root-back*)
      (set-warning! "file-tree root history: no previous root")
      (let ([target (car *ft-root-back*)])
        (set! *ft-root-back* (cdr *ft-root-back*))
        (set! *ft-root-forward* (cons *ft-root* *ft-root-forward*))
        (ft-activate-root! target))))

(define (ft-root-forward!)
  (if (null? *ft-root-forward*)
      (set-warning! "file-tree root history: no next root")
      (let ([target (car *ft-root-forward*)])
        (set! *ft-root-forward* (cdr *ft-root-forward*))
        (set! *ft-root-back* (cons *ft-root* *ft-root-back*))
        (ft-activate-root! target))))

(define (ft-selected-root)
  (define selected (ft-selected-path))
  (and selected (if (is-dir? selected) selected (fm-parent-dir selected))))

(define (ft-current-file-root)
  (define current (ft-current-file))
  (and current (if (is-dir? current) current (fm-parent-dir current))))

(define (ft-parent-root)
  (define parent (fm-parent-dir *ft-root*))
  (define previous *ft-root*)
  (if (string=? parent *ft-root*)
      (set-warning! "file-tree root has no parent")
      (begin
        (ft-set-root! parent)
        (ft-follow-path! previous))))

(define (ft-prompt-root!)
  (fm-prompt! 'input "Root: " *ft-root*
              (lambda (path) (ft-set-root! path))))

(define (ft-refresh-git!)
  (set! *ft-git-status* (ft-git-read *ft-root*))
  (set! *ft-git-ignored* (ft-git-read-ignored *ft-root*)))

(define (ft-path-git-kinds path)
  (ft-git-path-kinds *ft-git-status* *ft-root* path))

(define (ft-operation-targets)
  (define current (ft-selected-path))
  (if (null? (fm-session-marked *ft-session*))
      (if (and current (not (string=? current *ft-root*))) (list current) '())
      (filter (lambda (path) (not (string=? path *ft-root*)))
              (fm-session-marked *ft-session*))))

(define (ft-operation-directory)
  (define current (ft-selected-path))
  (if (and current (is-dir? current)) current (and current (fm-parent-dir current))))

(define (ft-operation-count paths) (int->string (length paths)))

(define (ft-clear-yank!)
  (set! *ft-session* (fm-session-clear-clipboard *ft-session*)))

(define (ft-reload!)
  (define selected (ft-selected-path))
  (set! *ft-session* (fm-session-prune-marks *ft-session* path-exists?))
  (ft-refresh-git!)
  (ft-rebuild!)
  (when selected (ft-select-path! selected)))

(define (ft-do-mark)
  (define path (ft-selected-path))
  (when (and path (not (string=? path *ft-root*)))
    (set! *ft-session* (fm-session-toggle-mark *ft-session* path))
    (set! *ft-selected* (min (+ *ft-selected* 1) (max 0 (- (length *ft-rows*) 1))))
    (ft-scroll-to-visible!))
  event-result/consume)

(define (ft-stage-operation! mode)
  (define paths (ft-operation-targets))
  (when (not (null? paths))
    (set! *ft-session* (fm-session-stage *ft-session* mode paths)))
  event-result/consume)

(define (ft-relative-path path)
  (define prefix (string-append *ft-workspace-root* (path-separator)))
  (cond [(string=? path *ft-workspace-root*) "."]
        [(starts-with? path prefix) (substring path (string-length prefix) (string-length path))]
        [else path]))

(define (ft-copy-selected! value label)
  (with-handler
    (lambda (err) (set-warning! (string-append "copy " label " failed: " (error-object-message err))))
    (begin
      (set-register! (fm-session-register *ft-session*) (list value))
      (set-warning! (string-append "copied " label ": " value))))
  (set! *ft-session* (fm-session-reset-register *ft-session*))
  event-result/consume)

(define (ft-copy-value! kind)
  (define path (ft-selected-path))
  (if path
      (ft-copy-selected!
        (cond [(equal? kind 'relative) (ft-relative-path path)]
              [(equal? kind 'filename) (fm-entry-label path)]
              [else path])
        (cond [(equal? kind 'relative) "relative path"]
              [(equal? kind 'filename) "filename"]
              [else "absolute path"]))
      (set-warning! "copy: no entry selected"))
  event-result/consume)

(define (ft-select-copy-register)
  (set! *ft-pending-action* 'copy-register)
  (set-warning! "register: enter a register name")
  event-result/consume)

(define (ft-handle-copy-register event)
  (define register (key-event-char event))
  (set! *ft-pending-action* #f)
  (if (char? register)
      (begin
        (set! *ft-session* (fm-session-with-register *ft-session* register))
        (set-warning! (string-append "register " (string register) ": ya=absolute yr=relative yn=filename")))
      (set-warning! "register: enter a register name"))
  event-result/consume)

(define (ft-paste! force?)
  (define destination (ft-operation-directory))
  (when (and destination (fm-session-mode *ft-session*)
             (not (null? (fm-session-clipboard *ft-session*))))
    (with-handler
      (lambda (err) (set-warning! (string-append "paste failed: " (error-object-message err))))
      (begin
        (fm-paste! (fm-session-mode *ft-session*)
                   (fm-session-clipboard *ft-session*) destination force?)
        (when (equal? (fm-session-mode *ft-session*) 'move) (ft-clear-yank!))
        (ft-reload!))))
  event-result/consume)

(define (ft-rename-paths! paths)
  (when (not (null? paths))
    (define path (car paths))
    (define old-name (fm-entry-label path))
    (fm-prompt! 'input "Rename: " old-name
                (lambda (new-name)
                  (when (and (not (string=? new-name old-name)) (fm-valid-name? new-name))
                    (with-handler
                      (lambda (err) (set-warning! (string-append "rename failed: " (error-object-message err))))
                      (let ([target (fm-rename! path new-name)])
                        (set! *ft-session*
                              (fm-session-replace-path *ft-session* path target))
                        (ft-reload!))))
                  (ft-rename-paths! (cdr paths))))))

(define (ft-create-kind directory?)
  (define directory (ft-operation-directory))
  (when directory
    (fm-prompt! 'input (if directory? "New directory: " "New file: ") ""
                (lambda (name)
                  (when (> (string-length name) 0)
                    (with-handler
                      (lambda (err) (set-warning! (string-append "create failed: " (error-object-message err))))
                      (fm-create! directory
                                  (if (and directory? (not (ends-with? name (path-separator))))
                                      (string-append name (path-separator))
                                      name))
                      (ft-reload!))))))
  event-result/consume)

(define (ft-trash)
  (define paths (ft-operation-targets))
  (when (not (null? paths))
    (fm-prompt! 'confirm (string-append "Move " (ft-operation-count paths) " item(s) to Trash? (y/N) ") ""
                (lambda (confirmed?)
                  (when confirmed?
                    (with-handler
                      (lambda (err) (set-warning! (string-append "trash failed: " (error-object-message err))))
                      (for-each fm-trash! paths)
                      (set! *ft-session*
                            (fm-session-complete-paths *ft-session* paths))
                      (ft-reload!))))))
  event-result/consume)

(define (ft-delete)
  (define paths (ft-operation-targets))
  (when (not (null? paths))
    (fm-prompt! 'confirm (string-append "Permanently delete " (ft-operation-count paths) " item(s)? (y/N) ") ""
                (lambda (confirmed?)
                  (when confirmed?
                    (with-handler
                      (lambda (err) (set-warning! (string-append "delete failed: " (error-object-message err))))
                      (for-each fm-delete! paths)
                      (set! *ft-session*
                            (fm-session-complete-paths *ft-session* paths))
                      (ft-reload!))))))
  event-result/consume)

(define (ft-state-ref key)
  (cond [(equal? key 'root) *ft-root*]
        [(equal? key 'focused?) *ft-focused?*]
        [(equal? key 'expanded) *ft-expanded*]
        [(equal? key 'rows) *ft-rows*]
        [(equal? key 'selected) *ft-selected*]
        [(equal? key 'scroll) *ft-scroll*]
        [(equal? key 'marked) (fm-session-marked *ft-session*)]
        [(equal? key 'clipboard) (fm-session-clipboard *ft-session*)]
        [(equal? key 'clipboard-mode) (fm-session-mode *ft-session*)]
        [(equal? key 'git-status) *ft-git-status*]
        [(equal? key 'git-ignored) *ft-git-ignored*]
        [else #f]))

(define (ft-state-set! key value)
  (cond [(equal? key 'layout)
         (set! *ft-content-height* (list-ref value 1))
         (ft-scroll-to-visible!)]
        [(equal? key 'bounds) (set! *ft-bounds* value)]))

(define ft-render-base
  (make-file-tree-render ft-state-ref ft-state-set! ft-config-ref))

(define (ft-panel-render slot-area root-area frame)
  (ft-render-base (hash) slot-area frame)
  ;; Which-key is an editor overlay, so it uses the full host area rather than
  ;; being clipped to the File Tree slot.
  (if *ft-help-visible?*
      (fm-which-key-help-render! "File Tree" (ft-config-ref 'keybindings)
                                 *ft-actions* root-area frame)
      (fm-which-key-render! (ft-config-ref 'keybindings) *ft-actions*
                            *ft-key-prefix* root-area frame)))

(define (ft-move! delta)
  (set! *ft-selected*
        (min (max 0 (+ *ft-selected* delta)) (max 0 (- (length *ft-rows*) 1))))
  (ft-scroll-to-visible!))

(define (ft-toggle-selected!)
  (define path (ft-selected-path))
  (when (and path (is-dir? path))
    (set! *ft-expanded*
          (if (fm-member? path *ft-expanded*)
              (ft-remove path *ft-expanded*)
              (fm-add-unique path *ft-expanded*)))
    (ft-rebuild!)))

(define (ft-open-selected-as mode close-policy)
  (define path (ft-selected-path))
  (define close?
    (or (equal? close-policy 'always)
        (and (equal? close-policy 'configured) (ft-config-ref 'hide-on-open))))
  (cond [(not path) event-result/consume]
        [(is-dir? path) (ft-toggle-selected!) event-result/consume]
        [else
         (enqueue-thread-local-callback
           (lambda ()
             (cond [(equal? mode 'vsplit) (helix.vsplit path)]
                   [(equal? mode 'hsplit) (helix.hsplit path)]
                   [else (helix.open path)])))
         (if close?
             (begin (file-tree-close) event-result/consume)
             (begin (panel-focus-editor!) event-result/ignore))]))

(define (ft-open-selected) (ft-open-selected-as 'normal 'configured))
(define (ft-open-selected-normal) (ft-open-selected-as 'normal 'never))
(define (ft-open-selected-vsplit) (ft-open-selected-as 'vsplit 'never))
(define (ft-open-selected-hsplit) (ft-open-selected-as 'hsplit 'never))
(define (ft-open-selected-close) (ft-open-selected-as 'normal 'always))

(define (ft-parent)
  (define row (ft-selected-row))
  (define path (and row (ft-row-path row)))
  (cond [(and path (is-dir? path) (fm-member? path *ft-expanded*))
         (ft-toggle-selected!)]
        [path (ft-select-path! (fm-parent-dir path))])
  event-result/consume)

(define (ft-collapse-parent)
  (define path (ft-selected-path))
  (when (and path (not (string=? path *ft-root*)))
    (define parent (fm-parent-dir path))
    (set! *ft-expanded* (ft-remove parent *ft-expanded*))
    (ft-rebuild!)
    (ft-select-path! parent))
  event-result/consume)

(define (ft-follow-current)
  (ft-follow-path! (ft-current-file))
  event-result/consume)

(define (ft-follow-current-file!)
  (when *ft-active*
    (ft-follow-path! (ft-current-file))))

(define (ft-refresh)
  (ft-refresh-git!)
  (ft-rebuild!)
  event-result/consume)

(define (ft-toggle-hidden)
  (set! *ft-show-hidden* (not *ft-show-hidden*))
  (ft-rebuild!)
  (set-warning! (string-append "hidden files: " (if *ft-show-hidden* "shown" "hidden")))
  event-result/consume)

(define (ft-show-help)
  (set! *ft-help-visible?* #t)
  event-result/consume)

;;@doc
;; Close file tree.
(define (ft-action-quit)
  (file-tree-close)
  event-result/consume)

(define (ft-action-down) (ft-move! 1) event-result/consume)
(define (ft-action-up) (ft-move! -1) event-result/consume)
(define (ft-action-copy) (ft-stage-operation! 'copy))
(define (ft-action-copy-absolute) (ft-copy-value! 'absolute))
(define (ft-action-copy-relative) (ft-copy-value! 'relative))
(define (ft-action-copy-filename) (ft-copy-value! 'filename))
(define (ft-action-move) (ft-stage-operation! 'move))
(define (ft-action-paste) (ft-paste! #f))
(define (ft-action-paste-force) (ft-paste! #t))
(define (ft-action-unyank) (ft-clear-yank!) event-result/consume)
(define (ft-action-rename)
  (ft-rename-paths! (ft-operation-targets))
  event-result/consume)
(define (ft-action-create-file) (ft-create-kind #f))
(define (ft-action-create-dir) (ft-create-kind #t))
(define (ft-action-root-selected)
  (ft-set-root! (ft-selected-root))
  event-result/consume)
(define (ft-action-root-parent) (ft-parent-root) event-result/consume)
(define (ft-action-root-workspace)
  (ft-set-root! *ft-workspace-root*)
  event-result/consume)
(define (ft-action-root-file)
  (ft-set-root! (ft-current-file-root))
  event-result/consume)
(define (ft-action-root-back) (ft-root-back!) event-result/consume)
(define (ft-action-root-forward) (ft-root-forward!) event-result/consume)
(define (ft-action-root-prompt) (ft-prompt-root!) event-result/consume)

(define *ft-actions*
  (fm-make-action-registry
    (list
      (list 'quit ft-action-quit)
      (list 'down ft-action-down "Next entry")
      (list 'up ft-action-up "Previous entry")
      (list 'open ft-open-selected "Open selected entry")
      (list 'open-normal ft-open-selected-normal "Open")
      (list 'open-vsplit ft-open-selected-vsplit "Open in vertical split")
      (list 'open-hsplit ft-open-selected-hsplit "Open in horizontal split")
      (list 'open-close ft-open-selected-close "Open and close tree")
      (list 'collapse ft-parent "Collapse or select parent")
      (list 'collapse-parent ft-collapse-parent "Collapse parent directory")
      (list 'mark ft-do-mark "Mark entry")
      (list 'copy ft-action-copy "Stage filesystem copy")
      (list 'copy-absolute ft-action-copy-absolute "Copy absolute path")
      (list 'copy-relative ft-action-copy-relative "Copy relative path")
      (list 'copy-filename ft-action-copy-filename "Copy filename")
      (list 'copy-register ft-select-copy-register "Select copy register")
      (list 'move ft-action-move "Stage filesystem move")
      (list 'paste ft-action-paste "Paste")
      (list 'paste-force ft-action-paste-force "Paste and overwrite")
      (list 'unyank ft-action-unyank "Clear staged operation")
      (list 'trash ft-trash "Move to trash")
      (list 'delete ft-delete "Delete permanently")
      (list 'rename ft-action-rename "Rename")
      (list 'create-file ft-action-create-file "Create file")
      (list 'create-dir ft-action-create-dir "Create directory")
      (list 'toggle-hidden ft-toggle-hidden "Toggle hidden files")
      (list 'follow ft-follow-current "Follow current file")
      (list 'refresh ft-refresh "Refresh")
      (list 'root-selected ft-action-root-selected "Selected directory as root")
      (list 'root-parent ft-action-root-parent "Parent directory as root")
      (list 'root-workspace ft-action-root-workspace "Workspace root")
      (list 'root-file ft-action-root-file "Current file directory")
      (list 'root-back ft-action-root-back "Previous root")
      (list 'root-forward ft-action-root-forward "Next root")
      (list 'root-prompt ft-action-root-prompt "Enter root path")
      (list 'help ft-show-help "Show key bindings"))))

(define (ft-run-action action)
  (fm-action-run *ft-actions* action event-result/consume))

(define (ft-modified-key-event? event)
  (and (key-event? event)
       (not (= 0 (or (key-event-modifier event) 0)))))

(define (ft-invalid-key-result had-prefix? event)
  (if (and (not had-prefix?) (ft-modified-key-event? event))
      event-result/ignore
      event-result/consume))

(define (ft-handle-mapped-key event)
  (define had-prefix? (not (string=? *ft-key-prefix* "")))
  (define result (fm-key-step (ft-config-ref 'keybindings) *ft-key-prefix* event))
  (define kind (fm-key-result-kind result))
  (define value (fm-key-result-value result))
  (cond [(equal? kind 'action)
         (set! *ft-key-prefix* "")
         (ft-run-action value)]
        [(equal? kind 'prefix)
         (set! *ft-key-prefix* value)
         event-result/consume]
        [(equal? kind 'cancel)
         (set! *ft-key-prefix* "")
         event-result/consume]
        [else
         (when (and had-prefix?
                    (not (fm-which-key-active? (ft-config-ref 'keybindings) *ft-actions*
                                               *ft-key-prefix*)))
           (set-warning! (string-append "unknown key sequence: " value)))
         (set! *ft-key-prefix* "")
         (ft-invalid-key-result had-prefix? event)]))

(define (ft-mouse-inside-tree? event)
  (and *ft-bounds*
       (let ([col (event-mouse-col event)]
             [row (event-mouse-row event)]
             [x (list-ref *ft-bounds* 0)]
             [y (list-ref *ft-bounds* 1)]
             [width (list-ref *ft-bounds* 2)]
             [height (list-ref *ft-bounds* 3)])
         (and col row
              (>= col x) (< col (+ x width))
              (>= row y) (< row (+ y height))))))

(define (ft-mouse-row-index event)
  (and *ft-bounds*
       (let* ([col (event-mouse-col event)]
              [row (event-mouse-row event)]
              [content-x (list-ref *ft-bounds* 4)]
              [content-y (list-ref *ft-bounds* 5)]
              [content-width (list-ref *ft-bounds* 6)]
              [content-height (list-ref *ft-bounds* 7)]
              [row-offset (- row content-y)]
              [index (+ *ft-scroll* row-offset)])
         (and (>= col content-x) (< col (+ content-x content-width))
              (>= row-offset 0) (< row-offset content-height)
              (< index (length *ft-rows*))
              index))))

(define (ft-focus-mouse-row! event)
  (define index (ft-mouse-row-index event))
  (set! *ft-help-visible?* #f)
  (set! *ft-key-prefix* "")
  (set! *ft-pending-action* #f)
  (when index (set! *ft-selected* index))
  index)

(define (ft-mouse-down-kind? kind)
  (and (>= kind 0) (<= kind 2)))

(define (ft-mouse-up-kind? kind)
  (and (>= kind 3) (<= kind 5)))

(define (ft-open-selected-from-mouse!)
  (define path (ft-selected-path))
  (cond [(not path) event-result/consume]
        [(is-dir? path)
         (ft-toggle-selected!)
         event-result/consume]
        [else
         (enqueue-thread-local-callback (lambda () (helix.open path)))
         (panel-focus-editor!)
         event-result/consume]))

(define (ft-handle-mouse event)
  (define kind (event-mouse-kind event))
  (if (not (ft-mouse-inside-tree? event))
      (begin
        (when (ft-mouse-down-kind? kind)
          (panel-focus-editor!)
          (set! *ft-mouse-pressed?* #f))
        (when (ft-mouse-up-kind? kind)
          (set! *ft-mouse-pressed?* #f))
        event-result/ignore)
      (begin
        (panel-focus! 'file-tree)
        (cond [(= kind 0)
               (set! *ft-mouse-pressed?* #t)
               (if (ft-focus-mouse-row! event)
                   (ft-open-selected-from-mouse!)
                   event-result/consume)]
              [(or (= kind 1) (= kind 2))
               (set! *ft-mouse-pressed?* #t)
               (ft-focus-mouse-row! event)
               event-result/consume]
              [(ft-mouse-up-kind? kind)
               ;; Some terminal emulators consume the mouse-down used to
               ;; reactivate their window but still forward its mouse-up.
               (define activation-click? (not *ft-mouse-pressed?*))
               (set! *ft-mouse-pressed?* #f)
               (when activation-click?
                 (ft-focus-mouse-row! event))
               event-result/consume]
              [(= kind 10)
               (ft-move! 1)
               event-result/consume]
              [(= kind 11)
               (ft-move! -1)
               event-result/consume]
              [else event-result/consume]))))

(define (ft-handle-event state event)
  (cond
    [(mouse-event? event) (ft-handle-mouse event)]
    [(focus-lost-event? event)
     (set! *ft-mouse-pressed?* #f)
     event-result/ignore]
    [(not *ft-focused?*) event-result/ignore]
    [(and *ft-help-visible?* (key-event-escape? event))
     (set! *ft-help-visible?* #f)
     event-result/consume]
    [*ft-help-visible?*
     (set! *ft-help-visible?* #f)
     (ft-handle-mapped-key event)]
    [(and (equal? *ft-pending-action* 'copy-register) (not (key-event-escape? event)))
     (ft-handle-copy-register event)]
    [(key-event-escape? event)
     (set! *ft-pending-action* #f)
     (set! *ft-session* (fm-session-reset-register *ft-session*))
     (if (string=? *ft-key-prefix* "")
         (panel-focus-editor!)
         (set! *ft-key-prefix* ""))
     event-result/consume]
    [else (ft-handle-mapped-key event)]))

;; Panel calls these private lifecycle functions after reserving the slot.
(define (ft-open!)
  (unless *ft-active*
    (set! *ft-active* #t)
    (set! *ft-mouse-pressed?* #f)
    (set! *ft-bounds* #f)
    (set! *ft-root* "")
    (set! *ft-workspace-root* (helix-find-workspace))
    (set! *ft-key-prefix* "")
    (set! *ft-help-visible?* #f)
    (set! *ft-pending-action* #f)
    (set! *ft-session* (fm-session-empty))
    (set! *ft-root-back* '())
    (set! *ft-root-forward* '())
    (set! *ft-root-views* (hash))
    (set! *ft-expanded* '())
    (set! *ft-selected* 0)
    (set! *ft-scroll* 0)
    (set! *ft-show-hidden* #f)
    (ft-clear-yank!)
    (fm-keymap-validate! (ft-config-ref 'keybindings) *ft-actions*)
    (ft-activate-root! *ft-workspace-root*)))

(define (ft-focus!)
  (set! *ft-focused?* #t))

(define (ft-blur!)
  (set! *ft-focused?* #f)
  (set! *ft-mouse-pressed?* #f)
  (set! *ft-key-prefix* ""))

(define (ft-close!)
  (set! *ft-active* #f)
  (set! *ft-focused?* #f)
  (set! *ft-mouse-pressed?* #f)
  (set! *ft-bounds* #f)
  (set! *ft-key-prefix* "")
  (set! *ft-help-visible?* #f)
  (set! *ft-pending-action* #f))

(define (ft-panel-layout! slot width _left _right _bottom)
  (ft-set-panel-layout! slot width))

(define (file-tree-panel-mode)
  (panel-component-mode
    #:name "file-tree"
    #:open (lambda (slot width)
             (ft-panel-layout! slot width 0 0 0)
             (ft-open!))
    #:close ft-close!
    #:layout ft-panel-layout!
    #:render ft-panel-render
    #:handle-event ft-handle-event
    #:focus ft-focus!
    #:blur ft-blur!))

;;@doc
;; Open or focus the persistent file tree in its registered panel slot.
(define (file-tree-open)
  (panel-show! 'file-tree))

;;@doc
;; Toggle the persistent file tree panel.
(define (file-tree-toggle)
  (panel-toggle! 'file-tree))

(define (file-tree-close)
  (panel-close! 'file-tree))

(define (file-tree-init)
  (register-hook 'document-focus-lost
                 (lambda (_) (ft-follow-current-file!)))
  (register-hook 'document-saved
                 (lambda (_) (when *ft-active* (ft-refresh-git!) (ft-rebuild!)))))
