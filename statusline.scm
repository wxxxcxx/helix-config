;; statusline.scm
;; Statusline — layout

(require "helix/configuration.scm")
(require "cogs/indicators/indicators.scm")
(require "cogs/statusline-palette.scm")
(provide statusline-init)

(define (statusline-init)
  (bufferline "never")
  (statusline
    #:center (list 'primary-selection-length 'file-indent-style 'file-line-ending 'file-encoding
                   'read-only-indicator 'diagnostics 'workspace-diagnostics 'spinner)
    #:left (list
      (left-arc-indicator #:fg major-bg)
      (mode-indicator #:fg (contrast-bg major-bg) #:bg major-bg)
      (right-arc-indicator #:fg major-bg #:bg (minor 0.4))
      (version-control-indicator #:fg (contrast-bg (minor 0.4)) #:bg (minor 0.4))
      (right-arc-indicator #:fg (minor 0.4) #:bg (minor 0.3))
      (file-name-indicator #:fg (contrast-bg (minor 0.3)) #:bg (minor 0.3))
      (right-arc-indicator #:fg (minor 0.3)))
    #:right (list
      (left-arc-indicator #:fg (minor 0.2))
      (selections-indicator #:fg (contrast-bg (minor 0.2)) #:bg (minor 0.2))
      (left-arc-indicator #:fg (minor 0.3) #:bg (minor 0.2))
      (position-indicator #:fg (contrast-bg (minor 0.3)) #:bg (minor 0.3))
      (left-arc-indicator #:fg (minor 0.4) #:bg (minor 0.3))
      (buffers-indicator #:fg (contrast-bg (minor 0.4)) #:bg (minor 0.4))
      (left-arc-indicator #:fg major-bg #:bg (minor 0.4))
      (file-type-indicator #:fg (contrast-bg major-bg) #:bg major-bg)
      (right-arc-indicator #:fg major-bg))))
