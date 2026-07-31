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

Hosted modes give Panel their renderer, event handler, and focus callbacks.
PanelHost renders each mode in its slot, focuses it on a click, forwards keyboard
events only to the focused mode, and returns focus to the editor when a click is
outside every hosted slot. A mode can explicitly release focus after an action:

```scheme
(panel-focus! 'file-tree)
(panel-focus-editor!)
```

The current Terminal adapter is a native mode: Panel owns its lifecycle, logical
focus, and side insets, while `steel-pty/panel.scm` retains its private component
and bottom rectangle. File Tree is a hosted mode and does not push its own Helix
component.
