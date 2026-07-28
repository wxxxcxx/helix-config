(require "helix/components.scm")
(require "helix/misc.scm")
(require "helix/editor.scm")
(require (only-in "helix/static.scm" cx->current-file))
(require (prefix-in helix. "helix/commands.scm"))
(require "cogs/glyph/glyph.scm")
(require (only-in "cogs/indicators/style.scm" make-style))
(require (only-in "cogs/statusline-palette.scm" major-bg))
(require "cogs/file-manager/files.scm")
(require "cogs/file-manager/actions.scm")
(require "cogs/file-manager/modal.scm")
(require "cogs/file-manager/keymap.scm")
(require "cogs/file-manager/which-key.scm")

(provide file-tree-init file-tree-open file-tree-close file-tree-configure!)

(struct FileTreeState ())

(define *ft-active* #f)
(define *ft-focused?* #f)
(define *ft-root* "")
(define *ft-workspace-root* "")
(define *ft-expanded* '())
(define *ft-rows* '())
(define *ft-selected* 0)
(define *ft-scroll* 0)
(define *ft-content-height* 1)
(define *ft-side* 'left)
(define *ft-width* 38)
(define *ft-hide-on-open?* #f)
(define *ft-show-hidden* #f)
(define *ft-marked* '())
(define *ft-clipboard* '())
(define *ft-clipboard-mode* #f)
(define *ft-git-status* (hash))
(define *ft-key-prefix* "")
(define *ft-help-visible?* #f)
(define *ft-pending-action* #f)
(define *ft-copy-register* #\+)
(define *ft-root-back* '())
(define *ft-root-forward* '())
(define *ft-root-views* (hash))

(define *ft-keybindings*
  (hash
    "q" '("quit" "Close file tree")
    "k" '("up" "Previous entry")
    "up" '("up" "Previous entry")
    "j" '("down" "Next entry")
    "down" '("down" "Next entry")
    "l" '("open" "Open selected entry")
    "enter" '("open" "Open selected entry")
    "h" '("collapse" "Collapse or select parent")
    "H" '("collapse-parent" "Collapse parent directory")
    "space" '("mark" "Mark entry")
    "\"" '("copy-register" "Select copy register")
    "m" '("move" "Stage filesystem move")
    "Y" '("unyank" "Clear staged operation")
    "X" '("unyank" "Clear staged operation")
    "d" '("trash" "Move to trash")
    "D" '("delete" "Delete permanently")
    "R" '("rename" "Rename")
    "." '("toggle-hidden" "Toggle hidden files")
    "r" '("refresh" "Refresh")
    "A-L" '("root-selected" "Selected directory as root")
    "A-H" '("root-parent" "Parent directory as root")
    "?" '("help" "Show key bindings")
    "o" (list
          (hash
            "o" '("open-normal" "Open")
            "v" '("open-vsplit" "Open in vertical split")
            "h" '("open-hsplit" "Open in horizontal split")
            "c" '("open-close" "Open and close tree"))
          "Open")
    "y" (list
          (hash
            "y" '("copy" "Stage filesystem copy")
            "a" '("copy-absolute" "Copy absolute path")
            "r" '("copy-relative" "Copy relative path")
            "n" '("copy-filename" "Copy filename"))
          "Yank")
    "p" (list
          (hash
            "p" '("paste" "Paste")
            "!" '("paste-force" "Paste and overwrite"))
          "Paste")
    "c" (list
          (hash
            "f" '("create-file" "Create file")
            "d" '("create-dir" "Create directory"))
          "Create")
    "t" (list
          (hash
            "h" '("toggle-hidden" "Toggle hidden files")
            "f" '("follow" "Follow current file"))
          "Toggle")
    "g" (list
          (hash
            "r" '("refresh" "Refresh")
            "s" '("root-selected" "Selected directory as root")
            "p" '("root-parent" "Parent directory as root")
            "w" '("root-workspace" "Workspace root")
            "f" '("root-file" "Current file directory")
            "[" '("root-back" "Previous root")
            "]" '("root-forward" "Next root")
            "/" '("root-prompt" "Enter root path"))
          "Goto / Action")))

(define (file-tree-configure! #:side [side #f] #:width [width #f]
                             #:hide-on-open [hide-on-open 'unset]
                             #:key [keybindings #f])
  (when side
    (unless (or (equal? side 'left) (equal? side 'right))
      (error! "file-tree: side must be 'left or 'right"))
    (set! *ft-side* side))
  (when width
    (set! *ft-width* (max 24 width)))
  (unless (equal? hide-on-open 'unset)
    (unless (boolean? hide-on-open)
      (error! "file-tree: hide-on-open must be a boolean"))
    (set! *ft-hide-on-open?* hide-on-open))
  (when keybindings
    (set! *ft-keybindings* (fm-keymap-merge *ft-keybindings* keybindings))))

(define (ft-apply-editor-clipping! width)
  (if (equal? *ft-side* 'right)
      (begin
        (set-editor-clip-left! 0)
        (set-editor-clip-right! width))
      (begin
        (set-editor-clip-left! width)
        (set-editor-clip-right! 0))))

(define (ft-clear-editor-clipping!)
  (set-editor-clip-left! 0)
  (set-editor-clip-right! 0))

(define (ft-member? value values)
  (cond [(null? values) #f]
        [(equal? value (car values)) #t]
        [else (ft-member? value (cdr values))]))

(define (ft-add value values)
  (if (ft-member? value values) values (cons value values)))

(define (ft-remove value values)
  (cond [(null? values) '()]
        [(equal? value (car values)) (cdr values)]
        [else (cons (car values) (ft-remove value (cdr values)))]))

(define (ft-append left right)
  (if (null? left) right (cons (car left) (ft-append (cdr left) right))))

(define (ft-flatten lists)
  (if (null? lists) '() (ft-append (car lists) (ft-flatten (cdr lists)))))

(define (ft-replace value replacement values)
  (cond [(null? values) '()]
        [(equal? value (car values)) (cons replacement (ft-replace value replacement (cdr values)))]
        [else (cons (car values) (ft-replace value replacement (cdr values)))]))

(define (ft-children path)
  (fe-sort-entries (fe-read-dir-names path *ft-show-hidden*) 'name #f))

(define (ft-node-rows path depth)
  (define row (list depth path))
  (if (and (is-dir? path) (ft-member? path *ft-expanded*))
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
  (define start (if (is-dir? path) path (fe-parent-dir path)))
  (let loop ([current start])
    (when (and (not (string=? current ""))
               (not (string=? current (fe-parent-dir current))))
      (set! *ft-expanded* (ft-add current *ft-expanded*))
      (unless (string=? current *ft-root*)
        (loop (fe-parent-dir current)))))
  (set! *ft-expanded* (ft-add *ft-root* *ft-expanded*)))

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
               [(string=? current (fe-parent-dir current)) #f]
               [else (loop (fe-parent-dir current))]))))

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
  (set! *ft-marked* '())
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
  (and selected (if (is-dir? selected) selected (fe-parent-dir selected))))

(define (ft-current-file-root)
  (define current (ft-current-file))
  (and current (if (is-dir? current) current (fe-parent-dir current))))

(define (ft-parent-root)
  (define parent (fe-parent-dir *ft-root*))
  (define previous *ft-root*)
  (if (string=? parent *ft-root*)
      (set-warning! "file-tree root has no parent")
      (begin
        (ft-set-root! parent)
        (ft-follow-path! previous))))

(define (ft-prompt-root!)
  (fm-prompt! 'input "Root: " *ft-root*
              (lambda (path) (ft-set-root! path))))

(define (ft-git-output)
  (with-handler
    (lambda (_) "")
    (let ([proc (~> (command "git" (list "-C" *ft-root* "status" "--porcelain=v1"))
                     with-stdout-piped
                     with-stderr-piped
                     spawn-process)])
      (if (Ok? proc)
          (let ([child (Ok->value proc)])
            (define output (read-port-to-string (child-stdout child)))
            (read-port-to-string (child-stderr child))
            output)
          ""))))

(define (ft-git-record-status record)
  (if (< (string-length record) 4)
      #f
      (let ([code (substring record 0 2)] [path (substring record 3 (string-length record))])
        (if (string=? path "") #f (list code path)))))

(define *ft-git-kind-order* (list 'conflict 'deleted 'renamed 'modified 'added))

(define (ft-normalize-git-kinds kinds)
  (filter (lambda (kind) (ft-member? kind kinds)) *ft-git-kind-order*))

(define (ft-merge-git-kinds left right)
  (ft-normalize-git-kinds (append left right)))

(define (ft-git-kinds-for-code code)
  (cond [(string-contains? code "?") (list 'added)]
        [(string-contains? code "U") (list 'conflict)]
        [else
         (define kinds '())
         (when (string-contains? code "D") (set! kinds (ft-add 'deleted kinds)))
         (when (string-contains? code "R") (set! kinds (ft-add 'renamed kinds)))
         (when (string-contains? code "M") (set! kinds (ft-add 'modified kinds)))
         (when (string-contains? code "A") (set! kinds (ft-add 'added kinds)))
         (if (null? kinds) (list 'modified) (ft-normalize-git-kinds kinds))]))

(define (ft-git-status-for-path code path table)
  (define current path)
  (define result table)
  (define kinds (ft-git-kinds-for-code code))
  (let loop ()
    (when (not (string=? current ""))
      (define existing (or (hash-try-get result current) '()))
      (set! result (hash-insert result current (ft-merge-git-kinds existing kinds))))
    (when (and (not (string=? current *ft-root*))
               (not (string=? current (fe-parent-dir current))))
      (set! current (fe-parent-dir current))
      (loop)))
  result)

(define (ft-refresh-git!)
  (define records (split-many (ft-git-output) "\n"))
  (set! *ft-git-status*
        (let loop ([remaining records] [statuses (hash)])
          (if (null? remaining)
              statuses
              (let ([entry (ft-git-record-status (car remaining))])
                (if entry
                    (loop (cdr remaining)
                          (ft-git-status-for-path (car entry)
                                                  (string-append *ft-root* (path-separator) (list-ref entry 1))
                                                  statuses))
                    (loop (cdr remaining) statuses)))))))

(define (ft-path-git-kinds path)
  (if (string=? path *ft-root*)
      '()
      (or (hash-try-get *ft-git-status* path) '())))

(define (ft-git-icon kind)
  (cond [(equal? kind 'added) (glyph "cod-diff_added")]
        [(equal? kind 'deleted) (glyph "cod-diff_removed")]
        [(equal? kind 'renamed) (glyph "cod-diff_renamed")]
        [(equal? kind 'conflict) (glyph "cod-warning")]
        [(equal? kind 'modified) (glyph "cod-diff_modified")]
        [else ""]))

(define (ft-git-style kind)
  (make-style
    (cond [(equal? kind 'added) "#A3BE8C"]
          [(equal? kind 'deleted) "#BF616A"]
          [(equal? kind 'renamed) "#88C0D0"]
          [(equal? kind 'conflict) "#BF616A"]
          [else "#EBCB8B"])
    #f #t))

(define (ft-style-on-row foreground row-style)
  (define bg (style->bg row-style))
  (if bg (style-bg foreground bg) foreground))

(define (ft-operation-targets)
  (define current (ft-selected-path))
  (if (null? *ft-marked*)
      (if (and current (not (string=? current *ft-root*))) (list current) '())
      (filter (lambda (path) (not (string=? path *ft-root*))) *ft-marked*)))

(define (ft-operation-directory)
  (define current (ft-selected-path))
  (if (and current (is-dir? current)) current (and current (fe-parent-dir current))))

(define (ft-operation-count paths) (int->string (length paths)))

(define (ft-clear-yank!)
  (set! *ft-clipboard* '())
  (set! *ft-clipboard-mode* #f))

(define (ft-reload!)
  (define selected (ft-selected-path))
  (set! *ft-marked* (filter path-exists? *ft-marked*))
  (ft-refresh-git!)
  (ft-rebuild!)
  (when selected (ft-select-path! selected)))

(define (ft-do-mark)
  (define path (ft-selected-path))
  (when (and path (not (string=? path *ft-root*)))
    (set! *ft-marked* (if (ft-member? path *ft-marked*)
                          (ft-remove path *ft-marked*)
                          (cons path *ft-marked*)))
    (set! *ft-selected* (min (+ *ft-selected* 1) (max 0 (- (length *ft-rows*) 1))))
    (ft-scroll-to-visible!))
  event-result/consume)

(define (ft-stage-operation! mode)
  (define paths (ft-operation-targets))
  (when (not (null? paths))
    (set! *ft-clipboard* paths)
    (set! *ft-clipboard-mode* mode)
    (set! *ft-marked* '()))
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
      (set-register! *ft-copy-register* (list value))
      (set-warning! (string-append "copied " label ": " value))))
  (set! *ft-copy-register* #\+)
  event-result/consume)

(define (ft-copy-value! kind)
  (define path (ft-selected-path))
  (if path
      (ft-copy-selected!
        (cond [(equal? kind 'relative) (ft-relative-path path)]
              [(equal? kind 'filename) (fe-entry-label path)]
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
        (set! *ft-copy-register* register)
        (set-warning! (string-append "register " (string register) ": ya=absolute yr=relative yn=filename")))
      (set-warning! "register: enter a register name"))
  event-result/consume)

(define (ft-paste! force?)
  (define destination (ft-operation-directory))
  (when (and destination *ft-clipboard-mode* (not (null? *ft-clipboard*)))
    (with-handler
      (lambda (err) (set-warning! (string-append "paste failed: " (error-object-message err))))
      (begin
        (fm-paste! *ft-clipboard-mode* *ft-clipboard* destination force?)
        (when (equal? *ft-clipboard-mode* 'move) (ft-clear-yank!))
        (ft-reload!))))
  event-result/consume)

(define (ft-rename-paths! paths)
  (when (not (null? paths))
    (define path (car paths))
    (define old-name (fe-entry-label path))
    (fm-prompt! 'input "Rename: " old-name
                (lambda (new-name)
                  (when (and (not (string=? new-name old-name)) (fm-valid-name? new-name))
                    (with-handler
                      (lambda (err) (set-warning! (string-append "rename failed: " (error-object-message err))))
                      (let ([target (fm-rename! path new-name)])
                        (set! *ft-marked* (ft-replace path target *ft-marked*))
                        (set! *ft-clipboard* (ft-replace path target *ft-clipboard*))
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
                      (set! *ft-marked* '())
                      (ft-clear-yank!)
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
                      (set! *ft-marked* '())
                      (ft-clear-yank!)
                      (ft-reload!))))))
  event-result/consume)

(define (ft-indent depth)
  (if (<= depth 0) "" (string-append "  " (ft-indent (- depth 1)))))

(define (ft-directory-icon root? expanded?)
  (glyph
    (cond [root? (if expanded? "cod-root_folder_opened" "cod-root_folder")]
          [expanded? "cod-folder_opened"]
          [else "cod-folder"])))

(define (ft-row-prefix row)
  (define path (ft-row-path row))
  (define depth (ft-row-depth row))
  (define root? (string=? path *ft-root*))
  (define dir? (is-dir? path))
  (define expanded? (and dir? (ft-member? path *ft-expanded*)))
  (string-append (if (ft-member? path *ft-marked*) "* " "  ")
                 (ft-indent depth)
                 (if dir? (string-append (ft-directory-icon root? expanded?) " ")
                     (string-append (glyph-icon (fe-entry-label path)) " "))))

(define (ft-render-clipboard-status content-x status-y content-w frame)
  (define base-style (theme-scope-ref "ui.statusline"))
  (frame-set-string! frame content-x status-y
                     (make-string content-w #\space) base-style)
  (when (and *ft-clipboard-mode* (not (null? *ft-clipboard*)))
    (define copy? (equal? *ft-clipboard-mode* 'copy))
    (define indicator
      (string-append " " (glyph (if copy? "cod-copy" "cod-arrow_swap")) " "
                     (if copy? "copy " "cut ")
                     (int->string (length *ft-clipboard*))))
    (define indicator-style
      (theme-scope-ref (if copy? "ui.statusline.insert" "ui.statusline.select")))
    (frame-set-string! frame content-x status-y
                       (fe-fit-text indicator content-w) indicator-style)))

(define (ft-render state rect frame)
  (define area-w (area-width rect))
  (define area-h (area-height rect))
  (define width (min *ft-width* (max 1 (- area-w 2))))
  (define height area-h)
  (define x (if (equal? *ft-side* 'right) (- area-w width) 0))
  (define y 0)
  (ft-apply-editor-clipping! width)
  (define has-divider? (> width 1))
  (define content-x (if (and has-divider? (equal? *ft-side* 'right)) (+ x 1) x))
  (define content-w (if has-divider? (- width 1) width))
  (define divider-x (if (equal? *ft-side* 'right) x (+ x width -1)))
  (define content-h (max 1 (- height 2)))
  (define status-y (max y (- (+ y height) 2)))
  (set! *ft-content-height* content-h)
  (ft-scroll-to-visible!)
  (define bg (theme-scope-ref "ui.background"))
  (define text (theme-scope-ref "ui.text"))
  (define selected (if *ft-focused?*
                       (theme-scope-ref "ui.menu.selected")
                       (theme-scope-ref "ui.selection")))
  (define root-style
    (style-with-bold (make-style major-bg #f *ft-focused?*)))
  (define dir-style (theme-scope-ref "ui.text.info"))
  (define divider (theme-scope-ref "ui.window"))
  (buffer/clear-with frame (area x y width height) bg)
  (when has-divider?
    (do [(row 0 (+ row 1))] [(>= row height)]
      (frame-set-string! frame divider-x (+ y row) "│" divider)))
  (do [(row 0 (+ row 1))] [(>= row content-h)]
    (define index (+ *ft-scroll* row))
    (define row-y (+ y row))
    (define selected? (= index *ft-selected*))
    (define entry (and (< index (length *ft-rows*)) (list-ref *ft-rows* index)))
    (define path (and entry (ft-row-path entry)))
    (define root? (and path (string=? path *ft-root*)))
    (define style (if selected? selected text))
    (frame-set-string! frame content-x row-y (make-string content-w #\space) style)
    (when entry
      (define prefix (ft-row-prefix entry))
      (define prefix-w (fe-display-width prefix))
      (define git-kinds (ft-path-git-kinds path))
      (define git-kind (and (not (null? git-kinds)) (car git-kinds)))
      (define git-icon (ft-git-icon git-kind))
      (define git-w (fe-display-width git-icon))
      (define right-padding (if (> content-w 1) 1 0))
      (define label-w
        (max 0 (- content-w prefix-w right-padding git-w (if git-kind 1 0))))
      (define icon-style
        (ft-style-on-row
          (cond [root? root-style]
                [(is-dir? path) dir-style]
                [else text])
          style))
      (define name-style
        (ft-style-on-row
          (cond [root? root-style]
                [git-kind (ft-git-style git-kind)]
                [selected? selected]
                [(is-dir? path) dir-style]
                [else text])
          style))
      (frame-set-string! frame content-x row-y prefix icon-style)
      (frame-set-string! frame (+ content-x prefix-w) row-y
                         (fe-fit-text (fe-entry-label path) label-w) name-style)
      (when git-kind
        (frame-set-string! frame
                           (+ content-x (- content-w right-padding git-w))
                           row-y git-icon
                           (ft-style-on-row (ft-git-style git-kind) style)))))
  (ft-render-clipboard-status content-x status-y content-w frame)
  (if *ft-help-visible?*
      (fm-which-key-help-render! "File Tree" *ft-keybindings* rect frame)
      (fm-which-key-render! *ft-keybindings* *ft-key-prefix* rect frame)))

(define (ft-move! delta)
  (set! *ft-selected*
        (min (max 0 (+ *ft-selected* delta)) (max 0 (- (length *ft-rows*) 1))))
  (ft-scroll-to-visible!))

(define (ft-toggle-selected!)
  (define path (ft-selected-path))
  (when (and path (is-dir? path))
    (set! *ft-expanded*
          (if (ft-member? path *ft-expanded*)
              (ft-remove path *ft-expanded*)
              (ft-add path *ft-expanded*)))
    (ft-rebuild!)))

(define (ft-open-selected-as mode close-policy)
  (define path (ft-selected-path))
  (define close?
    (or (equal? close-policy 'always)
        (and (equal? close-policy 'configured) *ft-hide-on-open?*)))
  (cond [(not path) event-result/consume]
        [(is-dir? path) (ft-toggle-selected!) event-result/consume]
        [else
         (enqueue-thread-local-callback
           (lambda ()
             (cond [(equal? mode 'vsplit) (helix.vsplit path)]
                   [(equal? mode 'hsplit) (helix.hsplit path)]
                   [else (helix.open path)])))
         (if close?
             (begin (file-tree-close) event-result/close)
             (begin (set! *ft-focused?* #f) event-result/ignore))]))

(define (ft-open-selected) (ft-open-selected-as 'normal 'configured))
(define (ft-open-selected-normal) (ft-open-selected-as 'normal 'never))
(define (ft-open-selected-vsplit) (ft-open-selected-as 'vsplit 'never))
(define (ft-open-selected-hsplit) (ft-open-selected-as 'hsplit 'never))
(define (ft-open-selected-close) (ft-open-selected-as 'normal 'always))

(define (ft-parent)
  (define row (ft-selected-row))
  (define path (and row (ft-row-path row)))
  (cond [(and path (is-dir? path) (ft-member? path *ft-expanded*))
         (ft-toggle-selected!)]
        [path (ft-select-path! (fe-parent-dir path))])
  event-result/consume)

(define (ft-collapse-parent)
  (define path (ft-selected-path))
  (when (and path (not (string=? path *ft-root*)))
    (define parent (fe-parent-dir path))
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

(define (ft-run-action action)
  (cond [(string=? action "quit") (file-tree-close) event-result/close]
        [(string=? action "down") (ft-move! 1) event-result/consume]
        [(string=? action "up") (ft-move! -1) event-result/consume]
        [(string=? action "open") (ft-open-selected)]
        [(string=? action "open-normal") (ft-open-selected-normal)]
        [(string=? action "open-vsplit") (ft-open-selected-vsplit)]
        [(string=? action "open-hsplit") (ft-open-selected-hsplit)]
        [(string=? action "open-close") (ft-open-selected-close)]
        [(string=? action "collapse") (ft-parent)]
        [(string=? action "collapse-parent") (ft-collapse-parent)]
        [(string=? action "mark") (ft-do-mark)]
        [(string=? action "copy") (ft-stage-operation! 'copy)]
        [(string=? action "copy-absolute") (ft-copy-value! 'absolute)]
        [(string=? action "copy-relative") (ft-copy-value! 'relative)]
        [(string=? action "copy-filename") (ft-copy-value! 'filename)]
        [(string=? action "copy-register") (ft-select-copy-register)]
        [(string=? action "move") (ft-stage-operation! 'move)]
        [(string=? action "paste") (ft-paste! #f)]
        [(string=? action "paste-force") (ft-paste! #t)]
        [(string=? action "unyank") (ft-clear-yank!) event-result/consume]
        [(string=? action "trash") (ft-trash)]
        [(string=? action "delete") (ft-delete)]
        [(string=? action "rename") (ft-rename-paths! (ft-operation-targets)) event-result/consume]
        [(string=? action "create-file") (ft-create-kind #f)]
        [(string=? action "create-dir") (ft-create-kind #t)]
        [(string=? action "toggle-hidden") (ft-toggle-hidden)]
        [(string=? action "follow") (ft-follow-current)]
        [(string=? action "refresh") (ft-refresh)]
        [(string=? action "root-selected") (ft-set-root! (ft-selected-root)) event-result/consume]
        [(string=? action "root-parent") (ft-parent-root) event-result/consume]
        [(string=? action "root-workspace") (ft-set-root! *ft-workspace-root*) event-result/consume]
        [(string=? action "root-file") (ft-set-root! (ft-current-file-root)) event-result/consume]
        [(string=? action "root-back") (ft-root-back!) event-result/consume]
        [(string=? action "root-forward") (ft-root-forward!) event-result/consume]
        [(string=? action "root-prompt") (ft-prompt-root!) event-result/consume]
        [(string=? action "help") (ft-show-help)]
        [else event-result/consume]))

(define (ft-handle-mapped-key event)
  (define result (fm-key-step *ft-keybindings* *ft-key-prefix* event))
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
         (when (and (not (string=? *ft-key-prefix* ""))
                    (not (fm-which-key-active? *ft-keybindings* *ft-key-prefix*)))
           (set-warning! (string-append "unknown key sequence: " value)))
         (set! *ft-key-prefix* "")
         event-result/consume]))

(define (ft-handle-event state event)
  (cond
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
     (set! *ft-copy-register* #\+)
     (if (string=? *ft-key-prefix* "")
         (set! *ft-focused?* #f)
         (set! *ft-key-prefix* ""))
     event-result/consume]
    [else (ft-handle-mapped-key event)]))

(define (file-tree-open)
  (if *ft-active*
      (set! *ft-focused?* #t)
      (begin
        (set! *ft-active* #t)
        (set! *ft-focused?* #t)
        (set! *ft-root* "")
        (set! *ft-workspace-root* (helix-find-workspace))
        (set! *ft-key-prefix* "")
        (set! *ft-help-visible?* #f)
        (set! *ft-pending-action* #f)
        (set! *ft-copy-register* #\+)
        (set! *ft-root-back* '())
        (set! *ft-root-forward* '())
        (set! *ft-root-views* (hash))
        (set! *ft-expanded* '())
        (set! *ft-selected* 0)
        (set! *ft-scroll* 0)
        (set! *ft-show-hidden* #f)
        (set! *ft-marked* '())
        (ft-clear-yank!)
        (ft-apply-editor-clipping! *ft-width*)
        (ft-activate-root! *ft-workspace-root*)
        (enqueue-thread-local-callback
          (lambda ()
            (push-component!
              (new-component! "file-tree" (FileTreeState) ft-render
                              (hash "handle_event" ft-handle-event))))))))

(define (file-tree-close)
  (set! *ft-active* #f)
  (set! *ft-focused?* #f)
  (set! *ft-key-prefix* "")
  (set! *ft-help-visible?* #f)
  (set! *ft-pending-action* #f)
  (ft-clear-editor-clipping!)
  (pop-last-component-by-name! "file-tree"))

(define (file-tree-init)
  (register-hook 'document-focus-lost
                 (lambda (_) (ft-follow-current-file!)))
  (register-hook 'document-saved
                 (lambda (_) (when *ft-active* (ft-refresh-git!) (ft-rebuild!)))))
