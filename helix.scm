(require "helix/editor.scm")
(require (prefix-in helix. "helix/commands.scm"))
(require (only-in "helix/misc.scm" set-status! set-warning!))
(require (prefix-in helix.static. "helix/static.scm"))

(provide eval-selection)

;;@doc
;; Evaluate the current primary selection as a Steel expression.
(define (eval-selection)
  (define expression (helix.static.current-highlighted-text!))
  (if (string=? (trim expression) "")
      (set-warning! "eval-selection: selection is empty")
      (with-handler
        (lambda (error-value)
          (set-warning!
            (string-append "eval-selection: " (error-object-message error-value))))
        (set-status! (eval-string expression)))))
