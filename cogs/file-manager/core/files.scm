(require "helix/misc.scm")

(provide fm-take fm-drop
         fm-base-name fm-entry-label fm-path-label fm-parent-dir fm-read-dir-names
         fm-windows-drive-root? fm-windows-drives-root?
         fm-filter-entries fm-sort-entries fm-format-size
         fm-file-ext fm-is-text-ext? fm-read-preview fm-preview-footer fm-clear-preview-footer-cache!
         fm-display-width fm-fit-text
         fm-calc-layout fm-calc-col-widths
         BORDER-H BORDER-V BORDER-TL BORDER-TR BORDER-BL BORDER-BR
         BORDER-LT BORDER-RT BORDER-TC border-h)

(define (fm-take lst n)
  (if (or (null? lst) (<= n 0)) '() (cons (car lst) (fm-take (cdr lst) (- n 1)))))

(define (fm-drop lst n)
  (if (or (null? lst) (<= n 0)) lst (fm-drop (cdr lst) (- n 1))))

(define (fm-base-name path) (file-name path))
(define (fm-parent-dir path) (parent-name path))

(define (fm-windows-drives-root? path)
  (and (equal? (current-os!) "windows") (string=? path "")))

(define (fm-windows-drive-root? path)
  (and (equal? (current-os!) "windows")
       (>= (string-length path) 2)
       (char=? (string-ref path 1) #\:)
       (or (= (string-length path) 2)
           (and (= (string-length path) 3)
                (or (char=? (string-ref path 2) #\\)
                    (char=? (string-ref path 2) #\/))))))

(define (fm-entry-label path)
  (if (fm-windows-drive-root? path)
      (substring path 0 2)
      (fm-base-name path)))

(define (fm-path-label path)
  (if (fm-windows-drives-root? path) "Drives" path))

(define (fm-read-dir path)
  (with-handler (lambda (_) '()) (read-dir path)))

(define *fm-preview-footer-cache* (hash))

(define (fm-capture-output program args)
  (with-handler
    (lambda (_) #f)
    (let ([proc (~> (command program args) with-stdout-piped spawn-process)])
      (and (Ok? proc)
           (trim (read-port-to-string (child-stdout (Ok->value proc))))))))

(define (fm-windows-drive-paths)
  (define output
    (fm-capture-output
      "powershell.exe"
      (list "-NoProfile" "-Command"
            "Get-PSDrive -PSProvider FileSystem | ForEach-Object { $_.Root }")))
  (if output
      (filter (lambda (path) (not (string=? path "")))
              (map trim (split-many output "\n")))
      '()))

(define (fm-nonempty-strings values)
  (filter (lambda (value) (not (string=? value ""))) values))

(define (fm-unix-permissions path)
  (define raw (fm-capture-output "ls" (list "-ld" path)))
  (if raw
      (let ([parts (fm-nonempty-strings (split-many raw " "))])
        (if (>= (length parts) 4)
            (string-append (car parts) " " (list-ref parts 2) ":" (list-ref parts 3))
            (if (null? parts) "Mode: unknown" (car parts))))
      "Mode: unknown"))

(define (fm-stat-permissions path)
  (cond
    [(equal? (current-os!) "windows")
     (let ([rights (fm-capture-output
                     "powershell.exe"
                     (list "-NoProfile" "-Command"
                           "$rights = ((Get-Acl -LiteralPath $args[0]).Access | ForEach-Object { $_.FileSystemRights } | Select-Object -Unique) -join ','; $rights"
                           path))])
       (string-append "ACL: " (or rights "unknown")))]
    [else
     (fm-unix-permissions path)]))

(define (fm-preview-footer path)
  (if (hash-contains? *fm-preview-footer-cache* path)
      (hash-get *fm-preview-footer-cache* path)
      (let ([size (if (is-dir? path)
                      (string-append (int->string (length (fm-read-dir path))) " items")
                      (fm-format-size path))])
        (define footer (string-append " " (fm-stat-permissions path) "  " size " "))
        (set! *fm-preview-footer-cache*
              (hash-insert *fm-preview-footer-cache* path footer))
        footer)))

(define (fm-clear-preview-footer-cache!)
  (set! *fm-preview-footer-cache* (hash)))

(define (fm-dotfile? name)
  (and (> (string-length name) 0) (char=? (string-ref name 0) #\.)))

(define (fm-sort-files entries)
  (define dirs (sort (filter is-dir? entries) string<?))
  (define files (sort (filter (lambda (p) (not (is-dir? p))) entries) string<?))
  (append dirs files))

(define (fm-read-dir-names path show-hidden?)
  (define entries (if (fm-windows-drives-root? path)
                      (fm-windows-drive-paths)
                      (fm-read-dir path)))
  (fm-sort-files
    (filter (lambda (p)
              (let ([name (fm-entry-label p)])
                (or show-hidden? (not (fm-dotfile? name)))))
            entries)))

(define (fm-filter-entries entries query)
  (if (string=? query "")
      entries
      (let ([needle (string-downcase query)])
        (filter (lambda (path)
                  (string-contains? (string-downcase (fm-entry-label path)) needle))
                entries))))

(define (fm-entry-size path)
  (define meta (with-handler (lambda (_) #f) (file-metadata path)))
  (if meta (fs-metadata-len meta) 0))

(define (fm-size-cache entries)
  (if (null? entries)
      (hash)
      (hash-insert (fm-size-cache (cdr entries)) (car entries) (fm-entry-size (car entries)))))

(define (fm-sort-entries entries mode reverse?)
  (define sizes (if (equal? mode 'size) (fm-size-cache entries) (hash)))
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
           (let ([left-ext (fm-file-ext left)] [right-ext (fm-file-ext right)])
             (if (string=? left-ext right-ext)
                 (compare-text (fm-entry-label left) (fm-entry-label right))
                 (compare-text left-ext right-ext)))]
          [(equal? mode 'size)
           (let ([left-size (hash-get sizes left)] [right-size (hash-get sizes right)])
             (if (= left-size right-size)
                 (compare-text (fm-entry-label left) (fm-entry-label right))
                 (compare-size left-size right-size)))]
          [else (compare-text (fm-entry-label left) (fm-entry-label right))]))
  (sort entries compare-files))

(define (fm-format-size path)
  (define meta (with-handler (lambda (_) #f) (file-metadata path)))
  (if meta
      (let ([len (fs-metadata-len meta)])
        (cond [(< len 1024)    (string-append (int->string len) " B")]
              [(< len 1048576) (string-append (int->string (quotient len 1024)) " KiB")]
              [else            (string-append (int->string (quotient len 1048576)) " MiB")]))
      ""))

(define (fm-file-ext path)
  (define parts (split-many path "."))
  (if (> (length parts) 1)
      (list-ref parts (- (length parts) 1))
      ""))

(define (fm-is-text-ext? path)
  (define text-exts '(
    "txt" "md" "rs" "py" "js" "ts" "tsx" "jsx" "css"
    "html" "json" "toml" "yaml" "yml" "lua" "scm"
    "c" "h" "cpp" "hpp" "java" "go" "rb" "sh" "zsh"
    "bash" "fish" "el" "ex" "exs" "hs" "scala" "kt"
    "swift" "zig" "clj" "cljs" "dart" "svelte" "vue"
    "sass" "scss" "less" "ps1" "tf" "sql" "r" "jl"
    "nix" "prisma" "php" "pl" "diff" "vim" "org"
    "lock" "toml" "xml" "conf" "ini" "cfg"))
  (define ext (fm-file-ext path))
  (define (fm-member value values)
    (cond [(null? values) #f]
          [(equal? value (car values)) #t]
          [else (fm-member value (cdr values))]))
  (fm-member ext text-exts))

(define (fm-read-bounded-line port max-width)
  (let loop ([remaining (max 1 max-width)] [result ""] [seen? #f])
    (let ([ch (read-char port)])
      (cond
        [(eof-object? ch) (and seen? (cons result #t))]
        [(char=? ch #\newline) (cons result #f)]
        [(char=? ch #\return) (loop remaining result seen?)]
        [(<= remaining 1)
         (cons (fm-fit-text (string-append result "…") max-width) #t)]
        [else
         (loop (- remaining 1) (string-append result (string ch)) #t)]))))

(define (fm-read-preview path max-lines max-width)
  (cond
    [(is-dir? path)
     (define children (fm-read-dir-names path #t))
     (fm-take children (min max-lines (length children)))]
    [(fm-is-text-ext? path)
     (with-handler
       (lambda (_) (list (string-append "  [" (fm-format-size path) "]")))
       (define port (open-input-file path))
       (define lines
         (let loop ([remaining max-lines] [result '()])
           (if (<= remaining 0)
               (reverse result)
               (let ([line (fm-read-bounded-line port max-width)])
                 (if (not line)
                     (reverse result)
                     (let ([next-result (cons (car line) result)])
                       (if (cdr line)
                           (reverse next-result)
                           (loop (- remaining 1) next-result))))))))
       (close-port port)
       lines)]
    [else (list (string-append "  [" (fm-format-size path) "]"))]))

(define (fm-char-width ch)
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

(define (fm-display-width text)
  (let loop ([index 0] [width 0])
    (if (>= index (string-length text))
        width
        (loop (+ index 1) (+ width (fm-char-width (string-ref text index)))))))

(define (fm-fit-text text width)
  (cond [(<= width 0) ""]
        [(<= (fm-display-width text) width) text]
        [(= width 1) "…"]
        [else
         (let loop ([index 0] [used 0])
           (if (or (>= index (string-length text))
                   (> (+ used (fm-char-width (string-ref text index))) (- width 1)))
               (string-append (substring text 0 index) "…")
               (loop (+ index 1)
                     (+ used (fm-char-width (string-ref text index))))))]))

(define (fm-calc-layout w h width-pct height-pct)
  (let* ([max-w (max 1 w)]
         [max-h (max 1 h)]
         [box-w (min max-w (min (max (quotient (* w width-pct) 100) 20) 120))]
         [box-h (min max-h (max (quotient (* h height-pct) 100) 3))]
         [box-x (quotient (- w box-w) 2)]
         [box-y (quotient (- h box-h) 2)])
    (list box-x box-y box-w box-h)))

(define (fm-calc-col-widths inner-w ratios)
  (define total (apply + ratios))
  (define avail (max 0 (- inner-w 2)))
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
