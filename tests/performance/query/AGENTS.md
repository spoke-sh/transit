# Working on Fuze benchmarks

Follow [test instructions](../../AGENTS.md), the [benchmark rules](../declarative/AGENTS.md)
and this directory's [guide](README.md). Keep scalar/vector, file, codec and
pipeline experiments explicit about their operator and input profile. Check exact
values before comparing execution, allocations or resident memory.

Use the owning runner tests and focused benchmark tasks. Share input generation
without sharing the production result calculation. Preserve warm/cold conditions,
compiler/profile identity and incomplete samples. A specialized operator speedup
does not establish an installed SQL or storage improvement.
