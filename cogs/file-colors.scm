;; cogs/file-colors.scm
;; File extension / special filename → color hex mapping

(provide file-color)

(define DEFAULT-COLOR "#6d8086")

(define *name-colors*
  (hash "Makefile"       "#6d8086"  "makefile"       "#6d8086"
        "CMakeLists.txt" "#6d8086"  "README"         "#dddddd"
        "README.md"      "#dddddd"  "LICENSE"        "#d0bf41"
        "Dockerfile"     "#458ee6"  ".dockerignore"  "#458ee6"
        ".gitignore"     "#f69a1b"  ".gitattributes" "#f69a1b"
        ".gitmodules"    "#f69a1b"  ".gitlab-ci.yml" "#e24329"
        ".env"           "#89e051"  ".bashrc"        "#89e051"
        ".zshrc"         "#89e051"  "Cargo.toml"     "#dea584"
        "package.json"   "#f1e05a"))

(define *ext-colors*
  (hash "7z"     "#eca517"  "aac"   "#00afff"  "astro"  "#e23f67"
        "awk"    "#4d5a5e"  "c"     "#599eff"  "clj"    "#8dc149"
        "cmake"  "#6d8086"  "conf"  "#6d8086"  "cpp"    "#519aba"
        "cr"     "#c8c8c8"  "cs"    "#596706"  "css"    "#42a5f5"
        "dart"   "#03589C"  "diff"  "#41535b"  "el"     "#8172be"
        "elm"    "#519aba"  "erl"   "#B83998"  "ex"     "#a074c4"
        "exs"    "#a074c4"  "fish"  "#4d5a5e"  "fnl"    "#fff3d7"
        "fs"     "#519aba"  "go"    "#519aba"  "gql"    "#e535ab"
        "h"      "#a074c4"  "haml"  "#eaeae1"  "hbs"    "#f0772b"
        "hs"     "#a074c4"  "html"  "#e44d26"  "hx"     "#ea8220"
        "ini"    "#6d8086"  "ino"   "#56b6c2"  "ipynb"  "#51a0cf"
        "java"   "#cc3e44"  "jl"    "#a270ba"  "jpg"    "#a074c4"
        "js"     "#cbcb41"  "json"  "#cbcb41"  "jsx"    "#20c2e3"
        "kt"     "#7F52FF"  "less"  "#563d7c"  "lock"   "#e5c07b"
        "lua"    "#51a0cf"  "md"    "#dddddd"  "nim"    "#f3d400"
        "nix"    "#7ebae4"  "nu"    "#3aa675"  "org"    "#77AA99"
        "pdf"    "#b30b00"  "php"   "#a074c4"  "pl"     "#519aba"
        "png"    "#a074c4"  "prisma" "#5a67d8" "ps1"    "#4273ca"
        "py"     "#ffbc03"  "r"     "#519aba"  "rb"     "#701516"
        "rs"     "#dea584"  "rss"   "#FB9D3B"  "sass"   "#f55385"
        "scala"  "#cc3e44"  "scm"   "#eeeeee"  "scss"   "#f55385"
        "sh"     "#4d5a5e"  "sln"   "#854CC7"  "sol"    "#519aba"
        "sql"    "#e38c00"  "svelte" "#ff3e00" "svg"    "#FFB13B"
        "swift"  "#e37933"  "tcl"   "#1e5cb3"  "tf"     "#5F43E9"
        "toml"   "#9c4221"  "ts"    "#519aba"  "tsx"    "#1354bf"
        "txt"    "#89e051"  "vim"   "#019833"  "vue"    "#8dc149"
        "yaml"   "#6d8086"  "yml"   "#6d8086"  "zig"    "#f69a1b"
        "zip"    "#eca517"  "zsh"   "#89e051"))

(define (file-extension name)
  (let ([parts (split-many name ".")])
    (if (> (length parts) 1)
        (list-ref parts (- (length parts) 1))
        "")))

(define (file-color name)
  (or (hash-try-get *name-colors* name)
      (hash-try-get *ext-colors* (file-extension name))
      DEFAULT-COLOR))
