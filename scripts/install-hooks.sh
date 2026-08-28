#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf 'error: %s is not a Git working tree\n' "$repo_root" >&2
  exit 1
fi

git -C "$repo_root" config --local core.hooksPath .githooks

printf 'Enabled hooks from %s/.githooks\n' "$repo_root"
printf 'The setting applies only to this repository.\n'
