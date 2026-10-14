# Authorization v1

This specification defines the proposed declarative authorization cutover.
Native capabilities do not advertise these operations until their implementation
and public consumer contracts are present. Existing native/state authorization
continues to describe the executable profile during implementation.

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
records and a scope/revision-bound cursor. At most eight grant paths appear in
one explanation page. Individual administrative commands contain bounded actions;
large cascades and change sets stage paged candidates with explicit byte/work
quotas. Only a complete candidate can publish one new authorization revision.
Abandoned candidates supply no authority. No retained-state expiry is implicit.

## Publication, replay and concurrent changes

Administration is authenticated, revision-checked and bound to an original native
operation identity. Lost receipts retry exact signed bytes. Replay restores
accepted authorization state without reprovisioning credentials or dispatching
effects. Ordinary startup never applies grants from configuration.

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
