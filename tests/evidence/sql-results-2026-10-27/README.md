# SQL result consumption comparison

These selected automatic reports preserve the comparison basis for the result
model's batching, binary carriage and consumer costs beyond ordinary CI artifact
retention. The [performance owner](../../performance/AGENTS.md) maintains this
reference; it is evidence, never an input that makes a correctness test pass.
The [qualification account](../../../docs/history/qualification/performance.md#statement-result-batching-and-consumption--2026-10-27)
contains interpretation, failed controls and limits.

| Record | Scope |
| --- | --- |
| [Control](matched-control.jsonl), [candidate](matched-candidate.jsonl) | Three sequential console/native samples per query, 70 deterministic rows, metadata, slow consumer and separate payload codec experiments |
| [Instrumented control](instrumented-control.jsonl), [candidate](instrumented-candidate.jsonl) | One separate sample per query with native/Table proxy counts and owner-work counters; these timings include instrumentation |
| [Codec control](codec-quiet.jsonl) | Actual scalar encoders and native TSR1/TCP1 encode/decode; one warmup and five repetitions, 10,000 rows, one-row versus 32-row batches |
| [Provenance](provenance.json) | Exact sources, commands, exit codes, timestamps, original log hashes, binary/driver/toolchain identities and 46 cross-run schema/value/count comparisons |

The control is `7d30e2c502c29243424617155b51296d6d778861`, immediately before
the result changes and already containing the early live-storage cutover.
The candidate is `8a866f513a015f7487f67e07bbcaa82fa48b6275`. Its subsequent rebase
incorporates documentation and agent guidance; the measured production sources
and driver remain unchanged. Both builds use pinned Zig ReleaseSafe and all five
frozen runtime executables. Installed measurements run sequentially: control,
candidate, instrumented control, instrumented candidate. The shared 48-thread
Threadripper host continues ordinary background activity; this is not an
isolated-host, cold-cache or randomized variance study.

The four installed JSONL reports are copied byte-for-byte. The codec report keeps
the two automatic JSON lines unchanged and omits the command echo; provenance
retains the original full-log hash. No credentials or application payloads are
retained. Hashes and paths describe their original executions. Verify retained
bytes here with `sha256sum --check SHA256SUMS.txt`; this does not rerun the proof.
The [method](../../performance/README.md#sql-result-consumption) explains replay
options and which timings, byte counts and allocator bounds each runner measures.

The synthetic string compression measurements use length-framed canonical cells,
not complete Arrow IPC or negotiated native wire messages. The native profile
continues to use identity encoding. Protocol allocation counts remain nonzero;
these records establish bounded costs and batching reductions, not zero
steady-state allocation, hardware cycle/IOPS isolation or a latency SLO.
