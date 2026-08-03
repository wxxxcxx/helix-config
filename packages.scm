(require (only-in "package.scm" package))

(provide steel-pty-package)

;; Package declarations are pure values shared by startup and maintenance tools.
(define steel-pty-package
  (package
    #:name "steel-pty"
    #:url "https://github.com/wxxxcxx/steel-pty"
    #:branch "codex/terminal-panel-fallback"
    #:verify "term.scm"))
