(require (only-in "../../../features/editor/external-file-policy.scm"
                  external-file-action))

(define (assert-equal actual expected message)
  (unless (equal? actual expected)
    (error (string-append message
                          ": expected " (to-string expected)
                          ", got " (to-string actual)))))

(assert-equal (external-file-action 'unchanged #f) 'ignore
              "unchanged clean buffers are ignored")
(assert-equal (external-file-action 'changed #f) 'reload
              "changed clean buffers are reloaded")
(assert-equal (external-file-action 'changed #t) 'warn-dirty
              "changed dirty buffers are preserved")
(assert-equal (external-file-action 'missing #f) 'warn-missing
              "missing files warn without reload")
(assert-equal (external-file-action 'error #f) 'warn-error
              "inspection failures remain visible")
