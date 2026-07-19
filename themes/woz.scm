;; Woz — transparent-background theme (Nord palette)
;;

(require "helix/components.scm")
(require (prefix-in theme. "helix/themes.scm"))

;; ── Palette ───────────────────────────────────────────────
(define bg          "#2E3440")
(define bg-alt      "#464f62")
(define bg-hl       "#546075")
(define fg          "#D8DEE9")
(define fg-dim      "#4C566A")
(define fg-bright   "#ECEFF4")
(define accent      "#88C0D0")
(define accent-alt  "#81A1C1")
(define accent-dim  "#5E81AC")
(define teal        "#8FBCBB")
(define green       "#A3BE8C")
(define orange      "#D08770")
(define red         "#BF616A")
(define purple      "#B48EAD")
(define yellow      "#EBCB8B")

;; ── Helpers ───────────────────────────────────────────────
(define (mk-style-fg color)
  (~> (style) (style-fg (theme.string->color color))))

(define (mk-style-bg color)
  (~> (style) (style-bg (theme.string->color color))))

(define (fg+italic color)
  (~> (style)
      (style-fg (theme.string->color color))
      style-with-italics))

(define (fg+bold color)
  (~> (style)
      (style-fg (theme.string->color color))
      style-with-bold))

;; ── Syntax hash ───────────────────────────────────────────
(define nord-syntax-hash
  (hash

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

   ;; ── Syntax: comments ──
   "comment"                    (hash 'fg fg-dim)
   "comment.line"               (hash 'fg fg-dim)
   "comment.block"              (hash 'fg fg-dim)
   "comment.block.documentation" (hash 'fg fg-dim)

   ;; ── Syntax: keywords ──
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

   ;; ── Syntax: functions ──
   "function"              (hash 'fg accent)
   "function.builtin"      (hash 'fg accent)
   "function.method"       (hash 'fg accent)
   "function.method.private" (hash 'fg accent)
   "function.macro"        (hash 'fg accent-alt)
   "function.special"      (hash 'fg accent-dim)

   ;; ── Syntax: types ──
   "type"             (hash 'fg teal)
   "type.builtin"     (hash 'fg teal)
   "type.parameter"   (hash 'fg teal)
   "type.enum"        (hash 'fg teal)
   "type.enum.variant" (hash 'fg accent)

   ;; ── Syntax: variables ──
   "variable"                 (hash 'fg fg)
   "variable.builtin"         (hash 'fg fg)
   "variable.parameter"       (hash 'fg fg)
   "variable.other"           (hash 'fg fg)
   "variable.other.member"    (hash 'fg fg)
   "variable.other.member.private" (hash 'fg fg)

   ;; ── Syntax: constants / strings ──
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

   ;; ── Syntax: constructor / namespace ──
   "constructor" (hash 'fg accent)
   "namespace"   (hash 'fg teal)

   ;; ── Syntax: punctuation ──
   "punctuation"         (hash 'fg fg-bright)
   "punctuation.delimiter" (hash 'fg fg-bright)
   "punctuation.bracket" (hash 'fg fg-bright)
   "punctuation.special" (hash 'fg accent-alt)

   ;; ── Syntax: operators ──
   "operator" (hash 'fg accent-alt)

   ;; ── Syntax: tags ──
   "tag"         (hash 'fg accent-alt)
   "tag.builtin" (hash 'fg accent-alt)

   ;; ── Syntax: labels / attributes / special ──
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

   ;; ── Markup: completion / hover ──
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

;; ── UI hash (transparent backgrounds, opaque cursor/select) ──
(define woz-ui-hash
  (hash
   ;; Root — no bg = transparent
   "ui.background" (hash 'fg fg)

   "ui.text"  (hash 'fg fg)
   "ui.text.focus"     (hash 'fg fg)
   "ui.text.info"      (hash 'fg accent)
   "ui.text.inactive"  (hash 'fg fg-dim)
   "ui.text.directory" (hash 'fg accent-alt)

   ;; ── Mode: Normal (accent tones) ──
    "ui.cursor.normal"          (hash 'fg fg       'bg accent-dim)
    "ui.cursor.primary.normal"  (hash 'fg fg-bright 'bg accent)
    "ui.statusline.normal"      (hash 'fg accent)
    "ui.mode.normal"            (hash 'fg accent)

   ;; ── Mode: Insert (purple tones) ──
    "ui.cursor.insert"          (hash 'fg fg       'bg purple)
    "ui.cursor.primary.insert"  (hash 'fg fg-bright 'bg purple)
    "ui.statusline.insert"      (hash 'fg purple)

   ;; ── Mode: Select (green tones) ──
    "ui.cursor.select"          (hash 'fg fg       'bg green)
    "ui.cursor.primary.select"  (hash 'fg fg-bright 'bg accent)
    "ui.statusline.select"      (hash 'fg green)

   ;; Cursor — fallback / generic
    "ui.cursor"              (hash 'fg fg       'bg accent-dim)
    "ui.cursor.primary"      (hash 'fg fg-bright 'bg accent)
    "ui.cursor.match"        (hash 'fg accent   'bg bg-hl)

   ;; Selection — dim green, matching select cursor hue
    "ui.selection"         (hash 'bg bg-alt)
    "ui.selection.primary" (hash 'bg bg-hl)

   ;; Line numbers — transparent bg
    "ui.linenr"          (hash 'fg fg-dim)
    "ui.linenr.selected" (hash 'fg fg)

   ;; Status line separator
    "ui.statusline.separator" (hash 'fg fg-dim)

   ;; Virtual text — transparent bg
   "ui.virtual.whitespace"     (hash 'fg fg-dim)
   "ui.virtual.indent-guide"   (hash 'fg fg-dim)
   "ui.virtual.inlay-hint"     (hash 'fg fg-dim)
   "ui.virtual.inlay-hint.parameter" (hash 'fg fg-dim)
   "ui.virtual.inlay-hint.type"     (hash 'fg accent-dim)
   "ui.virtual.wrap"           (hash 'fg fg-dim)
   "ui.virtual.jump-label"     (hash 'fg accent)
   "ui.virtual.ruler"          (hash 'fg fg-dim)

   ;; Window, popup, menu — transparent bg
   "ui.window"      (hash 'fg fg-dim)
   "ui.popup"       (hash 'fg fg)
   "ui.menu"        (hash 'fg fg)
   "ui.menu.scroll" (hash 'fg fg-dim)))

;; ── Assemble theme ────────────────────────────────────────
(define woz-hash (hash-union nord-syntax-hash woz-ui-hash))
(define woz-theme (theme.hashmap->theme "woz" woz-hash))

;; ── Chained styles (italic, bold) ─────────────────────────
;; Bold — structural / emphatic elements
(~> woz-theme
    (theme.comment                (fg+italic fg-dim))
    (theme.comment.block.documentation (fg+italic fg-dim))
    (theme.keyword                (fg+bold accent-alt))
    (theme.keyword.control        (fg+bold accent-alt))
    (theme.keyword.storage.type   (fg+bold accent-alt))
    (theme.keyword.storage.modifier (fg+bold accent-alt))
    (theme.function.builtin       (fg+italic accent))
    (theme.type.builtin           (fg+bold teal))
    (theme.constant.builtin       (fg+bold purple))
    (theme.variable.parameter     (fg+italic fg))
    (theme.variable.builtin       (fg+italic accent))
    (theme.type.parameter         (fg+italic teal))
    (theme.string.regexp          (fg+italic yellow))
    (theme.markup.bold            (fg+bold fg-bright))
    (theme.markup.italic          (fg+italic fg))
    (theme.markup.heading         (fg+bold accent))
    (theme.markup.list.checked    (fg+bold green))
    (theme.markup.link.url        (fg+italic accent))
    (theme.markup.raw.inline      (fg+italic green)))

(theme.register-theme woz-theme)
