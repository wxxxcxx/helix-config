(require "helix/components.scm")
(require "helix/misc.scm")
(require "helix/editor.scm")
(require (only-in "helix/static.scm" cx->current-file))
(require (prefix-in helix. "helix/commands.scm"))
(require "cogs/file-explorer/config.scm")
(require "cogs/file-explorer/files.scm")
(require "cogs/file-explorer/modal.scm")
(require "cogs/file-explorer/render.scm")

(provide file-explorer-configure! file-explorer-open file-explorer-close)

;; ── Explorer state ─────────────────────────────────────────────

(define *fe-active* #f)
(define *fe-path* "")
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
(define *fe-copy-register* #\+)

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
        [else #f]))

(define (fe-state-set! key value)
  (when (equal? key 'content-h)
    (set! *fe-content-h* value)))

(define fe-render
  (make-file-explorer-render fe-state-ref fe-state-set! fe-config-ref))

;; ── Key dispatch ───────────────────────────────────────────────

(define (fe-kb-string event)
  (define ch (key-event-char event))
  (cond [(key-event-down? event) "down"]
        [(key-event-up? event) "up"]
        [(key-event-enter? event) "enter"]
        [(key-event-tab? event) "tab"]
        [(key-event-escape? event) "escape"]
        [(char? ch) (string ch)]
        [else ""]))

(define (fe-match? action event)
  (define triggers (hash-try-get (fe-config-ref 'keybindings) action))
  (define event-str (fe-kb-string event))
  (define (fe-list-member value values)
    (cond [(null? values) #f]
          [(equal? value (car values)) #t]
          [else (fe-list-member value (cdr values))]))
  (cond [(not triggers) #f]
        [(string? triggers) (string=? triggers event-str)]
        [(list? triggers) (fe-list-member event-str triggers)]
        [else #f]))

;; ── Navigation ─────────────────────────────────────────────────

(define (fe-entry-index entries name)
  (let loop ([items entries] [index 0])
    (cond [(null? items) 0]
          [(string=? (fe-base-name (car items)) name) index]
          [else (loop (cdr items) (+ index 1))])))

(define (fe-path-index entries path)
  (let loop ([items entries] [index 0])
    (cond [(null? items) #f]
          [(string=? (car items) path) index]
          [else (loop (cdr items) (+ index 1))])))

(define (fe-parent-idx)
  (fe-entry-index *fe-parent-files* (fe-base-name *fe-path*)))

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
  (set! *fe-all-parent-files* (fe-read-dir-names (fe-parent-dir dir) (fe-show-hidden?)))
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

(define (fe-do-open)
  (define entry (fe-current-entry))
  (cond [(not entry) event-result/consume]
        [(is-dir? entry) (fe-enter-dir entry) event-result/consume]
        [(is-file? entry)
         (enqueue-thread-local-callback (lambda () (helix.open entry)))
         (file-explorer-close)
         event-result/consume]
        [else event-result/consume]))

(define (fe-do-parent)
  (define parent (fe-parent-dir *fe-path*))
  (if (equal? parent *fe-path*)
      event-result/consume
      (let ([child-name (fe-base-name *fe-path*)])
        (fe-enter-dir parent)
        (set! *fe-cursor-row* (fe-entry-index *fe-files* child-name))
        (vector-set! *fe-col-scroll* 1
                     (fe-scroll-to-visible (vector-ref *fe-col-scroll* 1) *fe-cursor-row* (length *fe-files*)))
        event-result/consume)))

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
  (fe-prompt! 'input "Find: " *fe-find-query*
              (lambda (query)
                (set! *fe-find-query* query)
                (fe-find! 1)))
  event-result/consume)

(define (fe-do-find-prev)
  (fe-prompt! 'input "Find: " *fe-find-query*
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

(define (fe-run! program args)
  (let ([proc (~> (command program args) with-stdout-piped with-stderr-piped spawn-process)])
    (if (Ok? proc)
        (let ([stderr (trim (read-port-to-string (child-stderr (Ok->value proc))))])
          (when (not (string=? stderr "")) (error stderr)))
        (error (string-append program ": could not spawn process")))))

(define (fe-target-path path)
  (string-append *fe-path* (path-separator) (fe-base-name path)))

(define (fe-clear-yank!)
  (set! *fe-clipboard* '())
  (set! *fe-clipboard-mode* #f))

(define (fe-remove-yanked-paths! paths)
  (for-each (lambda (path) (set! *fe-clipboard* (fe-remove path *fe-clipboard*))) paths)
  (when (null? *fe-clipboard*) (set! *fe-clipboard-mode* #f)))

(define (fe-reconcile-renamed-path! old-path new-path)
  (set! *fe-marked* (fe-replace old-path new-path *fe-marked*))
  (set! *fe-clipboard* (fe-replace old-path new-path *fe-clipboard*)))

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
      (set-warning! "copy: no entry selected")))

(define (fe-do-copy-value-key event)
  (define key (fe-kb-string event))
  (set! *fe-pending-action* #f)
  (cond
    [(string=? key "c")
     (fe-copy-current! (fe-current-entry) "path")]
    [(string=? key "f")
     (let ([entry (fe-current-entry)])
       (if entry
           (fe-copy-current! (fe-base-name entry) "filename")
           (set-warning! "copy: no entry selected")))]
    [else (set-warning! "copy: c=path, f=filename")])
  (set! *fe-copy-register* #\+)
  event-result/consume)

(define (fe-do-copy-value)
  (set! *fe-pending-action* 'copy-value)
  (set-warning! "copy: c=path, f=filename")
  event-result/consume)

(define (fe-do-copy-register-key event)
  (define register (key-event-char event))
  (set! *fe-pending-action* #f)
  (if (char? register)
      (begin
        (set! *fe-copy-register* register)
        (set-warning! (string-append "register " (string register) ": c=path, f=filename")))
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
        (for-each
          (lambda (source)
            (define target (fe-target-path source))
            (when (and (path-exists? target) (not force?))
              (error (string-append "destination exists: " (fe-base-name target))))
            (unless (equal? source target)
              (when (and force? (path-exists? target)) (fe-run! "rm" (list "-rf" "--" target)))
              (if (equal? *fe-clipboard-mode* 'copy)
                  (fe-run! "cp" (list "-R" "--" source target))
                  (fe-run! "mv" (list "--" source target)))))
          *fe-clipboard*)
        (when (equal? *fe-clipboard-mode* 'move) (fe-clear-yank!))
        (fe-reload!)))))

(define (fe-do-paste) (fe-paste! #f) event-result/consume)
(define (fe-do-paste-force) (fe-paste! #t) event-result/consume)
(define (fe-do-unyank) (fe-clear-yank!) event-result/consume)

(define (fe-valid-name? name)
  (and (> (string-length name) 0)
       (equal? name (fe-base-name name))
       (not (string=? name "."))
       (not (string=? name ".."))))

(define (fe-rename-paths! paths)
  (when (not (null? paths))
    (define entry (car paths))
    (define old-name (fe-base-name entry))
    (fe-prompt! 'input "Rename: " old-name
                (lambda (new-name)
                  (when (and (not (string=? new-name old-name)) (fe-valid-name? new-name))
                    (with-handler
                      (lambda (err) (set-warning! (string-append "rename failed: " (error-object-message err))))
                      (let ([target (string-append (fe-parent-dir entry) (path-separator) new-name)])
                        (when (path-exists? target) (error (string-append "already exists: " new-name)))
                        (fe-run! "mv" (list "--" entry target))
                        (fe-reconcile-renamed-path! entry target)
                        (fe-reload!))))
                  (fe-rename-paths! (cdr paths))))))

(define (fe-do-rename) (fe-rename-paths! (fe-operation-targets)) event-result/consume)

(define (fe-do-create)
  (fe-prompt! 'input "New (trailing / creates directory): " ""
              (lambda (name)
                (when (> (string-length name) 0)
                  (define target (string-append *fe-path* (path-separator) name))
                  (with-handler
                    (lambda (err) (set-warning! (string-append "create failed: " (error-object-message err))))
                    (begin
                      (when (path-exists? target) (error (string-append "already exists: " name)))
                      (if (ends-with? name (path-separator))
                          (fe-run! "mkdir" (list "-p" target))
                          (fe-run! "touch" (list "--" target)))
                      (fe-reload!))))))
  event-result/consume)

(define (fe-trash-path! path)
  (fe-run! "osascript"
           (list "-e" "on run argv\ntell application \"Finder\" to delete POSIX file (item 1 of argv)\nend run" path)))

(define (fe-do-trash)
  (define paths (fe-operation-targets))
  (when (not (null? paths))
    (fe-prompt! 'confirm (string-append "Move " (fe-operation-count paths) " item(s) to Trash? (y/N) ") ""
                (lambda (confirmed?)
                  (when confirmed?
                    (with-handler
                      (lambda (err) (set-warning! (string-append "trash failed: " (error-object-message err))))
                      (begin
                        (for-each fe-trash-path! paths)
                        (set! *fe-marked* '())
                        (fe-remove-yanked-paths! paths)
                        (fe-reload!)))))))
  event-result/consume)

(define (fe-do-delete)
  (define paths (fe-operation-targets))
  (when (not (null? paths))
    (fe-prompt! 'confirm (string-append "Permanently delete " (fe-operation-count paths) " item(s)? (y/N) ") ""
                (lambda (confirmed?)
                  (when confirmed?
                    (with-handler
                      (lambda (err) (set-warning! (string-append "delete failed: " (error-object-message err))))
                      (begin
                        (for-each (lambda (path) (fe-run! "rm" (list "-rf" "--" path))) paths)
                        (set! *fe-marked* '())
                        (fe-remove-yanked-paths! paths)
                        (fe-reload!)))))))
  event-result/consume)

;; ── Component lifecycle ────────────────────────────────────────

(define (fe-handle-event state event)
  (cond
    [(key-event-escape? event)
     (if (equal? *fe-pending-action* 'filter)
         (begin
           (fe-update-filter! *fe-filter-before-input*)
           (set! *fe-pending-action* #f))
         (begin
           (set! *fe-pending-action* #f)
           (when (not (null? *fe-marked*))
             (set! *fe-marked* '()))))
     (set! *fe-copy-register* #\+)
     event-result/consume]
    [(equal? *fe-pending-action* 'filter) (fe-do-filter-key event)]
    [(equal? *fe-pending-action* 'sort) (fe-do-sort-key event)]
    [(equal? *fe-pending-action* 'copy-value) (fe-do-copy-value-key event)]
    [(equal? *fe-pending-action* 'copy-register) (fe-do-copy-register-key event)]
    [(fe-match? "quit" event) (file-explorer-close) event-result/close]
    [(fe-match? "down" event) (fe-do-down)]
    [(fe-match? "up" event) (fe-do-up)]
    [(fe-match? "open" event) (fe-do-open)]
    [(fe-match? "parent" event) (fe-do-parent)]
    [(fe-match? "mark" event) (fe-do-mark)]
    [(fe-match? "copy" event) (fe-do-copy)]
    [(fe-match? "copy-value" event) (fe-do-copy-value)]
    [(fe-match? "copy-register" event) (fe-do-copy-register)]
    [(fe-match? "move" event) (fe-do-move)]
    [(fe-match? "paste" event) (fe-do-paste)]
    [(fe-match? "paste-force" event) (fe-do-paste-force)]
    [(fe-match? "unyank" event) (fe-do-unyank)]
    [(fe-match? "trash" event) (fe-do-trash)]
    [(fe-match? "delete" event) (fe-do-delete)]
    [(fe-match? "rename" event) (fe-do-rename)]
    [(fe-match? "create" event) (fe-do-create)]
    [(fe-match? "toggle-hidden" event) (fe-do-toggle-hidden)]
    [(fe-match? "filter" event) (fe-do-filter)]
    [(fe-match? "find" event) (fe-do-find)]
    [(fe-match? "find-next" event) (fe-do-find-next)]
    [(fe-match? "find-prev" event) (fe-do-find-prev)]
    [(fe-match? "find-previous" event) (fe-do-find-previous)]
    [(fe-match? "sort" event) (fe-do-sort)]
    [(fe-match? "refresh" event) (fe-do-refresh)]
    [else event-result/consume]))

(define (file-explorer-open)
  (when *fe-active* (file-explorer-close))
  (set! *fe-active* #t)
  (set! *fe-filter-query* "")
  (set! *fe-filter-before-input* "")
  (set! *fe-find-query* "")
  (set! *fe-pending-action* #f)
  (set! *fe-copy-register* #\+)
  (define current-file (with-handler (lambda (_) #f) (cx->current-file)))
  (fe-load-directory! (if current-file (fe-parent-dir current-file) (helix-find-workspace)))
  (when current-file (fe-select-entry! current-file))
  (push-component! (new-component! "file-explorer" (hash) fe-render
                                  (hash "handle_event" fe-handle-event))))

(define (file-explorer-close)
  (set! *fe-active* #f)
  (pop-last-component-by-name! "file-explorer"))
