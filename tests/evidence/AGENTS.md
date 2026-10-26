# Working on retained evidence

Follow the [test rules](../AGENTS.md) and [evidence index](README.md). This directory
owns result navigation and specifically justified reproducibility references.
Ordinary generated logs and pass/fail reports belong in ignored runner output and
CI artifacts, never a per-run Git archive. Qualification narratives belong
in [history](../../docs/history/qualification/README.md); current behavior belongs
in the public handbook and its component owners.

Preserve raw bytes, hashes, source/toolchain/definition identities, execution
conditions and actual outcomes. Failures, incomplete runs, skips and timeouts must
remain visible. Never relabel old evidence as a pass for new source. Record any
redaction or transformation explicitly, keeping credentials and private data out
of Git. Original commands and embedded paths describe their original source.

Keep active fixtures, executable checks and performance budgets outside this
directory. Adding a result must not create a dependency from correctness tests or
runtime packaging. Link a new result from its qualification topic and preserve
enough provenance to assess its scope. Avoid dumping unrelated output here.

For archival, preserve immutable source-revision links and original hashes before
removing generated output from the current tree. Run the archive integrity and
documentation checks. Do not edit a recorded failure to make
those checks pass. Source-selection changes require the real packaged-runtime
qualification as well as selector controls.
