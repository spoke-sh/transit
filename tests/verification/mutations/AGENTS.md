# Working on mutation campaigns

Follow the [verification rules](../AGENTS.md) and [campaign index](README.md).
Use committed-source clones and a passing unmodified baseline. Keep production
source edits exact and singular; restore the original source between mutants.

State which safety obligation the omitted guard challenges and which executed
assertion detects it. Compilation failure, timeout, infrastructure failure and
missing completion cannot count as detection. Preserve original diagnostics and
replayable counterexamples, then minimize only within the owning failure category.
Keep model mutations distinct from real implementation mutations. Run each
changed campaign at its existing bounds before claiming it is qualified.
