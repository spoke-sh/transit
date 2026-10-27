# Working on the test runner

Follow [test instructions](../AGENTS.md) and the [runner index](README.md).
Keep task selection, executable inputs, failure reporting and timing here. Storage,
query, SDK and application semantics belong to their own fixtures and validators.

Keep the execution authority in [suite.json](suite.json), the focused check
inventory in [checks.json](checks.json), and measured cost policy in
[ci-budgets.json](ci-budgets.json). Record direct Just nesting separately from
indirect build/runner nesting. Run `test_task_coverage.py` and `ci_runner.py`
after changing task ownership; registration does not establish a passing result.

[layout.json](layout.json) owns the allowed test directories. The migration is
complete; keep its exception list empty. Keep layout regression controls
in the fast check; test actual added, moved, deleted and untracked files.

Keep the fast profile free of runtime compilation, package installation, physical
fault schedules and Transit service setup. Report its limited scope explicitly.
Every check removed from an aggregate must retain an executable owner and required
CI coverage; a shorter inventory alone is not a speed improvement.

Pass arguments as arrays, preserve both generator and validator failures, and keep
check results incomplete until all expected stages finish. Use immutable generator
artifacts from the build graph; avoid shared mutable installation paths. Test real
failure propagation and source-clean execution when changing orchestration.
Use the shared capture helper for commands. Preserve separate exact generator
stdout and bounded diagnostic logs; record truncation and incomplete attempts.
Keep each invocation's artifacts automatically, with source/toolchain identity.
Do not replace runner output with manually authored pass records or Git logs.

Do not use elapsed time from one warm host as a cold or hosted qualification. Keep
build, setup and executed validation costs separate and record source identity.

CI selection must preserve source-to-document rename detection, full non-PR runs
and failure on missing comparison revisions. A module listing, skipped job or
interrupted report cannot qualify a selected task. Keep clean runs isolated from
workspace artifacts and caller environment overrides. Preserve private failure
evidence before cleanup; never publish credentials or real application payloads.
