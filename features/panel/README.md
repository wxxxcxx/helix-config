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
The current Terminal adapter uses the bottom slot lifecycle and side insets while
`steel-pty` continues to calculate and render its native bottom rectangle.
