;; Woz theme for Helix
;; A warm, earthy theme inspired by classic computing
(require "helix/components.scm")
(require (prefix-in theme. "helix/themes.scm"))

;; ── Palette ───────────────────────────────────────────────
(define bg          "#1a1b2f")  ; deep navy background
(define bg-alt      "#232540")  ; alt background (panels)
(define bg-hl       "#2d2f4a")  ; highlight / selection
(define bg-line     "#252740")  ; cursor line

(define fg          "#c9d1e6")  ; default text
(define fg-dim      "#6b7194")  ; dim text (comments, inlay)
(define fg-bright   "#e2e8f5")  ; bright text (cursor primary)

(define accent      "#7eb8d6")  ; keywords, control flow
(define accent-alt  "#5fa5c0")  ; functions, methods
(define accent-dim  "#4a7a94")  ; types, namespaces

(define teal        "#6fc1b0")  ; strings, constants
(define green       "#9bc07a")  ; string chars, diff added
(define orange      "#e2a66d")  ; numbers
(define red         "#e26d6d")  ; errors, diff removed
(define purple      "#b889c9")  ; macros, directives, special
(define yellow      "#e2c76d")  ; attributes, diff delta
(define blue        "#76a9d6")  ; info, links

;; ── Helpers ───────────────────────────────────────────────
(define (fg-color color)
  (~> (style) (style-fg (theme.string->color color))))

(define (bg-color color)
  (~> (style) (style-bg (theme.string->color color))))

(define (fg+bg fg-c bg-c)
  (~> (style)
      (style-fg (theme.string->color fg-c))
      (style-bg (theme.string->color bg-c))))

(define (fg+italic color)
  (~> (style)
      (style-fg (theme.string->color color))
      style-with-italics))

(define (fg+bold color)
  (~> (style)
      (style-fg (theme.string->color color))
      style-with-bold))

;; ── Build initial theme from hash ─────────────────────────
(define woz-hash
  (hash

   ;; ── Base ──
   "ui.background" (hash 'bg bg)
   "ui.text"       (hash 'fg fg)

   ;; ── Cursor / Selection ──
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

   ;; ── Line numbers / Gutter ──
   "ui.linenr"          (hash 'fg fg-dim)
   "ui.linenr.selected" (hash 'fg fg)
   "ui.gutter"          (hash 'bg bg)
   "ui.gutter.selected" (hash 'bg bg-alt)

   ;; ── Cursor line ──
   "ui.cursorline"         (hash 'bg bg-line)
   "ui.cursorline.primary" (hash 'bg bg-line)

   ;; ── UI Elements ──
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

   ;; ── Virtual / Whitespace ──
   "ui.virtual.whitespace"     (hash 'fg fg-dim)
   "ui.virtual.indent-guide"   (hash 'fg bg-hl)
   "ui.virtual.ruler"          (hash 'fg bg-hl)
   "ui.virtual.inlay-hint"     (hash 'fg fg-dim)
   "ui.virtual.inlay-hint.parameter" (hash 'fg fg-dim)
   "ui.virtual.inlay-hint.type"     (hash 'fg accent-dim)
   "ui.virtual.wrap"           (hash 'fg fg-dim)
   "ui.virtual.jump-label"     (hash 'fg green)

   ;; ── Menus / Completion ──
   "ui.menu"         (hash 'bg bg-alt)
   "ui.menu.selected" (hash 'bg bg-hl)
   "ui.menu.scroll"  (hash 'fg fg-dim)

   ;; ── Diagnostics ──
   "error"      (hash 'fg red)
   "warning"    (hash 'fg orange)
   "info"       (hash 'fg accent)
   "hint"       (hash 'fg fg-dim)
   "diagnostic.error"        (hash 'fg red)
   "diagnostic.warning"      (hash 'fg orange)
   "diagnostic.info"         (hash 'fg accent)
   "diagnostic.hint"         (hash 'fg fg-dim)
   "diagnostic.unnecessary"  (hash 'fg fg-dim)
   "diagnostic.deprecated"   (hash 'fg fg-dim)

   ;; ── Debug ──
   "ui.debug.breakpoint"  (hash 'fg red)
   "ui.debug.active"      (hash 'fg green)

   ;; ── Highlight / Picker ──
   "ui.highlight"           (hash 'bg bg-alt)
   "ui.background.separator" (hash 'bg bg-alt)

   ;; ── Syntax: Comments ──
   "comment"                    (hash 'fg fg-dim)
   "comment.line"               (hash 'fg fg-dim)
   "comment.block"              (hash 'fg fg-dim)
   "comment.block.documentation" (hash 'fg fg-dim)

   ;; ── Syntax: Keywords ──
   "keyword"                  (hash 'fg accent)
   "keyword.control"          (hash 'fg accent)
   "keyword.control.conditional" (hash 'fg accent)
   "keyword.control.repeat"   (hash 'fg accent)
   "keyword.control.import"   (hash 'fg accent)
   "keyword.control.return"   (hash 'fg accent)
   "keyword.control.exception" (hash 'fg red)
   "keyword.operator"         (hash 'fg accent)
   "keyword.directive"        (hash 'fg purple)
   "keyword.function"         (hash 'fg accent)
   "keyword.storage"          (hash 'fg accent)
   "keyword.storage.type"     (hash 'fg accent)
   "keyword.storage.modifier" (hash 'fg accent)

   ;; ── Syntax: Functions ──
   "function"              (hash 'fg accent-alt)
   "function.builtin"      (hash 'fg accent)
   "function.method"       (hash 'fg accent-alt)
   "function.method.private" (hash 'fg accent-alt)
   "function.macro"        (hash 'fg purple)
   "function.special"      (hash 'fg purple)

   ;; ── Syntax: Types ──
   "type"             (hash 'fg accent-dim)
   "type.builtin"     (hash 'fg accent-dim)
   "type.parameter"   (hash 'fg fg)
   "type.enum"        (hash 'fg accent-dim)
   "type.enum.variant" (hash 'fg accent-alt)

   ;; ── Syntax: Variables ──
   "variable"                 (hash 'fg fg)
   "variable.builtin"         (hash 'fg accent)
   "variable.parameter"       (hash 'fg fg)
   "variable.other"           (hash 'fg fg)
   "variable.other.member"    (hash 'fg fg)
   "variable.other.member.private" (hash 'fg fg)

   ;; ── Syntax: Constants / Strings ──
   "constant"               (hash 'fg teal)
   "constant.builtin"       (hash 'fg teal)
   "constant.builtin.boolean" (hash 'fg teal)
   "constant.character"     (hash 'fg green)
   "constant.character.escape" (hash 'fg teal)
   "constant.numeric"       (hash 'fg orange)
   "constant.numeric.integer" (hash 'fg orange)
   "constant.numeric.float" (hash 'fg orange)
   "string"                 (hash 'fg green)
   "string.regexp"          (hash 'fg teal)
   "string.special"         (hash 'fg teal)
   "string.special.path"    (hash 'fg green)
   "string.special.url"     (hash 'fg accent-alt)
   "string.special.symbol"  (hash 'fg teal)

   ;; ── Syntax: Constructor / Namespace ──
   "constructor" (hash 'fg accent-alt)
   "namespace"   (hash 'fg accent-dim)

   ;; ── Syntax: Punctuation ──
   "punctuation"         (hash 'fg fg)
   "punctuation.delimiter" (hash 'fg fg)
   "punctuation.bracket" (hash 'fg fg)
   "punctuation.special" (hash 'fg teal)

   ;; ── Syntax: Operators ──
   "operator" (hash 'fg accent)

   ;; ── Syntax: Tags ──
   "tag"         (hash 'fg accent-alt)
   "tag.builtin" (hash 'fg accent-alt)

   ;; ── Syntax: Labels / Attributes / Special ──
   "label"     (hash 'fg orange)
   "attribute" (hash 'fg yellow)
   "special"   (hash 'fg purple)

   ;; ── Markup ──
   "markup"                (hash 'fg fg)
   "markup.heading"        (hash 'fg accent)
   "markup.heading.marker" (hash 'fg accent)
   "markup.list"           (hash 'fg teal)
   "markup.list.unnumbered" (hash 'fg teal)
   "markup.list.numbered"  (hash 'fg orange)
   "markup.list.checked"   (hash 'fg green)
   "markup.list.unchecked" (hash 'fg fg-dim)
   "markup.bold"           (hash 'fg fg-bright)
   "markup.italic"         (hash 'fg fg)
   "markup.strikethrough"  (hash 'fg fg-dim)
   "markup.link"           (hash 'fg accent-alt)
   "markup.link.url"       (hash 'fg accent-alt)
   "markup.link.label"     (hash 'fg accent)
   "markup.link.text"      (hash 'fg fg)
   "markup.quote"          (hash 'fg teal)
   "markup.raw"            (hash 'fg green)
   "markup.raw.inline"     (hash 'fg green)
   "markup.raw.block"      (hash 'fg green)

   ;; ── Markup: Completion / Hover ──
   "markup.normal.completion"    (hash 'fg fg)
   "markup.normal.hover"         (hash 'fg fg)
   "markup.heading.completion"   (hash 'fg accent)
   "markup.heading.hover"        (hash 'fg accent)
   "markup.raw.inline.completion" (hash 'fg green)
   "markup.raw.inline.hover"     (hash 'fg green)

   ;; ── Diff ──
   "diff"              (hash 'fg fg)
   "diff.plus"         (hash 'fg green)
   "diff.plus.gutter"  (hash 'fg green)
   "diff.minus"        (hash 'fg red)
   "diff.minus.gutter" (hash 'fg red)
   "diff.delta"        (hash 'fg yellow)
   "diff.delta.moved"  (hash 'fg accent-alt)
   "diff.delta.conflict" (hash 'fg red)
   "diff.delta.gutter" (hash 'fg yellow)))

;; ── Create SteelTheme object ──────────────────────────────
(define woz-theme (theme.hashmap->theme "woz" woz-hash))

;; ── Additional chained styles (italic, bold) ──────────────
(~> woz-theme
    (theme.comment          (fg+italic fg-dim))
    (theme.keyword          (fg+bold accent))
    (theme.keyword.control  (fg+bold accent))
    (theme.function.builtin (fg+italic accent))
    (theme.markup.bold      (fg+bold fg-bright))
    (theme.markup.italic    (fg+italic fg)))

;; ── Register ──────────────────────────────────────────────
(theme.register-theme woz-theme)
