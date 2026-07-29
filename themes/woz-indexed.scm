;; Woz using the xterm indexed palette.

(require (prefix-in theme. "helix/themes.scm"))
(require (only-in "themes/woz-fallback.scm" make-woz-fallback-theme))

(provide register-woz-indexed-theme)

(define woz-indexed-theme
  (make-woz-fallback-theme
    "woz-indexed"
    (hash 'ansi? #f
          'bg "236"
          'bg-alt "239"
          'bg-hl "60"
          'fg "253"
          'fg-dim "60"
          'fg-bright "255"
          'accent "110"
          'accent-alt "67"
          'accent-dim "67"
          'teal "109"
          'green "108"
          'orange "173"
          'red "167"
          'purple "139"
          'yellow "180")))

(define (register-woz-indexed-theme)
  (theme.register-theme woz-indexed-theme))
