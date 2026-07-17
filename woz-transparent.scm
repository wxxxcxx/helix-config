;; Woz Transparent — woz theme with transparent background
;; Inherits syntax colors from woz, overrides UI backgrounds to
;; transparent so your terminal background/gradient shows through.
(require "helix/components.scm")
(require (prefix-in theme. "helix/themes.scm"))

(require "woz.scm")

;; Nord colors reused here for UI foreground text
(define fg        "#D8DEE9")
(define fg-dim    "#4C566A")
(define fg-bright "#ECEFF4")
(define accent    "#88C0D0")
(define green     "#A3BE8C")
(define red       "#BF616A")

;; ── Helpers ───────────────────────────────────────────────
(define (fg-only color)
  (~> (style) (style-fg (theme.string->color color))))

;; ── Derive transparent variant from base woz ──────────────
(define woz-transparent
  (~> (theme.get-theme-by-name "woz")

      ;; Editor area — fully transparent background
      (theme.ui.background (style))

      ;; Popups / menus / help — transparent bg, keep woz text color
      (theme.ui.popup       (fg-only fg))
      (theme.ui.popup.info  (fg-only fg))
      (theme.ui.help        (fg-only fg))
      (theme.ui.menu        (fg-only fg))

      ;; Menu selected item — invert or just fg
      (theme.ui.menu.selected   (fg-only accent))

      ;; Selection — semi-transparent feeling via fg-only
      (theme.ui.selection        (fg-only fg-dim))
      (theme.ui.selection.primary (fg-only fg-dim))

      ;; Cursor line — transparent
      (theme.ui.cursorline        (style))
      (theme.ui.cursorline.primary (style))

      ;; Gutter — transparent, keep line numbers (inherited from woz)
      (theme.ui.gutter        (style))
      (theme.ui.gutter.selected (style))

      ;; Status line — transparent, keep mode indicator
      (theme.ui.statusline         (fg-only fg-dim))
      (theme.ui.statusline.inactive (style))
      (theme.ui.statusline.normal   (fg-only fg-bright))
      (theme.ui.statusline.insert   (fg-only fg-bright))
      (theme.ui.statusline.select   (fg-only fg-bright))
      (theme.ui.statusline.separator (fg-only fg-dim))

      ;; Bufferline — transparent
      (theme.ui.bufferline           (fg-only fg-dim))
      (theme.ui.bufferline.active    (fg-only fg))
      (theme.ui.bufferline.background (style))

      ;; Window border — keep subtle fg
      (theme.ui.window (fg-only fg-dim))

      ;; Picker highlight
      (theme.ui.highlight           (style))
      (theme.ui.background.separator (style))
      (theme.ui.highlight.frameline  (style))

      ;; Debug
      (theme.ui.debug.breakpoint (fg-only red))
      (theme.ui.debug.active     (fg-only green))

      ;; Inlay hints — dim
      (theme.ui.virtual.inlay-hint          (fg-only fg-dim))
      (theme.ui.virtual.inlay-hint.parameter (fg-only fg-dim))
      (theme.ui.virtual.inlay-hint.type     (fg-only fg-dim))))

;; ── Register ──────────────────────────────────────────────
(theme.register-theme woz-transparent)
