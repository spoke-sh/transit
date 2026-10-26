# Working on storage measurements

Follow [test instructions](../AGENTS.md) and [benchmark rules](../benchmarks/AGENTS.md).
Use `just test::storage-benchmark`, `storage-ingest-benchmark` or `storage-growth`
and their owning scripts in the parent directory. These records measure actual
disk-backed owners with independent value/recovery checks.

Retain source/profile, filesystem, cache conditioning, WAL durability, input sizes,
resident bounds and raw samples. Distinguish native control work from direct Table
ingestion. A tmpfs control is not a physical-disk proof. Interrupted setup and
incomplete growth remain explicit, never zero-cost or successful samples. Keep
active storage implementation work with its package owner.
