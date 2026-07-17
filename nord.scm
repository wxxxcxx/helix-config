;; Nord theme for Helix
;; Based on the Nord color palette: https://www.nordtheme.com
(require "helix/components.scm")
(require (prefix-in theme. "helix/themes.scm"))

;; ── Palette ───────────────────────────────────────────────
;; Polar Night
(define nord0 "#2E3440")   ; darkest background
(define nord1 "#3B4252")   ; darker UI
(define nord2 "#434C5E")   ; selection, gutter
(define nord3 "#4C566A")   ; comments, invisibles
;; Snow Storm
(define nord4 "#D8DEE9")   ; default text
(define nord5 "#E5E9F0")   ; lighter
(define nord6 "#ECEFF4")   ; lightest
;; Frost
(define nord7 "#8FBCBB")   ; teal
(define nord8 "#88C0D0")   ; light blue
(define nord9 "#81A1C1")   ; medium blue
(define nord10 "#5E81AC")  ; dark blue
;; Aurora
(define nord11 "#BF616A")  ; red
(define nord12 "#D08770")  ; orange
(define nord13 "#EBCB8B")  ; yellow
(define nord14 "#A3BE8C")  ; green
(define nord15 "#B48EAD")  ; purple

;; ── Helpers ───────────────────────────────────────────────
(define (fg color)
  (~> (style) (style-fg (theme.string->color color))))

(define (fg+bg fg-color bg-color)
  (~> (style)
      (style-fg (theme.string->color fg-color))
      (style-bg (theme.string->color bg-color))))

(define (fg+italic color)
  (~> (style)
      (style-fg (theme.string->color color))
      style-with-italics))

(define (fg+bold color)
  (~> (style)
      (style-fg (theme.string->color color))
      style-with-bold))

;; ── Build initial theme from hash ─────────────────────────
(define nord-hash
  (hash

   ;; ── Base ──
   "ui.background" (hash 'bg nord0)
   "ui.text"       (hash 'fg nord4)

   ;; ── Cursor / Selection ──
   "ui.cursor"              (hash 'fg nord4)
   "ui.cursor.normal"       (hash 'fg nord4)
   "ui.cursor.insert"       (hash 'fg nord4)
   "ui.cursor.select"       (hash 'fg nord4)
   "ui.cursor.primary"      (hash 'fg nord6)
   "ui.cursor.primary.normal" (hash 'fg nord6)
   "ui.cursor.primary.select" (hash 'fg nord6)
   "ui.cursor.match"        (hash 'fg nord8)
   "ui.selection"           (hash 'bg nord2)
   "ui.selection.primary"   (hash 'bg nord1)

   ;; ── Line numbers / Gutter ──
   "ui.linenr"          (hash 'fg nord3)
   "ui.linenr.selected" (hash 'fg nord4)
   "ui.gutter"          (hash 'bg nord0)
   "ui.gutter.selected" (hash 'bg nord1)

   ;; ── Cursor line ──
   "ui.cursorline"         (hash 'bg nord1)
   "ui.cursorline.primary" (hash 'bg nord1)

   ;; ── UI Elements ──
   "ui.statusline"            (hash 'bg nord1)
   "ui.statusline.inactive"   (hash 'bg nord0)
   "ui.statusline.normal"     (hash 'bg nord10)
   "ui.statusline.insert"     (hash 'bg nord9)
   "ui.statusline.select"     (hash 'bg nord15)
   "ui.statusline.separator"  (hash 'fg nord3)
   "ui.bufferline"            (hash 'bg nord1)
   "ui.bufferline.active"     (hash 'bg nord2 'fg nord4)
   "ui.bufferline.background" (hash 'bg nord0)
   "ui.window"                (hash 'fg nord3)
   "ui.popup"                 (hash 'bg nord1)
   "ui.popup.info"            (hash 'bg nord1)
   "ui.help"                  (hash 'bg nord1)
   "ui.text.focus"            (hash 'fg nord4)
   "ui.text.info"             (hash 'fg nord8)
   "ui.text.inactive"         (hash 'fg nord3)
   "ui.text.directory"        (hash 'fg nord9)

   ;; ── Virtual / Whitespace ──
   "ui.virtual.whitespace"     (hash 'fg nord3)
   "ui.virtual.indent-guide"   (hash 'fg nord1)
   "ui.virtual.ruler"          (hash 'fg nord1)
   "ui.virtual.inlay-hint"     (hash 'fg nord3)
   "ui.virtual.inlay-hint.parameter" (hash 'fg nord3)
   "ui.virtual.inlay-hint.type"     (hash 'fg nord10)
   "ui.virtual.wrap"           (hash 'fg nord3)
   "ui.virtual.jump-label"     (hash 'fg nord14)

   ;; ── Menus / Completion ──
   "ui.menu"         (hash 'bg nord1)
   "ui.menu.selected" (hash 'bg nord2)
   "ui.menu.scroll"  (hash 'fg nord3)

   ;; ── Diagnostics ──
   "error"      (hash 'fg nord11)
   "warning"    (hash 'fg nord12)
   "info"       (hash 'fg nord8)
   "hint"       (hash 'fg nord3)
   "diagnostic.error"        (hash 'fg nord11)
   "diagnostic.warning"      (hash 'fg nord12)
   "diagnostic.info"         (hash 'fg nord8)
   "diagnostic.hint"         (hash 'fg nord3)
   "diagnostic.unnecessary"  (hash 'fg nord3)
   "diagnostic.deprecated"   (hash 'fg nord3)

   ;; ── Debug ──
   "ui.debug.breakpoint"  (hash 'fg nord11)
   "ui.debug.active"      (hash 'fg nord14)

   ;; ── Highlight / Picker ──
   "ui.highlight"           (hash 'bg nord1)
   "ui.background.separator" (hash 'bg nord1)

   ;; ── Syntax: Comments ──
   "comment"                    (hash 'fg nord3)
   "comment.line"               (hash 'fg nord3)
   "comment.block"              (hash 'fg nord3)
   "comment.block.documentation" (hash 'fg nord3)

   ;; ── Syntax: Keywords ──
   "keyword"                  (hash 'fg nord7)
   "keyword.control"          (hash 'fg nord7)
   "keyword.control.conditional" (hash 'fg nord7)
   "keyword.control.repeat"   (hash 'fg nord7)
   "keyword.control.import"   (hash 'fg nord7)
   "keyword.control.return"   (hash 'fg nord7)
   "keyword.control.exception" (hash 'fg nord11)
   "keyword.operator"         (hash 'fg nord7)
   "keyword.directive"        (hash 'fg nord15)
   "keyword.function"         (hash 'fg nord8)
   "keyword.storage"          (hash 'fg nord7)
   "keyword.storage.type"     (hash 'fg nord7)
   "keyword.storage.modifier" (hash 'fg nord7)

   ;; ── Syntax: Functions ──
   "function"              (hash 'fg nord9)
   "function.builtin"      (hash 'fg nord8)
   "function.method"       (hash 'fg nord9)
   "function.method.private" (hash 'fg nord9)
   "function.macro"        (hash 'fg nord15)
   "function.special"      (hash 'fg nord15)

   ;; ── Syntax: Types ──
   "type"             (hash 'fg nord10)
   "type.builtin"     (hash 'fg nord10)
   "type.parameter"   (hash 'fg nord4)
   "type.enum"        (hash 'fg nord10)
   "type.enum.variant" (hash 'fg nord9)

   ;; ── Syntax: Variables ──
   "variable"                 (hash 'fg nord4)
   "variable.builtin"         (hash 'fg nord8)
   "variable.parameter"       (hash 'fg nord4)
   "variable.other"           (hash 'fg nord4)
   "variable.other.member"    (hash 'fg nord4)
   "variable.other.member.private" (hash 'fg nord4)

   ;; ── Syntax: Constants / Strings ──
   "constant"               (hash 'fg nord7)
   "constant.builtin"       (hash 'fg nord7)
   "constant.builtin.boolean" (hash 'fg nord7)
   "constant.character"     (hash 'fg nord14)
   "constant.character.escape" (hash 'fg nord7)
   "constant.numeric"       (hash 'fg nord12)
   "constant.numeric.integer" (hash 'fg nord12)
   "constant.numeric.float" (hash 'fg nord12)
   "string"                 (hash 'fg nord14)
   "string.regexp"          (hash 'fg nord7)
   "string.special"         (hash 'fg nord7)
   "string.special.path"    (hash 'fg nord14)
   "string.special.url"     (hash 'fg nord9)
   "string.special.symbol"  (hash 'fg nord7)

   ;; ── Syntax: Constructor / Namespace ──
   "constructor" (hash 'fg nord9)
   "namespace"   (hash 'fg nord10)

   ;; ── Syntax: Punctuation ──
   "punctuation"         (hash 'fg nord4)
   "punctuation.delimiter" (hash 'fg nord4)
   "punctuation.bracket" (hash 'fg nord4)
   "punctuation.special" (hash 'fg nord7)

   ;; ── Syntax: Operators ──
   "operator" (hash 'fg nord7)

   ;; ── Syntax: Tags ──
   "tag"         (hash 'fg nord9)
   "tag.builtin" (hash 'fg nord9)

   ;; ── Syntax: Labels / Attributes / Special ──
   "label"     (hash 'fg nord12)
   "attribute" (hash 'fg nord13)
   "special"   (hash 'fg nord15)

   ;; ── Markup ──
   "markup"                (hash 'fg nord4)
   "markup.heading"        (hash 'fg nord8)
   "markup.heading.marker" (hash 'fg nord8)
   "markup.list"           (hash 'fg nord7)
   "markup.list.unnumbered" (hash 'fg nord7)
   "markup.list.numbered"  (hash 'fg nord12)
   "markup.list.checked"   (hash 'fg nord14)
   "markup.list.unchecked" (hash 'fg nord3)
   "markup.bold"           (hash 'fg nord6)
   "markup.italic"         (hash 'fg nord4)
   "markup.strikethrough"  (hash 'fg nord3)
   "markup.link"           (hash 'fg nord9)
   "markup.link.url"       (hash 'fg nord9)
   "markup.link.label"     (hash 'fg nord8)
   "markup.link.text"      (hash 'fg nord4)
   "markup.quote"          (hash 'fg nord7)
   "markup.raw"            (hash 'fg nord14)
   "markup.raw.inline"     (hash 'fg nord14)
   "markup.raw.block"      (hash 'fg nord14)

   ;; ── Markup: Completion / Hover ──
   "markup.normal.completion"    (hash 'fg nord4)
   "markup.normal.hover"         (hash 'fg nord4)
   "markup.heading.completion"   (hash 'fg nord8)
   "markup.heading.hover"        (hash 'fg nord8)
   "markup.raw.inline.completion" (hash 'fg nord14)
   "markup.raw.inline.hover"     (hash 'fg nord14)

   ;; ── Diff ──
   "diff"              (hash 'fg nord4)
   "diff.plus"         (hash 'fg nord14)
   "diff.plus.gutter"  (hash 'fg nord14)
   "diff.minus"        (hash 'fg nord11)
   "diff.minus.gutter" (hash 'fg nord11)
   "diff.delta"        (hash 'fg nord13)
   "diff.delta.moved"  (hash 'fg nord9)
   "diff.delta.conflict" (hash 'fg nord11)
   "diff.delta.gutter" (hash 'fg nord13)))

;; ── Create SteelTheme object ──────────────────────────────
(define nord-theme (theme.hashmap->theme "nord" nord-hash))

;; ── Additional chained styles (italic, bold, underline) ───
(~> nord-theme
    (theme.comment          (fg+italic nord3))
    (theme.keyword          (fg+bold nord7))
    (theme.keyword.control  (fg+bold nord7))
    (theme.function.builtin (fg+italic nord8))
    (theme.markup.bold      (fg+bold nord6))
    (theme.markup.italic    (fg+italic nord4))
    (theme.markup.heading.marker.1 (fg nord11))
    (theme.markup.heading.marker.2 (fg nord12))
    (theme.markup.heading.marker.3 (fg nord13))
    (theme.markup.heading.marker.4 (fg nord14))
    (theme.markup.heading.marker.5 (fg nord9))
    (theme.markup.heading.marker.6 (fg nord15)))

;; ── Register ──────────────────────────────────────────────
(theme.register-theme nord-theme)
