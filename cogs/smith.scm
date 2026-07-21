(require "helix/editor.scm")
(require "helix/misc.scm")

(provide smith-plugin smith-prune smith-init)

(define (capture-output cmd)
  (with-handler
    (lambda (err) #f)
    (let* ([proc (~> (command (car cmd) (cdr cmd))
                     with-stdout-piped
                     spawn-process)]
           [ok? (Ok? proc)])
      (and ok?
           (let* ([handle (Ok->value proc)]
                  [raw (read-port-to-string (child-stdout handle))])
             (and (string? raw)
                  (let ([trimmed (trim raw)])
                    (and (not (string=? trimmed ""))
                         trimmed))))))))

(with-handler
  (lambda (err)
    (set-status! "smith.hx: installing...")
    (let* ([proc (~> (command "forge" (list "pkg" "install" "--git"
                                            "https://github.com/kn66/smith.hx.git"))
                     with-stdout-piped
                     spawn-process)]
           [ok? (Ok? proc)])
      (when ok?
        (let* ([handle (Ok->value proc)]
               [out (child-stdout handle)])
          (when out
            (read-port-to-string out)))))
    (set-status! "smith.hx: installed")
    (eval '(require (only-in "smith.hx/smith.scm" smith-plugin smith-prune smith-init))))
  (eval '(require (only-in "smith.hx/smith.scm" smith-plugin smith-prune smith-init))))

(define smith-plugin (eval 'smith-plugin))
(define smith-prune (eval 'smith-prune))
(define smith-init (eval 'smith-init))
