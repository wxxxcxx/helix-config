(require (only-in "../../core/filesystem/watch/watch.scm"
                  filesystem-watch-init))
(require (only-in "features/file-manager/file-explorer/file-explorer.scm"
                  file-explorer-close
                  file-explorer-configure!
                  file-explorer-init
                  file-explorer-open))
(require (only-in "features/file-manager/file-tree/file-tree.scm"
                  file-tree-close
                  file-tree-configure!
                  file-tree-init
                  file-tree-open
                  file-tree-panel-mode
                  file-tree-toggle))

(provide file-manager-init
         file-explorer-close
         file-explorer-configure!
         file-explorer-open
         file-tree-close
         file-tree-configure!
         file-tree-open
         file-tree-panel-mode
         file-tree-toggle)

;; Keep the public entry module free of startup effects so the feature loader can
;; isolate load failures before any editor state is changed.
(define (file-manager-init)
  (filesystem-watch-init)
  (file-explorer-init)
  (file-tree-init))
