(require "cogs/file-manager/core/files.scm")

(provide fe-preview-empty fe-preview-load
         fe-preview-path fe-preview-directory? fe-preview-lines fe-preview-footer-text)

(struct FePreview (path directory? lines footer))

(define (fe-preview-empty)
  (FePreview #f #f '() ""))

(define (fe-preview-load path show-hidden?)
  (if (not path)
      (fe-preview-empty)
      (FePreview path
                 (is-dir? path)
                 (cond [(is-dir? path) (fm-read-dir-names path show-hidden?)]
                       [(fm-is-text-ext? path) (fm-read-preview path 200 256)]
                       [else '()])
                 (fm-preview-footer path))))

(define (fe-preview-path preview) (FePreview-path preview))
(define (fe-preview-directory? preview) (FePreview-directory? preview))
(define (fe-preview-lines preview) (FePreview-lines preview))
(define (fe-preview-footer-text preview) (FePreview-footer preview))
