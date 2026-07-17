;; nord — shared Nord palette and syntax colors
;; Both woz and woz-transparent inherit from this.
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
(define bg          "#2E3440")  ; nord0
(define bg-alt      "#3B4252")  ; nord1
(define bg-hl       "#434C5E")  ; nord2
(define fg          "#D8DEE9")  ; nord4
(define fg-dim      "#4C566A")  ; nord3
(define fg-bright   "#ECEFF4")  ; nord6
(define accent      "#88C0D0")  ; nord8
(define accent-alt  "#81A1C1")  ; nord9
(define accent-dim  "#5E81AC")  ; nord10
(define teal        "#8FBCBB")  ; nord7
(define green       "#A3BE8C")  ; nord14
(define orange      "#D08770")  ; nord12
(define red         "#BF616A")  ; nord11
(define purple      "#B48EAD")  ; nord15
(define yellow      "#EBCB8B")  ; nord13

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

;; ── Shared syntax hash (identical across woz variants) ────
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

(provide bg bg-alt bg-hl
         fg fg-dim fg-bright
         accent accent-alt accent-dim
         teal green orange red purple yellow
         mk-style-fg mk-style-bg fg+italic fg+bold
         nord-syntax-hash)
