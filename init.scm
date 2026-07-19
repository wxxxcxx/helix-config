;; Run at startup. Helix context is bound to *helix.cx*
(require (prefix-in helix. "helix/commands.scm"))
(require (prefix-in helix.static. "helix/static.scm"))
(require (prefix-in helix.keymaps. "helix/keymaps.scm"))
(require "helix/configuration.scm")

(require (only-in "smith.hx/smith.scm"
                  smith-plugin
                  smith-prune
                  smith-init))

;; Relative line numbers
(line-number 'relative)

;; Indent guides
(indent-guides (ig-render #t))

;; Editor misc: bufferline, clipboard, yank, jump labels
(bufferline "always")
(soft-wrap (sw-enable #t))
(set-option! 'clipboard-provider "pasteboard")
(set-option! 'default-yank-register "+")
(jump-label-alphabet "fjdkslarueiwoqpvncmxz")

;; Load and activate Woz theme
(require "themes/woz.scm")
(helix.theme "woz")

;; ── Statusline ───────────────────────────────────────────────────
;; Built-in statusline with SCM (version-control) info
(statusline
  #:left (list 'mode)
  #:center (list 'file-name 'file-modification-indicator)
  #:right (list 'diagnostics 'selections 'position 'file-indent-style
                'position-percentage 'total-line-numbers 'version-control 'file-type)
  #:mode-normal "◇ NORMAL"
  #:mode-insert "▸ INSERT"
  #:mode-select "◉ SELECT")

;; moka.hx: statusline and bufferline (disabled in favor of built-in)
; (smith-plugin "https://github.com/Ra77a3l3-jar/moka.hx.git"
;   (config
;    (moka-configure!
;     #:sections
;     (list
;      ;; Left: mode + file
;      (moka-section
;       (list (moka-segment 'mode #:bg "#88C0D0" #:fg "#2E3440" #:bubble? #t #:gap 1)
;             (moka-segment 'file #:bg "#3B4252" #:fg "#D8DEE9" #:bubble? #f #:gap 0)
;             (moka-segment 'git-branch #:bg "#3B4252" #:fg "#81A1C1" #:bubble? #f))
;       #:align 'left)

;      ;; Right: LSP + position
;      (moka-section
;       (list (moka-segment 'lsp #:bg "#3B4252" #:fg "#D8DEE9" #:bubble? #f #:gap 0)
;             (moka-segment 'position #:bg "#5E81AC" #:fg "#ECEFF4" #:bubble? #t))
;       #:align 'right)))

;    (moka-enable!)

;    (moka-bufferline-configure!
;     #:active (moka-buffer-style #:bg "#88C0D0" #:fg "#2E3440" #:bubble? #t)
;     #:inactive (moka-buffer-style #:bg "#3B4252" #:fg "#D8DEE9" #:bubble? #t)
;     #:gap 0)
;    (moka-bufferline-enable!)))

(smith-plugin "https://github.com/Ra77a3l3-jar/forest.hx.git"
  (config
   ;; Use 'right instead of 'left to move the sidebar.
   (forest-configure! 'left #:ignore (list ".git" "target" "__pycache__"))

   ;; Select 'snacks (persistent sidebar) or 'mini (floating).
   (forest-set-style! 'snacks))

  ;; Open or focus forest.hx with Space e in normal mode. Bindings are data,
  ;; so the keymap macro does not cross Smith's delayed evaluation boundary.
  (bind
   ("normal" ("space" "e") ":forest-open")))

;; Synchronize after every smith-plugin declaration has been evaluated.
(smith-init)

;; ── Input source switching ──────────────────────────────────────
(require "im-switch-config.scm")
