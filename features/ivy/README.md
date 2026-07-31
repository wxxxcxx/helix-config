# Ivy for Helix

A small completion frontend inspired by Ivy, adapted to Helix's modal workflow.
It replaces the native picker for the workflows where Steel exposes reliable,
structured data:

- `ivy-search`: fuzzy line search with live navigation and cancel restoration.
- `ivy-find-file`: filters the current directory, keeps the picker open when
  entering a directory, renders `../` first for its parent, and only exits after
  opening a file. `Ctrl-Enter` opens the input literally so a new path can be
  created.
- `ivy-buffer`: switches between open buffers, prioritizing the most recently
  focused buffer and marking current or modified documents.
- `ivy-project-search`: searches project contents with `rg`, starting after two
  input characters and limiting the panel to 400 results.
- `ivy-recent-file`: opens files seen during the current editor session,
  including files that have already been closed.
- `ivy-theme`: previews themes while moving and restores the original theme on
  cancel.
- `ivy-commands`: searches 414 native static and typable commands by name and
  documentation.

## Modules

- `ivy.scm`: completion panel, input handling, and candidate rendering.
- `core.scm`: candidate types and fuzzy filtering.
- `commands.scm`: public command exports.
- `commands/search.scm`: current-buffer search command.
- `commands/find-file.scm`: incremental directory and file selection.
- `commands/buffer.scm`: MRU-ordered open-buffer selection.
- `commands/project-search.scm`: dynamic project content search through
  ripgrep.
- `commands/recent-file.scm`: session MRU file tracking and selection.
- `commands/theme.scm`: theme selection with live preview and cancel rollback.
- `commands/execute.scm`: command catalog completion and execution.

## Controls

| Key | Action |
| --- | --- |
| `Up` / `Ctrl-p` | Previous candidate, wrapping at the start |
| `Down` / `Ctrl-n` | Next candidate, wrapping at the end |
| `PageUp` / `PageDown` | Move one visible page |
| `Alt-p` / `Alt-n` | Previous / next query from this command's history |
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

## Default bindings

| Key | Command |
| --- | --- |
| `/` | `ivy-search` |
| `Space-f` | `ivy-find-file` |
| `Space-b` | `ivy-buffer` |
| `Space-/` | `ivy-project-search` |
| `Space-r` | `ivy-recent-file` |
| `Space-T` | `ivy-theme` |
| `Space-?` | `ivy-commands` |

`command-catalog.scm` is generated from the wrappers shipped with the active
Helix fork. Regenerate it when upgrading to a version whose native command set
has changed.
