#!/usr/bin/env bash

# Shared helpers for the human-readable example hooks. This file is sourced by
# hooks; Git does not execute files in subdirectories of the hooks directory.

HOOK_DEMO_NAME="${HOOK_DEMO_NAME:-${0##*/}}"

hook_demo_git_dir="$(git rev-parse --absolute-git-dir 2>/dev/null || pwd -P)"
hook_demo_log_dir="${HOOK_DEMO_LOG_DIR:-$hook_demo_git_dir/hook-example-logs}"
hook_demo_log_file="$hook_demo_log_dir/$HOOK_DEMO_NAME.log"

hook_log_only() {
  local message timestamp
  message="$*"
  timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  mkdir -p "$hook_demo_log_dir"
  printf '[%s] [%s] %s\n' "$timestamp" "$HOOK_DEMO_NAME" "$message" \
    >>"$hook_demo_log_file"
}

hook_log() {
  hook_log_only "$@"
  if [[ "${HOOK_DEMO_QUIET:-0}" != 1 ]]; then
    printf '[hook-demo:%s] %s\n' "$HOOK_DEMO_NAME" "$*" >&2
  fi
}

hook_reject() {
  hook_log "REJECTED: $*"
  exit 1
}

hook_maybe_reject() {
  if [[ "${HOOK_DEMO_REJECT:-}" == all || \
        "${HOOK_DEMO_REJECT:-}" == "$HOOK_DEMO_NAME" ]]; then
    hook_reject "requested by HOOK_DEMO_REJECT"
  fi
}

hook_quote() {
  printf '%q' "$1"
}
