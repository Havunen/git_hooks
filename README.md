# Long-running Git hooks example

This repository demonstrates foreground tasks in Git's `pre-commit` and
`post-commit` hooks. The tasks are deliberately simulated with timed waits so
the behavior is predictable and does not require any external dependencies.

## Enable the hooks

Git does not enable version-controlled hooks automatically after a clone. Run:

```sh
./scripts/install-hooks.sh
```

The installer sets this repository's local `core.hooksPath` to `.githooks`.
It does not modify global Git configuration.

## Try it

Change and commit `demo.txt`:

```sh
printf '\nAnother line\n' >> demo.txt
git add demo.txt
git commit -m "Run the hook demo"
```

The pre-commit hook runs these tasks before Git creates the commit:

1. `scan-staged-files`
2. `run-linter`
3. `run-tests`

The post-commit hook then runs these tasks after Git creates the commit:

1. `generate-commit-report`
2. `refresh-cache`
3. `notify-downstream`

Every task waits for three seconds by default, so a successful commit takes
about 18 seconds. Both hooks run in the foreground on purpose: the terminal
continues to show progress and `git commit` does not return until the hooks are
finished.

Hook output is also appended to files under `.git/hook-task-logs/`.

## Configuration

Environment variables make the example easier to experiment with:

| Variable | Effect |
| --- | --- |
| `HOOK_TASK_DELAY_SECONDS` | Sets the wait per task for both hooks. |
| `PRE_COMMIT_TASK_DELAY_SECONDS` | Overrides the wait per pre-commit task. |
| `POST_COMMIT_TASK_DELAY_SECONDS` | Overrides the wait per post-commit task. |
| `PRE_COMMIT_FAIL_TASK` | Makes the named pre-commit task fail. |
| `POST_COMMIT_FAIL_TASK` | Makes the named post-commit task fail. |
| `SKIP_LONG_HOOKS=1` | Skips all simulated tasks. |

For example, this makes the pre-commit test task fail after running the prior
tasks:

```sh
PRE_COMMIT_FAIL_TASK=run-tests git commit -m "Blocked example"
```

The commit is rejected because a pre-commit hook is a quality gate. In
contrast, forcing `POST_COMMIT_FAIL_TASK=refresh-cache` reports an error after
the commit already exists; a post-commit hook cannot roll it back.

Use a shorter delay while developing the hook scripts:

```sh
HOOK_TASK_DELAY_SECONDS=1 git commit -m "Fast example"
```

To bypass the simulated tasks for one invocation, set `SKIP_LONG_HOOKS=1`.
Git's `git commit --no-verify` also bypasses the pre-commit hook, but it is not
a general switch for post-commit processing.

## Test the example

```sh
make test
```

The integration test creates a temporary repository, enables the hooks, and
checks successful commits, pre-commit rejection, and post-commit failure
semantics with zero-second delays.

## Adapting it

Replace the simulated loop in `scripts/run-hook-tasks.sh` with real commands
such as a formatter, test suite, generated-file refresh, or local notification.
Keep critical checks in pre-commit. Put best-effort follow-up work in
post-commit, remembering that the commit has already been written at that
point.
