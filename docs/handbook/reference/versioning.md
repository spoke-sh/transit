# Versioning and hard cutovers

Before Transit 1.0, every Transit-owned protocol has one supported definition,
named **v1**. Breaking changes replace that definition in a hard cutover. There
is no concurrent support for older definitions, deprecation window, fallback
decoder or compatibility route. This keeps implementation, verification and
documentation focused on the same current behavior.

## Scope

The policy covers native commands and HTTP envelopes, state and query contracts,
Station messages, serving and reactive bindings, installation/bootstrap schemas,
configuration formats, saved-operation formats and language-neutral ABIs.
Transit-owned version fields, signature domains, routes, file names and generated
declarations must agree with their owning v1 contract.

Upstream standards keep their own identifiers: HTTP/2, OpenAPI, AsyncAPI, Arrow,
Flight, ADBC and provider formats are not renumbered. Package and release versions
identify software artifacts. Application schema revisions, resource revisions,
ownership generations, sequence numbers and permission epochs retain their
domain meanings; they are not protocol generations.

## Software releases

Transit-owned runtime, library, SDK and chart packages share one release version.
The repository's `VERSION` file is the source of truth; the current baseline is
`0.0.1`. Package-manager manifests and exact internal dependency pins mirror it.
Upstream dependencies retain their own versions. This version identifies the
software release set; the current-v1 definition remains the compatibility gate.

`transit --version` reports the release version, full Git commit and CLI contract:

```text
Transit 0.0.1 (git 0123456789abcdef0123456789abcdef01234567; CLI contract 1)
```

A `-dirty` suffix on the commit indicates tracked modifications or untracked
source at build configuration time. Source archives without Git report `unknown`
unless the builder supplies provenance. These fields are compiled into the
executable: running the command needs neither Git nor the source checkout.
They identify source; they are not cryptographic attestations.

Build tooling accepts `-Dsource-revision=<full-sha>` (or `<full-sha>-dirty`) for
source archives and isolated builders. Nix passes its flake revision because its
filtered source excludes `.git`. Missing Nix provenance remains `unknown`.
Explicit metadata is a builder assertion, not independent verification.

Release tags have the exact form `vMAJOR.MINOR.PATCH`, matching `VERSION` at that
commit. CI rejects mismatched tags, package version drift and dirty tag builds.
Stable releases use three-part versions. Nightly distribution derives
`<VERSION>-nightly.YYYYMMDD.g<12-character-sha>` from a clean source revision.
Its immutable tag is `nightly-YYYYMMDD-g<12-character-sha>`; the full SHA and
contract definition remain in every artifact manifest. The release identity also
records package-native versions: Python uses `<VERSION>.devYYYYMMDD+g<sha>`,
Ruby uses `<VERSION>.nightly.YYYYMMDD.g<sha>`, and Zig uses
`<VERSION>-dev.g<sha>` to fit its 32-byte manifest limit. Zig's archive name and
release manifest retain the full nightly identity, including its date. The other
SDK packages use the SemVer prerelease. Exact internal pins and embedded loader expectations
follow that mapping in isolated packaging inputs. The source manifests retain
`VERSION`; nightly packaging does not commit daily version changes. Use patch
increments for compatible corrections and minor increments for additions or
incompatible pre-1.0 changes. A release increment never replaces a required
contract-definition cutover. Contributor steps live in the
[build guide](../../../build/README.md#changing-the-release-version).

## Compatibility between builds

The v1 label names the current contract; it does not promise that two pre-1.0
builds interoperate. Deploy clients, SDKs, workers and services from a matching
source revision or an explicitly verified release set. Their compatibility checks
must distinguish incompatible contract definitions even when both are called v1.
Do not infer compatibility from a shared version number or successful JSON parsing.

A cutover updates all affected producers and consumers together. Mixed old/new
deployments and rolling upgrades across an incompatible definition are unsupported.
Reject incompatible peers and artifacts before mutation, disclosure or external
dispatch. Canonical bytes, signing fixtures and generated schemas change with
their implementation owners.

## Durable data and pending operations

A hard cutover does not authorize deletion or reinterpretation of accepted work.
Old histories, checkpoints, saved signed requests, cursors and installation
records require an explicit compatibility decision. Never re-sign an uncertain
operation as a new request, reset its sequence, replay an effect or restore
authority from an older snapshot to make an upgrade succeed.

If a format is incompatible, refuse to open it. Preserve the original data and
recovery material. Operators resolve pending work with its matching build and
choose an explicitly supported offline conversion or a separately initialized
installation. A converter requires its own contract and proof; the policy does
not supply one or permit automatic reset. Starting a fresh installation is an
explicit operator action, not an upgrade fallback.

## Completing a cutover

Remove superseded code, public exports, routes, configuration switches, schemas,
fixtures and tests that exist only to support the old definition. Move required
consumers to the current implementation. Preserve regression coverage for
authority, fencing, exact retry, recovery, bounded memory and current permissions;
add rejection cases for incompatible inputs and stored data.

Current guides, exact contracts, examples, generated descriptions and site
navigation document only the supported definition. Git history and dated internal
reviews preserve earlier designs and proof results. Historical passing results
do not qualify the replacement; record newly executed evidence with the cutover.

## Current native definition

The current shared definition is
`082c5ef4fcfe2d1daa385774f5843ecf933af68d68a91df4b7d1281faf55dca1`.
It binds direct KV, mixed state/log transactions and frozen Stream/Queue
declaration intents together with retained Table branches and installed worker
rotation. Catalog roots require branch identity, name and retention-owner
directories; typed branch operations share the original client-token decision
owner. Installation records require per-worker enrollment receipts and the last
accepted public key. Restart conditionally rotates that key and ownership
without re-granting permissions. Earlier installations cannot synthesize these
fields and reject before starting authority.

Caller-token records now carry an explicit log-declaration reference and its
account-scoped immutable body. The saved body requires the current definition;
schema, policy, limits and original operation cannot be reconstructed from a
current name. Shared statement commands distinguish Stream/Queue declarations,
and terminal projections verify their original kind and namespace. Older token
records and result definitions are rejected rather than reinterpreted.
Log partition records and recovery baselines require explicit logical-change,
transaction-pin and preparation-reference fields. Immutable transaction sources
bind the exact old root and original begin identity; earlier log roots cannot
acquire these fields from current defaults. Log preparations now bind exact
predecessor/successor roots and action directories; commit/abort records resolve
only an actual shared decision. Earlier root and preparation formats reject.
The public catalog accepts explicit Stream/Queue partition read dependencies
and private append/offset/ACK statements under the common-cut and original-decision
lifecycle. Workspace and savepoint records require their log action directory;
pending and completed statements distinguish state and log work. Permanent log
operation reservations bind the complete frozen request. Earlier builds that
cannot interpret that accepted work reject under the replaced definition.

Queue items and lease observations require explicit nullable `blocked_after_ms`;
blocked items retain the accepted exhaustion time without a current-clock default.
Transaction log work adds paired terminal-transfer actions and source receipts.
The source and destination share one statement and common decision; source
terminalization cannot be replayed as a standalone operation. Permanent log
reservations require an operation-specific observation digest, including the
destination append's identity. Earlier workspaces, operation reservations and
Queue formats reject under this definition rather than acquiring these semantics.

Catalog intents require an explicit Table/KV kind. Named KV uses database-owned
partitions, typed direct requests and KV policy; the native resource declaration
and initialization marker accept Document only. Earlier named KV artifacts,
requests and marker kinds are rejected, without adoption or fallback decoding.
Native private Station state retains its own resource contract. Typed transaction
staging now accepts KV batches and KV reads require a nullable private-workspace
field. Earlier stored intents and responses reject under this definition.

Transaction selection, kind-specific guards, prepared evidence and paged
directory keys now bind logical owner partitions. Stream/Queue actions share one
preparation per partition. Storage components implement their preparation and
resolution; public transaction execution accepts Table/KV mutations and
Stream/Queue append, offset and ACK work with their retained read dependencies.
Browser placement, retained configuration and typed request resources remain
definition-bound. Earlier
checkpoints, signed requests and histories reject rather than being silently
extended or interpreted with new defaults. Preserve old storage and resolve
accepted work with its matching build. This change provides no in-place import
of an earlier definition. Replacements of the same current definition retain
sessions, declarations and one-use claims when their storage and keys persist.


Client-token receipts require an explicit nullable coordination partition.
Transaction begin acceptance reserves that partition in the same Catalog record
as its original token. Earlier receipts cannot acquire a default owner; they
reject under the replaced shared definition. Preserve their histories and resolve
uncertain work with the matching build before choosing a fresh installation.

The current catalog root requires a durable client-token directory and its
accepted-binding count. The shared definition changes with this stored layout;
earlier catalog roots, installations, saved requests and generated bindings
reject without synthesizing an empty directory. Preserve old data and resolve
pending operations with the matching build before an explicitly chosen fresh
installation. No automatic conversion is provided.

The shared definition binds local WAL directory and partition metadata, every
WAL frame, segment footer, deletion vector and Table manifest. It also binds
keyless segment ordering by stable row identity. Table acceptance roots require
exact immutable declarations, separate row-schema fingerprints, retirement and
monotonic segment identities. Name revisions cannot substitute for row-schema
revisions. Earlier roots missing these fields reject without a default or reset. Readers reject missing or
foreign artifact definitions before interpretation. The local disk owner rejects its earlier unmarked layout and missing
or foreign definitions. It does not convert old logs. Preserve them with their
matching build before an explicitly chosen fresh installation or a separately
qualified converter. The default local installation uses the native local owner;
backend selection does not establish compatibility with an earlier definition.

The current definition uses Transit domains for immutable payload locations and
Substrate resource/workload identities. It requires matching node, client, SDK,
controller and launcher builds. Older installations and saved operations reject
before their stored identities can be reinterpreted. Finish uncertain work with
its matching build before choosing a fresh installation; no automatic data reset
or migration is performed.

The native service, authority, shared client and Station use the paged v1
implementation. Native command and query routes are `/v1/command` and `/v1/query`.
The [native reference](native.md) and [service contract](../../../contracts/SERVICE_V1.md)
identify their owning specifications. Retained artifacts from incompatible
builds require the recovery procedure above.

The native contract carries an opaque `definition` identifier in canonical
signed requests and queries, query responses, persisted authority heads and
saved-operation envelopes. Local installation records and the launchers'
installation, candidate and selected-artifact records also require it. The
current identifier is exported as `x-transit.definition` in the
[generated schema](../../../contracts/transit-v1.schema.json), from the shared
protocol type. Unsupported identifiers reject; stored heads and saved requests
without one reject before use. Signed bytes from an older definition cannot
authenticate as the current definition.

Generated ABI contracts carry the same identifier. Native SDK loaders compare
it through the ABI definition-check export; port adapters validate the required
definition in their capability response. A missing export or incompatible
capability response fails loading. Replace the identifier whenever an
incompatible wire, ABI or stored framework definition changes, including changes
that retain the same fields but alter their meaning. It is a compatibility token,
not an automatically computed source hash or a substitute for verification.

Authorization operation records retain the original admission public key and
canonical request digest. Recovery requires both fields; records from earlier
definitions cannot acquire admission identity from the current credential.

The current definition separates browser control records (`BRC1`) from retained
Table branch records (`TBR1`). The earlier shared tag made the branch record
protection reject browser declaration/session writes. Generic branch record
access remains refused; the correction does not weaken that policy. Definitions
`82d06193f789b53ed2a0c6bf391f8870f4a0b7a5c954ecfb616e11f33de48efc`
and `04cd820c132773e6cd69e1d4174f1dff012f8e0f286a82dc35512327a252c6d6`
are rejected. Preserve their installations and matching binaries for recovery;
no offline conversion or reinterpretation of old branch records is supplied.

The current definition includes direct Table acceptance, immutable schema and
metadata identities, CREATE/ALTER/DROP lifecycle, exact typed DML recovery,
compact immutable index nodes and saved direct intents. It binds retained query
sources to independent Table cuts and native computation progress. General
catalog callers use the direct owner; the former actor-backed catalog service,
query-host catalog role and mediation schema are removed. Private Station Table
helpers keep their separate native-turn semantics.

Matching node, worker, CLI and SDK builds are required. Earlier actor-backed
catalogs, saved commands and retained query bundles are incompatible. No automatic
converter, fallback decoder or installation reset is supplied. Recover earlier
pending work with its matching build before an explicit cutover.

The local configuration checkpoint also includes the startup policy registry.
Installations from before this definition are rejected; automatic first startup
applies only to missing or empty directories and never converts retained history.
Keep existing installations with their matching artifacts, or deliberately select
a separate new installation directory.

Station query delivery includes authenticated typed terminal failures, distinct
from complete or partial Arrow results. The native handler input ABI includes
that failure value. Earlier handler libraries and port contracts reject at
loading or capability validation; application callback compatibility is not
established by sharing a language-level class name.

Finite query plans retain their own mandatory plan-definition identifier, owned
output names, Boolean programs and value-count progress. Publication identity
includes domain, namespace and record ID. These unchanged contracts remain part
of the current shared definition; an identifier does not bypass any of their
individual validation, recovery or authorization checks.

The current definition also requires typed assistance coverage and context status
in SQL session replies and shared query assistance. Matching console, service and
query-client builds are required. Missing fields or an earlier definition reject;
a short candidate list alone never establishes complete matching coverage.

The current Table definition uses the paged acceptance owner. The standalone
row-delta memtable, catalog composition and materializing segment scan are
removed, including the `TRDL` payload interpretation. This is a shared-definition
cutover: earlier WAL directories, frames, stored artifacts and callers reject,
including those produced by the earlier paged owner. Their original bytes remain
intact. Finish pending work with its matching build; no converter or automatic
installation reset is supplied.

## Current artifact inventory

The current definition covers the following stored and caller interpretation.
Each owner still validates its own framing, digests, identities and permissions;
matching the shared definition alone is insufficient.

| Artifact family | Current interpretation and owning contract |
| --- | --- |
| Native requests, authority and caller ABI | Signed command/query envelopes, saved requests, admission identity, authority heads, generated ABI declarations and port capabilities retain one matching definition. See the [native contract](../../../contracts/TRANSIT_V1.md) and [caller boundary](callers.md#language-neutral-boundary). |
| Local WAL, objects and native recovery | Directory/owner markers, WAL frames, object envelopes and native page/block references bind the shared definition. The accepted native WAL root includes policy, resource state, input progress, outputs and effect/retry evidence. See the [storage contract](../../../contracts/TRANSIT_STORAGE_V1.md#native-authority-on-local-storage). |
| Table storage and interpretation | Acceptance records, immutable declarations, row-schema fingerprints, index nodes, `.tseg`/`.tdel` objects and manifests bind exact interpretation. Logical types, physical codecs and collations remain distinct. See the [Table schema](../../../contracts/TABLE_SCHEMA_V1.md) and [storage formats](../../../contracts/TRANSIT_STORAGE_V1.md). |
| Direct operations and catalog lifecycle | Frozen intents, operation claims, DDL reservations, named resource initialization and dependency records retain exact object/definition identities and accepted outcomes. See the [direct Table](../../../contracts/DIRECT_TABLE_V1.md) and [declarative catalog](../../../contracts/DECLARATIVE_CATALOG_V1.md) contracts. |
| Retained sources and logical history | Durable Table pins, accepted WAL frontiers, independent source vectors and saved history-reader positions preserve their original basis across restart. See [snapshot coverage](../../../contracts/DATA_LIFECYCLE_V1.md) and [retained reads](../../../contracts/DIRECT_TABLE_V1.md#retained-reads-and-binary-payloads). |
| Computation and result records | Saved direct sources, native progress, captured/maintained results, exchange records and named attribution use the current owners and exact source/result evidence. See the [relational](../../../contracts/RELATIONAL_V1.md), [exchange](../../../contracts/RELATIONAL_EXCHANGE_V1.md) and [named computation](../../../contracts/NAMED_RELATIONAL_V1.md) contracts. |
| SQL and reactive callers | Saved commands, preparation/recovery, binary result columns and completion evidence, result references, assistance coverage and Follow controls require matching service and caller contracts. Native SQL result bodies use TSR1 framing; JSON result batches reject. See [SQL sessions](../../../contracts/SQL_SESSION_V1.md) and [reactive clients](../../../contracts/REACTIVE_CLIENT_V1.md). |
| Installation and deployment | Local installation/configuration checkpoints, startup policy, selected artifacts and launcher records reject incompatible retained installations. See [installation](../../../contracts/APPLICATION_INSTALLATION_V1.md). |
| Logical values and Arrow layouts | Existing logical descriptors and Arrow metadata keep their own mandatory identifiers and validation. The direct-owner cutover does not redefine upstream Arrow IPC or add a general encoded-array layout. See [logical Arrow](../../../contracts/FUZE_ARROW_V1.md) and [Arrow interfaces](arrow.md). |

Cross-Table transaction decisions and catalog-consistent snapshot acquisition,
additional native checkpoint representations, general changefeed consumer formats
and new encoded-array layouts require their own definition review before use.
They are not admitted merely because a current artifact contains an identity or
position field. An incompatible extension replaces the shared definition and
its affected owning formats, consumers and fixtures together.
