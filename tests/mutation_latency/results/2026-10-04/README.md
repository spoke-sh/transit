# Durable mutation campaign, 2026-10-04

Raw ReleaseSafe controls for [issue #55](https://github.com/rupurt/rey/issues/55).
Binary hashes identify each build; `source_revision` identifies the runner checkout,
which can differ from the declared frozen `build_revision`. Dirty intermediate
candidates are labeled in the original reports. Fixtures live on ext4 under
`/var/tmp`, with disk Ursula and owned MinIO. The host is an AMD Ryzen Threadripper 3960X with 48 logical CPUs. Shared-host
compilation and other proofs ran concurrently. These observations establish no latency SLO.

The gzip files preserve original report bytes, including failed controls, timing,
fixed diagnostic categories, bounded request traces, executable hashes and recovery
fixture paths. They contain no credentials or original signed requests. Failed
fixture paths refer to retained local evidence; they are not portable installations.

| Run | Status | Samples | Compressed SHA-256 |
| --- | --- | ---: | --- |
| [baseline-default](baseline-default.json.gz) | complete | 140 | `b17ff80859e46a0ec8c37b7fc09b7ed9ca62353520175662b67d95ddff261050` |
| [baseline-idle-counts](baseline-idle-counts.json.gz) | complete | 21 | `fd2d3e7e31366d299841bb93747a8bcb06823ee2580120fe829e6e648ecfd90c` |
| [baseline-setup-incomplete](baseline-setup-incomplete.json.gz) | failed | 0 | `a229f760628dfb1892cecf08c233d41138b12187b65560e8ca67392e9c238593` |
| [batched-default](batched-default.json.gz) | complete | 140 | `9687cc89e69d66a8406f32139bfe6f1f0ca3b195b3ebac12b1fad86a309b15e3` |
| [batched-idle-counts](batched-idle-counts.json.gz) | complete | 21 | `28dc7394b8a873c90ed6a22895bc9ec9fc2791c9d04c3e80416ab3f1957ce66c` |
| [caller-default](caller-default.json.gz) | complete | 140 | `6ab6998426062d3f112e042c1e64f570c16ada53f861a07da3939b971c08f7c0` |
| [compact-client-history-repeat](compact-client-history-repeat.json.gz) | failed | 109 | `d73222426c1aa175bb4fbc41535e3d7663ef7a7246654a2a7ab584b436d9549c` |
| [compact-client-history](compact-client-history.json.gz) | failed | 0 | `30a3a8a021fa6176129d7f2bda6d74f323e9cc26d2459e4c2ca74150cc70bca8` |
| [compact-default-repeat](compact-default-repeat.json.gz) | complete | 140 | `9d31789bb2f4de1b87b6b91ed9571afdb2712f0d236ca9003b660fc152301081` |
| [compact-default](compact-default.json.gz) | failed | 125 | `8a3e20641b615f0903ef0b81896e8bb30775db663aae45e01c7477e3b32aa498` |
| [compact-idle-counts](compact-idle-counts.json.gz) | complete | 21 | `0633e1ac20e089d7644c6fc7b0f57522f82a83265c64fa3e563cf5d5606a1273` |
| [compact-idle](compact-idle.json.gz) | complete | 140 | `34dae4bbb0589928ff244a90029f96e4e22df902459d0a7b3e1ae2144bdcbf20` |
| [compact-pressure-direct](compact-pressure-direct.json.gz) | failed | 235 | `077566c0bd7fd3c303babe2cd0fe75f52ec0c3067440a2f090a5d83d54eaa362` |
| [compact-pressure-reuse](compact-pressure-reuse.json.gz) | failed | 609 | `cad7ba01d68aecaef1634189d14c7b1da5aa5e2a3d4ab7b3fb795e5146caa7df` |
| [compact-pressure](compact-pressure.json.gz) | complete | 140 | `f7131b50c5806d755ff80c7173a936b70131f8c54f8f572c430a85c611aa9612` |
| [compact-setup-incomplete](compact-setup-incomplete.json.gz) | failed | 0 | `5aff367162a8b406ec67554f5b9453ec44fc0feece07bcefa3bb944514637b56` |
| [diagnostic-client-history](diagnostic-client-history.json.gz) | complete | 700 | `adec32b9ac1f3981f0bc4cb43b7c2b85b1bd821aab4dbe3b07028d92462211e5` |
| [diagnostic-client-unproxied](diagnostic-client-unproxied.json.gz) | failed | 112 | `65688b6ce771d2ec32743612ba76d6bc70938e95e1c020ed48fae9b544734993` |
| [gateway-diagnostic-client](gateway-diagnostic-client.json.gz) | failed | 124 | `4f5aa7a9d4a59e44572350a7fac8416f6de3cd539fd83bb808342c60615a6556` |
| [notified-default](notified-default.json.gz) | complete | 140 | `3c3c8aae1c2e7395eabf937d6b55f8653e8047e703d8239e52e28488d914ac3e` |
| [scoped-default](scoped-default.json.gz) | complete | 140 | `c306f8c15b218c2672b32291a5577e6b62de68721c0e4e368a9f3e71a142a515` |
| [native-diagnostic-client](native-diagnostic-client.json.gz) | failed | 111 | `b81f3df93784cb97cf14154245a08e24f94cfe20679afb4fa7ac2cc1e3f996d3` |
| [provider-diagnostic-client](provider-diagnostic-client.json.gz) | failed | 273 | `327dd06943e878884da64ef14009cd9179ff6a45054e954d4ba9dc9d601e5151` |
| [fixed-client-history](fixed-client-history.json.gz) | failed | 700 | `fe9902edcfe1b47cd46bffd8c194423efb231893897ea4b624a44fe6ffb9cd77` |
| [fixed-default](fixed-default.json.gz) | complete | 700 | `285a5dbb7832f55d915c38f0ed1b6efe1f90a7ff9606885edee71f865fdf78c6` |
| [fixed-client](fixed-client.json.gz) | complete | 140 | `5260768ee8fad16e6d9c4f7e40dedf6a7e47e548497a3c70cbce3b576033a1a0` |
| [fixed-rows](fixed-rows.json.gz) | complete | 140 | `22fcccc49306a01acc14389b46c89c347d54659240eaeb2b122936f0cf67124e` |
| [fixed-history](fixed-history.json.gz) | complete | 140 | `022dd7d8ec1ef9a3898fb45e952806e710c646fc1c595cc19972a6da377a45f2` |
| [fixed-cache](fixed-cache.json.gz) | complete | 140 | `22e2195a7a82b1fee74f3f529577e0bdc99f1f7d595b2d77762c444a7c0c97f9` |
| [fixed-readers](fixed-readers.json.gz) | complete | 140 | `f61b064f3239549cde75d60e8e35ad2956ae5ab7d1c95dc4dfeda10ae58e1140` |
| [fixed-idle](fixed-idle.json.gz) | complete | 140 | `509a11925ba74df3c63a6a1201980454474b5bbd7c8f0c368892ca73ff1ed4d2` |
| [fixed-pressure](fixed-pressure.json.gz) | complete | 700 | `4f08dbcfcd69f236832dd4c54aeaa1c5dc48821f1d0957bd5f983caccd27c4a7` |
| [slow-diagnostic-rows](slow-diagnostic-rows.json.gz) | complete | 280 | `e2124059fdfa6241ce0963b51c02d27ac690ee9cd9edb11d2ea377cbb0feaf0c` |
| [fixed-client-history-repeat](fixed-client-history-repeat.json.gz) | complete | 700 | `217253e5edb3939c23032b4cc2f056396763fd5e7c16a3c6e75e82f1914d58c5` |
| [baseline-fixed-provider](baseline-fixed-provider.json.gz) | complete | 140 | `7faa0e0adebc48575c3f465bad26aa78c67b8909810d2016a2ca7cfb2db9af6b` |
| [fixed-default-paired](fixed-default-paired.json.gz) | complete | 140 | `f15c61186e890848bb6962300aee66f79ef0b10392dde291e9e249f97a0187a4` |

## Interpretation

`baseline` freezes `623cde9b`, `caller` is `fa1fbf29`, `batched` is `3d1dc02e`,
`notified` is `fdb449a4`, and `scoped` is `213acb3b`. The compact candidate's
runtime is committed in `f4a1c5df`. Setup failures are preserved separately from
workload failures. A completed repetition contains seven cases: one/three-row
INSERT, existing/same-value/absent UPDATE, and existing/absent DELETE. Each
result checks affected rows and an independent subsequent read outside timing.
Cleanup mutations are not included in sample counts.

The first compact default control failed after 125 cases during an uncertain
three-row INSERT. Restart and explicit `.resume` reconciled its original saved
operation successfully; no fresh SQL was issued. A fixed-poll unproxied control also fails after 235 cases; restart and explicit
recovery complete its saved one-row DELETE. The owned recovery reports retain
original-file hashes and operation identity. A later completed control is a
separate run and does not retroactively qualify the failed workload. That first
failure predates structured diagnostic capture and has incomplete failure timing.

Instrumented controls include proxy overhead and background work. Earlier proxies
used HTTP/1.0 and a fresh upstream per request, so they cannot diagnose pooled
connection lifetime. `compact-pressure-reuse` and subsequent diagnostic controls
preserve sequential HTTP/1.1 reuse and advertised closure, with a finite proxy
idle timeout. Instrumented native traces retain the last 2,048 completed attempts
and explicitly count omitted events. The later runner also retains a separate
64-attempt failure ring so subsequent successes do not erase a rare failure. Provider time is included in authority work;
concurrent lock waits overlap and must not be added as exclusive wall time.

The isolated [page-layout study](page-layout.json) counts raw core bytes; native
packed-page counters include the canonical base64 JSON provider envelope. The
study compares a JSON 4/5 baseline with compact 4/5, 4/32 and 8/32 variants and
monolithic/separate roots. It does not execute provider I/O or native authority.

Diagnostic-only builds retain their [gateway patch](gateway-diagnostic-only.patch)
and [native patch](native-diagnostic-only.patch). They add fixed error-category
capture around the shipped diagnostic source in `1abb2136`/`199ea31b`; they never
change request bytes, retry policy or authority publication. These temporary
probes are not part of the shipped runtime. Their reports remain diagnostic
controls with dirty-source labels and executable hashes.

## Reproduction

Enter the pinned development environment, set `TMPDIR` to an owned ext4 directory,
and build frozen matching binaries with `zig build transit transit-node
transit-query-host transit-board mutation-latency-client -Doptimize=ReleaseSafe
--prefix PREFIX`. Wait for the build to finish before starting the fixture.
Run `python3 -B tests/mutation_latency.py PREFIX/bin/transit
PREFIX/bin/transit-node PREFIX/bin/transit-query-host --repeat 20 --output FILE
--build-revision REVISION`. Original reports retain every additional control.
Use the matched source revision for old contract definitions. Never reuse or reset
an incompatible installation for a comparison.

`--client PREFIX/bin/transit-mutation-latency-client` selects the persistent Zig
consumer; its checkpoint costs differ from the console. `--rows` varies retained
cardinality and `--age` adds retained updates at fixed cardinality. `--idle-ms`,
`--readers`, `--resident-pages` and `--worker-interval-ms` are independent controls.
`--instrument` is a separate diagnostic profile. Nearest-rank p95 requires 20
samples per case; p99 requires 100. Incomplete runs establish neither a successful
workload nor its latency distribution.

## Provider refusal diagnosis

`native-diagnostic-client` fails after 111 cases and captures
`ServiceUnavailable` inside the node. `provider-diagnostic-client` fails after
273 cases and captures `ProviderColdBackpressure`, using the temporary
[provider probe](provider-diagnostic-only.patch). The gateway probe had already
excluded its transport catch path for a separate reproduced failure. The
[bounded metric samples](provider-metrics-tail.json) record hot bytes reaching
8,296,095 (high watermark 8,368,963), below the 8 MiB rejection threshold before
the failed append, with zero observed cold-write errors. These samples end before
the refusal and do not claim its counter is zero. The diagnostic build retains
only fixed provider categories; arbitrary response bodies are not logged.

The pinned flush planner can repeatedly select a small journal prefix, then
discard a full-sized page chunk because their sum exceeds its batch target. The
[local provider correction](../../../../nix/ursula-cold-flush.patch) sizes later
chunks against the remaining target. Its repeated two-stream unit case preserves
planning/publication separation and exact offsets. The hot limit remains 8 MiB.
The first patched provider build passes all 83 upstream stream units and six
integration tests. End-to-end qualification of the corrected provider is recorded
separately; this diagnosis does not retroactively complete failed controls.

## Corrected-provider controls

[Provider build provenance](provider-build.json) identifies the bounded-flush
correction committed in `4ef3f598`. The frozen `fixed` Transit executables use the
compact runtime and diagnostics through that source; `fe4b5181` changes only
documentation. The early declared `9e68a171+bounded-provider-flush` build label
describes that runtime plus the provider correction; executable hashes and the
actual runner source revision remain authoritative. Later runner changes retain
reader failures and bounded supervisor categories. A dirty runner checkout can
include temporary diagnostic sources that are absent from the frozen binaries.

`fixed-default` and `fixed-pressure` each complete 700 cases. The latter uses a
fixed 20 ms worker interval and reports no runtime restart. The former records an
authority-timeout restart; its INSERT/UPDATE/DELETE p50 is 448/492/447 ms, p95
732/860/578 ms, and maximum statement time is 13.6 seconds during recovery. The
longer run grows more retained history than the original 140-case baseline.
These are shared-host controls with simultaneous integration work, not a paired
speedup comparison or an error-free availability guarantee.

The direct caller, 120-row, 120-update-history, cache-64, one-reader and idle-gap
controls each complete 140 cases. The 120-row control records two runtime
authority-timeout restarts. Several controls also record cold-bucket setup
retries before workload readiness. Those setup events are not mutation failures.

`fixed-client-history` is **failed**: all 700 mutation cases and final row count
verify with zero uncertain writes, but its reader stops during the supervisor
restart. Its original runner loses the reader's detailed cause and cannot
establish continued reader load; no successful workload percentiles are derived
from it. Its [supervisor sidecar](fixed-client-history-supervisor.json) was
captured from the owned fixture. Subsequent reports retain reader progress and
structured failure categories directly.

The [corrected-provider S3 proof](fixed-pages-s3.json) passes 1,024-key writes,
interrupted batch acknowledgements, retained-root restart, checkpoint and trim
recovery with two resident cache pages. This proof retains its own source and
provider provenance; it does not establish mutation latency.

The [slow-request probe](slow-native-diagnostic-only.patch) is temporary and
unproxied. It completes 280 cases with 120 rows and no restart. The
[bounded slow samples](slow-diagnostic-events.json) retain 64 of 77 events meeting
a 500 ms wait/work threshold or reporting failure. One retained sample spends
1,891 of 1,900 ms in provider I/O across 86 attempts, while another read waits
1,879 ms before doing 4 ms of work. These observations establish long provider
work and resulting serialized queueing. They do not directly reproduce or prove
the cause of every earlier authority timeout, and are not a distribution of all
requests. The temporary probe is absent from the shipped runtime.

The subsequent `fixed-client-history-repeat` completes all 700 mutation cases and
5,729 concurrent reads with no reader failure, uncertain write or runtime restart.
It uses 12 retained rows, six setup updates and a 64-page cache. Single-row
INSERT/UPDATE/DELETE p50 is 285/346/285 ms and p95 323/405/323 ms. This separate
successful workload does not erase the failed first combined control.

`baseline-fixed-provider` and `fixed-default-paired` run the frozen old/new Transit
binaries sequentially with the same corrected provider, fresh default fixtures
and 20 repetitions. Both complete 140 cases without uncertain writes or restart.
INSERT/UPDATE/DELETE p50 changes from 346/334/329 to 135/152/143 ms and p95 from
404/402/546 to 154/179/148 ms. The gRPC cold-storage diagnostic overlaps part of
these controls; the larger CI campaign has stopped. This matches configuration
and provider, not host interference, and establishes no p99 or deployment SLO.

## Clean qualification attempts

The [d4 task results](clean-d4-interrupted.json) and
[completion metadata](clean-d4-interrupted.meta.json) retain the interrupted old
provider run after 63 successes. The [4ef results](clean-4ef-interrupted.json) and
[metadata](clean-4ef-interrupted.meta.json) retain the early stop for a known
public-document ownership error. Neither is a completed clean suite.

The [fe4 results](clean-fe4-failed.json) and [metadata](clean-fe4-failed.meta.json)
record 43 successes followed by the gRPC cold-object assertion failure. The
[diagnostic rerun](cold-pack-diagnosis.json) finds 135 actual shared packs and
zero individual chunks; the old fixture counted only individual chunks.
The counter correction preserves spill assertions and tests both pinned paths
while excluding unrelated metadata. Previously recorded `cold_objects` may
under-count shared packs; their nonzero assertions still establish actual data
objects, not total object cardinality. Raw reports remain unchanged.

The [completed 3a task results](clean-3a-complete.json) and
[completion metadata](clean-3a-complete.meta.json) verify all 75 ordinary tasks
in order, with zero failed exits and an explicit completed flag, at
`3a52d102ede0763dff9b0590b11f21722dd163b7`. Elapsed suite time is 6,789.17 seconds,
excluding initial checkout/dependency setup. The gRPC and HTTP worker proofs
observe 135 and 193 cold objects respectively under unchanged 8 MiB hot limits.
[Query/mutation records](clean-3a-runtime-evidence.json),
[ten-language interoperability](clean-3a-public-interop.json) and
[Station readiness recovery](clean-3a-station-readiness.json) retain their scoped
results separately from latency controls.

The later documentation source `cd9fde43` passes the separate seven-task clean
experience lane; its [results](clean-cd9-experience.json) and
[metadata](clean-cd9-experience.meta.json) do not stand in for a full suite.
Subsequent source changes are documentation and evidence only. Neither ordinary
CI nor that scoped lane qualifies the browser tier, external deployment profiles
or the unpatched official provider image. Failed earlier attempts remain failed.
