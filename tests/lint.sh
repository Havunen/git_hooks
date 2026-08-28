#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

command -v shellcheck >/dev/null 2>&1 || {
  printf 'error: shellcheck is required for make lint\n' >&2
  exit 1
}
command -v python3 >/dev/null 2>&1 || {
  printf 'error: python3 is required to check proc-receive\n' >&2
  exit 1
}

mapfile -d '' shell_files < <(
  find .githooks scripts tests -type f ! -name proc-receive -print0
)

bash -n "${shell_files[@]}"
shellcheck -x -P .githooks "${shell_files[@]}"
python3 -c 'import ast, pathlib, sys; ast.parse(pathlib.Path(sys.argv[1]).read_text())' \
  .githooks/proc-receive
git diff --check

printf 'PASS: syntax and lint checks succeeded\n'
