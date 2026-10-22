# Storage foundation baseline, 2026-10-18

This page retains measurement summaries at the stated revisions. References marked
“archived” name raw files removed from the current tree; those bytes are available
only in repository history before the cleanup. These observations do not qualify
current builds.

These controls freeze source `ee88a131` in a clean independent worktree. The
ReleaseSafe build includes the CLI, node, query host, Board and SQL gateway;
binary/provider hashes and exact controls are retained in the
qualification record (archived).
The owned fixtures use disk Ursula and MinIO on ext4 under `/var/tmp`. Builds
finish before measurement, and the campaigns run sequentially.

The uninstrumented console controls validate all returned values independently.
The narrow profile completes 140 operations; wide and nested each complete 21,
without errors or unknown outcomes. Wide adds 30 default 64-byte UTF8 fields to
the two-column narrow table. Nested adds a structure containing a 128-byte label
and a 32-element nullable text list. These are synthetic workloads, not an SLO.

| Case | Narrow p50 / p95, ms | Wide p50, ms | Nested p50, ms |
| --- | ---: | ---: | ---: |
| insert_1 | 1393.978 / 1499.855 | 24638.151 | 20052.109 |
| update_1 | 1415.741 / 1549.377 | 5564.572 | 4275.709 |
| update_same | 843.800 / 915.435 | 984.606 | 920.911 |
| update_absent | 798.637 / 869.846 | 959.250 | 866.894 |
| delete_1 | 836.110 / 917.526 | 1027.371 | 903.863 |
| delete_absent | 809.205 / 868.140 | 976.206 | 902.572 |
| insert_3 | 2702.204 / 2945.764 | 69872.130 | 52407.179 |

Percentiles use empirical nearest rank. Narrow has 20 samples per case; wide
and nested have three. None establishes p99. The SQL gateways are built and
hashed, but these controls use the console; wire-path measurements are separate.

The retained-history control selects 32 seed rows, 32 extra retained mutations
and one concurrent reader. All 21 foreground mutations complete, but the
campaign **fails** because the reader receives `query.transport_unavailable`
with native cause `HttpCapacity`. Preserve that failure when comparing the new
implementation; it is not a successful concurrency result.

The separate instrumented run completes seven operations without errors or
unknown outcomes. Its first single-row INSERT records 153 native and 1,443
provider attempts, two turns, one internal delivery and 71 staged pages. These
include overlapping background activity and instrumentation overhead. They are
neither isolated fsync counts nor independent durations to add together.

Raw reports preserve their original bytes with deterministic gzip:
narrow (archived), wide (archived),
nested (archived), retained/concurrent failure (archived)
and request attribution (archived). The qualification record
pins both raw and compressed hashes. No improvement is claimed before matched
controls on the completed foundation.
