;; default.scm
;; Basic editor configuration

(require "helix/configuration.scm")
(require "helix/components.scm")
(require "themes/woz.scm")

(define (default-init)
  (line-number 'relative)
  (indent-guides (ig-render #t))
  (bufferline "always")
  (soft-wrap (sw-enable #t))
  (unless (equal? (current-os!) "windows")
    (set-option! 'clipboard-provider
                 (if (equal? (current-os!) "macos") "pasteboard" "xclip")))
  (set-option! 'default-yank-register "+")
  (jump-label-alphabet "fjdkslarueiwoqpvncmxz")
  (helix.theme "woz"))

(provide default-init)
