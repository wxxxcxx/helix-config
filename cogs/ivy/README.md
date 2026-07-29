# Ivy for Helix

A small completion frontend inspired by Ivy, adapted to Helix's modal workflow.
It provides one bottom panel and three commands:

- `ivy-search`: fuzzy line search with live navigation and cancel restoration.
- `ivy-find-file`: filters the current directory, keeps the picker open when
  entering a directory, renders `../` first for its parent, and only exits after
  opening a file. `Ctrl-Enter` opens the input literally so a new path can be
  created.
- `ivy-commands`: searches 414 native static and typable commands by name and
  documentation.

## Modules

- `ivy.scm`: completion panel, input handling, and candidate rendering.
- `core.scm`: candidate types and fuzzy filtering.
- `search.scm`: current-buffer search command.
- `find-file.scm`: incremental directory and file selection.
- `commands.scm`: command catalog completion and execution.

## Controls

| Key | Action |
| --- | --- |
| `Up` / `Ctrl-p` | Previous candidate |
| `Down` / `Ctrl-n` | Next candidate |
| `PageUp` / `PageDown` | Move one visible page |
| `Left` / `Right`, `Home` / `End` | Edit within the query |
| `Ctrl-u` | Delete to the start of the query |
| `Backspace` on an empty file query | Go to the parent directory |
| `Enter` | Accept the selected candidate |
| `Tab` in `ivy-find-file` | Confirm the selected directory or file |
| `Escape` | Cancel |
| Left click a candidate | Select and accept the candidate |
| Right click a candidate | Select without accepting |
| Left click the prompt | Reposition the query cursor |
| Mouse wheel | Move one candidate |
| Left click outside the panel | Cancel |

`command-catalog.scm` is generated from the wrappers shipped with the active
Helix fork. Regenerate it when upgrading to a version whose native command set
has changed.
