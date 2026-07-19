;; im-switch-config.scm
;; Input source switching: auto-detect platform and register hooks.
;;
;; Inspired by helix-fcitx-focus (github.com/mtul0729/helix-fcitx-focus)
;; and emacs-smart-input-source (github.com/laishulu/emacs-smart-input-source).

(require "helix/editor.scm")
(require "helix/misc.scm")
(require "cogs/im-switch.scm")

;; Helix exposes modes as opaque struct values, not symbols.
;; Cache insert-mode once so we compare with equal? instead of eq?.
(define insert-mode (string->editor-mode "insert"))

(define (insert-mode? mode)
  (equal? mode insert-mode))

;; Auto-detect platform
(im-switch-autoconfigure!
  #:normal-source "com.apple.keylayout.ABC")

;; Leaving insert → English;
(register-hook 'on-mode-switch
  (lambda (event)
    (let ([old-mode (mode-switch-old event)]
          [new-mode (mode-switch-new event)])
      (cond
        [(and (insert-mode? old-mode) (not (insert-mode? new-mode)))
         (im-switch-to-normal)]))))
