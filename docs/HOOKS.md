# Complete Git hook catalog

The `.githooks` directory contains one executable for every hook documented by
Git 2.55 in the [official githooks manual](https://git-scm.com/docs/githooks).
The table describes where each hook runs, what this example does, and whether a
failure can stop or roll back the related operation.

“Rejects” means a non-zero exit can stop the operation at that point. “No
rollback” means Git has already completed the important state change, although
the surrounding command may still report the hook's status in some cases.

## Patch and commit lifecycle

| Hook | Invocation and input | Example behavior | Outcome control |
| --- | --- | --- | --- |
| `applypatch-msg` | `git am`; commit-message file argument | Logs the subject; optionally rejects `WIP` | Rejects patch application |
| `pre-applypatch` | `git am`; no arguments | Counts staged paths after applying the patch | Rejects its commit |
| `post-applypatch` | `git am`; no arguments | Logs the new commit for notification | No rollback |
| `pre-commit` | `git commit`; no arguments | Runs three visible, timed quality tasks | Rejects commit |
| `pre-merge-commit` | Automatic merge before its commit; no arguments | Logs `MERGE_HEAD` and supports opt-in rejection | Rejects merge commit |
| `prepare-commit-msg` | Message file, source, optional source commit | Optionally prefixes `HOOK_DEMO_TICKET` | Can edit or reject; not skipped by `--no-verify` |
| `commit-msg` | Commit-message file argument | Validates optional WIP/prefix policies | Rejects commit |
| `post-commit` | After `git commit`; no arguments | Runs three visible follow-up tasks | No rollback |

## History and working-tree operations

| Hook | Invocation and input | Example behavior | Outcome control |
| --- | --- | --- | --- |
| `pre-rebase` | Upstream and optional branch arguments | Can protect a named branch from rebasing | Rejects rebase |
| `post-checkout` | Old HEAD, new HEAD, branch/file flag | Logs branch switches, checkouts, clones, and worktree additions | No rollback |
| `post-merge` | Squash flag | Logs where dependency or metadata restoration could run | No rollback |
| `post-rewrite` | `amend`/`rebase` argument; old/new commits on stdin | Logs every rewritten commit mapping | No rollback |
| `post-index-change` | Worktree-updated and skip-worktree flags | Logs index writes | No rollback |
| `reference-transaction` | Transaction state; old/new/ref lines on stdin | Audits each ref transaction state | Rejects only `preparing`/`prepared` states |
| `pre-auto-gc` | Before `git gc --auto`; no arguments | Logs maintenance and supports opt-in rejection | Rejects automatic GC |

## Push and receive

| Hook | Runs in | Invocation and input | Example behavior | Outcome control |
| --- | --- | --- | --- | --- |
| `pre-push` | Sending repository | Remote name/URL; proposed ref updates on stdin | Logs all outgoing updates | Rejects entire push |
| `pre-receive` | Receiving repository | Once per push; all proposed ref updates on stdin | Logs and validates the complete update set | Rejects all updates |
| `update` | Receiving repository | Once per ref; ref, old object, new object arguments | Logs and validates one update | Rejects that ref |
| `proc-receive` | Receiving repository | Pkt-line negotiation, commands, and status replies | Logs commands and delegates with `fall-through` | Decides each configured command |
| `post-receive` | Receiving repository | Successful ref updates on stdin | Logs rich old/new/ref notifications | No rollback |
| `post-update` | Receiving repository | Updated ref names as arguments | Logs the simpler ref-name-only notification | No rollback |
| `push-to-checkout` | Receiving non-bare repository | New commit argument when `updateInstead` is configured | Uses `read-tree -u -m` to update index/worktree | Rejects update on failure |

Push-triggered receive hooks run with the receiving repository's Git directory
as their working directory. They are not installed on a hosting service merely
because they exist in a client clone.

`pre-receive` sees the whole push once, while `update` runs separately for each
ref. Central policy normally belongs in one of these server-side hooks rather
than relying only on hooks developers can bypass locally.

## Email, filesystem monitoring, and Git-P4

| Hook | Invocation and input | Example behavior | Outcome control |
| --- | --- | --- | --- |
| `sendemail-validate` | Patch-content and SMTP-header files | Optionally requires an email Subject | Rejects `git send-email` |
| `fsmonitor-watchman` | Protocol version and previous token | Emits a valid full-invalidation response | Failure makes Git fall back to a full scan |
| `p4-prepare-changelist` | Prepared changelist file | Optionally prefixes `HOOK_DEMO_TICKET` | Can edit or reject submit |
| `p4-changelist` | Edited changelist file | Logs subject; optionally rejects `WIP` | Rejects submit |
| `p4-pre-submit` | Before Git-P4 launches submit | Logs and supports opt-in rejection | Rejects submit |
| `p4-post-changelist` | After successful P4 submit | Logs a notification point | No rollback |

## Input conventions demonstrated here

- Arguments are always quoted because Git may supply file paths containing
  spaces.
- Multi-ref hooks consume stdin completely using `read -r` loops.
- Object IDs are treated as opaque strings, so SHA-1 and SHA-256 repositories
  both work.
- Human-readable logging goes to stderr. Protocol hooks reserve stdout for
  their required machine-readable replies.
- Logs live under the actual Git directory, which also works for linked
  worktrees and bare repositories.
- Rejecting or mutating behavior is opt-in so simply enabling this catalog does
  not impose an accidental project policy.
