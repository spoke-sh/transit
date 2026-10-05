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
