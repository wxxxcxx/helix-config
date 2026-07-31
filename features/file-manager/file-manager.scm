(require (only-in "features/file-manager/file-explorer/file-explorer.scm"
                  file-explorer-close
                  file-explorer-configure!
                  file-explorer-open))
(require (only-in "features/file-manager/file-tree/file-tree.scm"
                  file-tree-close
                  file-tree-configure!
                  file-tree-init
                  file-tree-open
                  file-tree-set-layout-hooks!))

(provide file-manager-init
         file-explorer-close
         file-explorer-configure!
         file-explorer-open
         file-tree-close
         file-tree-configure!
         file-tree-open
         file-tree-set-layout-hooks!)

;; Keep the public entry module free of startup effects so use-feature can
;; isolate load failures before any editor state is changed.
(define (file-manager-init)
  (file-tree-init))
