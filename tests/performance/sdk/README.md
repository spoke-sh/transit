# Installed SDK performance

[Performance index](../README.md) · [SDK consumer owners](../../sdk/README.md)

This workload measures the shipped Catalog and finite Query APIs through the
public Zig SDK, installed Python synchronous/asynchronous wheels and installed
Node packages. It uses one private native-local installation, synchronous
durability and the same two-column integer data and budgets in every language.
It does not supply missing ordinary SQL/context or transaction adapters.

Enter `nix develop .#bindings`. Prepare matching optimized native clients and
packages before starting a timing run:

```sh
native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize ReleaseSafe)
python3 -B bindings/build_python.py .cache/bindings/ReleaseSafe/wheels transit-native-client transit-native-station transit-client transit-station --native-prefix "$native_prefix"
python3 -B bindings/build_node.py .cache/bindings/ReleaseSafe/node transit-native-client transit-client transit-native-station transit-station-sdk --native-prefix "$native_prefix"
mkdir -p .cache/performance/sdk
just test::sdk-performance --native-prefix "$native_prefix" --repeat 5 > .cache/performance/sdk/run.jsonl
python3 -B tests/runner/launch.py tests/performance/sdk/report.py .cache/performance/sdk/run.jsonl > .cache/performance/sdk/report.json
```

The Just task compiles the matching service and Zig consumer before running.
For alternating campaigns, build and freeze both arms first, then invoke
[`run.py`](run.py) with explicit `--cli`, `--node`, `--host`, `--zig`, `--wheels`,
`--node-packages` and `--native-prefix` paths. Do not compile or run other owned
disk-heavy checks during measurements. The declared native build must be
ReleaseSafe; installed libraries/hosts must match its hashes and the service's
contract definition. Zig uses the public SDK build exports and a copied binary;
this does not qualify the distributed Zig archive.
For source-attributed comparisons, also pass `--native-record PATH` using the
record path printed by native preparation. Its prefix, complete artifact hashes
and build metadata must match `--native-prefix`; the report records that build's
revision, dirty state and source hash separately from the driver checkout.
Comparison refuses missing native source provenance.

Each language runs outside the checkout with a new process and explicit package
resolution. Package installation is timed separately. Cold time covers process
launch through the first verified metadata response; import and client-open
observations are narrower consumer measurements. Warmup defaults to one call per
case; `--repeat` defaults to five measured calls. These defaults are a smoke
probe, not a tail-latency or 10× claim.

[`workload.py`](workload.py) owns the language-neutral cases and independent
oracle. Metadata checks row/column counts and an absent object. Queries cover
empty, point, eight-row range and full results (70 rows by default).
Relational `ORDER BY` is unsupported and is not included in the statements.
Writes cover one and eight rows followed by a fresh query of those exact values.
Every query collects at most 1,000 pairs, sorts them by `(id, value)` and verifies
a SHA-256 digest of signed little-endian 64-bit values, including duplicates.
This canonicalization belongs to the oracle and is included in consumer timing;
it does not assert a SQL result order. Queries require terminal coverage. Every write requires the original
committed operation's matched/changed counts. Saved operations and snapshot
acquisitions are file- and directory-synced before dispatch; reads close their
query and release their retained snapshot before reporting success.

Each JSONL attempt retains complete/failed status. A unique automatic copy lives
under `.cache/performance/sdk/runs/`; its path is printed to stderr. Service and
consumer cleanup precedes the final campaign outcome, including output failure. Consumer elapsed time covers
the public operation plus persistence, decoding and verification; end-to-end
time additionally includes the benchmark's stdin/stdout exchange and independent
oracle. First-row time includes source lookup, snapshot acquisition and query
opening. CPU and peak RSS observations are process-local where supported;
Linux process-tree RSS/PSS/thread snapshots include Node native hosts outside
timed calls. Native allocation counts, language allocations and copy counts are
explicitly unavailable. The benchmark establishes no zero-allocation claim.

[`report.py`](report.py) refuses missing/duplicate calls, failed warmups,
incomplete results, missing resource phases and unjoined close. It reports
sample counts, p50, empirical p95 and maximum separately for consumer and
end-to-end latency. `--control CONTROL.jsonl` computes p50 ratios only when
workload, driver, toolchain, machine and durability/cache declarations match.
OS and server caches are retained; there is no eviction or cold-disk claim.
An interrupted or failed campaign keeps its installation and saved operation
files privately; preserve that directory before attempting recovery.

Automatic maintenance is enabled by default. `--maintenance disabled` is a
separate fixed-data profile for SDK overhead: automatic Table flush, archive and
compaction are disabled in that private fixture, while foreground writes retain
the same synchronous durability. Reports record the profile and reject
comparisons across profiles. An exact snapshot acquisition racing maintenance
can fail with a frontier conflict; the driver retains that attempt and original
identity, and does not silently choose a new snapshot or resample it. Passing
the isolated profile does not qualify concurrent maintenance behavior.

No numeric SDK regression budget is active yet. Qualify at least three
alternating matched pairs with at least 50 steady samples per arm and case
before freezing budgets. Repeat cold starts independently and retain every
attempt. Timing does not replace the installed Catalog/Query fault, cancellation,
revocation, uncertain-operation and process-death schedules. Other languages,
wide/nested values, concurrent facets, transactions, allocation/copy attribution
and clean-lane qualification remain separate obligations in
[Milestone 9](../../../docs/roadmap/09-client-foundation-and-language-apis.md#sdk-performance-implementation-sequence--2026-11-01).
