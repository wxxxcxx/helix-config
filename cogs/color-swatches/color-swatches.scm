(require-builtin helix/core/configuration as helix.config.)
(require (only-in "helix/configuration.scm"
                  get-language-config
                  lsp
                  refresh-all-language-configs!
                  set-lsp-config!))
(require (only-in "helix/static.scm" get-init-scm-path))
(require (only-in "cogs/color.scm" color-terminal?))

(provide color-swatches-init)

(define color-swatches-server-name "color-swatches")

(define (color-swatches-runtime-file config-root)
  (define configured-runtime
    (with-handler (lambda (_) #f) (env-var "HELIX_RUNTIME")))
  (define configured-file
    (and configured-runtime
         (string-append configured-runtime "/languages.toml")))
  (if (and configured-file (path-exists? configured-file))
      configured-file
      (string-append config-root "/runtime/languages.toml")))

;; Steel has no API for enumerating language configurations. Parse only the
;; top-level [[language]] names from Helix's runtime TOML, then read the actual
;; merged configuration for each language through get-language-config.
(define (color-swatches-language-names path)
  (if (not (path-exists? path))
      (list "scheme")
      (let ([port (open-input-file path)])
        (let loop ([expect-name? #f] [names '()])
          (define line (read-line port))
          (cond [(eof-object? line)
                 (close-input-port port)
                 (reverse names)]
                [(string=? (trim line) "[[language]]")
                 (loop #t names)]
                [expect-name?
                 (define value (trim line))
                 (define parts (split-many value "\""))
                 (if (and (starts-with? value "name")
                          (>= (length parts) 2))
                     (loop #f (cons (list-ref parts 1) names))
                     (loop #t names))]
                [else (loop #f names)])))))

(define (color-swatches-server-entry-name entry)
  (cond [(string? entry) entry]
        [(hash? entry) (hash-try-get entry 'name)]
        [else #f]))

(define (color-swatches-remove-server servers server-name)
  (filter
    (lambda (entry)
      (not (equal? (color-swatches-server-entry-name entry) server-name)))
    servers))

(define (color-swatches-configure-language! language-name enabled?)
  (define config (get-language-config language-name))
  (when config
    (define servers (or (hash-try-get config 'language-servers) '()))
    (define without-colors
      (color-swatches-remove-server servers color-swatches-server-name))
    (helix.config.update-language-config!
      language-name
      (hash "name" language-name
            "language-servers"
            (if enabled?
                (append without-colors (list color-swatches-server-name))
                without-colors)))))

(define (color-swatches-init)
  (define config-root (parent-name (get-init-scm-path)))
  (define server-path (string-append config-root "/cogs/color-swatches/server.scm"))
  (define language-names
    (color-swatches-language-names
      (color-swatches-runtime-file config-root)))
  (define enabled? (color-terminal?))
  (lsp (hash 'display-color-swatches enabled?))
  (when enabled?
    (set-lsp-config!
      color-swatches-server-name
      (hash "name" color-swatches-server-name
            "command" "steel"
            "args" (list server-path))))
  (for-each
    (lambda (language-name)
      (color-swatches-configure-language! language-name enabled?))
    language-names)
  (refresh-all-language-configs!))
