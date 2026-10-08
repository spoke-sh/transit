# General Table performance campaign, 2026-10-07

Physical-disk controls for [issue #75](https://github.com/rupurt/rey/issues/75).
The fixed-profile baseline is merged `cc5f57e7`; general Tables use runtime
`1832f58a`. The corrected concurrent-reader harness is `decdbd94`, with the same
runtime binaries. Reports retain exact source/build revisions and binary hashes.
All measured source trees are clean. Later artifact/documentation commits do not
change the measured executables.

Fixtures use fresh owned ext4 installations under `/var/tmp`, MinIO, eight
authority cache pages and default worker waits. Runs are sequential; no other
build or proof from this campaign overlaps measurements. Ambient shared-host
work is not controlled. Bootstrap, cleanup and independent typed readback are
outside mutation timings. The missing Board binary is built before the candidate
measurement, after the baseline completes.

## Matched narrow mutations

Each run completes 140 mutations: 20 observations of seven cases, without errors,
unknown outcomes or observed supervisor restarts. No additional seed rows,
history, readers or instrumentation are selected. Both retain one seed row.

| Case | Baseline p50 / p95, ms | General p50 / p95, ms |
| --- | ---: | ---: |
| INSERT one | 111.849 / 135.072 | 187.734 / 269.727 |
| UPDATE existing | 130.647 / 165.118 | 195.975 / 230.873 |
| UPDATE same value | 111.075 / 126.180 | 184.706 / 222.813 |
| UPDATE absent | 133.621 / 174.639 | 164.104 / 225.031 |
| DELETE existing | 113.678 / 129.392 | 189.306 / 269.698 |
| DELETE absent | 135.990 / 168.374 | 168.874 / 221.243 |
| INSERT three | 124.153 / 135.227 | 869.284 / 1049.596 |

These measurements establish a regression, not latency parity or an SLO.
Nearest-rank p95 has 20 samples; p99 remains null.

## Width, nesting and retained data

Wide and nested controls each complete 21 mutations and verify every extra typed
cell after each mutation. Wide uses 32 columns, including 30 text defaults of
64 bytes each. Nested uses three columns, including a struct with a 128-byte
label and a 32-element nullable text list. DROP/CREATE setup timings are recorded
separately. These have no equivalent historical schema baseline. Three samples
per case do not support p95 or p99.

| Profile | INSERT one p50, ms | UPDATE existing p50, ms | INSERT three p50, ms |
| --- | ---: | ---: | ---: |
| Wide | 5741.170 | 1989.814 | 16794.683 |
| Nested | 4654.751 | 1244.318 | 12400.868 |

The retained-data pair adds 32 seeded rows, 32 retained mutations and one reader.
Baseline completes 21 writes/88 reads; general Tables complete 21 writes/156
reads. Both have no errors, unknown outcomes or observed restarts. Read counts
are not throughput comparisons: slower writes leave a longer reader interval.
Baseline/general p50 is 163.631/2771.244 ms for INSERT, 135.940/1982.695 ms for
UPDATE, 174.479/2148.965 ms for DELETE and 172.411/4172.535 ms for three-row INSERT.
These combine cardinality, history and reader load; they do not isolate each
contribution.

One separate instrumented run completes seven cases. Point changes use one
send/turn; three-row INSERT uses one send, four turns and three internal
deliveries. Native attempts are 29–33 for point cases and 153 for three-row
INSERT. Provider attempts are 153–250 and 1390 respectively. The three-row
interval transfers 266107 request bytes and 2074100 response bytes through the
provider proxy. Counts include concurrent worker/observation activity. Attempts
are not fsync counts; overlapping timings are not an exclusive wall-time
breakdown. One observation is not a distribution. The first processed input
does not establish terminal completion of a staged statement.

## Failed attempts and open gate

- `failed-missing-board` exits before samples because the private bundle lacks
  Board; the bundle is completed before `general` runs.
- `failed-reader-config` completes writer samples but its reader rejects a
  superseded top-level recovery-file setting before SQL. `general-load` uses
  the corrected interactive catalog configuration.
- `failed-probe-port` exits before samples because an ephemeral proxy port
  collides with the fixture's not-yet-bound store port. A fresh owned fixture
  completes `general-counts`; no accepted SQL from failed setup is retried.

The separate 41-row interactive Table proof preserves its request ceilings and
fails them: full scan/COUNT uses 75 requests against nine, LIMIT 3 uses 23 against
four, and primary-key equality uses 22 against three. Correct rows, current denial,
cancellation and incomplete-prefix checks do not turn that budget failure into
a pass. General scalar ranges scan by row identity; the old int64 physical range
path is no longer their access method.

Performance remains an open completion gate on #75. Larger allowances have not
been accepted or substituted. These results do not establish the earlier
point-write latency or scan efficiency. Retained-memory and recovery proofs are
separate evidence in the [proof ledger](../../../README.md).

## Reproduction

Enter `nix develop` and use an owned disk-backed TMPDIR. Build each frozen source
with `zig build transit transit-node transit-query-host transit-board
-Doptimize=ReleaseSafe --prefix PREFIX`. After all builds finish, run:

```sh
python3 -B tests/mutation_latency.py PREFIX/bin/transit PREFIX/bin/transit-node PREFIX/bin/transit-query-host --repeat 20 --resident-pages 8 --build-revision REVISION --output FILE
```

Use that revision's harness. For the corrected general harness, select
`--repeat 3 --schema-profile wide` or `nested`; select
`--repeat 3 --rows 32 --age 32 --readers 1` for retained data.
Use `--repeat 1 --instrument` only for separate attribution. Never reuse an
incompatible installation across the current-definition cutover.

## Artifacts

Compressed files preserve original report bytes, including failures. They contain
synthetic values, measurements, hashes and fixture paths, without credentials or
signed requests. Hashes cover the compressed files.

| Report | Status | Compressed SHA-256 |
| --- | --- | --- |
| [baseline](baseline.json.gz) | complete | `6bb6abafbea16596e869d0a59e8acbc4fe3ba01514ab36147139ca45af9459ae` |
| [general](general.json.gz) | complete | `5b28891666369066e4d2ed19f1cdd89c414cd9d8908c6c5c84f42593139c75d3` |
| [wide](wide.json.gz) | complete | `62485abea0ded4f63264aab216bedb9d53b411270d4a66f9ed2a485288e34792` |
| [nested](nested.json.gz) | complete | `adf97fe6263c55ae66131c627d1186dc5414d959cba154840cdea422736e2f93` |
| [baseline-load](baseline-load.json.gz) | complete | `79cd6be620715e1d529b91f2d97a73d3d565f3c72ee24a20a6463263aa8eabd0` |
| [general-load](general-load.json.gz) | complete | `055b2fd0f98e86e96caf7629edf3f559354579756377725258213011f1de051e` |
| [general-counts](general-counts.json.gz) | complete | `b95cba97adbd70b46ca481937360d7da451d8717b78593f1c3051f8e787782fd` |
| [failed-reader-config](failed-reader-config.json.gz) | failed | `ae10626f670f49423f335564ea6b83b48ff80af4d0abc15e1ae9022f95661007` |
| [failed-missing-board](failed-missing-board.json.gz) | failed | `fb47b0d1d4d2ea7d1d7ca4233b69f56f665141831e50d8b2ebff20ab8366a74b` |
| [failed-probe-port](failed-probe-port.json.gz) | failed | `6c7c30c0d67666ea1108cde6e1909c12e1c8f01d80a164079bc87960f0a3ba5c` |
