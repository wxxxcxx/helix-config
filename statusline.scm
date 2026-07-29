;; statusline.scm
;; Statusline — layout

(require "helix/configuration.scm")
(require "cogs/indicators/indicators.scm")
(require (only-in "cogs/indicators/style.scm" statusline-width-at-least?))
(require "cogs/statusline-palette.scm")
(provide statusline-init)

(define statusline-full-min-width 100)

(define (statusline-init)
  (bufferline "never")
  (version-control-init)
  (statusline
    #:center (list 'file-indent-style 'file-line-ending 'file-encoding
                   'read-only-indicator 'diagnostics 'workspace-diagnostics 'spinner)
    #:left (list
      (mode-indicator #:fg (contrast-bg major-bg) #:bg major-bg
                      #:left-separator? #t
                      #:right-separator? #t
                      #:right-separator-bg
                      (lambda ()
                        (if (statusline-width-at-least? statusline-full-min-width)
                            ((minor 0.4))
                            ((minor 0.3)))))
      (version-control-indicator #:fg (contrast-bg (minor 0.4)) #:bg (minor 0.4)
                                 #:min-width statusline-full-min-width
                                 #:right-separator? #t #:right-separator-bg (minor 0.3))
      (file-name-indicator #:fg (contrast-bg (minor 0.3)) #:bg (minor 0.3)
                           #:right-separator? #t))
    #:right (list
      (selections-indicator #:fg (contrast-bg (minor 0.2)) #:bg (minor 0.2)
                            #:min-width statusline-full-min-width
                            #:left-separator? #t)
      (position-indicator #:fg (contrast-bg (minor 0.3)) #:bg (minor 0.3)
                          #:min-width statusline-full-min-width
                          #:left-separator? #t #:left-separator-bg (minor 0.2))
      (buffers-indicator #:fg (contrast-bg (minor 0.4)) #:bg (minor 0.4)
                         #:min-width statusline-full-min-width
                         #:left-separator? #t #:left-separator-bg (minor 0.3))
      (file-type-indicator #:fg (contrast-bg major-bg) #:bg major-bg
                           #:left-separator? #t
                           #:left-separator-bg
                           (lambda ()
                             (and (statusline-width-at-least? statusline-full-min-width)
                                  ((minor 0.4))))
                           #:right-separator? #t))))
