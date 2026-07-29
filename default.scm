;; default.scm
;; Basic editor configuration

(require "helix/configuration.scm")
(require "helix/components.scm")
(require "cogs/color.scm")
(require "themes/woz.scm")
(require "themes/woz-safe.scm")

(define (default-lsp-entry-name entry)
  (cond [(string? entry) entry]
        [(hash? entry) (hash-try-get entry 'name)]
        [else #f]))

(define (default-has-lsp? entries name)
  (cond [(null? entries) #f]
        [(equal? (default-lsp-entry-name (car entries)) name) #t]
        [else (default-has-lsp? (cdr entries) name)]))

(define (default-enable-steel-lsp!)
  (unless (get-lsp-config "steel-language-server")
    (set-lsp-config!
      "steel-language-server"
      (hash "name" "steel-language-server"
            "command" "steel-language-server")))
  (define scheme-config (get-language-config "scheme"))
  (when scheme-config
    (define servers (or (hash-try-get scheme-config 'language-servers) '()))
    (unless (default-has-lsp? servers "steel-language-server")
      (update-language-config!
        "scheme"
        (hash "name" "scheme"
              "language-servers" (append servers (list "steel-language-server")))))))

(define (default-init)
  (default-enable-steel-lsp!)
  (line-number 'relative)
  (indent-guides (ig-render #t))
  (bufferline "always")
  (soft-wrap (sw-enable #t))
  (lsp (hash 'display-color-swatches #t))
  (unless (equal? (current-os!) "windows")
    (set-option! 'clipboard-provider
                 (if (equal? (current-os!) "macos") "pasteboard" "xclip")))
  (set-option! 'default-yank-register "+")
  (jump-label-alphabet "fjdkslarueiwoqpvncmxz")
  (helix.theme (if (color-terminal?) "woz" "woz-safe")))

(provide default-init)
