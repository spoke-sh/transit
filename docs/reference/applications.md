# Application installation, definitions and migration

An installed application, a published interface and a data migration are separate
objects. Installing new code does not authorize new operations, publish a UI or
transform durable data. Use the [first application guide](../guides/applications.md)
for a separately compiled Zig worker and [work-items](../../examples/work-items/README.md)
for the complete example.

## Installation and bootstrap

The language-neutral declaration describes roles, resources, artifacts and
compatibility. It grants no rights on its own. The local manager performs scoped
native provisioning and reconciles physical worker processes, while Transit
history remains the authority for grants and ownership.

Install under an explicit operation ID and retain the frozen signed request.
Accepted management intent, installed/ready state and successful domain behavior
are separate observations. After uncertainty, reconcile that operation rather
than preparing a new installation with fresh identities.

| Revision or identity | Meaning |
| --- | --- |
| Installation/application identity | Durable management and application scope |
| Artifact revision | Selected compatible executable |
| Ownership generation | Current eligible worker, fenced independently from artifact selection |
| Data epoch | Active domain/schema state |
| Published interface revision | Conditional active UI/service definition |

The version-2 local server supports separate installed applications, scoped
caller exports, compatible replacement and exact recovery on Linux x86_64.
The supervisor hosts independently compiled Zig workers. Worker adapters for
other SDK languages are not available. Pinned neighborhood upgrades,
arbitrary incompatible executable replacement and automatic history migration
remain outside the profile.

## Declarative application interfaces

The shared compiler validates a bounded complete definition and its reference
graph. Query declarations, explicit commands, renderer/theme compatibility and
source capabilities are distinct. Follow supports int64 Table sources;
KV and Document sources support finite queries without watches.

SQL text, visual edits and generated modules use that same neutral model and
semantic validation. Offline parse/format/module generation performs no publication,
query submission or effect dispatch. Structural schema validity alone cannot
validate graph references, grants or runtime capability.

Publication uses a frozen reviewed proposal and conditional active revision.
Bounded upload/staging is recoverable; only final validated activation changes
the published interface. Status reads use the operator's current policy, not a
host's stronger inspection credential. Conflicts or unknown replies require
reconciliation of the exact operation before editing another proposal.

## Data migration

Migration belongs to the data owner. Its separate policy and ledger bind a
reviewed supported plan, source epoch, target schema and ordered steps. Each step
has durable receipt/cursor evidence, so recovery does not reapply committed work
under a fresh ordinal.

The selected work-item transformation enforces a write pause, bounded copying,
complete target verification and explicit activation. Interface publication and
administrator release of writes follow separately. A changed UI definition
cannot claim data has migrated. Abandonment cannot undo activation or erase plan
and step evidence; broader transforms need their own implementation and proof.

## Contracts and commands

- [Local installation guide](../../apps/transit-cli/docs/applications.md): management commands, exports, replacement and recovery.
- [Installation/bootstrap contract](../../contracts/APPLICATION_INSTALLATION_V1.md): neutral fields, identity and host obligations.
- [Application definition contract](../../contracts/APPLICATION_V1.md): compiler and conditional publication.
- [Migration contract](../../contracts/APPLICATION_MIGRATION_V1.md): data-owner steps and exact recovery.
- [Compiler package](../../packages/zig/transit-station-app/README.md): real parse/format/schema/module commands and native APIs.
- [Browser package](../../packages/ts/transit-application/README.md): generated runtime validation, scoped signing and proposal recovery.

General DDL in the wider SQL reference grammar is still grammar-only. The
application declaration compiler handles application definitions; the query
console executes finite SELECT statements. See [SQL](sql.md).
