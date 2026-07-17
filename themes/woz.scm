;; Woz — standard theme with solid Nord backgrounds
(require "helix/components.scm")
(require (prefix-in theme. "helix/themes.scm"))
(require "themes/base.scm")

;; ── UI hash (woz-specific: solid backgrounds) ─────────────
(define woz-ui-hash
  (hash
   "ui.background" (hash 'bg bg)
   "ui.text"       (hash 'fg fg)

   "ui.cursor"              (hash 'fg fg)
   "ui.cursor.normal"       (hash 'fg fg)
   "ui.cursor.insert"       (hash 'fg fg)
   "ui.cursor.select"       (hash 'fg fg)
   "ui.cursor.primary"      (hash 'fg fg-bright)
   "ui.cursor.primary.normal" (hash 'fg fg-bright)
   "ui.cursor.primary.select" (hash 'fg fg-bright)
   "ui.cursor.match"        (hash 'fg accent)
   "ui.selection"           (hash 'bg bg-hl)
   "ui.selection.primary"   (hash 'bg bg-alt)

   "ui.linenr"          (hash 'fg fg-dim)
   "ui.linenr.selected" (hash 'fg fg)
   "ui.gutter"          (hash 'bg bg)
   "ui.gutter.selected" (hash 'bg bg-alt)

   "ui.cursorline"         (hash 'bg bg-alt)
   "ui.cursorline.primary" (hash 'bg bg-alt)

   "ui.statusline"            (hash 'bg bg-alt)
   "ui.statusline.inactive"   (hash 'bg bg)
   "ui.statusline.normal"     (hash 'bg accent-dim)
   "ui.statusline.insert"     (hash 'bg accent-alt)
   "ui.statusline.select"     (hash 'bg purple)
   "ui.statusline.separator"  (hash 'fg fg-dim)
   "ui.bufferline"            (hash 'bg bg-alt)
   "ui.bufferline.active"     (hash 'bg bg-hl 'fg fg)
   "ui.bufferline.background" (hash 'bg bg)
   "ui.window"                (hash 'fg fg-dim)
   "ui.popup"                 (hash 'bg bg-alt)
   "ui.popup.info"            (hash 'bg bg-alt)
   "ui.help"                  (hash 'bg bg-alt)
   "ui.text.focus"            (hash 'fg fg)
   "ui.text.info"             (hash 'fg accent)
   "ui.text.inactive"         (hash 'fg fg-dim)
   "ui.text.directory"        (hash 'fg accent-alt)

   "ui.virtual.whitespace"     (hash 'fg fg-dim)
   "ui.virtual.indent-guide"   (hash 'fg fg-dim)
   "ui.virtual.ruler"          (hash 'fg bg-hl)
   "ui.virtual.inlay-hint"     (hash 'fg fg-dim)
   "ui.virtual.inlay-hint.parameter" (hash 'fg fg-dim)
   "ui.virtual.inlay-hint.type"     (hash 'fg accent-dim)
   "ui.virtual.wrap"           (hash 'fg fg-dim)
   "ui.virtual.jump-label"     (hash 'fg accent)

   "ui.menu"         (hash 'bg bg-alt)
   "ui.menu.selected" (hash 'bg bg-hl)
   "ui.menu.scroll"  (hash 'fg fg-dim)

   "ui.debug.breakpoint"  (hash 'fg red)
   "ui.debug.active"      (hash 'fg green)

   "ui.highlight"           (hash 'bg bg-alt)
   "ui.background.separator" (hash 'bg bg-alt)))

;; ── Assemble theme ────────────────────────────────────────
(define woz-hash (hash-union nord-syntax-hash woz-ui-hash))
(define woz-theme (theme.hashmap->theme "woz" woz-hash))

;; ── Chained styles (italic, bold) ─────────────────────────
(~> woz-theme
    (theme.comment          (fg+italic fg-dim))
    (theme.keyword          (fg+bold accent-alt))
    (theme.keyword.control  (fg+bold accent-alt))
    (theme.function.builtin (fg+italic accent))
    (theme.markup.bold      (fg+bold fg-bright))
    (theme.markup.italic    (fg+italic fg))
    (theme.markup.heading   (fg+bold accent)))

(theme.register-theme woz-theme)
