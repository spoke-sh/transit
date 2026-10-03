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

The local server supports separate installed applications, scoped
caller exports, compatible replacement and exact recovery on Linux x86_64.
The supervisor hosts independently compiled Zig workers. Worker adapters for
other SDK languages are not available. Pinned neighborhood upgrades,
arbitrary incompatible executable replacement and automatic history migration
remain outside the profile.

Version-1 server configuration includes Board inspection. Applications declare
resource access explicitly through the version-1 installation declaration's
`inspection` list. These grants belong to Board's separate identity; restarting
or replacing a worker does not restore revoked access. See
[application inspection](../../apps/transit-cli/docs/applications.md#board-inspection).

## Declarative application interfaces

The shared compiler validates a bounded complete definition and its reference
graph. Query declarations, explicit commands, renderer/theme compatibility and
source capabilities are distinct. Follow supports int64 Table sources;
KV and Document sources support finite queries without watches.

SQL text, visual edits and generated modules use that same neutral model and
semantic validation. Offline parse/format/module generation performs no publication,
query submission or effect dispatch. Structural schema validity alone cannot
validate graph references, grants or runtime capability.

The [application SQL reference](sql/application.md) describes `CREATE INTERFACE`,
`CREATE THEME`, `CREATE SCREEN`, `CREATE BINDING` and `CREATE ACTION`, including
their required options and a complete program.

Publication uses a frozen reviewed proposal and conditional active revision.
Bounded upload/staging is recoverable; only final validated activation changes
the published interface. Status reads use the operator's current policy, not a
host's stronger inspection credential. Conflicts or unknown replies require
reconciliation of the exact operation before editing another proposal.

Application host errors preserve the compiler's member, option and source
location and distinguish local validation from signed-command dispatch. Unknown
admission identifies the exact saved sequence; native rejection and failed reads
do not imply a terminal publication outcome. Board's definition editor displays
this shared evidence and retains pending signed work for explicit recovery.

Publication status retains rejected-input detail separately from the operation's
receipt. Original compiler locations refer to the verified assembled body;
policy denials retain the rejecting policy, and incomplete uploads retain their
written and required chunk counts. Later policy changes, activation or explicit
cleanup do not rewrite those explanations. A rejected input alone does not settle
a staged operation or undo an applied interface. Current read access is required
to disclose either the receipt or its diagnostic evidence.

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

The application declaration compiler handles application definitions. State
declarations have their own offline compiler, and compatible empty Tables publish
through explicit catalog callers. Connector DDL and SQL privileges remain
grammar-only; the query console does not execute administration. See the
[SQL grammar surface](sql/grammar-surface.md) for implemented and planned forms.
