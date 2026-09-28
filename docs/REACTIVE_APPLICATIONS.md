# Declarative reactive applications

Status: [M23](roadmap/M23.md) implementation in progress, reviewed through
[board-grammar D1](design/board-grammar/D1.md). The bounded application v1 compiler, conditional publication, declared Board
shell, finite Table draft scheduler and data-owner migration ledger are
implemented in their owning packages. The generated downstream workflow and
placement matrix remain open; this design document is not executable evidence.
[Serving](SERVING.md), [reactive APIs](REACTIVE_API.md), [reactive interfaces](REACTIVE.md)
and [Arrow](ARROW.md) retain their M19–M22 contracts and qualification limits.

## One application definition, several authoring surfaces

Board should be expressible as a versioned series of declarations over a shared
typed model. A downstream application should use that model to define its data,
published operations, live views, actions and presentation. SQL, a visual editor,
CLI and SDK builders are alternative authoring surfaces with the same validation
and public-operation lowering. They do not maintain independent configuration
authorities. Accepted durable definitions determine publication; local drafts,
generated files and observed listeners have separate identities.

This target describes the UI's composition, dependencies and behavior bindings.
It does not express every pixel or arbitrary handler in SQL. Allowlisted,
versioned TypeScript renderers implement layout and interaction. Zig owners
implement shared declaration validation, planning, serving and lifecycle logic;
Fuze executes supported queries outside the kernel. Application handlers and
codecs remain application code. No SQL declaration loads arbitrary executable
code, reads provider storage, grants access, or dispatches an external effect.

## Definition and ownership model

| Proposed element | Contents | Semantic owner |
| --- | --- | --- |
| Application/interface revision | Stable identity, target realm, entry screen, compatible contract/component versions, dependency digest | Station application owner through public operations; M23 must specify publication/recovery |
| Screen | Bounded route, shell/navigation placement, component references and layout | Interface definition plus frontend renderer; route publication uses serving |
| Binding | Exact authorized inspection projection, finite query or command target; codec/schema; refresh profile and budgets | Existing Board/query/service owner; no universal query disguised over unlike sources |
| Action | Local navigation/edit, explicit durable command, or qualified read-session control | Local UI for local actions; owning public operation for durable actions |
| Theme | Versioned presentation tokens and component style variants | Interface renderer; no data/authority semantics |
| Migration plan | Base and target revisions, dependency order, frozen steps, checks, receipts and recovery policy | Application migration coordinator above Station; not kernel policy |

The binding discriminant matters: an inspection projection is not automatically
a relational Table or a watch. Catalog and dependency discovery use bounded
public projections with independent observation bases. A query binding names the
declared source and the qualified Fuze profile. A command binding resolves a
fixed service operation and destination. Generated TypeScript validators derive
from versioned public types; hand-authored wire copies are prohibited.

Publication must define an immutable validated revision and a conditional active
revision pointer, or an equivalently explicit public visibility decision. That
decision only activates the interface definition. It cannot make unrelated
resource, policy, route and code changes one atomic transaction. A loaded browser
pins a compatible definition generation; an incompatible revision requires a
visible reload/rebind, fences obsolete refresh results and preserves recovery
of already accepted commands. An old definition or theme never preserves revoked
rights. Routes and actions accepted earlier keep their recorded destinations.

## SQL and support levels

The [grammar contract](../contracts/sql/README.md) is the current parser authority.

| Surface | Current status | M23 obligation |
| --- | --- | --- |
| Qualified `SELECT` over declared Table/KV/Document sources | Executable within the v1/v2 capability matrices | Reuse the existing parser/plan and exact-result contract |
| `CREATE TABLE`, `KV`, `DOCUMENT`, `CONNECTION`, `SOURCE`, `SINK`; `GRANT`, `REVOKE`, `SHOW`, `DESCRIBE` | Reference grammar only; production rejects administrative statements | Select and qualify typed owners, catalog resolution and complete lowering for the advertised subset |
| `SECRET('reference')` option | Reference grammar only | Reuse the proposed metadata lifecycle from Console D6; never resolve a private value in Board |
| Managed SECRET, service/endpoint/watch declarations, conditional alter/retire | Missing executable syntax and/or semantics | Version semantic operations and lifecycle first, then grammar and public lowering |
| `CREATE INTERFACE`, `SCREEN`, `BINDING`, `ACTION`, `THEME` | Bounded application v1 compiler and conditional publication implemented | Qualify the complete renderer/dependency inventory and downstream placement matrix |
| Migration plan/apply/recover | Versioned data-owner ledger and work-item Table transform implemented | Complete generated workflow and physical placement proofs; no universal schema evolution |

[The candidate Board program](design/board-grammar/board.proposed.sql) illustrates
all proposed destinations. Every statement there is **non-executable proposal**,
including the fictional projection/operation names. Its `query` option contains
a separately compiled SQL string; interpolated parameters, source resolution
and budgets require a typed binding rather than string concatenation. This is
not an extension to `TransitExtensions.g4` and not a parser fixture.

M23 must preserve the meaning of supported definitions across SQL → typed model
→ visual editor → SQL, including full-width IDs, null/missing distinctions,
dependency references and operation class. Equality means semantic equality;
formatting and comments need an explicit preservation policy. Unsupported syntax
stays visible and cannot be silently discarded by opening a form. Mixed scripts
are validated completely before apply; partial admission is then tracked per
step, never described as transaction-wide success.

## Reactive execution

Use M19 for authenticated operation admission and exact recovery, M20 for typed
sessions/watches and compatible snapshot/change handoff, and M21 for bounded
snapshot refresh. M22 adds qualified Arrow/Flight clients; it is neither a UI
transport requirement nor a source of continuous-query semantics.

Bindings declare Snapshot or Follow changes, an explicit source/schema/query
generation, visible-work lease and query/read budgets. Follow changes is allowed
only for an advertised source adapter. Missing watch support is an explicit
capability error or a deliberately selected Snapshot profile, never hidden polling
presented as a watch. One newest dirty position and the qualified shared-principal
scheduler bound refresh work across tabs. Complete-result verification and current
authority precede presentation, with a bounded resident page set.

Keep displayed result, pending refresh, current draft and speculative candidate
identities separate. Draft scheduling from Console D4 is an M23 opt-in Live
session requiring its own budget and fairness qualification; only fully compiled,
authorized read candidates qualify. Choosing a prediction cannot authorize work
or establish result truth. Administrative SQL, connector dispatch and arbitrary
commands never enter this scheduler. Incremental continuous SQL remains outside
the selected profile; disable Stream rather than reinterpret snapshot refresh.

## A repeatable developer workflow

The proposed convention is **declare → bind → compose → migrate and observe**:

1. **Declare the model.** Author versioned resources, codecs, operations and
   explicit access requirements. Keep secrets as external references. Generate
   application skeletons and shared fixtures, not duplicate protocol semantics.
2. **Bind the API.** Publish the qualified service operation set, watch adapters,
   errors and budgets. Generate clients, runtime validators and OpenAPI/AsyncAPI
   through their owning M20 definitions. Discover actual capabilities before
   enabling controls; a generated API is not proof of support.
3. **Compose the interface.** Bind allowlisted renderers to sources and actions,
   declare routes/navigation, and preview with synthetic data or an explicit
   authorized read scope. Theme tokens are orthogonal to semantic mappings.
4. **Plan, apply, recover and inspect.** Compare against an exact accepted base,
   review required operations, apply with current authority, recover each receipt
   and report accepted versus actually served revisions.

A Rails-like experience means useful conventions, scaffolding, a single local
loop, checked migrations and a runnable example. The first downstream proof is
a non-trading work-item application: a qualified Table schema, a domain command,
an exact live list and an explicit form action. It must use the same interface
and lifecycle primitives as Board without importing Board-specific routes or
kernel policy. The initial schema must fit a qualified Table profile; the example
cannot smuggle arbitrary column/schema evolution into the generator.

Choose actual commands and package boundaries during implementation. Add packages
only for real shared code with manifests and direct dependencies, and add `just`
tasks only when they run. Existing native/Compose/Substrate launchers remain the
development/deployment owners. Generating files never applies definitions or
performs network effects.

## What a migration means

A migration is an immutable, attributable plan from a known application revision
to another, with ordered public operations and a recoverable disposition for each.
Its stable identity and digest bind the exact target realm, base, schemas, source
and service identities, prerequisites and code/component versions. A changed
plan is a new proposal. The coordinator checks current rights for every step;
the earlier plan or a successful validation is not a grant.

| Change class | Strategy | Failure / compatibility boundary |
| --- | --- | --- |
| Theme, layout, compatible component composition | Validate then conditionally publish a new interface revision | Old browsers retain a compatible definition generation; rollback selects another compatible revision and reauthorizes reads |
| Query, source schema, route or watch binding | Add a qualified binding, verify, then explicitly switch new admissions | Fence late results; reset incompatible watches; accepted commands retain the old target and receipt |
| Data/schema transformation | Expand, bounded backfill, verify, switch consumers, then explicitly retire old definitions | Requires a selected writer/codec contract, concurrent-write policy and resumable progress; no automatic generic `ALTER TABLE` |
| Credential or access change | Separate metadata revision, consumer rebinding and current-grant operations | Cannot be undone by restoring UI files; preserve independent recovery access and frozen effect references |
| Physical worker/authority movement or disaster restore | Follow runtime/cluster recovery contracts | [M26](roadmap/M26.md) owns this broader proof; an application migration cannot revive retired authority |

**Plan** resolves dependencies within current disclosure rights, checks the exact
base revision, capabilities, schema compatibility and bounds, and reports the
affected operation classes. A diff is read-only. It reports what cannot be
established; hidden dependencies cannot be summarized by leaked counts.

**Apply** freezes each operation identity before admission. Record started,
accepted, completed, rejected, uncertain and blocked outcomes distinctly. The
durable coordinator's checkpoints and step receipts survive its worker loss.
An acknowledgement lost after acceptance recovers that exact operation; it
never blindly resubmits under a new identity. Reapplying a completed plan recovers
its receipts. Reusing an ID with another digest rejects. Concurrent plans use
conditional revisions/fencing and cannot silently overwrite each other.

**Data movement** is an application behavior over bounded pages and batches.
Choose either an explicit write pause with a defined resume boundary or a
qualified dual-version catch-up protocol. Without one, live backfill is unsupported.
Cross-resource copy is not atomic; verification must name its coverage, high-water
mark and source/target revisions before consumer switch. A partial backfill stays
incomplete and cannot become the current schema through an optimistic UI update.
M7's one-mutated-resource-per-turn boundary remains intact.

**Recovery and rollback** read the ledger and resume the original step under
current authority. Compatibility may permit selecting an older interface revision;
reversing a data change requires an explicit validated inverse or compensation.
Many operations are irreversible, including external effects, permanent retirement
and erased history. A generic “down” function cannot promise reversal. Keep old
readers/routes only within their explicit compatibility and lifetime policy.
Removal from the application definition does not delete a resource, revoke a grant
or expire history. Retirement and cleanup are explicit; retention defaults unlimited.

## First qualification boundary

[M23](roadmap/M23.md) owns the implementation inventory and proofs: equivalent
SQL/visual/API plans, capability rejection, publication races, receipt recovery,
revocation, bounded reactive refresh, monochrome accessibility, and a real
generated application with compatible publication plus one explicitly supported
data evolution. This document supplies design intent, not a new wire contract.
Before wiring languages, define versioned neutral contracts and independent
fixtures under `contracts/`, generated from their actual owning public types.

The first implemented boundary is [application v1](../contracts/APPLICATION_V1.md):
one bounded SQL/JSON model and a conditional Station publication owner. Operator
policy is outside editable presentation; each immutable body and exact proposal
has retained evidence. Publication and active-head visibility share an ordinary
four-mutation turn. The offline compiler and owner tests do not yet qualify
administrative ingress, generated browser clients or physical migration recovery.


## Current M23 implementation boundary

The shared application package now compiles complete definitions and owns
conditional immutable publication through signed Station uploads. Board's opt-in
editor and native operator endpoint reuse those types and validators. SQL/Form/
Canvas editing does not admit work; explicit review freezes base, revision and
publication digest. One uncertain signature survives route replacement and can
be exported independently of the signing key. The actual native browser proof
covers editing, a lost admission reply, disk/worker recovery and current read
denial. Interface-driven shell generation, generic migration/data evolution and
generated application placements remain unqualified until their own proofs run.
See the [implementation guide](../apps/transit-board/docs/application.md) and
[test evidence](../tests/README.md#m23-application-declaration-boundary).

## Migration implementation boundaries

The [work-item example](../examples/work-items/README.md) separates bounded copy,
complete verification, data activation and explicit write release. Its two domain
writes plus progress and receipt fit the unchanged four-write turn. Activation
changes one active-Table record and three ledger records; normal writes stay
paused so interface publication and validation can occur separately. Releasing
that pause is an administrator action over the exact epoch/source contract. It
is not a transaction spanning data, configuration and interface owners.

A durable last-key cursor is safe here because the exclusive application owner
pauses all normal writes. Each step uses a new bounded read position. Other
applications must supply their own write coordination or versioned source;
copying this cursor alone cannot stabilize mutable contents. Abandonment leaves
target Table identities and receipts retained, so another attempt needs a fresh
plan/target identity. M26 must preserve these roots and pauses during movement.
