(require "package.scm")

(define dependencies
  (list
    (package-git-dependency
      #:name "steel-pty"
      #:url "https://github.com/wxxxcxx/steel-pty"
      #:revision "68f2fc6fa7b68141c6b3f020325ac1751b5fc512"
      #:verify "term.scm")))

(define (setup-arguments)
  (define arguments (command-line))
  (if (ends-with? (car arguments) "steel")
      (drop arguments 2)
      (drop arguments 1)))

(define (setup-help)
  (displayln "Usage: steel setup.scm [install|list|clean] [--force]")
  (displayln "  install  Install missing or stale dependencies (default)")
  (displayln "  list     Show dependency status and installed revision")
  (displayln "  clean    Uninstall dependencies and remove source caches"))

(define (setup-main)
  (define arguments (setup-arguments))
  (define command-name
    (if (or (null? arguments) (string=? (car arguments) "--force"))
        "install"
        (car arguments)))
  (define force? (not (not (member "--force" arguments))))
  (cond [(string=? command-name "install")
         (package-install-all! dependencies #:force force?)]
        [(string=? command-name "list") (package-list! dependencies)]
        [(string=? command-name "clean") (package-clean-all! dependencies)]
        [(or (string=? command-name "help") (string=? command-name "--help"))
         (setup-help)]
        [else
         (setup-help)
         (error (string-append "unknown setup command: " command-name))]))

(setup-main)
