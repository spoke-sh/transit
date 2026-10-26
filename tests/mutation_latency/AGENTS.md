# Working on mutation measurements

Follow [test instructions](../AGENTS.md) and [benchmark rules](../benchmarks/AGENTS.md).
The driver is [mutation_latency.py](../mutation_latency.py); use its owning
`just test::mutation-latency` recipe and runner checks. This directory retains
source-attributed measurement records.

Separate admission, durable acceptance, execution and observed completion.
Preserve original operation identity and report uncertainty rather than replaying
a write. Record backend, sync behavior, workload and cache conditions. Counts and
single samples do not establish a latency distribution or a provider guarantee.
