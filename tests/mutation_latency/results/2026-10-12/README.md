# Complete Table history mutation cost, 2026-10-12

The existing console benchmark completes 140 independently verified mutations
at source `d91f6f0f`, with no errors or unknown outcomes. It uses owned ext4
directories under `/var/tmp`, disk Ursula, MinIO, eight resident authority pages,
the narrow two-column Table, one seed row and default waits. No extra rows,
history or readers are selected. Runtime measurements overlap two separate
maintained-query proofs on the same host; this is not an isolated timing control.

| Case | Historical general Table p50, ms | Complete history p50 / p95, ms |
| --- | ---: | ---: |
| INSERT one | 187.734 | 1036.925 / 1222.652 |
| UPDATE existing | 195.975 | 1035.852 / 1160.008 |
| UPDATE same value | 184.706 | 490.633 / 620.267 |
| UPDATE absent | 164.104 | 469.553 / 527.479 |
| DELETE existing | 189.306 | 507.841 / 642.527 |
| DELETE absent | 168.874 | 493.034 / 748.015 |
| INSERT three | 869.284 | 2034.800 / 2352.572 |

Each current case has 20 samples; p99 remains null. The historical comparator
is [the accepted general Table campaign](../2026-10-07/README.md), which also
retains the earlier fixed-profile baseline from the
[mutation completion work](../2026-10-05/README.md). Different source revisions,
dates and concurrent load prevent attributing the whole timing difference to
change capture. These observations do not establish latency parity or an SLO.

The separate instrumented run completes seven cases, one per case. INSERT one
and UPDATE existing now use two native turns and one internal delivery, compared
with one turn and no delivery in the general Table baseline. Their provider work
records 521/633 requests versus 147/175, and 63/68 staged pages versus 21/22.
The additional history mutation crosses the existing four-write inline boundary;
the implementation stages work instead of raising that bound. Same-value/absent
updates and both deletes use one turn. Three-row INSERT remains four turns and
three deliveries, recording 1,487 provider requests versus 1,380. Concurrent
observation activity can affect request totals; requests and staged pages are
not fsync counts. One sample supplies no timing distribution.

[Ordinary report](mutation-history.json.gz) and
[instrumented report](mutation-history-counts.json.gz) preserve complete original
JSON bytes compressed with deterministic gzip. The [qualification record](../../../verification/results/relational-mutation-cost-2026-10-12.json)
pins compressed/raw hashes, commands, controls and limits. Reports contain fixed
fixture values, binary hashes and paths, without private seed contents or signed
requests. Reproduce with the pinned shell and the existing
`just test::mutation-latency --repeat 20 --output FILE` task; add `--instrument
--repeat 1` for attribution. The underlying command in the record uses the
already-built binaries, preserving a separate build and measurement phase.
