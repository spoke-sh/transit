# Working on repository checks

Follow [test instructions](../AGENTS.md) and the [tooling index](README.md).
Keep task selection, executable inputs, failure reporting and timing here. Storage,
query, SDK and application semantics belong to their own fixtures and validators.

Keep the fast profile free of runtime compilation, package installation, physical
fault schedules and Transit service setup. Report its limited scope explicitly.
Every check removed from an aggregate must retain an executable owner and required
CI coverage; a shorter inventory alone is not a speed improvement.

Pass arguments as arrays, preserve both generator and validator failures, and keep
check results incomplete until all expected stages finish. Use immutable generator
artifacts from the build graph; avoid shared mutable installation paths. Test real
failure propagation and source-clean execution when changing orchestration.

Do not use elapsed time from one warm host as a cold or hosted qualification. Keep
build, setup and executed validation costs separate and record source identity.

CI selection must preserve source-to-document rename detection, full non-PR runs
and failure on missing comparison revisions. A module listing, skipped job or
interrupted report cannot qualify a selected task. Keep clean runs isolated from
workspace artifacts and caller environment overrides. Preserve private failure
evidence before cleanup; never publish credentials or real application payloads.
