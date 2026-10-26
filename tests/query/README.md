# Query semantics and independent oracles

These checks cover planning, logical values, result completeness, snapshots and
execution. The [query reference](../../docs/handbook/reference/queries.md),
[SQL reference](../../docs/handbook/reference/sql.md) and owning contracts define
supported behavior. [Contribution instructions](AGENTS.md) preserve independent
expectations and qualification boundaries.

| Area | Entry points |
| --- | --- |
| Independent SQL grammar, plans and rewrites | [SQL checks](sql/README.md) |
| Logical values, source descriptors and codecs | [logical/](logical/), [Arrow](arrow/) |
| File discovery, bounded reads and independent plan bytes | [File-query schedule](files/fuze_file_query.py) |
| Unified source, result, lifetime and recovery semantics | [Unified schedule](unified/unified_query.py), [codec oracle](unified/unified_codec.py), [lifecycle](unified/unified_lifecycle.py), [expiry](unified/unified_expiry.py) |
| Direct Table capture, relational work and worker replacement | [execution/](execution/), [capture](execution/direct_captured_query.py), [relational oracle](execution/relational.py) |

Use the owning [test recipes](../../tasks/test.just) for native binaries, pinned
reference parsers and explicit backend choices. Python drivers use
`python3 -B tests/runner/launch.py tests/query/AREA/DRIVER.py`. Installed language
adapters remain in [SDK](../sdk/README.md); SQL wire/session assertions remain in
[interfaces](../interfaces/README.md). Benchmark workloads and active budgets
live in [performance](../performance/README.md).
