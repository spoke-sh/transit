# Shared client resource baseline — 2026-10-29

This comparison preserves the installed SQL console's process, thread, memory
and statement costs before shared-context and I/O-pool work. The
[performance qualification topic](../../../docs/history/qualification/performance.md#shared-client-resource-baseline--2026-10-29)
owns its interpretation and retention. Correctness tests and packaging do not
consume these observations or derive budgets from them.

Control `4c536bc3fd3e80a5e5f473bbec70635b69aac5b9` and candidate
`96786c46df12903a54a936828f43e492052e0fc8` run the same driver and workload:

```sh
just test::console-latency --statements --repeat 5 --resources
```

Each arm builds all five selected executables with pinned Zig
`0.17.0-dev.2267+48abf1a34` and ReleaseSafe, freezes them, then verifies all 47
statements and typed readbacks. The [control](control.jsonl) and
[candidate](candidate.jsonl) retain every JSON line, including all measurements,
value/count output and binary/driver/helper hashes. The [manifest](manifest.json)
records source revisions, current definition, toolchain/host conditions, original
log hashes, completed outcomes and the byte-preserving selection of JSON lines.
Neither run had uncommitted source changes. The binary-revision override was
unused; each arm's binaries were built from its recorded source revision.

The shared host had unrelated builds and services active, with higher load in
the candidate arm. Runs are sequential, with no competing proof owned by this
task, no cache eviction and no CPU affinity/frequency control. Linux resource
snapshots occur between timed calls and are non-atomic. Both arms include the
installation supervisor, six children and one console. PSS apportions shared
pages; summed RSS does not. Virtual address space is not allocator reserve.
The first call includes connection setup but excludes the preceding `Popen`
duration; this is not a complete process-startup or first-output benchmark.

Five mutation samples and six warm reads cannot establish tail latency or
attribute timing differences to the package extraction. Preserve the observed
slower samples. Neither this workload nor these resource snapshots qualify
other language hosts, zero allocation, cancellation or joined close. See the
[measurement method](../../performance/README.md) for those limits and the
independent sampler/reporting controls.
