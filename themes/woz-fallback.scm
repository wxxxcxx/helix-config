;; Shared indexed/ANSI fallback theme builder.

(require (prefix-in theme. "helix/themes.scm"))

(provide make-woz-fallback-theme)

(define (make-woz-fallback-theme name palette)
  (define ansi?      (hash-get palette 'ansi?))
  (define bg         (hash-get palette 'bg))
  (define bg-alt     (hash-get palette 'bg-alt))
  (define bg-hl      (hash-get palette 'bg-hl))
  (define fg         (hash-get palette 'fg))
  (define fg-dim     (hash-get palette 'fg-dim))
  (define fg-bright  (hash-get palette 'fg-bright))
  (define accent     (hash-get palette 'accent))
  (define accent-alt (hash-get palette 'accent-alt))
  (define accent-dim (hash-get palette 'accent-dim))
  (define teal       (hash-get palette 'teal))
  (define green      (hash-get palette 'green))
  (define orange     (hash-get palette 'orange))
  (define red        (hash-get palette 'red))
  (define purple     (hash-get palette 'purple))
  (define yellow     (hash-get palette 'yellow))

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
   "comment"                    (hash 'fg fg-dim 'modifiers '("italic"))
   "comment.line"               (hash 'fg fg-dim 'modifiers '("italic"))
   "comment.block"              (hash 'fg fg-dim 'modifiers '("italic"))
   "comment.block.documentation" (hash 'fg fg-dim 'modifiers '("italic"))

   ;; ── Syntax: keywords ──
   "keyword"                  (hash 'fg accent-alt 'modifiers '("bold"))
   "keyword.control"          (hash 'fg accent-alt 'modifiers '("bold"))
   "keyword.control.conditional" (hash 'fg accent-alt 'modifiers '("bold"))
   "keyword.control.repeat"   (hash 'fg accent-alt 'modifiers '("bold"))
   "keyword.control.import"   (hash 'fg accent-alt 'modifiers '("bold"))
   "keyword.control.return"   (hash 'fg accent-alt 'modifiers '("bold"))
   "keyword.control.exception" (hash 'fg red 'modifiers '("bold"))
   "keyword.operator"         (hash 'fg accent-alt)
   "keyword.directive"        (hash 'fg accent-dim)
   "keyword.function"         (hash 'fg accent)
   "keyword.storage"          (hash 'fg accent-alt)
   "keyword.storage.type"     (hash 'fg accent-alt 'modifiers '("bold"))
   "keyword.storage.modifier" (hash 'fg accent-alt 'modifiers '("bold"))

   ;; ── Syntax: functions ──
   "function"              (hash 'fg accent)
   "function.builtin"      (hash 'fg accent 'modifiers '("italic"))
   "function.method"       (hash 'fg accent)
   "function.method.private" (hash 'fg accent)
   "function.macro"        (hash 'fg accent-alt)
   "function.special"      (hash 'fg accent-dim)

   ;; ── Syntax: types ──
   "type"             (hash 'fg teal)
   "type.builtin"     (hash 'fg teal 'modifiers '("bold"))
   "type.parameter"   (hash 'fg teal 'modifiers '("italic"))
   "type.enum"        (hash 'fg teal)
   "type.enum.variant" (hash 'fg accent)

   ;; ── Syntax: variables ──
   "variable"                 (hash 'fg fg)
   "variable.builtin"         (hash 'fg fg 'modifiers '("italic"))
   "variable.parameter"       (hash 'fg fg 'modifiers '("italic"))
   "variable.other"           (hash 'fg fg)
   "variable.other.member"    (hash 'fg fg)
   "variable.other.member.private" (hash 'fg fg)

   ;; ── Syntax: constants / strings ──
   "constant"               (hash 'fg fg)
   "constant.builtin"       (hash 'fg purple 'modifiers '("bold"))
   "constant.builtin.boolean" (hash 'fg purple 'modifiers '("bold"))
   "constant.character"     (hash 'fg green)
   "constant.character.escape" (hash 'fg yellow)
   "constant.numeric"       (hash 'fg purple)
   "constant.numeric.integer" (hash 'fg purple)
   "constant.numeric.float" (hash 'fg purple)
   "string"                 (hash 'fg green)
   "string.regexp"          (hash 'fg yellow 'modifiers '("italic"))
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
   "markup.heading"        (hash 'fg accent 'modifiers '("bold"))
   "markup.heading.marker" (hash 'fg accent)
   "markup.list"           (hash 'fg teal)
   "markup.list.unnumbered" (hash 'fg teal)
   "markup.list.numbered"  (hash 'fg orange)
   "markup.list.checked"   (hash 'fg green 'modifiers '("bold"))
   "markup.list.unchecked" (hash 'fg fg-dim)
   "markup.bold"           (hash 'fg fg-bright 'modifiers '("bold"))
   "markup.italic"         (hash 'fg fg 'modifiers '("italic"))
   "markup.strikethrough"  (hash 'fg fg-dim)
   "markup.link"           (hash 'fg accent)
   "markup.link.url"       (hash 'fg accent 'modifiers '("italic"))
   "markup.link.label"     (hash 'fg accent-alt)
   "markup.link.text"      (hash 'fg fg)
   "markup.quote"          (hash 'fg fg-dim)
   "markup.raw"            (hash 'fg green)
   "markup.raw.inline"     (hash 'fg green 'modifiers '("italic"))
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
   "ui.text.focus"     (if ansi?
                            (hash 'fg fg 'modifiers '("reversed"))
                            (hash 'fg fg 'bg bg-hl))
   "ui.text.info"      (hash 'fg accent)
   "ui.text.inactive"  (hash 'fg fg-dim)
   "ui.text.directory" (hash 'fg accent-alt)

   ;; ── Mode: Normal (accent tones) ──
    "ui.cursor.normal"          (if ansi?
                                    (hash 'fg accent-dim 'modifiers '("reversed"))
                                    (hash 'fg fg 'bg accent-dim))
    "ui.cursor.primary.normal"  (if ansi?
                                    (hash 'fg accent 'modifiers '("reversed" "bold"))
                                    (hash 'fg fg-bright 'bg accent))
    "ui.statusline.normal"      (hash 'fg accent)
    "ui.mode.normal"            (hash 'fg accent)

   ;; ── Mode: Insert (purple tones) ──
    "ui.cursor.insert"          (if ansi?
                                    (hash 'fg purple 'modifiers '("reversed"))
                                    (hash 'fg fg 'bg purple))
    "ui.cursor.primary.insert"  (if ansi?
                                    (hash 'fg purple 'modifiers '("reversed" "bold"))
                                    (hash 'fg fg-bright 'bg purple))
    "ui.statusline.insert"      (hash 'fg purple)

   ;; ── Mode: Select (green tones) ──
    "ui.cursor.select"          (if ansi?
                                    (hash 'fg green 'modifiers '("reversed"))
                                    (hash 'fg fg 'bg green))
    "ui.cursor.primary.select"  (if ansi?
                                    (hash 'fg green 'modifiers '("reversed" "bold"))
                                    (hash 'fg fg-bright 'bg accent))
    "ui.statusline.select"      (hash 'fg green)

   ;; Cursor — fallback / generic
   "ui.cursor"              (if ansi?
                                (hash 'fg accent-dim 'modifiers '("reversed"))
                                (hash 'fg fg 'bg accent-dim))
   "ui.cursor.primary"      (if ansi?
                                (hash 'fg accent 'modifiers '("reversed" "bold"))
                                (hash 'fg fg-bright 'bg accent))
   "ui.cursor.match"        (hash 'fg bg 'bg yellow 'modifiers '("bold"))
   "ui.cursorline"          (if ansi? (hash) (hash 'bg bg-alt))
   "ui.cursorline.primary"  (if ansi?
                                (hash 'modifiers '("underlined"))
                                (hash 'bg bg-hl))

   ;; Selection — dim green, matching select cursor hue
    "ui.selection"         (if ansi?
                                (hash 'modifiers '("reversed"))
                                (hash 'bg bg-alt))
    "ui.selection.primary" (if ansi?
                                (hash 'modifiers '("reversed" "bold"))
                                (hash 'bg bg-hl))

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

   ;; Window, popup, menu
   "ui.window"      (hash 'fg fg-dim)
   "ui.popup"       (hash 'fg fg)
   "ui.menu"          (hash 'fg fg 'bg bg-alt)
   "ui.menu.selected" (if ansi?
                           (hash 'fg accent 'modifiers '("reversed" "bold"))
                           (hash 'fg accent 'bg bg-hl))
   "ui.menu.scroll"   (hash 'fg fg-dim)))

;; ── Assemble theme ────────────────────────────────────────
(define woz-hash (hash-union nord-syntax-hash woz-ui-hash))
(theme.hashmap->theme name woz-hash))
