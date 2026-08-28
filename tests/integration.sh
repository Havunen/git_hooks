#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/git-hooks-example.XXXXXX)"

expected_hooks=(
  applypatch-msg
  pre-applypatch
  post-applypatch
  pre-commit
  pre-merge-commit
  prepare-commit-msg
  commit-msg
  post-commit
  pre-rebase
  post-checkout
  post-merge
  pre-push
  pre-receive
  update
  proc-receive
  post-receive
  post-update
  reference-transaction
  push-to-checkout
  pre-auto-gc
  post-rewrite
  sendemail-validate
  fsmonitor-watchman
  p4-changelist
  p4-prepare-changelist
  p4-post-changelist
  p4-pre-submit
  post-index-change
)

cleanup() {
  case "$test_root" in
    /tmp/git-hooks-example.*) rm -rf -- "$test_root" ;;
    *) printf 'Refusing to remove unexpected test path: %s\n' "$test_root" >&2 ;;
  esac
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

mkdir -p "$test_root/repo"
cp -R "$project_root/.githooks" "$project_root/scripts" "$test_root/repo/"

repo="$test_root/repo"
git -C "$repo" init -q
git -C "$repo" config user.name 'Hook Test'
git -C "$repo" config user.email 'hook-test@example.invalid'
git -C "$repo" config commit.gpgSign false
"$repo/scripts/install-hooks.sh" >/dev/null

[[ "$(git -C "$repo" config --local core.hooksPath)" == .githooks ]] || \
  fail 'installer did not configure core.hooksPath'

for hook_name in "${expected_hooks[@]}"; do
  [[ -x "$repo/.githooks/$hook_name" ]] || \
    fail "hook is missing or not executable: $hook_name"
done

actual_hook_count="$(find "$repo/.githooks" -maxdepth 1 -type f -perm -u+x | wc -l)"
actual_hook_count="${actual_hook_count//[[:space:]]/}"
[[ "$actual_hook_count" == "${#expected_hooks[@]}" ]] || \
  fail "expected ${#expected_hooks[@]} executable hooks, found $actual_hook_count"

printf 'first\n' >"$repo/demo.txt"
git -C "$repo" add demo.txt

first_output="$test_root/first-commit.out"
if ! HOOK_TASK_DELAY_SECONDS=0 git -C "$repo" commit -m 'First commit' \
  >"$first_output" 2>&1; then
  sed 's/^/  | /' "$first_output" >&2
  fail 'successful hook run rejected the commit'
fi

grep -q '\[pre-commit\].*all tasks completed successfully' "$first_output" || \
  fail 'pre-commit success output was missing'
grep -q '\[post-commit\].*all tasks completed successfully' "$first_output" || \
  fail 'post-commit success output was missing'

printf 'blocked\n' >>"$repo/demo.txt"
git -C "$repo" add demo.txt

blocked_output="$test_root/blocked-commit.out"
if HOOK_TASK_DELAY_SECONDS=0 PRE_COMMIT_FAIL_TASK=run-tests \
  git -C "$repo" commit -m 'Must be blocked' >"$blocked_output" 2>&1; then
  fail 'pre-commit failure did not reject the commit'
fi

[[ "$(git -C "$repo" rev-list --count HEAD)" == 1 ]] || \
  fail 'a rejected pre-commit changed the commit count'
grep -q 'task run-tests FAILED' "$blocked_output" || \
  fail 'pre-commit failure output was missing'

post_output="$test_root/post-failure.out"
HOOK_TASK_DELAY_SECONDS=0 POST_COMMIT_FAIL_TASK=refresh-cache \
  git -C "$repo" commit -m 'Post hook failure' >"$post_output" 2>&1 || \
  fail 'Git reported failure even though only post-commit failed'

[[ "$(git -C "$repo" rev-list --count HEAD)" == 2 ]] || \
  fail 'post-commit failure prevented the commit from being created'
grep -q 'post-commit failed; the commit already exists' "$post_output" || \
  fail 'post-commit failure output was missing'

printf 'message policy\n' >>"$repo/demo.txt"
git -C "$repo" add demo.txt
wip_output="$test_root/wip-commit.out"
if HOOK_TASK_DELAY_SECONDS=0 HOOK_DEMO_REJECT_WIP=1 \
  git -C "$repo" commit -m 'WIP rejected subject' >"$wip_output" 2>&1; then
  fail 'commit-msg did not reject a WIP subject when requested'
fi
grep -q 'commit subjects beginning with WIP' "$wip_output" || \
  fail 'commit-msg rejection output was missing'

ticket_output="$test_root/ticket-commit.out"
HOOK_TASK_DELAY_SECONDS=0 HOOK_DEMO_TICKET=DEMO-123 \
  git -C "$repo" commit -m 'Ticketed subject' >"$ticket_output" 2>&1 || \
  fail 'prepare-commit-msg ticket example rejected the commit'
[[ "$(git -C "$repo" log -1 --format=%s)" == '[DEMO-123] Ticketed subject' ]] || \
  fail 'prepare-commit-msg did not prefix the subject'

git -C "$repo" switch -q -c hook-example-branch

git_dir="$(git -C "$repo" rev-parse --absolute-git-dir)"
[[ -s "$git_dir/hook-task-logs/pre-commit.log" ]] || \
  fail 'pre-commit log was not written'
[[ -s "$git_dir/hook-task-logs/post-commit.log" ]] || \
  fail 'post-commit log was not written'
[[ -s "$git_dir/hook-example-logs/prepare-commit-msg.log" ]] || \
  fail 'prepare-commit-msg log was not written'
[[ -s "$git_dir/hook-example-logs/commit-msg.log" ]] || \
  fail 'commit-msg log was not written'
[[ -s "$git_dir/hook-example-logs/post-checkout.log" ]] || \
  fail 'post-checkout log was not written'
[[ -s "$git_dir/hook-example-logs/post-index-change.log" ]] || \
  fail 'post-index-change log was not written'
[[ -s "$git_dir/hook-example-logs/reference-transaction.log" ]] || \
  fail 'reference-transaction log was not written'

fsmonitor_output="$test_root/fsmonitor.out"
HOOK_DEMO_LOG_DIR="$test_root/fsmonitor-logs" \
  "$repo/.githooks/fsmonitor-watchman" 2 previous-token >"$fsmonitor_output"
python3 -c \
  'import pathlib, sys; data = pathlib.Path(sys.argv[1]).read_bytes(); assert data.startswith(b"hook-demo-") and data.endswith(b"\0/\0"), data' \
  "$fsmonitor_output" || fail 'fsmonitor-watchman emitted an invalid v2 response'

remote="$test_root/remote.git"
git init -q --bare "$remote"
cp -R "$project_root/.githooks" "$remote/.githooks"
git -C "$remote" config core.hooksPath .githooks
git -C "$repo" remote add origin "$remote"

push_output="$test_root/push.out"
HOOK_DEMO_QUIET=1 git -C "$repo" push origin HEAD:refs/heads/main \
  >"$push_output" 2>&1 || {
    sed 's/^/  | /' "$push_output" >&2
    fail 'ordinary push through client and server hooks failed'
  }

remote_log_dir="$remote/hook-example-logs"
[[ -s "$git_dir/hook-example-logs/pre-push.log" ]] || \
  fail 'client pre-push log was not written'
[[ -s "$remote_log_dir/pre-receive.log" ]] || \
  fail 'server pre-receive log was not written'
[[ -s "$remote_log_dir/update.log" ]] || \
  fail 'server update log was not written'
[[ -s "$remote_log_dir/post-receive.log" ]] || \
  fail 'server post-receive log was not written'
[[ -s "$remote_log_dir/post-update.log" ]] || \
  fail 'server post-update log was not written'

git -C "$remote" config receive.procReceiveRefs refs/for
proc_output="$test_root/proc-receive-push.out"
HOOK_DEMO_QUIET=1 git -C "$repo" push origin HEAD:refs/for/main \
  >"$proc_output" 2>&1 || {
    sed 's/^/  | /' "$proc_output" >&2
    fail 'proc-receive fall-through push failed'
  }

[[ "$(git -C "$remote" rev-parse refs/for/main)" == "$(git -C "$repo" rev-parse HEAD)" ]] || \
  fail 'proc-receive fall-through did not update the requested ref'
[[ -s "$remote_log_dir/proc-receive.log" ]] || \
  fail 'proc-receive log was not written'

printf 'PASS: hook integration checks succeeded\n'
