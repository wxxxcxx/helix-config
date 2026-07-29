#!/usr/bin/env bash

set -euo pipefail

readonly SETUP_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly STEEL_BIN="${STEEL_BIN:-steel}"

if ! command -v "$STEEL_BIN" >/dev/null 2>&1; then
  echo "error: steel is required; build the Steel-enabled Helix fork first" >&2
  exit 127
fi

exec "$STEEL_BIN" "$SETUP_ROOT/setup.scm" "$@"
