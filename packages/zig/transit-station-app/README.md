# transit-station-app

[Named relational definitions](docs/named-relational.md) compose immutable query
names, separate current authorization and explicit captured/maintained activation.
Their application-owned namespace is separate from UI interface definitions.

[Named Document resources](docs/named-resources.md) combine the direct
catalog's explicit provisioning stages with actual native writer initialization
and the existing Document service. Named KV belongs to the direct database API.

M23's shared declarative application owner, above Station and serving. The
[application contract](../../../contracts/APPLICATION_V1.md) owns neutral values,
publication and migration boundaries. Implementation is in progress; package
checks do not by themselves qualify browser publication or deployment recovery.
The separate native browser task records its actual coverage in the test guide.

`Model` validates one bounded definition and its complete reference graph without
I/O. Bindings keep inspection, finite queries and explicit commands distinct.
Full-width interface revisions reuse serving's decimal encoding. Static renderer
and theme enums describe compatibility, never grant authority or load code.

Run `nix develop --command sh -c 'cd packages/zig/transit-station-app && zig build test'`.
Definition histories use ordinary durable publication; per-definition bounds
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
Failures use a bounded stderr diagnostic with the member, option, cause and
source location when available. `Sql.parseDiagnostic` and
`Model.Definition.validateDiagnostic` expose owned context to local callers.
Embedded SELECT positions are relative to that SELECT; arbitrary option values
are not copied into the diagnostic.

Capacity diagnostics identify the first failing member dimension or parser bound,
its measured/attempted count, unit, limit and `at_least`/`at_most` rule. Member
minimums remain distinct from maximums. Option slots, decoded literal bytes,
comment nesting and complete program bytes retain their own bounds. Parser
measurements stop at the first rejected byte/slot; they do not claim to have
scanned the remaining declaration.

`transit-app --diagnostics=json parse|format|module FILE` writes one shared
diagnostic envelope per failure on stderr and exits with status 1. The option
also applies to `schema`. Successful stdout remains the requested model, SQL,
module or schema. Diagnostic outcomes are `not_submitted`: offline compilation
never publishes. The primary location identifies the original declaration;
an `expression` location fact identifies a nested SELECT in its own coordinates.
Invalid JSON syntax retains its scanner byte offset; valid JSON rejected by
schema or graph validation has no invented position. Paths preserve non-UTF-8
bytes with explicit encoding, and output failures set `completion` to false.
The generated structural schema still requires the owning semantic validator
for graph references and source capabilities. The independent grammar proof and
allocation-failure suite cover this boundary; runtime qualification is separate.

`Publication` composes conditional interface activation on a `Turn`.
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
exact lost replies, worker fencing and node/disk-store restart. The separate browser proof covers declared navigation and exact operation recovery.
The [work-item example](../../../examples/work-items/README.md) now qualifies
its selected data/schema migration and generated browser on native placement.
Physical application placements remain open.

The committed `api/application.schema.json` is reflected by `transit-app schema`.
`just transit-board::generate` regenerates it and the shared browser package;
`just transit-board::contract` checks compiler/schema/type/validator drift.
[transit-application](../../ts/transit-application/README.md) consumes these exact
types for presentation, visual edits and generation identity. Query declarations
explicitly identify Table/KV/Document; only the qualified Table/unified profile
admits Follow. Finite query capability alone never implies a watch.

For actual transports, `Request.Command` and `Behavior` implement bounded signed
Station uploads. `begin`, 128-byte `part` messages and explicit `publish` preserve
one frozen proposal; `publish` validates the complete canonical body before
visibility. `Behavior.guard()` runs before Station frame processing, retaining
malformed/denied dispositions and leaving infrastructure failures unresolved.
Initialize the owner with its independent administrator before granting operator
admission. Application policy revocation is separate from resource-read grants.
The native fault proof uses these real commands and handler, including a committed
first half resumed after a worker kill; it no longer supplies a preloaded body to
the publication handler.

`Native` prepares ordinary native request/query digests for an operator to sign
outside the web host. Forwarding rechecks the configured scope and exact payload;
the Transit authority verifies the signature and current grant. Status reads use
that same operator's signature and one bounded resource read, including its own
policy, operation and upload progress. The host never substitutes its inspection
identity. Freeze the whole signed submission across unknown replies; a fresh
sequence does not resolve an earlier attempt. Independent Python signing fixtures
and the real restart proof cover request bytes, optional status selectors,
lost replies and current read denial. This adapter does not itself admit web users.

`Host` owns bounded administrative transport values and complete compiler replies.
`Upload.next` selects one recoverable signed-upload continuation from a reviewed
proposal and observed progress; it cannot admit work. `Host.published` acquires
one current immutable definition through the public resource reader, validates
its complete body and rechecks the active head before returning. A changed head,
missing chunk or denied read invalidates the whole acquisition. Hosts can compose
these helpers without protocol encoding or publication policy in TypeScript.
The optional [Board endpoint](../../../apps/transit-board/docs/application.md)
uses these shared types and retains the default inspection boundary.

`Host.compileDiagnostic` and `Host.runDiagnostic` return owned shared diagnostics
through an optional output pointer while preserving primary errors. Compilation
keeps the original validator's member/option and nested SELECT context. The host
records its actual forwarding boundary: failed local envelopes are unsent;
unconfirmed signed commands retain their exact sequence/digest and recovery
guidance. Read failures and caller-supplied upload observations never establish
a terminal publication outcome. `HostDiagnostic.acquisition` explains incomplete
or denied published-definition reads without returning a partial definition.

The compiler and host expose finite reviewed diagnostic registries. Invalid
operator configuration, encoded command capacity and invalid native/resource
evidence have specific codes. Known transport causes retain failed-read versus
uncertain-submission distinctions. A truncated read with no retained origin marks
that origin unrecorded; it does not invent a publication or abandonment outcome.

`Migration` adds the separate [data-owner ledger](../../../contracts/APPLICATION_MIGRATION_V1.md).
Initialize its immutable configuration, provision current per-operator migration
policy, then conditionally `begin` a reviewed supported plan. `apply` invokes the
domain transition only when that exact step lacks a receipt. Its callback returns
a bounded cursor or activation and shares the ordinary four-write private turn.
For staged domain publication, `stage` first saves the exact step and original
admission input. Its later callback receives that frozen `Pending` and returns
null while building or a terminal transition. Building may use all four writes;
completion reserves two ledger writes, or three for activation. Every continuation
checks current policy. `continueStage` restricts self-message continuation to an
already admitted step under the original operator's current policy. `pending` and `receipt` distinguish admitted staging from
completed work; abandonment retains evidence without completing the transform.
`authorize` checks the current external migration principal before an application
inspects its target state. A malformed stored step identity or inconsistent
pending digest remains an unresolved storage invariant failure; it is never
attributed to a caller's changed intent or passed to the domain transform.
The owner must reject unsupported transforms before beginning, enforce its write
pause, and prove complete target verification before activating. Policy is
separate from interface publication permission. `abandon` cannot undo activation
or discard plan/step evidence. Point reads and caller-owned fixed values keep
ledger work independent of historical plan/step cardinality. `MigrationDiagnostic.progress`
projects the retained plan and progress after an authorized read. It distinguishes
active, applied and abandoned plans and preserves the reviewed basis and next
ordinal without choosing application cursor arguments. The work-item operator
includes this envelope as `migration_diagnostic` in inspection output.

The independent record/digest fixtures and package tests cover twenty retained
steps, exact reconstruction, conflicting plans and ordinals, current denial,
explicit abandonment, source mismatch, infrastructure errors and rollback of
partial decisions. The [work-item example](../../../examples/work-items/README.md) additionally
qualifies signed native migration commands, an actual Table transformation,
worker replacement and node/disk recovery. The [proof ledger](../../../docs/history/qualification/README.md)
records executed native, browser and physical placement schedules by source
revision. Its post-activation write pause separates
data activation from interface publication and explicit administrator release.

The host's `next_cleanup` continuation composes explicit abandonment with bounded
publication collection. Signed state reads expose `collected` and `reserved` so
clients distinguish closure from released staging capacity. Permanent descriptors
and receipts remain; applied interface revisions are never rolled back by cleanup.

`transit-app module FILE.sql` emits a strict TypeScript proposal module using the
same whole-program validation as `parse`. It imports the shared runtime validator;
it does not generate authority, credentials or a publication fallback. A generated
application can use `requireArtifacts` to accept subsequent published definitions
only within its realm, application/component version and compiled renderer set.
The application still provides its own business renderers and handler artifacts.

Publication receipts retain the head revision and body digest observed at the
original conditional conflict. `Native.State.receipt_diagnostic` projects that
receipt separately from any input disposition. It survives a later head, restart
and explicit abandonment/collection; current native read grants still gate access.
The record remains below one 256-byte value and activation still uses four writes.

`PublicationFailure` records rejected-input causes and witnesses in two bounded
values after rolling back the attempted publication transition. Original policy,
compiler and incomplete-upload evidence survives later state changes. Native
observations expose the typed input disposition alongside the independent receipt;
all selected fields fit one eight-key read. The input commitment contains no
payload values. Infrastructure failure still leaves accepted work unresolved.

`MigrationFailure` captures policy, proposal, epoch/contract and step witnesses
at the original rejecting check. Applications commit its bounded record and
witness only after rolling back the attempted transition; work-items adds its
cursor, verification and submitted-state evidence. The operator projects typed
`input_rejected` detail after a current authorized read. Original step receipts
and activation remain independent, and later state cannot rewrite the witness.
