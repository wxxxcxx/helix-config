;; statusline.scm
;; Statusline — layout

(require "helix/configuration.scm")
(require "cogs/indicators/indicators.scm")
(require "cogs/statusline-palette.scm")
(provide statusline-init)

(define (statusline-init)
  (bufferline "never")
  (version-control-init)
  (statusline
    #:center (list 'file-indent-style 'file-line-ending 'file-encoding
                   'read-only-indicator 'diagnostics 'workspace-diagnostics 'spinner)
    #:left (list
      (mode-indicator #:fg (contrast-bg major-bg) #:bg major-bg
                      #:left-separator? #t
                      #:right-separator? #t #:right-separator-bg (minor 0.4))
      (version-control-indicator #:fg (contrast-bg (minor 0.4)) #:bg (minor 0.4)
                                 #:right-separator? #t #:right-separator-bg (minor 0.3))
      (file-name-indicator #:fg (contrast-bg (minor 0.3)) #:bg (minor 0.3)
                           #:right-separator? #t))
    #:right (list
      (selections-indicator #:fg (contrast-bg (minor 0.2)) #:bg (minor 0.2)
                            #:left-separator? #t)
      (position-indicator #:fg (contrast-bg (minor 0.3)) #:bg (minor 0.3)
                          #:left-separator? #t #:left-separator-bg (minor 0.2))
      (buffers-indicator #:fg (contrast-bg (minor 0.4)) #:bg (minor 0.4)
                         #:left-separator? #t #:left-separator-bg (minor 0.3))
      (file-type-indicator #:fg (contrast-bg major-bg) #:bg major-bg
                           #:left-separator? #t #:left-separator-bg (minor 0.4)
                           #:right-separator? #t))))
