;; Woz theme for Helix
;; Color palette: Nord (https://www.nordtheme.com)
;;
;;   nord0  #2E3440  bg          background
;;   nord1  #3B4252  bg-alt      panels, statusline, gutter
;;   nord2  #434C5E  bg-hl       selection, cursorline
;;   nord3  #4C566A  fg-dim      comments, invisibles, guides
;;   nord4  #D8DEE9  fg          variables, constants, attributes
;;   nord5  #E5E9F0  —           (unused)
;;   nord6  #ECEFF4  fg-bright   plain text, brackets
;;   nord7  #8FBCBB  teal        types, classes, primitives
;;   nord8  #88C0D0  accent      functions, methods
;;   nord9  #81A1C1  accent-alt  keywords, operators, tags
;;   nord10 #5E81AC  accent-dim  preprocessor, pragmas
;;   nord11 #BF616A  red         errors, diff deletions
;;   nord12 #D08770  orange      annotations, decorators, numbers
;;   nord13 #EBCB8B  yellow      warnings, escape chars, regex
;;   nord14 #A3BE8C  green       strings, diff additions
;;   nord15 #B48EAD  purple      numeric constants
(require "helix/components.scm")
(require (prefix-in theme. "helix/themes.scm"))

;; ── Palette ───────────────────────────────────────────────
(define bg          "#2E3440")  ; nord0 - background
(define bg-alt      "#3B4252")  ; nord1 - panels, statusline, gutter
(define bg-hl       "#434C5E")  ; nord2 - selection, cursorline
(define bg-line     "#3B4252")  ; nord1 - cursor line

(define fg          "#D8DEE9")  ; nord4 - variables, constants, fields
(define fg-dim      "#4C566A")  ; nord3 - comments, guides
(define fg-bright   "#ECEFF4")  ; nord6 - brackets, plain text

(define accent      "#88C0D0")  ; nord8 - functions, methods
(define accent-alt  "#81A1C1")  ; nord9 - keywords, operators, tags
(define accent-dim  "#5E81AC")  ; nord10 - preprocessor, pragmas

(define teal        "#8FBCBB")  ; nord7 - types, classes
(define green       "#A3BE8C")  ; nord14 - strings
(define orange      "#D08770")  ; nord12 - annotations, decorators
(define red         "#BF616A")  ; nord11 - errors
(define purple      "#B48EAD")  ; nord15 - numeric constants
(define yellow      "#EBCB8B")  ; nord13 - warnings, escape chars

;; ── Helpers ───────────────────────────────────────────────
(define (fg-color color)
  (~> (style) (style-fg (theme.string->color color))))

(define (bg-color color)
  (~> (style) (style-bg (theme.string->color color))))

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
   "ui.virtual.indent-guide"   (hash 'fg fg-dim)
   "ui.virtual.ruler"          (hash 'fg bg-hl)
   "ui.virtual.inlay-hint"     (hash 'fg fg-dim)
   "ui.virtual.inlay-hint.parameter" (hash 'fg fg-dim)
   "ui.virtual.inlay-hint.type"     (hash 'fg accent-dim)
   "ui.virtual.wrap"           (hash 'fg fg-dim)
   "ui.virtual.jump-label"     (hash 'fg accent)

   ;; ── Menus / Completion ──
   "ui.menu"         (hash 'bg bg-alt)
   "ui.menu.selected" (hash 'bg bg-hl)
   "ui.menu.scroll"  (hash 'fg fg-dim)

   ;; ── Diagnostics ──
   "error"      (hash 'fg red)
   "warning"    (hash 'fg yellow)
   "info"       (hash 'fg accent)
   "hint"       (hash 'fg fg-dim)
   "diagnostic.error"        (hash 'fg red)
   "diagnostic.warning"      (hash 'fg yellow)
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
   "keyword"                  (hash 'fg accent-alt)
   "keyword.control"          (hash 'fg accent-alt)
   "keyword.control.conditional" (hash 'fg accent-alt)
   "keyword.control.repeat"   (hash 'fg accent-alt)
   "keyword.control.import"   (hash 'fg accent-alt)
   "keyword.control.return"   (hash 'fg accent-alt)
   "keyword.control.exception" (hash 'fg red)
   "keyword.operator"         (hash 'fg accent-alt)
   "keyword.directive"        (hash 'fg accent-dim)
   "keyword.function"         (hash 'fg accent)
   "keyword.storage"          (hash 'fg accent-alt)
   "keyword.storage.type"     (hash 'fg accent-alt)
   "keyword.storage.modifier" (hash 'fg accent-alt)

   ;; ── Syntax: Functions ──
   "function"              (hash 'fg accent)
   "function.builtin"      (hash 'fg accent)
   "function.method"       (hash 'fg accent)
   "function.method.private" (hash 'fg accent)
   "function.macro"        (hash 'fg accent-alt)
   "function.special"      (hash 'fg accent-dim)

   ;; ── Syntax: Types ──
   "type"             (hash 'fg teal)
   "type.builtin"     (hash 'fg teal)
   "type.parameter"   (hash 'fg teal)
   "type.enum"        (hash 'fg teal)
   "type.enum.variant" (hash 'fg accent)

   ;; ── Syntax: Variables ──
   "variable"                 (hash 'fg fg)
   "variable.builtin"         (hash 'fg fg)
   "variable.parameter"       (hash 'fg fg)
   "variable.other"           (hash 'fg fg)
   "variable.other.member"    (hash 'fg fg)
   "variable.other.member.private" (hash 'fg fg)

   ;; ── Syntax: Constants / Strings ──
   "constant"               (hash 'fg fg)
   "constant.builtin"       (hash 'fg purple)
   "constant.builtin.boolean" (hash 'fg purple)
   "constant.character"     (hash 'fg green)
   "constant.character.escape" (hash 'fg yellow)
   "constant.numeric"       (hash 'fg purple)
   "constant.numeric.integer" (hash 'fg purple)
   "constant.numeric.float" (hash 'fg purple)
   "string"                 (hash 'fg green)
   "string.regexp"          (hash 'fg yellow)
   "string.special"         (hash 'fg green)
   "string.special.path"    (hash 'fg green)
   "string.special.url"     (hash 'fg accent)
   "string.special.symbol"  (hash 'fg green)

   ;; ── Syntax: Constructor / Namespace ──
   "constructor" (hash 'fg accent)
   "namespace"   (hash 'fg teal)

   ;; ── Syntax: Punctuation ──
   "punctuation"         (hash 'fg fg-bright)
   "punctuation.delimiter" (hash 'fg fg-bright)
   "punctuation.bracket" (hash 'fg fg-bright)
   "punctuation.special" (hash 'fg accent-alt)

   ;; ── Syntax: Operators ──
   "operator" (hash 'fg accent-alt)

   ;; ── Syntax: Tags ──
   "tag"         (hash 'fg accent-alt)
   "tag.builtin" (hash 'fg accent-alt)

   ;; ── Syntax: Labels / Attributes / Special ──
   "label"     (hash 'fg orange)
   "attribute" (hash 'fg fg)
   "special"   (hash 'fg accent-dim)

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
   "markup.link"           (hash 'fg accent)
   "markup.link.url"       (hash 'fg accent)
   "markup.link.label"     (hash 'fg accent-alt)
   "markup.link.text"      (hash 'fg fg)
   "markup.quote"          (hash 'fg fg-dim)
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
   "diff.delta.moved"  (hash 'fg accent)
   "diff.delta.conflict" (hash 'fg red)
   "diff.delta.gutter" (hash 'fg yellow)))

;; ── Create SteelTheme object ──────────────────────────────
(define woz-theme (theme.hashmap->theme "woz" woz-hash))

;; ── Additional chained styles (italic, bold) ──────────────
(~> woz-theme
    (theme.comment          (fg+italic fg-dim))
    (theme.keyword          (fg+bold accent-alt))
    (theme.keyword.control  (fg+bold accent-alt))
    (theme.function.builtin (fg+italic accent))
    (theme.markup.bold      (fg+bold fg-bright))
    (theme.markup.italic    (fg+italic fg))
    (theme.markup.heading   (fg+bold accent)))

;; ── Register ──────────────────────────────────────────────
(theme.register-theme woz-theme)
