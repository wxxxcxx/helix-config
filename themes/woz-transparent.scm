;; Woz Transparent — transparent-background variant of woz
(require "helix/components.scm")
(require (prefix-in theme. "helix/themes.scm"))
(require "themes/base.scm")

;; ── UI hash (transparent: no backgrounds, fg-only) ────────
(define woz-tp-ui-hash
  (hash
   "ui.text"  (hash 'fg fg)

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

   "ui.statusline.normal"   (hash 'fg fg-bright)
   "ui.statusline.insert"   (hash 'fg fg-bright)
   "ui.statusline.select"   (hash 'fg fg-bright)
   "ui.statusline.separator" (hash 'fg fg-dim)

   "ui.text.focus"     (hash 'fg fg)
   "ui.text.info"      (hash 'fg accent)
   "ui.text.inactive"  (hash 'fg fg-dim)
   "ui.text.directory" (hash 'fg accent-alt)

   "ui.virtual.whitespace"     (hash 'fg fg-dim)
   "ui.virtual.indent-guide"   (hash 'fg fg-dim)
   "ui.virtual.inlay-hint"     (hash 'fg fg-dim)
   "ui.virtual.inlay-hint.parameter" (hash 'fg fg-dim)
   "ui.virtual.inlay-hint.type"     (hash 'fg accent-dim)
   "ui.virtual.wrap"           (hash 'fg fg-dim)
   "ui.virtual.jump-label"     (hash 'fg accent)
   "ui.virtual.ruler"          (hash 'fg fg-dim)

   "ui.window"      (hash 'fg fg-dim)
   "ui.menu.scroll" (hash 'fg fg-dim)))

;; ── Assemble theme ────────────────────────────────────────
(define woz-tp-hash (hash-union nord-syntax-hash woz-tp-ui-hash))
(define woz-transparent (theme.hashmap->theme "woz-transparent" woz-tp-hash))

;; ── Chained styles (italic, bold) ─────────────────────────
(~> woz-transparent
    (theme.comment          (fg+italic fg-dim))
    (theme.keyword          (fg+bold accent-alt))
    (theme.keyword.control  (fg+bold accent-alt))
    (theme.function.builtin (fg+italic accent))
    (theme.markup.bold      (fg+bold fg-bright))
    (theme.markup.italic    (fg+italic fg))
    (theme.markup.heading   (fg+bold accent)))

(theme.register-theme woz-transparent)
