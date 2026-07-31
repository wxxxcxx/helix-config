# Features

Each directory owns one editor capability. A feature keeps its implementation
and public entry module together; loading the entry module must not mutate
editor state. Startup effects belong in the exported initialization function
called from `init.scm`.

- `editor/`: base editor options and theme registration
- `statusline/`: statusline layout and indicators
- `terminal/`: embedded terminal adapter
- `ivy/`: picker UI and commands
- `file-manager/`: one public feature containing the explorer and persistent tree
- `input-source/`: input method switching hooks
- `color-swatches/`: language-server configuration for color previews
- `lsp-status/`: LSP client status component and command
- `splash/`: blank-start splash component
- `workflows/`: cross-feature coordination
- `ui/`: shared color, palette, and rendering primitives

Global entry bindings are user policy: declare them beside the corresponding
`use-feature` form in `init.scm`. This makes enabling, disabling, and rebinding
a feature a local edit. Helix merges each feature's global keymap incrementally,
so a broken feature cannot suppress bindings from healthy ones.

Bindings used only while a component is active remain inside that component;
they are part of its event protocol rather than the user's global configuration.

`workflows/` may depend on multiple features. Other feature directories should
depend only on their own files, `ui/`, or external Helix modules. This keeps
cross-feature coupling visible at the composition layer.
