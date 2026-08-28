#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'usage: %s {pre-commit|post-commit}\n' "${0##*/}" >&2
  exit 2
}

[[ $# -eq 1 ]] || usage
hook_name="$1"

case "$hook_name" in
  pre-commit)
    tasks=(scan-staged-files run-linter run-tests)
    delay_seconds="${PRE_COMMIT_TASK_DELAY_SECONDS:-${HOOK_TASK_DELAY_SECONDS:-3}}"
    fail_task="${PRE_COMMIT_FAIL_TASK:-}"
    ;;
  post-commit)
    tasks=(generate-commit-report refresh-cache notify-downstream)
    delay_seconds="${POST_COMMIT_TASK_DELAY_SECONDS:-${HOOK_TASK_DELAY_SECONDS:-3}}"
    fail_task="${POST_COMMIT_FAIL_TASK:-}"
    ;;
  *)
    usage
    ;;
esac

if [[ ! "$delay_seconds" =~ ^[0-9]+$ ]]; then
  printf '[%s] error: task delay must be a non-negative integer, got %q\n' \
    "$hook_name" "$delay_seconds" >&2
  exit 2
fi

if [[ "${SKIP_LONG_HOOKS:-0}" == 1 ]]; then
  printf '[%s] skipping long-running tasks (SKIP_LONG_HOOKS=1)\n' "$hook_name"
  exit 0
fi

git_dir="$(git rev-parse --absolute-git-dir)"
log_dir="$git_dir/hook-task-logs"
log_file="$log_dir/$hook_name.log"
mkdir -p "$log_dir"

record() {
  local message="$1"
  local timestamp
  timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf '[%s] [%s] %s\n' "$timestamp" "$hook_name" "$message" | tee -a "$log_file"
}

on_interrupt() {
  record "interrupted"
  exit 130
}
trap on_interrupt INT TERM

if [[ "$hook_name" == pre-commit ]]; then
  staged_count="$(git diff --cached --name-only | sed '/^$/d' | wc -l)"
  staged_count="${staged_count//[[:space:]]/}"
  context="$staged_count staged file(s)"
else
  context="commit $(git rev-parse --short HEAD)"
fi

record "starting ${#tasks[@]} task(s) for $context (pid $$)"

for task in "${tasks[@]}"; do
  record "task $task started"

  for ((elapsed = 1; elapsed <= delay_seconds; elapsed++)); do
    sleep 1
    record "task $task progress: ${elapsed}/${delay_seconds}s"
  done

  if [[ -n "$fail_task" && "$task" == "$fail_task" ]]; then
    record "task $task FAILED (requested by environment)"
    if [[ "$hook_name" == pre-commit ]]; then
      record "pre-commit failed; Git will not create the commit"
    else
      record "post-commit failed; the commit already exists"
    fi
    exit 1
  fi

  record "task $task completed"
done

record "all tasks completed successfully"
