(require (only-in "../../../core/list.scm"
                  list-drop
                  list-take))
(require (only-in "../../../core/path.scm"
                  core-path-base-name
                  core-path-directory-entries
                  core-path-entry-label
                  core-path-label
                  core-path-parent
                  core-path-read-directory
                  core-path-windows-drive-root?
                  core-path-windows-drives-root?))
(require (only-in "../../../core/process.scm"
                  core-process-trimmed-output))
(require (only-in "features/file-manager/core/collections.scm" fm-member?))
(require (only-in "features/ui/text.scm"
                  ui-display-width
                  ui-fit-text))

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
  (list-take lst n))

(define (fm-drop lst n)
  (list-drop lst n))

(define fm-base-name core-path-base-name)
(define fm-parent-dir core-path-parent)
(define fm-windows-drives-root? core-path-windows-drives-root?)
(define fm-windows-drive-root? core-path-windows-drive-root?)
(define fm-entry-label core-path-entry-label)
(define fm-path-label core-path-label)
(define fm-read-dir core-path-read-directory)

(define *fm-preview-footer-cache* (hash))

(define (fm-capture-output program args)
  (with-handler
    (lambda (_) #f)
    (core-process-trimmed-output program args)))

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

(define fm-read-dir-names core-path-directory-entries)

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
  (fm-member? ext text-exts))

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

(define (fm-display-width text)
  (ui-display-width text))

(define (fm-fit-text text width)
  (ui-fit-text text width))

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
