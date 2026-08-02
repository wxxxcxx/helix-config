(require (only-in "../../../features/file-manager/file-tree/model.scm"
                  ft-model-build-rows
                  ft-model-remove
                  ft-model-row-index
                  ft-model-row-path))

(define (assert-equal actual expected message)
  (unless (equal? actual expected)
    (error (string-append message
                          ": expected " (to-string expected)
                          ", got " (to-string actual)))))

(define directories '("/root" "/root/src"))

(define (directory? path)
  (if (member path directories) #t #f))

(define (children path)
  (cond [(string=? path "/root") '("/root/README" "/root/src")]
        [(string=? path "/root/src") '("/root/src/main.scm")]
        [else '()]))

(define rows
  (ft-model-build-rows "/root"
                       '("/root" "/root/src")
                       directory?
                       children))

(assert-equal rows
              '((0 "/root")
                (1 "/root/README")
                (1 "/root/src")
                (2 "/root/src/main.scm"))
              "expanded directories produce flattened rows")
(assert-equal (ft-model-row-path (list-ref rows 2)) "/root/src"
              "row path is available to controllers")
(assert-equal (ft-model-row-index rows "/root/src/main.scm") 3
              "row lookup finds nested paths")
(assert-equal (ft-model-row-index rows "/root/missing") #f
              "row lookup reports missing paths")
(assert-equal (ft-model-remove "/root/src" '("/root" "/root/src"))
              '("/root")
              "expanded path removal preserves remaining paths")
(assert-equal (ft-model-build-rows "" '() directory? children) '()
              "empty root produces no rows")
