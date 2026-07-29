;; Woz using only the terminal's semantic ANSI palette.

(require (prefix-in theme. "helix/themes.scm"))
(require (only-in "themes/woz-fallback.scm" make-woz-fallback-theme))

(provide register-woz-ansi-theme)

(define woz-ansi-theme
  (make-woz-fallback-theme
    "woz-ansi"
    (hash 'ansi? #t
          'bg "black"
          'bg-alt "gray"
          'bg-hl "gray"
          'fg "light-gray"
          'fg-dim "gray"
          'fg-bright "white"
          'accent "light-cyan"
          'accent-alt "light-blue"
          'accent-dim "blue"
          'teal "cyan"
          'green "light-green"
          'orange "light-yellow"
          'red "light-red"
          'purple "light-magenta"
          'yellow "light-yellow")))

(define (register-woz-ansi-theme)
  (theme.register-theme woz-ansi-theme))
