# Working on qualification artifacts

Follow [verification instructions](../AGENTS.md). These are recorded experiments,
not runnable fixtures or an implicit qualification of current main. Do not import
historical result files into correctness tests as expected production outcomes.

Retain commands, source and definition identities, tool/build profile, backend,
hardware/resource limits, completion and actual outcomes. Keep failed, partial,
skipped and inconclusive runs visible. Hash raw files and identify transformed or
redacted copies. Never rewrite an old result to attribute it to newer source.

Keep credentials, private configuration and durable user data out of Git. Archive
only the logs needed to assess or reproduce the claim. Large disposable build
outputs belong outside the repository. A retained failed installation may be
needed privately even when its publishable report is small.

Link results from a [qualification topic](../../../docs/history/qualification/README.md).
Indexes summarize navigation; active progress and handoffs belong in issues/PRs.
For moves, preserve artifact bytes and hashes and update current referring links;
historical commands and embedded original paths retain their original meaning.
