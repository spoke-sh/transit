# Process-limited storage growth attempt

The [raw attempt](attempt.json.gz) is **failed**: native setup for 512 turns
exceeds the unchanged 1,800-second child timeout. Its two Table fixtures complete
creation, strictly cold fresh-process readback, independent values/digests and
unchanged file inventories. The complete four-fixture growth requirement remains
open. See the [method and reproduction command](../../storage_benchmark.md#growth-under-a-process-memory-ceiling).

## Source and environment

The run starts on clean revision
`b85a0a076f78ecd8061221cd3ffef7f572466236`. Its frozen ReleaseSafe probe uses
16 KiB deterministic payloads, CPU 0 and a 134,217,728-byte `RLIMIT_AS` ceiling.
Zig is `0.17.0-dev.2267+48abf1a34`, Linux is 6.17.0-41 and the filesystem reports
the `ext2/ext3` family. Host RAM is 127,324,508 KiB; other work runs concurrently.
The Table keeps one index page, 512 KiB of encoded segment cache and a separate
128 KiB decoded allowance. Candidate/result scratch and process mappings remain
additional memory, all subject to the process ceiling.

| Identity | SHA-256 |
| --- | --- |
| Frozen executable | `4d1bddccb9ecf0366dd20d583d1314499e1069abeb44edccbb42cbb1385581a0` |
| Probe | `ae7f66300d9769d74d0404edb7e92b9a86ffb4d733a49d53630b29ed66e4f1b9` |
| Growth driver | `540e86bdecab15a12e2323204ccfcb8f3131cae0ab0174b031c6d8f30fd02d78` |
| Common driver | `0dfbd0d3795977afe2794e0d7f79d430d4431b0e92ec7e097249671cb937311b` |
| Uncompressed report | `c49303f1f7f137f5080b9b377c9693f89ca504006dc9a357b6c6490773c98b3f` |

These source hashes match that recorded commit. Later compact Table evidence,
policy-page caching and root enumeration are outside this measurement.

## Completed Table observations

| Rows | Retained bytes | Allocated disk bytes | Files | Setup seconds | Readback seconds |
| --- | ---: | ---: | ---: | ---: | ---: |
| 2,048 | 44,586,146 | 112,709,632 | 25,613 | 428.40 | 3.61 |
| 8,192 | 191,717,253 | 501,526,528 | 118,950 | 1,794.41 | 17.55 |

The larger retained fixture exceeds the process address-space ceiling, not host
RAM. Its logical recovery replays 513 frames without checkpoint maintenance and
its complete value read has a 312,449-byte tracked allocation peak. Those heap
counters exclude stack and static executable memory. The larger fixture's
probe-image virtual peaks are 76,216 KiB at setup and 10,996 KiB at readback;
corresponding image RSS peaks are 33,744 KiB and 7,424 KiB. `wait4` RSS in the raw
report additionally includes inherited pre-exec Python memory and must not be
substituted for these image measurements.

One sample per fixture provides no latency distribution or service throughput
claim. The larger setup nearly exhausts the time budget. Small immutable files
and publication barriers remain costs even though memory stays bounded in these
completed cases. Both Table readbacks perform no appends or object publication.
Archiving re-runs their independent result validators and checks exact cold
residency. Native setup does not produce a completion record before timeout;
there is no native growth or complete-matrix pass to infer from the Table data.
This is not installed SQL, physical power-loss or final clean-revision evidence.
