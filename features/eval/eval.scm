(require (only-in "helix/ext.scm" eval-buffer evalp))
(require (only-in "helix/misc.scm" set-status! set-warning!))
(require (only-in "helix/static.scm" current-highlighted-text!))

(provide evalp
         eval-buffer
         eval-selection)

;;@doc
;; Evaluate the current primary selection as a Steel expression.
(define (eval-selection)
  (define expression (current-highlighted-text!))
  (if (string=? (trim expression) "")
      (set-warning! "eval-selection: selection is empty")
      (with-handler
        (lambda (error-value)
          (set-warning!
            (string-append "eval-selection: "
                           (error-object-message error-value))))
        (set-status! (eval-string expression)))))
