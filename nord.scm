;; Nord theme for Helix
;; Based on the Nord color palette: https://www.nordtheme.com
;;
;; Colors:
;;   nord0  #2E3440  polar night (base background)
;;   nord1  #3B4252  darker UI
;;   nord2  #434C5E  selection, gutter
;;   nord3  #4C566A  comments, invisibles
;;   nord4  #D8DEE9  default text
;;   nord5  #E5E9F0  lighter
;;   nord6  #ECEFF4  lightest
;;   nord7  #8FBCBB  teal          strings, constants
;;   nord8  #88C0D0  light blue    keywords, variables
;;   nord9  #81A1C1  medium blue   functions, methods
;;   nord10 #5E81AC  dark blue     types, namespaces
;;   nord11 #BF616A  red           errors, warnings
;;   nord12 #D08770  orange        numbers
;;   nord13 #EBCB8B  yellow        attributes, markup
;;   nord14 #A3BE8C  green         strings, diff added
;;   nord15 #B48EAD  purple        special, preprocessor
(require "helix/themes.scm")

(define nord-theme
  (~> (hash)

      ;; ── Base ────────────────────────────────────────────
      (ui.background "#2E3440")
      (ui.text "#D8DEE9")

      ;; ── Cursor / Selection ──────────────────────────────
      (ui.cursor "#D8DEE9")
      (ui.cursor.normal "#D8DEE9")
      (ui.cursor.insert "#D8DEE9")
      (ui.cursor.select "#D8DEE9")
      (ui.cursor.primary "#ECEFF4")
      (ui.cursor.primary.normal "#ECEFF4")
      (ui.cursor.primary.select "#ECEFF4")
      (ui.cursor.match "#88C0D0")
      (ui.selection "#434C5E")
      (ui.selection.primary "#3B4252")

      ;; ── Line numbers / Gutter ───────────────────────────
      (ui.linenr "#4C566A")
      (ui.linenr.selected "#D8DEE9")
      (ui.gutter "#2E3440")
      (ui.gutter.selected "#3B4252")

      ;; ── Cursor line / column ────────────────────────────
      (ui.cursorline "#3B4252")
      (ui.cursorline.primary "#3B4252")
      (ui.cursorline.secondary "#3B4252")

      ;; ── UI Elements ─────────────────────────────────────
      (ui.statusline "#3B4252")
      (ui.statusline.inactive "#2E3440")
      (ui.statusline.normal "#5E81AC")
      (ui.statusline.insert "#81A1C1")
      (ui.statusline.select "#B48EAD")
      (ui.statusline.separator "#4C566A")
      (ui.bufferline "#3B4252")
      (ui.bufferline.active "#4C566A")
      (ui.bufferline.background "#2E3440")
      (ui.window "#4C566A")
      (ui.popup "#3B4252")
      (ui.popup.info "#3B4252")
      (ui.help "#3B4252")
      (ui.text.focus "#D8DEE9")
      (ui.text.info "#88C0D0")
      (ui.text.inactive "#4C566A")
      (ui.text.directory "#81A1C1")

      ;; ── Virtual / Whitespace ────────────────────────────
      (ui.virtual.whitespace "#4C566A")
      (ui.virtual.indent-guide "#3B4252")
      (ui.virtual.ruler "#3B4252")
      (ui.virtual.inlay-hint "#4C566A")
      (ui.virtual.inlay-hint.parameter "#4C566A")
      (ui.virtual.inlay-hint.type "#5E81AC")
      (ui.virtual.wrap "#4C566A")
      (ui.virtual.jump-label "#A3BE8C")

      ;; ── Menus / Completion ──────────────────────────────
      (ui.menu "#3B4252")
      (ui.menu.selected "#434C5E")
      (ui.menu.scroll "#4C566A")

      ;; ── Diagnostics ─────────────────────────────────────
      (error "#BF616A")
      (warning "#D08770")
      (info "#88C0D0")
      (hint "#4C566A")
      (diagnostic.error "#BF616A")
      (diagnostic.warning "#D08770")
      (diagnostic.info "#88C0D0")
      (diagnostic.hint "#4C566A")
      (diagnostic.unnecessary "#4C566A")
      (diagnostic.deprecated "#4C566A")

      ;; ── Debug ───────────────────────────────────────────
      (ui.debug.breakpoint "#BF616A")
      (ui.debug.active "#A3BE8C")
      (ui.highlight.frameline "#3B4252")

      ;; ── Highlight / Picker ──────────────────────────────
      (ui.highlight "#3B4252")
      (ui.background.separator "#3B4252")

      ;; ── Syntax: Comments ────────────────────────────────
      (comment "#4C566A")
      (comment.line "#4C566A")
      (comment.block "#4C566A")
      (comment.block.documentation "#4C566A")

      ;; ── Syntax: Keywords ────────────────────────────────
      (keyword "#8FBCBB")
      (keyword.control "#8FBCBB")
      (keyword.control.conditional "#8FBCBB")
      (keyword.control.repeat "#8FBCBB")
      (keyword.control.import "#8FBCBB")
      (keyword.control.return "#8FBCBB")
      (keyword.control.exception "#BF616A")
      (keyword.operator "#8FBCBB")
      (keyword.directive "#B48EAD")
      (keyword.function "#88C0D0")
      (keyword.storage "#8FBCBB")
      (keyword.storage.type "#8FBCBB")
      (keyword.storage.modifier "#8FBCBB")

      ;; ── Syntax: Functions ───────────────────────────────
      (function "#81A1C1")
      (function.builtin "#88C0D0")
      (function.method "#81A1C1")
      (function.method.private "#81A1C1")
      (function.macro "#B48EAD")
      (function.special "#B48EAD")

      ;; ── Syntax: Types ───────────────────────────────────
      (type "#5E81AC")
      (type.builtin "#5E81AC")
      (type.parameter "#D8DEE9")
      (type.enum "#5E81AC")
      (type.enum.variant "#81A1C1")

      ;; ── Syntax: Variables ───────────────────────────────
      (variable "#D8DEE9")
      (variable.builtin "#88C0D0")
      (variable.parameter "#D8DEE9")
      (variable.other "#D8DEE9")
      (variable.other.member "#D8DEE9")
      (variable.other.member.private "#D8DEE9")

      ;; ── Syntax: Constants / Strings ─────────────────────
      (constant "#8FBCBB")
      (constant.builtin "#8FBCBB")
      (constant.builtin.boolean "#8FBCBB")
      (constant.character "#A3BE8C")
      (constant.character.escape "#8FBCBB")
      (constant.numeric "#D08770")
      (constant.numeric.integer "#D08770")
      (constant.numeric.float "#D08770")
      (string "#A3BE8C")
      (string.regexp "#8FBCBB")
      (string.special "#8FBCBB")
      (string.special.path "#A3BE8C")
      (string.special.url "#81A1C1")
      (string.special.symbol "#8FBCBB")

      ;; ── Syntax: Constructor / Namespace ─────────────────
      (constructor "#81A1C1")
      (namespace "#5E81AC")

      ;; ── Syntax: Punctuation ─────────────────────────────
      (punctuation "#D8DEE9")
      (punctuation.delimiter "#D8DEE9")
      (punctuation.bracket "#D8DEE9")
      (punctuation.special "#8FBCBB")

      ;; ── Syntax: Operators ───────────────────────────────
      (operator "#8FBCBB")

      ;; ── Syntax: Tags ────────────────────────────────────
      (tag "#81A1C1")
      (tag.builtin "#81A1C1")

      ;; ── Syntax: Labels / Attributes / Special ───────────
      (label "#D08770")
      (attribute "#EBCB8B")
      (special "#B48EAD")

      ;; ── Markup ──────────────────────────────────────────
      (markup "#D8DEE9")
      (markup.heading "#88C0D0")
      (markup.heading.marker "#88C0D0")
      (markup.heading.marker.1 "#BF616A")
      (markup.heading.marker.2 "#D08770")
      (markup.heading.marker.3 "#EBCB8B")
      (markup.heading.marker.4 "#A3BE8C")
      (markup.heading.marker.5 "#81A1C1")
      (markup.heading.marker.6 "#B48EAD")
      (markup.list "#8FBCBB")
      (markup.list.unnumbered "#8FBCBB")
      (markup.list.numbered "#D08770")
      (markup.list.checked "#A3BE8C")
      (markup.list.unchecked "#4C566A")
      (markup.bold "#ECEFF4")
      (markup.italic "#D8DEE9")
      (markup.strikethrough "#4C566A")
      (markup.link "#81A1C1")
      (markup.link.url "#81A1C1")
      (markup.link.label "#88C0D0")
      (markup.link.text "#D8DEE9")
      (markup.quote "#8FBCBB")
      (markup.raw "#A3BE8C")
      (markup.raw.inline "#A3BE8C")
      (markup.raw.block "#A3BE8C")

      ;; ── Markup: Completion / Hover ──────────────────────
      (markup.normal.completion "#D8DEE9")
      (markup.normal.hover "#D8DEE9")
      (markup.heading.completion "#88C0D0")
      (markup.heading.hover "#88C0D0")
      (markup.raw.inline.completion "#A3BE8C")
      (markup.raw.inline.hover "#A3BE8C")

      ;; ── Diff ────────────────────────────────────────────
      (diff "#D8DEE9")
      (diff.plus "#A3BE8C")
      (diff.plus.gutter "#A3BE8C")
      (diff.minus "#BF616A")
      (diff.minus.gutter "#BF616A")
      (diff.delta "#EBCB8B")
      (diff.delta.moved "#81A1C1")
      (diff.delta.conflict "#BF616A")
      (diff.delta.gutter "#EBCB8B")))

;; Register the theme
(register-theme nord-theme)
