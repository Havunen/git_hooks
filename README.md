# Git hooks example catalog

This repository contains runnable examples for all 28 hook types documented by
Git 2.55. Most examples observe their inputs and append a record under
`.git/hook-example-logs/`. The `pre-commit` and `post-commit` examples also run
deliberately slow foreground tasks so their effect on `git commit` is easy to
see.

See [docs/HOOKS.md](docs/HOOKS.md) for the complete hook-by-hook catalog.

## Enable the local hooks

Git intentionally does not enable version-controlled hooks after a clone. Run:

```sh
./scripts/install-hooks.sh
```

The installer sets this repository's local `core.hooksPath` to `.githooks`.
It does not modify global Git configuration and it does not install anything
on a remote Git server.

## Try the commit hooks

```sh
printf '\nAnother line\n' >> demo.txt
git add demo.txt
git commit -m "Run the hook demo"
```

The pre-commit hook runs three tasks before Git creates the commit:

1. `scan-staged-files`
2. `run-linter`
3. `run-tests`

The post-commit hook then runs three tasks after Git creates the commit:

1. `generate-commit-report`
2. `refresh-cache`
3. `notify-downstream`

Every task waits for three seconds by default, so a successful commit takes
about 18 seconds. Both hooks run in the foreground on purpose: the terminal
shows progress and `git commit` does not return until they finish. Their
detailed output is stored under `.git/hook-task-logs/`.

Use zero-second tasks when exploring the other examples:

```sh
HOOK_TASK_DELAY_SECONDS=0 git commit -m "Fast hook example"
```

## Opt-in behavior examples

The examples only log and allow operations by default. Environment variables
enable mutations or rejection for one command:

| Variable | Effect |
| --- | --- |
| `HOOK_DEMO_REJECT=pre-push` | Makes the named hook reject its operation; `all` targets every rejectable hook. |
| `HOOK_DEMO_REJECT_WIP=1` | Rejects WIP commit, patch, and P4 changelist subjects. |
| `HOOK_DEMO_REQUIRE_PREFIX=ABC-` | Requires commit subjects to begin with the value. |
| `HOOK_DEMO_TICKET=ABC-123` | Prefixes commit or P4 changelist messages in their prepare hook. |
| `HOOK_DEMO_PROTECTED_BRANCH=main` | Prevents `pre-rebase` from rebasing that branch. |
| `HOOK_DEMO_REQUIRE_EMAIL_SUBJECT=1` | Rejects a patch email without a Subject header. |
| `HOOK_DEMO_QUIET=1` | Writes example logs without printing human-readable notices. |
| `HOOK_DEMO_LOG_DIR=/path` | Overrides the example log directory. |
| `SKIP_LONG_HOOKS=1` | Skips the simulated pre/post-commit tasks. |

Long-task timing has more granular controls:

| Variable | Effect |
| --- | --- |
| `HOOK_TASK_DELAY_SECONDS` | Sets the wait per task for both commit hooks. |
| `PRE_COMMIT_TASK_DELAY_SECONDS` | Overrides the wait per pre-commit task. |
| `POST_COMMIT_TASK_DELAY_SECONDS` | Overrides the wait per post-commit task. |
| `PRE_COMMIT_FAIL_TASK` | Fails one named pre-commit task. |
| `POST_COMMIT_FAIL_TASK` | Fails one named post-commit task. |

Examples:

```sh
# commit-msg rejects this before Git writes the commit
HOOK_TASK_DELAY_SECONDS=0 HOOK_DEMO_REJECT_WIP=1 \
  git commit -m "WIP experiment"

# prepare-commit-msg changes the resulting subject to [ABC-123] Fix parser
HOOK_TASK_DELAY_SECONDS=0 HOOK_DEMO_TICKET=ABC-123 \
  git commit -m "Fix parser"

# pre-push consumes and logs every proposed ref update, then rejects the push
HOOK_DEMO_REJECT=pre-push git push origin main
```

`git commit --no-verify` bypasses `pre-commit` and `commit-msg`, but not every
commit-related hook. In particular, `prepare-commit-msg` is still invoked.

## Client versus server hooks

The installer enables hooks only in this working repository. These local hooks
can run here:

- commit, patch, merge, rebase, checkout, rewrite, index, and maintenance hooks;
- `pre-push`, before data leaves this repository;
- email and Git-P4 hooks when their corresponding Git commands are used.

The receive hooks (`pre-receive`, `update`, `proc-receive`, `post-receive`,
`post-update`, and usually `push-to-checkout`) run in the receiving repository.
To experiment with them, create a disposable bare remote and install the whole
`.githooks` directory there:

```sh
git init --bare /tmp/hook-demo-remote.git
cp -R .githooks /tmp/hook-demo-remote.git/.githooks
git -C /tmp/hook-demo-remote.git config core.hooksPath .githooks
git remote add hook-demo /tmp/hook-demo-remote.git
git push hook-demo HEAD:refs/heads/main
```

The receive hooks share only files inside `.githooks`, so copying that directory
is sufficient. Real server hooks should be deployed and secured by the server
administrator rather than copied ad hoc.

## Protocol-specific examples

`proc-receive` uses a binary pkt-line protocol rather than ordinary lines. Its
Python 3 example negotiates protocol version 1, logs each command, and responds
with `option fall-through`, leaving the actual ref update to `receive-pack`.
It runs only when a server administrator configures `receive.procReceiveRefs`.

`fsmonitor-watchman` must emit NUL-delimited output and therefore never prints
human-readable messages on stdout. This educational implementation returns `/`,
which safely tells Git to inspect everything. It demonstrates the protocol but
does not improve performance. Try version 2 without changing local config:

```sh
git -c core.fsmonitor=.githooks/fsmonitor-watchman \
  -c core.fsmonitorHookVersion=2 status
```

## Test the examples

```sh
make test
make lint
```

The integration test verifies the complete executable hook set, commit success
and rejection, message mutation, checkout callbacks, client-side push handling,
server-side receive handling in a bare repository, `proc-receive` fall-through,
and the fsmonitor wire format. `make lint` additionally runs ShellCheck and a
Python syntax check.

## Adapting the examples

Replace simulated waits in `scripts/run-hook-tasks.sh` with real formatters or
tests. Replace logging bodies in the other hook files with project-specific
work. Keep fast, critical checks in hooks that can reject an operation; use
post-operation hooks for best-effort notifications and cache refreshes.
