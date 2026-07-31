;; Base editor configuration and theme selection.

(require "helix/configuration.scm")
(require "helix/components.scm")
(require (only-in "helix/commands.scm" theme))
(require "features/ui/color.scm")
(require (only-in "features/ui/indent-guides.scm" indent-guide-character))
(require (only-in "themes/woz.scm" register-woz-theme))
(require (only-in "themes/woz-indexed.scm" register-woz-indexed-theme))
(require (only-in "themes/woz-ansi.scm" register-woz-ansi-theme))

(define (editor-lsp-entry-name entry)
  (cond [(string? entry) entry]
        [(hash? entry) (hash-try-get entry 'name)]
        [else #f]))

(define (editor-has-lsp? entries name)
  (cond [(null? entries) #f]
        [(equal? (editor-lsp-entry-name (car entries)) name) #t]
        [else (editor-has-lsp? (cdr entries) name)]))

(define (editor-enable-steel-lsp!)
  (unless (get-lsp-config "steel-language-server")
    (set-lsp-config!
      "steel-language-server"
      (hash "name" "steel-language-server"
            "command" "steel-language-server")))
  (define scheme-config (get-language-config "scheme"))
  (when scheme-config
    (define servers (or (hash-try-get scheme-config 'language-servers) '()))
    (unless (editor-has-lsp? servers "steel-language-server")
      (update-language-config!
        "scheme"
        (hash "name" "scheme"
              "language-servers" (append servers (list "steel-language-server")))))))

(define (editor-init)
  (register-woz-theme)
  (register-woz-indexed-theme)
  (register-woz-ansi-theme)
  (when (color-terminal?) (true-color #t))
  (editor-enable-steel-lsp!)
  (line-number 'relative)
  (indent-guides (ig-render #t) (ig-character indent-guide-character))
  (bufferline "always")
  (soft-wrap (sw-enable #t))
  (lsp (hash 'display-color-swatches (color-terminal?)))
  (unless (equal? (current-os!) "windows")
    (set-option! 'clipboard-provider
                 (if (equal? (current-os!) "macos") "pasteboard" "xclip")))
  (set-option! 'mouse-yank-register "+")
  (set-option! 'default-yank-register "+")
  (jump-label-alphabet "fjdkslarueiwoqpvncmxz")
  (theme
    (cond [(color-terminal?) "woz"]
          [(indexed-terminal?) "woz-indexed"]
          [else "woz-ansi"])))

(provide editor-init)
