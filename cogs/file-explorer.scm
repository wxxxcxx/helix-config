(require "helix/components.scm")
(require "helix/misc.scm")
(require "helix/editor.scm")
(require (only-in "helix/static.scm" cx->current-file))
(require (prefix-in helix. "helix/commands.scm"))
(require "cogs/file-explorer/config.scm")
(require "cogs/file-manager/bookmarks.scm")
(require "cogs/file-manager/bookmarks-view.scm")
(require "cogs/file-manager/files.scm")
(require "cogs/file-manager/actions.scm")
(require "cogs/file-manager/modal.scm")
(require "cogs/file-manager/keymap.scm")
(require "cogs/file-manager/which-key.scm")
(require "cogs/file-explorer/render.scm")

(provide file-explorer-configure! file-explorer-open file-explorer-close)

;; ── Explorer state ─────────────────────────────────────────────

(define *fe-active* #f)
(define *fe-path* "")
(define *fe-workspace-root* "")
(define *fe-parent-files* '())
(define *fe-files* '())
(define *fe-all-parent-files* '())
(define *fe-all-files* '())
(define *fe-cursor-row* 0)
(define *fe-col-scroll* (vector 0 0))
(define *fe-show-hidden* #f)
(define *fe-content-h* 0)
(define *fe-parent-cursor* 0)
(define *fe-scrolls* (hash))
(define *fe-parent-scrolls* (hash))
(define *fe-marked* '())
(define *fe-clipboard* '())
(define *fe-clipboard-mode* #f)
(define *fe-filter-query* "")
(define *fe-filter-before-input* "")
(define *fe-find-query* "")
(define *fe-sort-mode* 'name)
(define *fe-sort-reverse?* #f)
(define *fe-pending-action* #f)
(define *fe-key-prefix* "")
(define *fe-help-visible?* #f)
(define *fe-copy-register* #\+)
(define *fe-bookmarks* '())

;; The renderer only reads this snapshot and reports its usable height.
(define (fe-state-ref key)
  (cond [(equal? key 'path) *fe-path*]
        [(equal? key 'parent-files) *fe-parent-files*]
        [(equal? key 'files) *fe-files*]
        [(equal? key 'cursor-row) *fe-cursor-row*]
        [(equal? key 'col-scroll) *fe-col-scroll*]
        [(equal? key 'show-hidden) *fe-show-hidden*]
        [(equal? key 'parent-cursor) *fe-parent-cursor*]
        [(equal? key 'marked) *fe-marked*]
        [(equal? key 'clipboard) *fe-clipboard*]
        [(equal? key 'clipboard-mode) *fe-clipboard-mode*]
        [(equal? key 'filter-query) *fe-filter-query*]
        [(equal? key 'filtering?) (equal? *fe-pending-action* 'filter)]
        [(equal? key 'sort-mode) *fe-sort-mode*]
        [(equal? key 'sort-reverse?) *fe-sort-reverse?*]
        [(equal? key 'bookmarks) *fe-bookmarks*]
        [else #f]))

(define (fe-state-set! key value)
  (when (equal? key 'content-h)
    (set! *fe-content-h* value)))

(define fe-render-base
  (make-file-explorer-render fe-state-ref fe-state-set! fe-config-ref))

(define (fe-render state rect frame)
  (fe-render-base state rect frame)
  (if *fe-help-visible?*
      (fm-which-key-help-render! "File Explorer" (fe-config-ref 'keybindings) rect frame)
      (fm-which-key-render! (fe-config-ref 'keybindings) *fe-key-prefix* rect frame)))

;; ── Key dispatch ───────────────────────────────────────────────

(define (fe-kb-string event) (fm-key-token event))

;; ── Navigation ─────────────────────────────────────────────────

(define (fe-entry-index entries name)
  (let loop ([items entries] [index 0])
    (cond [(null? items) 0]
          [(string=? (fe-entry-label (car items)) name) index]
          [else (loop (cdr items) (+ index 1))])))

(define (fe-path-index entries path)
  (let loop ([items entries] [index 0])
    (cond [(null? items) #f]
          [(string=? (car items) path) index]
          [else (loop (cdr items) (+ index 1))])))

(define (fe-parent-idx)
  (fe-entry-index *fe-parent-files* (fe-entry-label *fe-path*)))

(define (fe-scrolloff)
  (define configured (with-handler (lambda (_) 3) (car (helix.get-option '(scrolloff)))))
  (min (max configured 0) (quotient (max 0 (- *fe-content-h* 1)) 2)))

(define (fe-scroll-to-visible scroll row count)
  (define height (max 1 *fe-content-h*))
  (define max-scroll (max 0 (- count height)))
  (define current-scroll (min (max 0 scroll) max-scroll))
  (define offset (fe-scrolloff))
  (define top (+ current-scroll offset))
  (define bottom (- (+ current-scroll height) offset 1))
  (cond [(< row top) (max 0 (- row offset))]
        [(> row bottom) (min max-scroll (max 0 (- row (- height offset 1))))]
        [else current-scroll]))

(define (fe-save-scrolls!)
  (set! *fe-scrolls* (hash-insert *fe-scrolls* *fe-path* (cons (vector-ref *fe-col-scroll* 1) *fe-cursor-row*)))
  (set! *fe-parent-scrolls* (hash-insert *fe-parent-scrolls* *fe-path* (vector-ref *fe-col-scroll* 0))))

(define (fe-load-scroll dir)
  (define saved (hash-try-get *fe-scrolls* dir))
  (if saved (car saved) 0))

(define (fe-load-cursor dir)
  (define saved (hash-try-get *fe-scrolls* dir))
  (if saved (cdr saved) 0))

(define (fe-load-parent-scroll dir)
  (or (hash-try-get *fe-parent-scrolls* dir) 0))

(define (fe-show-hidden?)
  (or *fe-show-hidden* (fe-config-ref 'show-hidden)))

(define (fe-rebuild-visible-files!)
  (set! *fe-parent-files* (fe-sort-entries *fe-all-parent-files* *fe-sort-mode* *fe-sort-reverse?*))
  (set! *fe-files*
        (fe-sort-entries (fe-filter-entries *fe-all-files* *fe-filter-query*)
                         *fe-sort-mode*
                         *fe-sort-reverse?*)))

(define (fe-restore-selection! selected-path)
  (set! *fe-parent-cursor* (fe-parent-idx))
  (define selected-index (and selected-path (fe-path-index *fe-files* selected-path)))
  (set! *fe-cursor-row*
        (if selected-index
            selected-index
            (min *fe-cursor-row* (max 0 (- (length *fe-files*) 1)))))
  (vector-set! *fe-col-scroll* 0
               (fe-scroll-to-visible (vector-ref *fe-col-scroll* 0) *fe-parent-cursor* (length *fe-parent-files*)))
  (vector-set! *fe-col-scroll* 1
               (fe-scroll-to-visible (vector-ref *fe-col-scroll* 1) *fe-cursor-row* (length *fe-files*))))

(define (fe-load-directory! dir)
  (set! *fe-path* dir)
  (set! *fe-all-parent-files*
        (if (fe-windows-drives-root? dir)
            '()
            (fe-read-dir-names (fe-parent-dir dir) (fe-show-hidden?))))
  (set! *fe-all-files* (fe-read-dir-names dir (fe-show-hidden?)))
  (fe-rebuild-visible-files!)
  (set! *fe-parent-cursor* (fe-parent-idx))
  (set! *fe-cursor-row* (min (fe-load-cursor dir) (max 0 (- (length *fe-files*) 1))))
  (set! *fe-col-scroll*
        (vector (fe-scroll-to-visible (fe-load-parent-scroll dir) *fe-parent-cursor* (length *fe-parent-files*))
                (fe-scroll-to-visible (fe-load-scroll dir) *fe-cursor-row* (length *fe-files*)))))

(define (fe-enter-dir dir)
  (let ([old-path *fe-path*])
    (when (and (not (string=? old-path dir)) (> (string-length old-path) 0))
      (fe-save-scrolls!)))
  (set! *fe-filter-query* "")
  (fe-load-directory! dir))

(define (fe-current-entry)
  (if (< *fe-cursor-row* (length *fe-files*))
      (list-ref *fe-files* *fe-cursor-row*)
      #f))

(define (fe-select-entry! path)
  (define index (fe-path-index *fe-files* path))
  (when index
    (set! *fe-cursor-row* index)
    (vector-set! *fe-col-scroll* 1
                 (fe-scroll-to-visible (vector-ref *fe-col-scroll* 1) index (length *fe-files*)))))

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

(define (fe-do-parent)
  (define parent (fe-parent-dir *fe-path*))
  (cond
    [(fe-windows-drive-root? *fe-path*)
     (fe-enter-dir "")
     event-result/consume]
    [(or (fe-windows-drives-root? *fe-path*)
         (string=? parent "")
         (equal? parent *fe-path*))
     event-result/consume]
    [else
     (let ([child-name (fe-entry-label *fe-path*)])
       (fe-enter-dir parent)
       (set! *fe-cursor-row* (fe-entry-index *fe-files* child-name))
       (vector-set! *fe-col-scroll* 1
                    (fe-scroll-to-visible (vector-ref *fe-col-scroll* 1) *fe-cursor-row* (length *fe-files*)))
       event-result/consume)]))

(define (fe-move-selection delta)
  (define max-index (max 0 (- (length *fe-files*) 1)))
  (define next (min max-index (max 0 (+ *fe-cursor-row* delta))))
  (set! *fe-cursor-row* next)
  (vector-set! *fe-col-scroll* 1
               (fe-scroll-to-visible (vector-ref *fe-col-scroll* 1) next (length *fe-files*))))

(define (fe-do-down) (fe-move-selection 1) event-result/consume)
(define (fe-do-up) (fe-move-selection -1) event-result/consume)

(define (fe-reload!)
  (define selected-path (fe-current-entry))
  (fe-clear-preview-footer-cache!)
  (set! *fe-all-parent-files* (fe-read-dir-names (fe-parent-dir *fe-path*) (fe-show-hidden?)))
  (set! *fe-all-files* (fe-read-dir-names *fe-path* (fe-show-hidden?)))
  (fe-rebuild-visible-files!)
  (fe-restore-selection! selected-path))

(define (fe-do-toggle-hidden)
  (set! *fe-show-hidden* (not *fe-show-hidden*))
  (fe-reload!)
  (set-warning! (string-append "hidden files: " (if *fe-show-hidden* "shown" "hidden")))
  event-result/consume)

(define (fe-do-refresh) (fe-reload!) event-result/consume)

(define (fe-apply-visible-list!)
  (define selected-path (fe-current-entry))
  (fe-rebuild-visible-files!)
  (fe-restore-selection! selected-path))

(define (fe-do-filter)
  (set! *fe-filter-before-input* *fe-filter-query*)
  (set! *fe-pending-action* 'filter)
  event-result/consume)

(define (fe-update-filter! query)
  (set! *fe-filter-query* query)
  (fe-apply-visible-list!))

(define (fe-do-filter-key event)
  (define ch (key-event-char event))
  (cond
    [(key-event-enter? event)
     (set! *fe-pending-action* #f)]
    [(key-event-backspace? event)
     (define length (string-length *fe-filter-query*))
     (when (> length 0)
       (fe-update-filter! (substring *fe-filter-query* 0 (- length 1))))]
    [(char? ch)
     (fe-update-filter! (string-append *fe-filter-query* (string ch)))]
    [else #f])
  event-result/consume)

(define (fe-entry-matches? entry query)
  (not (null? (fe-filter-entries (list entry) query))))

(define (fe-wrapped-index index count)
  (cond [(< index 0) (+ index count)]
        [(>= index count) (- index count)]
        [else index]))

(define (fe-find! direction)
  (when (and (not (string=? *fe-find-query* "")) (not (null? *fe-files*)))
    (let loop ([index (fe-wrapped-index (+ *fe-cursor-row* direction) (length *fe-files*))]
               [remaining (length *fe-files*)])
      (cond [(= remaining 0)
             (set-warning! (string-append "not found: " *fe-find-query*))]
            [(fe-entry-matches? (list-ref *fe-files* index) *fe-find-query*)
             (set! *fe-cursor-row* index)
             (vector-set! *fe-col-scroll* 1
                          (fe-scroll-to-visible (vector-ref *fe-col-scroll* 1)
                                                index
                                                (length *fe-files*)))]
            [else
             (loop (fe-wrapped-index (+ index direction) (length *fe-files*))
                   (- remaining 1))]))))

(define (fe-do-find)
  (fm-prompt! 'input "Find: " *fe-find-query*
              (lambda (query)
                (set! *fe-find-query* query)
                (fe-find! 1)))
  event-result/consume)

(define (fe-do-find-prev)
  (fm-prompt! 'input "Find: " *fe-find-query*
              (lambda (query)
                (set! *fe-find-query* query)
                (fe-find! -1)))
  event-result/consume)

(define (fe-do-find-next) (fe-find! 1) event-result/consume)
(define (fe-do-find-previous) (fe-find! -1) event-result/consume)

(define (fe-sort-label)
  (string-append (cond [(equal? *fe-sort-mode* 'extension) "extension"]
                       [(equal? *fe-sort-mode* 'size) "size"]
                       [else "name"])
                 (if *fe-sort-reverse?* " descending" " ascending")))

(define (fe-do-sort-key event)
  (define key (fe-kb-string event))
  (set! *fe-pending-action* #f)
  (cond
    [(or (string=? key "a") (string=? key "A"))
     (set! *fe-sort-mode* 'name)
     (set! *fe-sort-reverse?* (string=? key "A"))]
    [(or (string=? key "e") (string=? key "E"))
     (set! *fe-sort-mode* 'extension)
     (set! *fe-sort-reverse?* (string=? key "E"))]
    [(or (string=? key "s") (string=? key "S"))
     (set! *fe-sort-mode* 'size)
     (set! *fe-sort-reverse?* (string=? key "S"))]
    [else (set-warning! "sort: a=name, e=extension, s=size")])
  (when (or (string=? key "a") (string=? key "A")
            (string=? key "e") (string=? key "E")
            (string=? key "s") (string=? key "S"))
    (fe-apply-visible-list!)
    (set-warning! (string-append "sort: " (fe-sort-label))))
  event-result/consume)

(define (fe-do-sort)
  (set! *fe-pending-action* 'sort)
  (set-warning! "sort: a=name, e=extension, s=size; uppercase reverses")
  event-result/consume)

;; ── Persistent bookmarks ──────────────────────────────────────

(define (fe-bookmark-target)
  (or (fe-current-entry) *fe-path*))

(define (fe-bookmark-save!)
  (with-handler
    (lambda (err)
      (set-warning! (string-append "bookmark save failed: " (error-object-message err))))
    (fe-bookmarks-save! *fe-bookmarks*)))

(define (fe-prune-bookmarks!)
  (define pruned (fe-bookmark-prune *fe-bookmarks*))
  (unless (= (length pruned) (length *fe-bookmarks*))
    (set! *fe-bookmarks* pruned)
    (fe-bookmark-save!)))

(define (fe-jump-to-bookmark! path)
  (cond
    [(not (path-exists? path))
     #f]
    [else
     (define parent (fe-parent-dir path))
     (fe-enter-dir parent)
     (unless (string=? parent path)
       (fe-select-entry! path))
     #t]))

(define (fe-set-bookmark! key path)
  (set! *fe-bookmarks* (fe-bookmark-set *fe-bookmarks* key path))
  (fe-bookmark-save!))

(define (fe-remove-bookmark! key)
  (set! *fe-bookmarks* (fe-bookmark-remove *fe-bookmarks* key))
  (fe-bookmark-save!))

(define (fe-do-bookmarks)
  (fe-prune-bookmarks!)
  (fe-bookmarks-view! *fe-bookmarks*
                      (fe-bookmark-target)
                      fe-jump-to-bookmark!
                      fe-set-bookmark!
                      fe-remove-bookmark!)
  event-result/consume)

;; ── Selection and filesystem operations ────────────────────────

(define (fe-member? value values)
  (cond [(null? values) #f]
        [(equal? value (car values)) #t]
        [else (fe-member? value (cdr values))]))

(define (fe-remove value values)
  (cond [(null? values) '()]
        [(equal? value (car values)) (fe-remove value (cdr values))]
        [else (cons (car values) (fe-remove value (cdr values)))]))

(define (fe-replace value replacement values)
  (cond [(null? values) '()]
        [(equal? value (car values)) (cons replacement (fe-replace value replacement (cdr values)))]
        [else (cons (car values) (fe-replace value replacement (cdr values)))]))

(define (fe-marked? path) (fe-member? path *fe-marked*))

(define (fe-operation-targets)
  (define current (fe-current-entry))
  (if (null? *fe-marked*)
      (if current (list current) '())
      *fe-marked*))

(define (fe-operation-count paths) (int->string (length paths)))

(define (fe-do-mark)
  (define entry (fe-current-entry))
  (when entry
    (set! *fe-marked* (if (fe-marked? entry) (fe-remove entry *fe-marked*) (cons entry *fe-marked*)))
    (fe-move-selection 1))
  event-result/consume)

(define (fe-clear-yank!)
  (set! *fe-clipboard* '())
  (set! *fe-clipboard-mode* #f))

(define (fe-remove-yanked-paths! paths)
  (for-each (lambda (path) (set! *fe-clipboard* (fe-remove path *fe-clipboard*))) paths)
  (when (null? *fe-clipboard*) (set! *fe-clipboard-mode* #f)))

(define (fe-reconcile-renamed-path! old-path new-path)
  (set! *fe-marked* (fe-replace old-path new-path *fe-marked*))
  (set! *fe-clipboard* (fe-replace old-path new-path *fe-clipboard*))
  (set! *fe-bookmarks* (fe-bookmark-replace *fe-bookmarks* old-path new-path))
  (fe-bookmark-save!))

(define (fe-stage-operation! mode)
  (define paths (fe-operation-targets))
  (when (not (null? paths))
    (set! *fe-clipboard* paths)
    (set! *fe-clipboard-mode* mode)
    (set! *fe-marked* '())
    (set-warning! (string-append (if (equal? mode 'copy) "yank" "cut")
                                 ": " (fe-operation-count paths) " item(s) ready"))))

(define (fe-do-copy) (fe-stage-operation! 'copy) event-result/consume)
(define (fe-do-move) (fe-stage-operation! 'move) event-result/consume)

(define (fe-copy-current! value label)
  (define entry (fe-current-entry))
  (if entry
      (with-handler
        (lambda (err)
          (set-warning! (string-append "copy " label " failed: " (error-object-message err))))
        (begin
          (set-register! *fe-copy-register* (list value))
          (set-warning! (string-append "copied " label ": " value))))
      (set-warning! "copy: no entry selected"))
  (set! *fe-copy-register* #\+)
  event-result/consume)

(define (fe-relative-path path)
  (define prefix (string-append *fe-workspace-root* (path-separator)))
  (cond [(string=? path *fe-workspace-root*) "."]
        [(starts-with? path prefix) (substring path (string-length prefix) (string-length path))]
        [else path]))

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
      (fe-copy-current! (fe-base-name entry) "filename")
      (set-warning! "copy: no entry selected"))
  event-result/consume)

(define (fe-do-copy-register-key event)
  (define register (key-event-char event))
  (set! *fe-pending-action* #f)
  (if (char? register)
      (begin
        (set! *fe-copy-register* register)
        (set-warning! (string-append "register " (string register) ": ya=absolute yr=relative yn=filename")))
      (set-warning! "register: enter a register name"))
  event-result/consume)

(define (fe-do-copy-register)
  (set! *fe-pending-action* 'copy-register)
  (set-warning! "register: enter a register name")
  event-result/consume)

(define (fe-paste! force?)
  (when (and *fe-clipboard-mode* (not (null? *fe-clipboard*)))
    (with-handler
      (lambda (err) (set-warning! (string-append "paste failed: " (error-object-message err))))
      (begin
        (fm-paste! *fe-clipboard-mode* *fe-clipboard* *fe-path* force?)
        (when (equal? *fe-clipboard-mode* 'move) (fe-clear-yank!))
        (fe-reload!)))))

(define (fe-do-paste) (fe-paste! #f) event-result/consume)
(define (fe-do-paste-force) (fe-paste! #t) event-result/consume)
(define (fe-do-unyank) (fe-clear-yank!) event-result/consume)

(define (fe-rename-paths! paths)
  (when (not (null? paths))
    (define entry (car paths))
    (define old-name (fe-base-name entry))
    (fm-prompt! 'input "Rename: " old-name
                (lambda (new-name)
                  (when (and (not (string=? new-name old-name)) (fm-valid-name? new-name))
                    (with-handler
                      (lambda (err) (set-warning! (string-append "rename failed: " (error-object-message err))))
                      (let ([target (fm-rename! entry new-name)])
                        (fe-reconcile-renamed-path! entry target)
                        (fe-reload!))))
                  (fe-rename-paths! (cdr paths))))))

(define (fe-do-rename) (fe-rename-paths! (fe-operation-targets)) event-result/consume)

(define (fe-do-create-kind directory?)
  (fm-prompt! 'input (if directory? "New directory: " "New file: ") ""
              (lambda (name)
                (when (> (string-length name) 0)
                  (with-handler
                    (lambda (err) (set-warning! (string-append "create failed: " (error-object-message err))))
                    (begin
                      (fm-create! *fe-path*
                                  (if (and directory? (not (ends-with? name (path-separator))))
                                      (string-append name (path-separator))
                                      name))
                      (fe-reload!))))))
  event-result/consume)

(define (fe-do-create-file) (fe-do-create-kind #f))
(define (fe-do-create-dir) (fe-do-create-kind #t))

(define (fe-do-trash)
  (define paths (fe-operation-targets))
  (when (not (null? paths))
    (fm-prompt! 'confirm (string-append "Move " (fe-operation-count paths) " item(s) to Trash? (y/N) ") ""
                (lambda (confirmed?)
                  (when confirmed?
                    (with-handler
                      (lambda (err) (set-warning! (string-append "trash failed: " (error-object-message err))))
                      (begin
                        (for-each fm-trash! paths)
                        (set! *fe-marked* '())
                        (fe-remove-yanked-paths! paths)
                        (fe-prune-bookmarks!)
                        (fe-reload!)))))))
  event-result/consume)

(define (fe-do-delete)
  (define paths (fe-operation-targets))
  (when (not (null? paths))
    (fm-prompt! 'confirm (string-append "Permanently delete " (fe-operation-count paths) " item(s)? (y/N) ") ""
                (lambda (confirmed?)
                  (when confirmed?
                    (with-handler
                      (lambda (err) (set-warning! (string-append "delete failed: " (error-object-message err))))
                      (begin
                        (for-each fm-delete! paths)
                        (set! *fe-marked* '())
                        (fe-remove-yanked-paths! paths)
                        (fe-prune-bookmarks!)
                        (fe-reload!)))))))
  event-result/consume)

;; ── Component lifecycle ────────────────────────────────────────

(define (fe-show-help)
  (set! *fe-help-visible?* #t)
  event-result/consume)

(define (fe-run-action action)
  (cond [(string=? action "quit") (file-explorer-close) event-result/close]
        [(string=? action "down") (fe-do-down)]
        [(string=? action "up") (fe-do-up)]
        [(string=? action "open") (fe-do-open)]
        [(string=? action "open-normal") (fe-do-open)]
        [(string=? action "open-close") (fe-do-open)]
        [(string=? action "open-vsplit") (fe-do-open-vsplit)]
        [(string=? action "open-hsplit") (fe-do-open-hsplit)]
        [(string=? action "parent") (fe-do-parent)]
        [(string=? action "mark") (fe-do-mark)]
        [(string=? action "copy") (fe-do-copy)]
        [(string=? action "copy-absolute") (fe-do-copy-absolute)]
        [(string=? action "copy-relative") (fe-do-copy-relative)]
        [(string=? action "copy-filename") (fe-do-copy-filename)]
        [(string=? action "copy-register") (fe-do-copy-register)]
        [(string=? action "bookmarks") (fe-do-bookmarks)]
        [(string=? action "move") (fe-do-move)]
        [(string=? action "paste") (fe-do-paste)]
        [(string=? action "paste-force") (fe-do-paste-force)]
        [(string=? action "unyank") (fe-do-unyank)]
        [(string=? action "trash") (fe-do-trash)]
        [(string=? action "delete") (fe-do-delete)]
        [(string=? action "rename") (fe-do-rename)]
        [(string=? action "create-file") (fe-do-create-file)]
        [(string=? action "create-dir") (fe-do-create-dir)]
        [(string=? action "toggle-hidden") (fe-do-toggle-hidden)]
        [(string=? action "filter") (fe-do-filter)]
        [(string=? action "find") (fe-do-find)]
        [(string=? action "find-next") (fe-do-find-next)]
        [(string=? action "find-previous") (fe-do-find-previous)]
        [(string=? action "sort") (fe-do-sort)]
        [(string=? action "refresh") (fe-do-refresh)]
        [(string=? action "help") (fe-show-help)]
        [else event-result/consume]))

(define (fe-handle-mapped-key event)
  (define result (fm-key-step (fe-config-ref 'keybindings) *fe-key-prefix* event))
  (define kind (fm-key-result-kind result))
  (define value (fm-key-result-value result))
  (cond [(equal? kind 'action)
         (set! *fe-key-prefix* "")
         (fe-run-action value)]
        [(equal? kind 'prefix)
         (set! *fe-key-prefix* value)
         event-result/consume]
        [(equal? kind 'cancel)
         (set! *fe-key-prefix* "")
         event-result/consume]
        [else
         (when (and (not (string=? *fe-key-prefix* ""))
                    (not (fm-which-key-active? (fe-config-ref 'keybindings)
                                               *fe-key-prefix*)))
           (set-warning! (string-append "unknown key sequence: " value)))
         (set! *fe-key-prefix* "")
         event-result/consume]))

(define (fe-handle-event state event)
  (cond
    [(and *fe-help-visible?* (key-event-escape? event))
     (set! *fe-help-visible?* #f)
     event-result/consume]
    [*fe-help-visible?*
     (set! *fe-help-visible?* #f)
     (fe-handle-mapped-key event)]
    [(key-event-escape? event)
     (if (equal? *fe-pending-action* 'filter)
         (begin
           (fe-update-filter! *fe-filter-before-input*)
           (set! *fe-pending-action* #f))
         (begin
           (set! *fe-pending-action* #f)
           (set! *fe-key-prefix* "")
           (when (not (null? *fe-marked*))
             (set! *fe-marked* '()))))
     (set! *fe-copy-register* #\+)
     event-result/consume]
    [(equal? *fe-pending-action* 'filter) (fe-do-filter-key event)]
    [(equal? *fe-pending-action* 'sort) (fe-do-sort-key event)]
    [(equal? *fe-pending-action* 'copy-register) (fe-do-copy-register-key event)]
    [else (fe-handle-mapped-key event)]))

(define (file-explorer-open)
  (when *fe-active* (file-explorer-close))
  (set! *fe-active* #t)
  (set! *fe-filter-query* "")
  (set! *fe-filter-before-input* "")
  (set! *fe-find-query* "")
  (set! *fe-pending-action* #f)
  (set! *fe-key-prefix* "")
  (set! *fe-help-visible?* #f)
  (set! *fe-copy-register* #\+)
  (set! *fe-bookmarks* (fe-bookmarks-load))
  (fe-prune-bookmarks!)
  (set! *fe-workspace-root* (helix-find-workspace))
  (define current-file (with-handler (lambda (_) #f) (cx->current-file)))
  (fe-load-directory! (if current-file (fe-parent-dir current-file) *fe-workspace-root*))
  (when current-file (fe-select-entry! current-file))
  (push-component! (new-component! "file-explorer" (hash) fe-render
                                  (hash "handle_event" fe-handle-event))))

(define (file-explorer-close)
  (set! *fe-active* #f)
  (set! *fe-help-visible?* #f)
  (pop-last-component-by-name! "file-explorer"))
