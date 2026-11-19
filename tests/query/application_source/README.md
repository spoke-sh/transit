# Application source correspondence

Transit runs the source grammar and typed-target proofs owned by the exact
[transitc snapshot](../../../third_party/transitc/upstream.json). The
[upstream verification guide](../../../third_party/transitc/tests/query/application_source/README.md)
records the compiler projection, independent ANTLR comparisons, Lean laws,
negative controls and their limits.

`verify.py` and `types.py` are process adapters. They select Transit's authoritative
SQL grammar and execute the upstream drivers. The root build composes the pinned
source probe with the same compiler, SQL frontend, protocol and memory modules as
Transit. There is one source grammar, compiler and model implementation.

Run `just test::application-source-grammar` and
`just test::application-source-types` inside `nix develop`. These execute the
proofs; the fast inventory check only audits registration and does not run Lean.
Evidence is retained under the snapshot's ignored `.cache/verification/` tree.
Missing or incomplete evidence cannot pass. The installed application build/test
schedules separately check runtime execution, migration history, restart,
authorization and original accepted identities.
