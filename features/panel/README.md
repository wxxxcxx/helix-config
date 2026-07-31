# Panel

Panel owns three layout slots with built-in defaults:

- `left`: 38 columns
- `right`: 38 columns
- `bottom`: 2/5 of the available height

Override a slot only when the default does not fit:

```scheme
(panel-configure! 'left #:size 42)
```

Features provide modes while user configuration chooses their placement:

```scheme
(panel-register-mode! 'left 'file-tree (file-tree-panel-mode))
(panel-toggle! 'file-tree)
```

Only one mode is active in a slot. Left and right modes may be visible together.

Panel modes use one lifecycle shape: `open`, `close`, `layout`, `focus`,
`blur`, and optional `fullscreen` callbacks. Components own their Helix surface
and input handling; Panel only tells them which slot they occupy and which mode
has logical focus. A component can explicitly release focus after an action:

```scheme
(panel-focus! 'file-tree)
(panel-focus-editor!)
```

Scheme components can use `panel-component-mode` to avoid repeating the Helix
component lifecycle. It creates the component, raises it on focus/fullscreen,
removes it on close, and renders into the current `panel-slot-area`:

```scheme
(panel-component-mode
  #:name "file-tree"
  #:open (lambda (slot width)
           (ft-panel-layout! slot width 0 0 0)
           (ft-open!))
  #:close ft-close!
  #:layout ft-panel-layout!
  #:render ft-panel-render
  #:handle-event ft-handle-event
  #:focus ft-focus!
  #:blur ft-blur!)
```

`panel-toggle-fullscreen!` maximizes the focused mode and restores its original
slot on the next call. The key belongs in Panel configuration so every mode uses
the same command. Register it both as a global binding and as a Panel fallback
binding so focused panel components can delegate unhandled modified keys to
Panel before the event reaches Helix's global keymap:

```scheme
(use-feature panel
  (:load "features/panel/panel.scm")
  (:config
    (panel-init)
    (panel-register-key! "C-ret" panel-toggle-fullscreen!)
    (helix.keymaps.keymap (global)
      (normal ("C-ret" panel-toggle-fullscreen!))
      (insert ("C-ret" panel-toggle-fullscreen!)))))
```

The terminal adapter installs the same fallback through `steel-pty`'s
ignored-event hook. Terminal-owned keys still go to the PTY first; ignored keys
then pass through Panel before falling back to Helix globals.

Terminal remains a native Helix component so it directly owns text input,
paste events, and IME cursor placement. File Tree also owns its own Helix
component through `panel-component-mode`.
