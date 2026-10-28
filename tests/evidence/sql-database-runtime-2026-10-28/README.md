# SQL database runtime comparison

This reference retains the matched control/candidate samples for assessing the
SQL account-runtime cutover beyond ordinary CI retention. The SQL and
[performance owners](../../performance/AGENTS.md) maintain it; it is evidence,
never a correctness-test input. The
[qualification account](../../../docs/history/qualification/sql.md#database-owned-sql-runtime--2026-10-28)
records interpretation, failures and scope.

[Control](control.jsonl) is `fbbaeae12`, before removal of SQL account actors.
[Candidate](candidate.jsonl) uses runtime source `f0e3d3d52`; its recorded checkout
adds fixture corrections without changing runtime code. Both use pinned Zig
ReleaseSafe. [Provenance](provenance.json) records exact source and definition
identities, toolchain, executable hashes, commands, timestamps and original log
hashes. The measurement driver is identical in both checkouts.

The real TLS PostgreSQL/MySQL services run over local disk storage with four
rows. Each literal/prepared path executes point, range, full, empty and LIMIT 0
reads: one excluded warmup and 20 recorded observations per case (400 reads).
Three INSERT/UPDATE/DELETE cycles per path produce 36 measured mutations; each
checks its authoritative count and exact readback through the other protocol.
Read p95 is empirical nearest rank over 20 samples. Mutation p50 uses three
samples and establishes no tail bound.

Owned runs execute sequentially after builds finish, control then candidate.
Ordinary applications continue on the shared 48-thread host; this is not host
isolation, randomized variance analysis, cold-cache or maintenance qualification.
The result does not establish a latency SLO, throughput, a single HTTP request
per SQL statement, or causation attributable to one internal mechanism.

| Path | Case | Control p50 ms | Candidate p50 ms | Control p95 ms | Candidate p95 ms |
| --- | --- | ---: | ---: | ---: | ---: |
| postgres literal | point | 1712.769 | 776.921 | 2816.603 | 863.926 |
| postgres literal | range | 1207.304 | 796.183 | 1719.013 | 870.432 |
| postgres literal | full | 1214.056 | 782.228 | 1746.811 | 860.701 |
| postgres literal | empty | 1180.935 | 789.211 | 1738.878 | 893.576 |
| postgres literal | limit zero | 1160.603 | 744.825 | 1682.122 | 824.610 |
| postgres prepared | point | 1145.243 | 641.387 | 1682.982 | 737.774 |
| postgres prepared | range | 1115.151 | 669.026 | 1679.569 | 720.645 |
| postgres prepared | full | 1109.436 | 663.623 | 1705.249 | 705.472 |
| postgres prepared | empty | 1144.863 | 656.588 | 1673.133 | 705.521 |
| postgres prepared | limit zero | 1064.864 | 620.109 | 1664.791 | 685.490 |
| mysql literal | point | 532.494 | 655.049 | 586.846 | 672.877 |
| mysql literal | range | 1117.453 | 661.387 | 1714.172 | 713.535 |
| mysql literal | full | 1179.384 | 634.531 | 1698.527 | 697.259 |
| mysql literal | empty | 1123.495 | 637.574 | 1691.142 | 703.482 |
| mysql literal | limit zero | 1076.171 | 612.587 | 1677.465 | 677.496 |
| mysql prepared | point | 1286.906 | 901.138 | 1866.703 | 991.778 |
| mysql prepared | range | 1322.373 | 916.536 | 1889.918 | 985.078 |
| mysql prepared | full | 1251.187 | 908.897 | 1890.045 | 983.219 |
| mysql prepared | empty | 1282.932 | 881.741 | 1851.073 | 944.093 |
| mysql prepared | limit zero | 1250.792 | 885.365 | 1873.662 | 978.974 |
| postgres literal | insert | 2588.822 | 1019.320 | — | — |
| postgres literal | update | 3901.078 | 1041.212 | — | — |
| postgres literal | delete | 3792.556 | 1159.798 | — | — |
| postgres prepared | insert | 3733.372 | 1069.214 | — | — |
| postgres prepared | update | 3810.950 | 1179.392 | — | — |
| postgres prepared | delete | 3724.371 | 1085.869 | — | — |
| mysql literal | insert | 3859.104 | 1170.059 | — | — |
| mysql literal | update | 2605.339 | 1254.599 | — | — |
| mysql literal | delete | 2515.567 | 1242.794 | — | — |
| mysql prepared | insert | 2705.249 | 1600.844 | — | — |
| mysql prepared | update | 2833.231 | 1679.165 | — | — |
| mysql prepared | delete | 2715.188 | 1570.910 | — | — |

The two retained report lines are copied byte-for-byte from their full logs;
provenance describes the metadata selection and omitted hostname. Verify the
retained bytes with `sha256sum --check SHA256SUMS.txt`. Routine correctness logs
and failed installation attempts remain in ignored runner output and the linked
qualification narrative, rather than becoming an archive of every run.
