;; default.scm
;; Basic editor configuration

(require "helix/configuration.scm")
(require "helix/components.scm")
(require "themes/woz.scm")

(define (init)
  (line-number 'relative)
  (indent-guides (ig-render #t))
  (bufferline "always")
  (soft-wrap (sw-enable #t))
  (set-option! 'clipboard-provider "pasteboard")
  (set-option! 'default-yank-register "+")
  (jump-label-alphabet "fjdkslarueiwoqpvncmxz")
  (helix.theme "woz"))

(provide init)
