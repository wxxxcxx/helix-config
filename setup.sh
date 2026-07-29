#!/usr/bin/env bash

set -euo pipefail

readonly STEEL_PTY_REPOSITORY="https://github.com/wxxxcxx/steel-pty"
readonly STEEL_PTY_REVISION="68f2fc6fa7b68141c6b3f020325ac1751b5fc512"
readonly STEEL_ROOT="${STEEL_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/steel}"
readonly STEEL_PTY_DIRECTORY="$STEEL_ROOT/cogs/steel-pty"
readonly STEEL_PTY_SOURCE_DIRECTORY="$STEEL_ROOT/cog-sources/steel-pty"

if ! command -v forge >/dev/null 2>&1; then
  echo "error: forge is required; build the Steel-enabled Helix fork first" >&2
  exit 1
fi

force=false
case "${1:-}" in
  "") ;;
  --force) force=true ;;
  *)
    echo "usage: $0 [--force]" >&2
    exit 2
    ;;
esac

installed_revision="$(git -C "$STEEL_PTY_SOURCE_DIRECTORY" rev-parse HEAD 2>/dev/null || true)"
installed_repository="$(git -C "$STEEL_PTY_SOURCE_DIRECTORY" remote get-url origin 2>/dev/null || true)"

if [[ "$force" == true ]] \
  || [[ "$installed_revision" != "$STEEL_PTY_REVISION" ]] \
  || [[ "$installed_repository" != "$STEEL_PTY_REPOSITORY" ]]; then
  if [[ -d "$STEEL_PTY_SOURCE_DIRECTORY/.git" ]] \
    && [[ "$installed_repository" != "$STEEL_PTY_REPOSITORY" ]]; then
    git -C "$STEEL_PTY_SOURCE_DIRECTORY" remote set-url origin "$STEEL_PTY_REPOSITORY"
  fi
  if [[ -d "$STEEL_PTY_SOURCE_DIRECTORY/.git" ]]; then
    git -C "$STEEL_PTY_SOURCE_DIRECTORY" fetch origin
  fi
  install_args=(pkg install --git "$STEEL_PTY_REPOSITORY" --rev "$STEEL_PTY_REVISION")
  install_args+=(--force)
  forge "${install_args[@]}"
else
  echo "steel-pty fork is already installed at $STEEL_PTY_REVISION"
fi

if [[ ! -f "$STEEL_PTY_DIRECTORY/term.scm" ]]; then
  echo "error: steel-pty entry not found at $STEEL_PTY_DIRECTORY/term.scm" >&2
  exit 1
fi

echo "steel-pty is ready at revision $STEEL_PTY_REVISION"
