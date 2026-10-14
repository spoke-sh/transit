# Authorization v1

The native `declarative_authorization` capability provides roles, credential
bindings, generic objects, grants, staged administration and current policy
inspection. [Authorization.zig](../packages/zig/transit-protocol/src/Authorization.zig)
owns the types; the native schema reflects them. The SQL mapping and trusted Table
mediation described below are integration profiles under implementation; the
native capability alone does not advertise restricted Table access.

## Authority and identity

Authorization is part of the native authority's immutable, journal-published
state. Its implementation depends only on public protocol types. SQL parsing,
Table interpretation and application computation remain outside that authority.

Authentication identifies a current principal and credential epoch. A binding
selects one stable login role. Credential rotation changes the credential epoch,
not that role's identity or grants; it invalidates old sessions and never revives
retired native identities. Non-login roles cannot authenticate. A selected active
role requires a current eligible membership path from the authenticated login
role. Services cannot authenticate a caller by supplying an arbitrary subject ID.

Names are bounded UTF-8 identifiers resolved to stable realm-local identities.
Rename preserves identity. Retired role/object identities are never reused.
Role membership, grants and ownership use IDs, not unresolved names.

## Roles and grants

Membership records identify member, granted role, grantor, revision and ADMIN,
INHERIT and SET options. Membership cycles reject before publication. INHERIT
controls effective privileges; SET controls explicit role selection; ADMIN
controls membership delegation. Administrative attributes do not become ordinary
inherited data privileges. PUBLIC is an implicit all-role grantee with no
membership or delegation authority and no default privileges at bootstrap.

Object grants identify an exact object, grantee, grantor, action set and grant
options. Effective access is the union of independently valid grant paths.
Revocation removes the selected path and its unsupported dependents; it never
becomes an overriding deny against another valid path. RESTRICT refuses an
operation with dependent grants; CASCADE closes only dependent authority. A
grantor cannot grant an action or delegation option it does not currently hold.

Object ownership supplies administration and grant-option authority separately
from ordinary data privileges. Owners can revoke their own ordinary privileges.
Ownership does not transfer resource writer PIDs, execution generations or
lifetime ownership. Role retirement requires explicit dependency handling.

Native operation targets are realm, process and resource identities. Framework
targets have opaque stable identities registered by an authorized domain owner.
Their actions are validated against the owner's declared object class; the
kernel does not infer Table semantics or authorize an arbitrary registration.

The realm authorization object is `{ kind: realm, id: 0 }` within the envelope's
realm. Process/resource objects use their native identities. Framework domains
and objects receive separately allocated stable IDs. Root explicitly registers
each domain's registrar principal and action mask; only that registrar creates
its objects. Ownership alone never allows an arbitrary registrar substitution.

The SQL profile maps CONNECT to databases, USAGE/CREATE to schemas and
SELECT/INSERT/UPDATE/DELETE to Tables. Lifecycle control follows logical ownership.
Catalogs map explicitly to databases; schemas are catalog metadata namespaces.
Creator/schema-scoped default grants apply to newly published objects. Updating
a default never silently edits grants on existing objects.

## Bounded evaluation and storage

Role, membership, object and grant collections are paged durable catalogs.
Allocation bounds apply to a decision or command, not total collection size.
The initial decision profile permits at most 256 distinct role vertices and
4096 work charges per evaluation, with a maximum path depth of
32. A role/object lookup, membership/grant page fetch and each returned edge
consume one charge. Each page contains at most eight records. Exceeding any bound rejects with
an explicit authorization-budget diagnostic; no partial positive decision is
usable. These bounds are authority configuration, not a caller-selected way to
bypass work or authorize data.

Names are at most 63 UTF-8 bytes. An inspection response contains at most eight
records and a scope/revision-bound cursor. Grants and memberships retain their
grantor for bounded provenance inspection. Individual administrative commands contain bounded actions;
large cascades and change sets stage paged candidates with explicit byte/work
quotas. Only a complete candidate can publish one new authorization revision.
Abandoned candidates supply no authority. No retained-state expiry is implicit.

The typed administrative workflow uses `begin`, `advance`, `publish` and
`abandon`. Each begin carries its expected policy revision, active role and one
owned action. The retained outcome identifies the original caller, basis,
created identity, changed-record count, step count and status. A step processes
at most eight records; each dependency decision has the evaluation bounds above.
Deployment quotas default to 65536 steps and 1000000 changed primary records per
candidate. These are work limits, not limits on retained roles, grants or objects.
Index entries are storage details of the corresponding primary record.
Revoked edges remain in primary history but leave the active membership/grant
indexes. Repeated revocation does not add work to unrelated access decisions.

Credential changes and role-name changes preserve stable role identities.
Role retirement checks owned objects and administrative role ownership before
processing memberships, credentials, grants and defaults. Ownership must be
explicitly transferred or the owned object retired; CASCADE does not delete
application data. Cascaded grants cannot revive when a later independent grant
restores the former grantor's authority. Temporarily disabling a role preserves
its grant provenance while denying its use; an unrelated cascade does not erase
those suspended paths. Ownership transfer rewrites owner grant provenance within
the same private candidate before publication.

## Publication, replay and concurrent changes

Administration is authenticated, revision-checked and bound to an original native
operation identity. Lost receipts retry exact signed bytes. Replay restores
accepted authorization state without reprovisioning credentials or dispatching
effects. Ordinary startup never applies grants from configuration.

`command.authorization` carries the workflow. A begin receipt is its change ID;
`query.authorization.kind.change` reports the retained outcome. Begin and
advance stage private roots; only publish selects a complete policy root. A
separate durable identity high-water mark reserves IDs during staging, including
competing or subsequently abandoned candidates. A changed basis rejects advance
or publish. A failed staging operation never replaces the previously recorded
candidate. Recovery requires no graph materialization or policy reapplication.

The identity query exposes the caller's bound login role and credential epoch
without requiring native resource-inspection rights. Role/grant inspection is
scoped to the caller, ownership or an explicit unscoped native inspection grant.
Pagination binds the realm, caller, selected role, selector and policy revision;
changing any scope rejects the continuation. Decision reads require the complete
requested action set. Missing objects and denied decisions both withhold data.

Direct native `grant`/`create_principal` provisioning creates a private role and
an explicit graph grant. `grant_resource` edits a graph grant through an index,
not a separate permission store. Replacing a direct native grant retires its old
private role, so old resource rights cannot revive. These `native/` roles cannot
own framework objects, be rebound as logical login roles or be altered through
logical role administration. Named logical roles use credential binding and
rotation instead. Worker rotation preserves the private role and sequence while
advancing the credential epoch and fencing the process generation.

Policy revision is independent of data snapshot revision. Cached bytes, prepared
statements, sessions and cursors supply no permission. Every protected read
checks current authorization before disclosure; mutation publication validates
its original subject/active-role requirements against current authority and
retains the existing execution/fencing checks. A racing policy publication
invalidates stale prepared authority decisions.

Revocation does not recall bytes already sent or undo committed writes. Work
that has not committed retains its original operation identity and exposes its
actual phase under current disclosure rights. Recovery operators require their
own explicit rights. Error messages, metadata and outcomes are protected data.

Registration of framework authorization identities and domain publication use
an attributed recoverable handshake. Reserved objects grant no visibility into
unpublished data. Reused names bind new identities. Multi-owner provisioning is
not presented as an atomic cross-resource transaction.

## Trusted Table mediation

Restricted users hold object privileges and no backing-resource read capability.
A trusted service authenticates the original subject, checks every referenced
object and executes through public clients using private scoped service keys.
It checks current rights again before each protected result batch and completion.
Its service identity cannot stand in for a missing user privilege.

Native resource readers remain explicitly privileged infrastructure callers.
The restricted-user proof includes native entries, leased snapshots, retained
versions, metadata, schema chunks, indexes, history, results and recovery paths.
Client-side filtering is not an isolation boundary. The kernel does not prove
that a trusted executor computed honestly, and protocol authorization does not
isolate processes sharing the same operating-system account.

## Compatibility and profile

The cutover replaces the shared mandatory native definition identifier, including
signed requests, persisted roots, saved operations, generated declarations and
bindings. Missing or incompatible definitions reject before execution/disclosure.
No fallback decoder, legacy authorization store, converter or automatic reset is
provided. Removing old local data is an explicit user action.

The reference profile follows NIST core/hierarchical RBAC and PostgreSQL 18's
documented role/privilege semantics. It is not a claim of complete SQL-standard,
PostgreSQL or MySQL server conformance. Unsupported row/column policies, ABAC,
identity federation and security-definer behavior reject. Adapter dialects lower
to shared typed operations; they do not maintain independent permission stores.
Transit role records also have an administrative owner. This is a Transit
extension; PostgreSQL roles themselves do not have object owners.
