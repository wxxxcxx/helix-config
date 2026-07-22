;; cogs/glyph.scm
;; Nerd Font glyph database — file, directory, git, and UI icons

(require "helix/components.scm")

(provide glyph-icon
         glyph-dir-closed glyph-dir-open
         glyph-hex->color
         glyph-git-icon
         glyph-ui-icon
         file->icon)

;; ── Hex → Color ─────────────────────────────────────────────────

(define (hex-byte hex start)
  (string->number (substring hex start (+ start 2)) 16))

(define (glyph-hex->color hex)
  (Color/rgb (hex-byte hex 1) (hex-byte hex 3) (hex-byte hex 5)))

;; ── Defaults ─────────────────────────────────────────────────────

(define DEFAULT-FILE-ICON "󰈔")
(define GLYPH-DIR-CLOSED   "󰉋")
(define GLYPH-DIR-OPEN     "󰉍")

;; ── Git status ──────────────────────────────────────────────────

(define *git-status*
  (hash 'modified  "~"  'added     "+"
        'deleted   "-"  'renamed   "→"
        'untracked "?"  'ignored   "!"))

(define (glyph-git-icon status)
  (let ([entry (hash-try-get *git-status* status)])
    (if entry entry "?")))

;; ── UI icons ─────────────────────────────────────────────────────

(define *ui-icons*
  (hash 'error "󰅙"  'alert       "󰀪"
        'information "󰋽"  'star  "󰌶"
        'check "󰄬"  'close       "󰅖"))

(define (glyph-ui-icon key)
  (let ([entry (hash-try-get *ui-icons* key)])
    (if entry entry "?")))

;; ── Special filenames ───────────────────────────────────────────

(define *filenames*
  (hash "Makefile"       "󱁤"  "makefile"       "󱁤"
        "CMakeLists.txt" "󱁤"  "README"         ""
        "README.md"      ""  "LICENSE"        ""
        "Dockerfile"     "󰡨"  ".dockerignore"  "󰡨"
        ".gitignore"     "󰒓"  ".gitattributes" "󰒓"
        ".gitmodules"    "󰒓"  ".gitlab-ci.yml" "󰮠"
        ".env"           "󰒓"  ".bashrc"        "󰒓"
        ".zshrc"         "󰒓"  "Cargo.toml"     "󱘗"
        "package.json"   "󰘦"))

;; ── File extension icons ────────────────────────────────────────

(define *extensions*
  (hash "7z"     "󰗄"  "aac"   "󰈣"  "astro"  ""
        "awk"    ""   "c"     "󰙱"  "clj"    ""
        "cmake"  "󱁤"   "conf"  "󰯂"  "cpp"    "󰙲"
        "cr"     ""   "cs"    "󰌛"  "css"    "󰌜"
        "dart"   ""   "diff"  "󰦓"  "el"     ""
        "elm"    ""   "erl"   ""  "ex"     ""
        "exs"    ""   "fish"  ""  "fnl"    ""
        "fs"     ""   "go"    "󰟓"  "gql"    "󰡷"
        "h"      "󰫵"   "haml"  "󰅴"  "hbs"    "󰌞"
        "hs"     "󰲒"   "html"  "󰌝"  "hx"     "󰫵"
        "ini"    "󰯂"   "ino"   ""  "ipynb"  "󰠮"
        "java"   "󰬷"   "jl"    ""  "jpg"    "󰈥"
        "js"     "󰌞"   "json"  "󰘦"  "jsx"    ""
        "kt"     "󱈙"   "less"  "󰌜"  "lock"   "󰾢"
        "lua"    "󰢱"   "md"    "󰍔"  "nim"    ""
        "nix"    "󱄅"   "nu"    ""  "org"    ""
        "pdf"    "󰈦"   "php"   "󰌟"  "pl"     ""
        "png"    "󰸭"   "prisma" ""  "ps1"   "󰨊"
        "py"     "󰌠"   "r"     "󰟢"  "rb"     "󰴭"
        "rs"     "󱘗"   "rss"   "󰗀"  "sass"   "󰟬"
        "scala"  ""   "scm"   "󰘧"  "scss"   "󰟬"
        "sh"     ""   "sln"   "󰘐"  "sol"    ""
        "sql"    "󰆎"   "svelte" ""  "svg"   "󰜡"
        "swift"  "󰛥"   "tcl"   "󰛓"  "tf"     "󱁢"
        "toml"   ""   "ts"    "󰛦"  "tsx"    ""
        "txt"    "󰈙"   "vim"   ""  "vue"    "󰡄"
        "yaml"   ""   "yml"   ""  "zig"    ""
        "zip"    "󰗄"   "zsh"   ""))

;; ── Lookup ───────────────────────────────────────────────────────

(define (file-extension name)
  (let ([parts (split-many name ".")])
    (if (> (length parts) 1)
        (list-ref parts (- (length parts) 1))
        "")))

(define (lookup name)
  (or (hash-try-get *filenames* name)
      (hash-try-get *extensions* (file-extension name))))

(define (glyph-icon name)
  (let ([entry (lookup name)])
    (if entry entry DEFAULT-FILE-ICON)))

(define (glyph-dir-closed) GLYPH-DIR-CLOSED)
(define (glyph-dir-open)   GLYPH-DIR-OPEN)

(define (file->icon name)
  (lookup name))
