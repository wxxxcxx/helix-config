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
    #:center (list 'primary-selection-length 'file-indent-style 'file-line-ending 'file-encoding
                   'read-only-indicator 'diagnostics 'workspace-diagnostics 'spinner)
    #:left (list
      (mode-indicator #:fg (contrast-bg major-bg) #:bg major-bg
                      #:left-arc? #t #:left-arc-fg major-bg
                      #:right-arc? #t #:right-arc-fg major-bg #:right-arc-bg (minor 0.4))
      (version-control-indicator #:fg (contrast-bg (minor 0.4)) #:bg (minor 0.4)
                                 #:right-arc? #t #:right-arc-fg (minor 0.4) #:right-arc-bg (minor 0.3))
      (file-name-indicator #:fg (contrast-bg (minor 0.3)) #:bg (minor 0.3)
                           #:right-arc? #t #:right-arc-fg (minor 0.3)))
    #:right (list
      (selections-indicator #:fg (contrast-bg (minor 0.2)) #:bg (minor 0.2)
                            #:left-arc? #t #:left-arc-fg (minor 0.2))
      (position-indicator #:fg (contrast-bg (minor 0.3)) #:bg (minor 0.3)
                          #:left-arc? #t #:left-arc-fg (minor 0.3) #:left-arc-bg (minor 0.2))
      (buffers-indicator #:fg (contrast-bg (minor 0.4)) #:bg (minor 0.4)
                         #:left-arc? #t #:left-arc-fg (minor 0.4) #:left-arc-bg (minor 0.3))
      (file-type-indicator #:fg (contrast-bg major-bg) #:bg major-bg
                           #:left-arc? #t #:left-arc-fg major-bg #:left-arc-bg (minor 0.4)
                           #:right-arc? #t #:right-arc-fg major-bg))))
