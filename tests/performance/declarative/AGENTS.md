# Working on benchmark experiments

Follow [test instructions](../../AGENTS.md) and the [benchmark guide](README.md).
Keep manifests, workload generation, independent correctness checks and measured
results distinct. Record source/toolchain/build profile, machine, storage,
durability, input sizes, resource budgets, repetitions and cache conditions.

Report build/setup, execution and recovery costs separately. Preserve raw samples,
failures and incomplete runs; compare matched configurations. Do not label a
smoke run or component count as end-to-end performance. Never weaken durability,
authorization, values or completion assertions to improve a timing.

Use the owning benchmark runner and `test_runner.py`; expensive workloads remain
explicit. Put reusable methods in the guide and accepted experiments in linked
qualification history. Results are evidence, not executable regression oracles.
