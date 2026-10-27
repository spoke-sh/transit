# Working on performance checks

Follow the [test rules](../AGENTS.md), [workload index](README.md) and the owning
benchmark guide. Keep workload generation, exact independent value checks, active
budgets and observed results distinct. Group new work by its measured operation.

Run Python drivers through `tests/runner/launch.py`, import helpers by owner and
use `runner.paths.ROOT`. Give shared Zig helpers explicit build modules. Preserve
workload sizes, repetitions, seeds, warm/cold conditions, resource bounds and
backend/durability profiles when moving a runner.

Record source/toolchain/binary/driver identity, phase times, machine and cache
conditions. Never weaken durability, authority, value or completion checks to
improve a timing. Failed, incomplete or mismatched samples cannot meet a budget.
Keep original hashes intact; requalify changed measurement drivers before
freezing new budgets. Do not rewrite old identities to manufacture comparability.

Run owning reporting/oracle controls, then the affected real workloads. Keep
ordinary output in ignored automatic records and CI artifacts, with selected
scientific interpretation in qualification history. Avoid concurrent heavy
measurements that compete for CPU, physical disk or mutable build outputs.
