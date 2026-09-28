# transit-station-app

M23's shared declarative application owner, above Station and serving. The
[application contract](../../../contracts/APPLICATION_V1.md) owns neutral values,
publication and migration boundaries. Implementation is in progress; package
checks do not qualify browser publication or deployment recovery.

`Model` validates one bounded definition and its complete reference graph without
I/O. Bindings keep inspection, finite queries and explicit commands distinct.
Full-width interface revisions reuse serving's decimal encoding. Static renderer
and theme enums describe compatibility, never grant authority or load code.

Run `nix develop --command sh -c 'cd packages/zig/transit-station-app && zig build test'`.
Definition histories will use ordinary durable publication; per-definition bounds
must not become a fixed total revision or application cardinality.

`zig build transit-app` at the repository root installs the offline compiler:

```sh
zig-out/bin/transit-app parse path/to/interface.sql
zig-out/bin/transit-app format path/to/interface.json
zig-out/bin/transit-app schema
just test::application-grammar
```

`parse` returns the complete validated model. `format` rejects unknown JSON
fields and emits canonical SQL only after bounded whole-program validation.
Neither command publishes, grants access, submits queries or dispatches effects.
The generated structural schema still requires the owning semantic validator
for graph references and source capabilities. The independent grammar proof and
allocation-failure suite cover this boundary; runtime qualification is separate.

`Publication` composes conditional interface activation on a `GrowingTurn`.
Initialize its immutable configuration with the separately provisioned bootstrap
administrator, then explicitly grant an operator publication policy. `step`
validates a complete canonical body against the frozen proposal on every staging
step; the host remains responsible for authorized body acquisition and signed
native input. One chunk is staged per call, and final activation fits the existing
four-mutation budget. Use current public readers for `head`/`receipt`; these
helpers are not network endpoints. Explicit `abandon`/`collect` close unused
staging without expiring published history. See the contract for exact layout,
limits and quota recovery. Tests cover races, denial, lost-result reconstruction,
partial-decision rollback and retained revision growth. `just test::application` additionally qualifies signed native operator admission,
exact lost replies, worker fencing and node/disk-store restart. Browser generation
switching, administrative HTTP ingress and physical application placements remain
open; the native proof is not those broader qualifications.

The committed `api/application.schema.json` is reflected by `transit-app schema`.
`just transit-board::generate` regenerates it and the shared browser package;
`just transit-board::contract` checks compiler/schema/type/validator drift.
[transit-application](../../ts/transit-application/README.md) consumes these exact
types for presentation, visual edits and generation identity. Query declarations
explicitly identify Table/KV/Document; only the qualified Table/unified profile
admits Follow. Finite query capability alone never implies a watch.
