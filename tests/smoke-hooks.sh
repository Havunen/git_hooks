#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/git-hooks-smoke.XXXXXX)"

cleanup() {
  case "$test_root" in
    /tmp/git-hooks-smoke.*) rm -rf -- "$test_root" ;;
    *) printf 'Refusing to remove unexpected test path: %s\n' "$test_root" >&2 ;;
  esac
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

repo="$test_root/repo"
mkdir -p "$repo"
cp -R "$project_root/.githooks" "$project_root/scripts" "$repo/"
git -C "$repo" init -q
git -C "$repo" config user.name 'Hook Smoke Test'
git -C "$repo" config user.email 'hook-smoke@example.invalid'
git -C "$repo" config commit.gpgSign false
git -C "$repo" config core.hooksPath "$test_root/no-hooks"
printf 'initial\n' >"$repo/demo.txt"
git -C "$repo" add demo.txt
git -C "$repo" commit -q -m initial

head_oid="$(git -C "$repo" rev-parse HEAD)"
zero_oid="$(printf '%040d' 0)"
message_file="$test_root/message.txt"
headers_file="$test_root/headers.txt"
printf 'Example subject\n\nBody\n' >"$message_file"
printf 'From: Hook Test <hook@example.invalid>\nSubject: Example patch\n' >"$headers_file"

(
  cd "$repo"
  export HOOK_DEMO_LOG_DIR="$test_root/logs"
  export HOOK_DEMO_QUIET=1
  export HOOK_TASK_DELAY_SECONDS=0
  hooks="$repo/.githooks"

  "$hooks/applypatch-msg" "$message_file"
  "$hooks/pre-applypatch"
  "$hooks/post-applypatch"
  "$hooks/pre-commit"
  "$hooks/pre-merge-commit"
  "$hooks/prepare-commit-msg" "$message_file" message
  "$hooks/commit-msg" "$message_file"
  "$hooks/post-commit"
  "$hooks/pre-rebase" HEAD main
  "$hooks/post-checkout" "$head_oid" "$head_oid" 1
  "$hooks/post-merge" 0
  printf '%s %s %s %s\n' \
    refs/heads/main "$head_oid" refs/heads/main "$zero_oid" | \
    "$hooks/pre-push" origin example.invalid
  printf '%s %s %s\n' "$zero_oid" "$head_oid" refs/heads/main | \
    "$hooks/pre-receive"
  "$hooks/update" refs/heads/main "$zero_oid" "$head_oid"
  printf '%s %s %s\n' "$zero_oid" "$head_oid" refs/heads/main | \
    "$hooks/post-receive"
  "$hooks/post-update" refs/heads/main
  printf '%s %s %s\n' "$zero_oid" "$head_oid" refs/heads/main | \
    "$hooks/reference-transaction" committed
  "$hooks/push-to-checkout" "$head_oid"
  "$hooks/pre-auto-gc"
  printf '%s %s\n' "$head_oid" "$head_oid" | \
    "$hooks/post-rewrite" amend
  "$hooks/sendemail-validate" "$message_file" "$headers_file"
  "$hooks/p4-changelist" "$message_file"
  "$hooks/p4-prepare-changelist" "$message_file"
  "$hooks/p4-post-changelist"
  "$hooks/p4-pre-submit"
  "$hooks/post-index-change" 0 1
  "$hooks/fsmonitor-watchman" 2 smoke-token >"$test_root/fsmonitor.out"
)

logged_hooks=(
  applypatch-msg pre-applypatch post-applypatch pre-merge-commit
  prepare-commit-msg commit-msg pre-rebase post-checkout post-merge pre-push
  pre-receive update post-receive post-update reference-transaction
  push-to-checkout pre-auto-gc post-rewrite sendemail-validate
  p4-changelist p4-prepare-changelist p4-post-changelist p4-pre-submit
  post-index-change fsmonitor-watchman
)

for hook_name in "${logged_hooks[@]}"; do
  [[ -s "$test_root/logs/$hook_name.log" ]] || \
    fail "$hook_name did not write its smoke-test log"
done

git_dir="$(git -C "$repo" rev-parse --absolute-git-dir)"
[[ -s "$git_dir/hook-task-logs/pre-commit.log" ]] || \
  fail 'pre-commit did not write its smoke-test log'
[[ -s "$git_dir/hook-task-logs/post-commit.log" ]] || \
  fail 'post-commit did not write its smoke-test log'

python3 -c \
  'import pathlib, sys; data = pathlib.Path(sys.argv[1]).read_bytes(); assert data.startswith(b"hook-demo-") and data.endswith(b"\0/\0"), data' \
  "$test_root/fsmonitor.out" || fail 'fsmonitor smoke response was invalid'

printf 'PASS: direct hook smoke checks succeeded\n'
