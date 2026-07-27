(require "helix/misc.scm")

(provide fe-take fe-drop
         fe-base-name fe-parent-dir fe-read-dir-names fe-filter-entries fe-sort-entries fe-format-size
         fe-file-ext fe-is-text-ext? fe-read-preview fe-preview-footer fe-clear-preview-footer-cache!
         fe-display-width fe-fit-text
         fe-calc-layout fe-calc-col-widths
         BORDER-H BORDER-V BORDER-TL BORDER-TR BORDER-BL BORDER-BR
         BORDER-LT BORDER-RT BORDER-TC border-h)

(define (fe-take lst n)
  (if (or (null? lst) (<= n 0)) '() (cons (car lst) (fe-take (cdr lst) (- n 1)))))

(define (fe-drop lst n)
  (if (or (null? lst) (<= n 0)) lst (fe-drop (cdr lst) (- n 1))))

(define (fe-base-name path) (file-name path))
(define (fe-parent-dir path) (parent-name path))

(define (fe-read-dir path)
  (with-handler (lambda (_) '()) (read-dir path)))

(define *fe-preview-footer-cache* (hash))

(define (fe-capture-output program args)
  (with-handler
    (lambda (_) #f)
    (let ([proc (~> (command program args) with-stdout-piped spawn-process)])
      (and (Ok? proc)
           (trim (read-port-to-string (child-stdout (Ok->value proc))))))))

(define (fe-nonempty-strings values)
  (filter (lambda (value) (not (string=? value ""))) values))

(define (fe-unix-permissions path)
  (define raw (fe-capture-output "ls" (list "-ld" path)))
  (if raw
      (let ([parts (fe-nonempty-strings (split-many raw " "))])
        (if (>= (length parts) 4)
            (string-append (car parts) " " (list-ref parts 2) ":" (list-ref parts 3))
            (if (null? parts) "Mode: unknown" (car parts))))
      "Mode: unknown"))

(define (fe-stat-permissions path)
  (cond
    [(equal? (current-os!) "windows")
     (let ([rights (fe-capture-output
                     "powershell.exe"
                     (list "-NoProfile" "-Command"
                           "$rights = ((Get-Acl -LiteralPath $args[0]).Access | ForEach-Object { $_.FileSystemRights } | Select-Object -Unique) -join ','; $rights"
                           path))])
       (string-append "ACL: " (or rights "unknown")))]
    [else
     (fe-unix-permissions path)]))

(define (fe-preview-footer path)
  (if (hash-contains? *fe-preview-footer-cache* path)
      (hash-get *fe-preview-footer-cache* path)
      (let ([size (if (is-dir? path)
                      (string-append (int->string (length (fe-read-dir path))) " items")
                      (fe-format-size path))])
        (define footer (string-append " " (fe-stat-permissions path) "  " size " "))
        (set! *fe-preview-footer-cache*
              (hash-insert *fe-preview-footer-cache* path footer))
        footer)))

(define (fe-clear-preview-footer-cache!)
  (set! *fe-preview-footer-cache* (hash)))

(define (fe-dotfile? name)
  (and (> (string-length name) 0) (char=? (string-ref name 0) #\.)))

(define (fe-sort-files entries)
  (define dirs (sort (filter is-dir? entries) string<?))
  (define files (sort (filter (lambda (p) (not (is-dir? p))) entries) string<?))
  (append dirs files))

(define (fe-read-dir-names path show-hidden?)
  (define entries (fe-read-dir path))
  (fe-sort-files
    (filter (lambda (p)
              (let ([name (fe-base-name p)])
                (or show-hidden? (not (fe-dotfile? name)))))
            entries)))

(define (fe-filter-entries entries query)
  (if (string=? query "")
      entries
      (let ([needle (string-downcase query)])
        (filter (lambda (path)
                  (string-contains? (string-downcase (fe-base-name path)) needle))
                entries))))

(define (fe-entry-size path)
  (define meta (with-handler (lambda (_) #f) (file-metadata path)))
  (if meta (fs-metadata-len meta) 0))

(define (fe-size-cache entries)
  (if (null? entries)
      (hash)
      (hash-insert (fe-size-cache (cdr entries)) (car entries) (fe-entry-size (car entries)))))

(define (fe-sort-entries entries mode reverse?)
  (define sizes (if (equal? mode 'size) (fe-size-cache entries) (hash)))
  (define (compare-text left right)
    (if reverse?
        (string<? right left)
        (string<? left right)))
  (define (compare-size left right)
    (if reverse?
        (> right left)
        (< left right)))
  (define (compare-files left right)
    (cond [(and (is-dir? left) (not (is-dir? right))) #t]
          [(and (not (is-dir? left)) (is-dir? right)) #f]
          [(equal? mode 'extension)
           (let ([left-ext (fe-file-ext left)] [right-ext (fe-file-ext right)])
             (if (string=? left-ext right-ext)
                 (compare-text (fe-base-name left) (fe-base-name right))
                 (compare-text left-ext right-ext)))]
          [(equal? mode 'size)
           (let ([left-size (hash-get sizes left)] [right-size (hash-get sizes right)])
             (if (= left-size right-size)
                 (compare-text (fe-base-name left) (fe-base-name right))
                 (compare-size left-size right-size)))]
          [else (compare-text (fe-base-name left) (fe-base-name right))]))
  (sort entries compare-files))

(define (fe-format-size path)
  (define meta (with-handler (lambda (_) #f) (file-metadata path)))
  (if meta
      (let ([len (fs-metadata-len meta)])
        (cond [(< len 1024)    (string-append (int->string len) " B")]
              [(< len 1048576) (string-append (int->string (quotient len 1024)) " KiB")]
              [else            (string-append (int->string (quotient len 1048576)) " MiB")]))
      ""))

(define (fe-file-ext path)
  (define parts (split-many path "."))
  (if (> (length parts) 1)
      (list-ref parts (- (length parts) 1))
      ""))

(define (fe-is-text-ext? path)
  (define text-exts '(
    "txt" "md" "rs" "py" "js" "ts" "tsx" "jsx" "css"
    "html" "json" "toml" "yaml" "yml" "lua" "scm"
    "c" "h" "cpp" "hpp" "java" "go" "rb" "sh" "zsh"
    "bash" "fish" "el" "ex" "exs" "hs" "scala" "kt"
    "swift" "zig" "clj" "cljs" "dart" "svelte" "vue"
    "sass" "scss" "less" "ps1" "tf" "sql" "r" "jl"
    "nix" "prisma" "php" "pl" "diff" "vim" "org"
    "lock" "toml" "xml" "conf" "ini" "cfg"))
  (define ext (fe-file-ext path))
  (define (fe-member value values)
    (cond [(null? values) #f]
          [(equal? value (car values)) #t]
          [else (fe-member value (cdr values))]))
  (fe-member ext text-exts))

(define (fe-read-preview path max-lines max-width)
  (cond
    [(is-dir? path)
     (define children (fe-read-dir-names path #t))
     (fe-take children (min max-lines (length children)))]
    [(fe-is-text-ext? path)
     (with-handler
       (lambda (_) (list (string-append "  [" (fe-format-size path) "]")))
       (define content (with-handler
                         (lambda (_) "")
                         (read-port-to-string (open-input-file path))))
       (define lines (split-many content "\n"))
       (define display-lines (fe-take lines (min max-lines (length lines))))
       (map (lambda (line) (fe-fit-text line max-width)) display-lines))]
    [else (list (string-append "  [" (fe-format-size path) "]"))]))

(define (fe-char-width ch)
  (define code (char->integer ch))
  (cond
    ;; Combining marks, variation selectors, and joiners do not occupy a cell.
    [(or (and (>= code #x0300) (<= code #x036f))
         (and (>= code #x1ab0) (<= code #x1aff))
         (and (>= code #x1dc0) (<= code #x1dff))
         (and (>= code #x200b) (<= code #x200d))
         (and (>= code #x20d0) (<= code #x20ff))
         (and (>= code #xfe00) (<= code #xfe0f))
         (and (>= code #x1f3fb) (<= code #x1f3ff))
         (and (>= code #xfe20) (<= code #xfe2f)))
     0]
    ;; East Asian wide/full-width characters and common terminal emoji ranges.
    [(or (and (>= code #x1100) (<= code #x115f))
         (= code #x2329)
         (= code #x232a)
         (and (>= code #x2e80) (<= code #xa4cf))
         (and (>= code #xac00) (<= code #xd7a3))
         (and (>= code #xf900) (<= code #xfaff))
         (and (>= code #xfe10) (<= code #xfe19))
         (and (>= code #xfe30) (<= code #xfe6f))
         (and (>= code #xff00) (<= code #xff60))
         (and (>= code #xffe0) (<= code #xffe6))
         (and (>= code #x1f300) (<= code #x1faff))
         (and (>= code #x20000) (<= code #x3fffd)))
     2]
    [else 1]))

(define (fe-display-width text)
  (let loop ([index 0] [width 0])
    (if (>= index (string-length text))
        width
        (loop (+ index 1) (+ width (fe-char-width (string-ref text index)))))))

(define (fe-fit-text text width)
  (cond [(<= width 0) ""]
        [(<= (fe-display-width text) width) text]
        [(= width 1) "…"]
        [else
         (let loop ([index 0] [used 0])
           (if (or (>= index (string-length text))
                   (> (+ used (fe-char-width (string-ref text index))) (- width 1)))
               (string-append (substring text 0 index) "…")
               (loop (+ index 1)
                     (+ used (fe-char-width (string-ref text index))))))]))

(define (fe-calc-layout w h width-pct height-pct)
  (let* ([box-w (min (max (quotient (* w width-pct) 100) 40) 120)]
         [box-h (min (max (quotient (* h height-pct) 100) 10) (- h 2))]
         [box-x (quotient (- w box-w) 2)]
         [box-y (quotient (- h box-h) 2)])
    (list box-x box-y box-w box-h)))

(define (fe-calc-col-widths inner-w ratios)
  (define total (apply + ratios))
  (define avail (- inner-w 2))
  (define left (quotient (* avail (list-ref ratios 0)) total))
  (define middle (quotient (* avail (list-ref ratios 1)) total))
  (define right (- avail left middle))
  (list left middle right))

(define BORDER-H  "─")
(define BORDER-V  "│")
(define BORDER-TL "╭")
(define BORDER-TR "╮")
(define BORDER-BL "╰")
(define BORDER-BR "╯")
(define BORDER-LT "├")
(define BORDER-RT "┤")
(define BORDER-TC "┬")

(define (border-h n)
  (if (<= n 0) "" (string-append BORDER-H (border-h (- n 1)))))
