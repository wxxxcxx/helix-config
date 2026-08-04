# Core

Core contains feature-independent helpers. Modules in this directory must not
depend on a concrete editor feature or produce startup side effects.

- `collections.scm`: structural membership and uniqueness helpers.
- `list.scm`: bounded list slicing.
- `path.scm`: platform-aware path roots, labels, joins, and directory listing.
- `process.scm`: child-process stdout capture.

Feature-specific APIs may keep compatibility wrappers, but another feature
should require the Core implementation directly instead of depending on the
owner feature.
