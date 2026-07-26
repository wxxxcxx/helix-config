;; cogs/glyph/glyph.scm
;; Nerd Font glyph database — file, directory, git, and UI icons

(require "helix/components.scm")
(require "cogs/glyph/glyphnames.scm")

(provide glyph-icon
         glyph-dir-closed glyph-dir-open
         glyph-hex->color
         glyph-git-icon
         glyph-ui-icon
         file->icon
         glyph)

;; ── Hex → Color ─────────────────────────────────────────────────

(define (hex-byte hex start)
  (string->number (substring hex start (+ start 2)) 16))

(define (glyph-hex->color hex)
  (Color/rgb (hex-byte hex 1) (hex-byte hex 3) (hex-byte hex 5)))

;; ── Defaults ─────────────────────────────────────────────────────

(define DEFAULT-FILE-ICON (glyph "md-file"))
(define GLYPH-DIR-CLOSED   (glyph "md-folder"))
(define GLYPH-DIR-OPEN     (glyph "md-folder_download"))

;; ── Git status ──────────────────────────────────────────────────

(define *git-status*
  (hash 'modified  "~"  'added     "+"
        'deleted   "-"  'renamed   "→"
        'untracked "?"  'ignored   "!"))

(define (glyph-git-icon status)
  (or (hash-try-get *git-status* status) "?"))

;; ── UI icons ─────────────────────────────────────────────────────

(define *ui-icons*
  (hash 'error (glyph "md-close_circle")  'alert       (glyph "md-alert_outline")
        'information (glyph "md-information_outline")  'star  (glyph "md-lightbulb_outline")
        'check (glyph "md-check")  'close       (glyph "md-close")))

(define (glyph-ui-icon key)
  (or (hash-try-get *ui-icons* key) "?"))

;; ── Special filenames ───────────────────────────────────────────

(define *filenames*
  (hash
        "Makefile" (glyph "dev-gnu")
        "makefile" (glyph "md-tools")
        "CMakeLists.txt" (glyph "dev-cmake")
        "README" (glyph "oct-log")
        "README.md" (glyph "oct-log")
        "LICENSE" (glyph "seti-license")
        "Dockerfile" (glyph "dev-docker")
        ".dockerignore" (glyph "dev-docker")
        ".gitignore" (glyph "dev-git")
        ".gitattributes" (glyph "dev-git")
        ".gitmodules" (glyph "dev-git")
        ".gitlab-ci.yml" (glyph "dev-gitlab")
        ".env" (glyph "md-cog")
        ".bashrc" (glyph "dev-bash")
        ".zshrc" (glyph "dev-bash")
        "Cargo.toml" (glyph "dev-rust")
        "package.json" (glyph "dev-nodejs")
  ))

;; ── File extension icons ────────────────────────────────────────

(define *extensions*
  (hash
        "7z" (glyph "md-zip_box")
        "aac" (glyph "md-file_music")
        "astro" (glyph "dev-astro")
        "awk" (glyph "dev-awk")
        "c" (glyph "dev-c")
        "clj" (glyph "dev-clojure")
        "cmake" (glyph "dev-cmake")
        "conf" (glyph "md-script_text")
        "cpp" (glyph "dev-cplusplus")
        "cr" (glyph "dev-crystal")
        "cs" (glyph "dev-csharp")
        "css" (glyph "dev-css3")
        "dart" (glyph "dev-dart")
        "diff" (glyph "md-plus_minus_box")
        "el" (glyph "custom-common_lisp")
        "elm" (glyph "dev-elm")
        "erl" (glyph "dev-erlang")
        "ex" (glyph "dev-elixir")
        "exs" (glyph "dev-elixir")
        "fish" (glyph "dev-bash")
        "fnl" (glyph "custom-fennel")
        "fs" (glyph "dev-fsharp")
        "go" (glyph "dev-go")
        "gql" (glyph "dev-graphql")
        "h" (glyph "dev-c")
        "haml" (glyph "md-code_tags")
        "hbs" (glyph "md-language_javascript")
        "hs" (glyph "dev-haskell")
        "html" (glyph "dev-html5")
        "hx" (glyph "dev-c")
        "ini" (glyph "md-script_text")
        "ino" (glyph "dev-arduino")
        "ipynb" (glyph "dev-jupyter")
        "java" (glyph "dev-java")
        "jl" (glyph "dev-julia")
        "jpg" (glyph "md-file_jpg_box")
        "js" (glyph "dev-javascript")
        "json" (glyph "dev-json")
        "jsx" (glyph "dev-react")
        "kt" (glyph "dev-kotlin")
        "less" (glyph "dev-less")
        "lock" (glyph "md-bee_flower")
        "lua" (glyph "dev-lua")
        "md" (glyph "dev-markdown")
        "nim" (glyph "dev-nim")
        "nix" (glyph "dev-nixos")
        "nu" (glyph "seti-shell")
        "org" (glyph "custom-orgmode")
        "pdf" (glyph "md-file_pdf_box")
        "php" (glyph "dev-php")
        "pl" (glyph "dev-perl")
        "png" (glyph "md-file_png_box")
        "prisma" (glyph "dev-prisma")
        "ps1" (glyph "dev-powershell")
        "py" (glyph "dev-python")
        "r" (glyph "dev-r")
        "rb" (glyph "dev-ruby")
        "rs" (glyph "dev-rust")
        "rss" (glyph "md-xml")
        "sass" (glyph "dev-sass")
        "scala" (glyph "dev-scala")
        "scm" (glyph "md-lambda")
        "scss" (glyph "dev-sass")
        "sh" (glyph "dev-bash")
        "sln" (glyph "md-microsoft_visual_studio")
        "sol" (glyph "dev-solidity")
        "sql" (glyph "md-card_account_mail")
        "svelte" (glyph "dev-svelte")
        "svg" (glyph "md-svg")
        "swift" (glyph "dev-swift")
        "tcl" (glyph "md-feather")
        "tf" (glyph "dev-terraform")
        "toml" (glyph "custom-toml")
        "ts" (glyph "dev-typescript")
        "tsx" (glyph "dev-react")
        "txt" (glyph "md-file_document")
        "vim" (glyph "dev-vim")
        "vue" (glyph "dev-vuejs")
        "yaml" (glyph "dev-yaml")
        "yml" (glyph "dev-yaml")
        "zig" (glyph "dev-zig")
        "zip" (glyph "md-zip_box")
        "zsh" (glyph "dev-bash")
  ))

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
