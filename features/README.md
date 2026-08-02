# Features

Each directory owns one editor capability. A feature keeps its implementation
and public entry module together; loading the entry module must not mutate
editor state. Startup effects belong in the exported initialization function
called from `init.scm`.

- `editor/`: base editor options and theme registration
- `statusline/`: statusline layout and indicators
- `panel/`: left, right, and bottom slots with pluggable modes
- `terminal/`: embedded terminal adapter
- `ivy/`: picker UI and commands
- `file-manager/`: one public feature containing the explorer and persistent tree
- `input-source/`: input method switching hooks
- `color-swatches/`: language-server configuration for color previews
- `lsp-status/`: LSP client status component and command
- `splash/`: blank-start splash component
- `ui/`: shared color, palette, and rendering primitives

Global entry bindings are user policy: declare them inside the corresponding
`feature` config form in `init.scm`. Declarations are collected first and
initialized after all features are known, so feature order is governed by
explicit dependencies rather than declaration position. Helix merges each
feature's global keymap incrementally, so a broken feature cannot suppress
bindings from healthy ones.

Bindings used only while a component is active remain inside that component;
they are part of its event protocol rather than the user's global configuration.

Panel modes depend on the shared `panel/` lifecycle API. Other feature
directories should depend only on their own files, `ui/`, or external Helix
modules. Cross-feature placement stays visible in `init.scm` through explicit
dependencies and mode registration.
