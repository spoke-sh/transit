# Authorization v1

The native `declarative_authorization` capability provides roles, credential
bindings, generic objects, grants, staged administration and current policy
inspection. [Authorization.zig](../packages/zig/transit-protocol/src/Authorization.zig)
owns the types; the native schema reflects them. The catalog and explicit Table
service enforce database/schema/Table privileges. The dedicated SQL compiler
lowers selected administration to native policy and catalog schema operations;
the neutral client provides preview and explicit apply/recovery.
The native capability alone does not advertise a Table service or establish an
adapter's original-subject profile.

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
Verified observations identify the login role separately from the selected role;
`SESSION_USER` and an active role do not become interchangeable identities.
Native SEND checks the selected role's effective privileges, including eligible
inherited grants, rather than adding the login role's independent grants. The
credential's PID restriction remains in force when selecting a role.

Native sends can select an eligible `role`. Admission retains an immutable
subject claim, indexed by destination PID and admitted input position, including
the principal, selected role, credential epoch and payload commitment. A domain
continuation references that admission through `Subject.accepted`; an invented
principal, input or destination rejects. The claim remains independent of a
worker's execution generation and survives journal checkpointing. Opted-in
process collection removes its claims in bounded pages.

For service reads, `Subject.signed` carries a separately signed `Claim`: mandatory
definition, realm, principal, credential epoch, optional selected role, service
PID and domain-owned request digest. SHA-256 over
`transit.authorization.subject.v1\0` plus canonical claim JSON is signed with
Ed25519. Fixed byte arrays remain JSON arrays, even when their bytes form valid
UTF-8. The service must bind the context to its complete immutable request;
the native authority cannot interpret application request bytes. Current
credential, role selection and object privileges remain required on every use.

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
each domain's registrar principal and action mask. That registrar or native root
can create an object; root bootstrap still records the domain's registrar as the
object registrar. Ownership alone never allows a registrar substitution.

`register_domain.lifetime_resource` optionally binds the domain to a native
resource's usability. Root alone sets this immutable prerequisite; the persisted
domain always includes the field, including an explicit `null` for an unbound
domain. It grants no resource privileges or associations. A successful `Guard`
also checks each required domain's bound resource and its lifetime dependencies.
Privilege `decision` inspection remains an authority decision, not a resource
usability check. Direct Table database, schema and Table domains must all bind
the configured catalog resource.
An expired or absent bound resource denies the guard. Storage or clock failures
remain unavailable observations. A turn rejected by this guard after exact-retry
lookup uses `AuthorizationSubjectDenied`, permitting the worker to reconsider
the same input without treating an uncertain earlier commit as rejected.

Native turns evaluate these prerequisites using their recorded time sample.
Policy or resource changes invalidate a prepared publication through the native
commit fence. A deadline passing after preparation does not resample that
prepared transition's time; a later preparation uses its own sample. Public
current guard checks obtain a time sample when a bound lifetime requires one.

A registrar may supply an immutable 32-byte binding key and optional parent
object. These opaque values establish no inherited access. The binding is unique
within its domain and survives retirement. The native registration index records
the original administrative action and outcome before object publication.
`registration` inspection lets that registrar recover a lost begin reply;
`binding` inspection returns only published objects. Abandonment permits another
candidate with a new reserved identity; retirement never permits binding reuse.

The SQL profile maps CONNECT to databases, USAGE/CREATE to schemas and
SELECT/INSERT/UPDATE/DELETE to Tables. Lifecycle control follows logical ownership.
Catalogs map explicitly to databases; schemas are catalog metadata namespaces.
Configuration includes the database name and stable native database identity.
The catalog owns bounded schema name lookup, rename and DROP RESTRICT. Every
Table CREATE admission increments its schema revision; a schema drop scans
eight durable Table records per turn and refuses publication if that revision
changes or a live/initializing Table exists. Retired schema IDs remain reserved;
name reuse registers a different native identity. Native schema objects remain
available for authorized historical inspection after namespace retirement.
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
large cascades stage paged candidates with explicit byte/work
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

`query.authorization.preview` takes an expected revision and the same `Action`
as begin. It executes candidate transitions in private scratch memory, with no
provider writes, identity reservations or policy publication. It reports
`complete`, visited changed records, steps, scratch pages and reads. Its bounds
are 32 scratch pages, 4096 page loads and 64 transition steps. Scratch exhaustion
returns `complete: false`: it does not establish that remaining dependencies
permit publication. The retained begin/advance workflow validates larger changes
under deployment quotas. A stale revision rejects; a preview never reserves its
principal sequence or permits bypassing validation during apply.

The neutral client also accepts a scoped grant changeset: a mandatory current
definition, realm, base revision, explicit managed scope and 1–32 grant,
membership or default-grant intents. Scope contains at most 32 object references,
membership pairs or creator/schema/domain targets. An intent outside the scope,
or overlapping intents for the same target and grantee, rejects before I/O.
Omitted entries have no effect. Removal and option/dependency behavior must be
explicit. Scope itself supplies no permission.

Preparation seals the complete document, principal and selected role with an
Ed25519 signature over SHA-256 of `transit.authorization.changeset.v1\0` followed
by the shared JSON encoding of those fields and the public key. It prepares and
previews only the first native change. Subsequent intents are validated against
the preceding publication's revision. Each native change publishes separately;
the changeset has ordered partial outcomes and is not an atomic transaction.
An intervening revision stops progress without rebasing, rollback or compensation.

The saved record contains the seal, completed native records/outcomes and at
most one current change. Its maximum encoded size is 128 KiB. Observation and
submission verify completed outcomes against the retained native operation
ledger; a local completion flag never proves acceptance. Recovery compares the
retained admission public key and exact begin-request digest with the saved
envelope before signing a continuation. A locally valid signature under a
self-supplied key does not establish the original signer. A completed step is
checkpointed before preparation of its successor. Pending sends retain exact
bytes and use current-credential receipt recovery. Abandonment closes only a
resolved unpublished candidate; it cannot undo the published prefix. Mixed
credential, provisioning, schema and data work uses its owning explicit
lifecycles; this grant document does not create or infer those operations.

Repeated grants by the same effective grantor union the requested privilege and
grant-option bits into an existing active edge. Repeated membership grants
preserve omitted ADMIN/INHERIT/SET options; new edges default to false/true/true.
Turning an option off checks dependent authority with RESTRICT semantics.
Repeated matching default grants union their bits. These bounded lookups inspect
at most the configured evaluation record allowance and fail closed on exhaustion.
`revoke_privileges`, `revoke_role` and `revoke_defaults` identify typed targets
instead of an edge ID and scan their indexed records in eight-record steps.
Privilege and membership revocation removes the issuing grantor's matching
authority and then checks dependency closure; independent grantors survive.
Partial default revocation applies only to future registrations.

`operation` inspection returns the retained action, outcome and required `begin`
identity to its original principal or root. `begin.public_key` is the key verified
at admission; `begin.digest` is the canonical native request digest, including
its sequence, role, basis and action. Both remain unchanged through publication,
credential rotation and restart, allowing recovery to verify the exact saved
intent without treating the current credential as its historical signer. Exact logical
role-name resolution is public within the authenticated realm; private native
roles and general role enumeration retain their inspection restrictions. Names
and role attributes contain no credentials.

`receipt` inspection accepts the exact original native request body. The
current credential of the same principal, or root, can recover its
receipt after key rotation without re-signing the old request. The retained
request digest must match; a different body at that sequence conflicts. Missing
receipt evidence for an already-consumed sequence is an error, not absence.
This observation neither executes the request nor confers data access.
For a send, a current native inspector of its destination process may also
verify that exact request's receipt. This permits a private mediation service
to validate historical admission after caller credential rotation. It grants
no access to other destinations or to the sender's administrative requests;
the domain service separately checks current original-subject disclosure rights.

Credential changes and role-name changes preserve stable role identities.
Role retirement checks owned objects and administrative role ownership before
processing memberships, credentials, grants and defaults. Ownership must be
explicitly transferred or the owned object retired; CASCADE does not delete
application data. Cascaded grants cannot revive when a later independent grant
restores the former grantor's authority. Temporarily disabling a role preserves
its grant provenance while denying its use; an unrelated cascade does not erase
those suspended paths. Ownership transfer rewrites owner grant provenance within
the same private candidate before publication.
Assigning a new owner requires SET eligibility from the actual login role,
independently of active-role INHERIT, unless the caller is root or the object's
authorized registrar. Current-owner authority remains required.

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

`authenticate` verifies an original subject, and `check` evaluates a `Guard`.
A caller may submit `check` for its own independently signed subject without
native inspection rights. The guard still evaluates current scoped privileges
and credential/role eligibility. `authenticate`, checks for other subjects, and
checks for accepted historical subjects require current native inspection rights
on the audience PID. Self-check grants no raw native inspection or impersonation.
A guard contains at most 16 requirements, all of which must succeed, sharing one
4096-charge object-evaluation budget. Requirements distinguish all requested
privileges, any requested privilege, ownership and metadata visibility (ownership
or any requested privilege). The latter never authorizes an ordinary data read.
An optional `selectable` role additionally requires SET eligibility from the
verified subject's login role. It authorizes owner assignment independently of
INHERIT; the executor's role cannot satisfy it for a different subject. Merging
guards with two different assignment targets fails closed. Root's explicit
administrative exception remains separate from service execution permission.
The native turn's optional `authorization` guard checks the original subject
again at publication and receipt disclosure. A domain worker is responsible for
declaring every actual dependency; the kernel does not prove its computation.

`AuthorizationSubjectDenied` rejects a proposed turn only after exact-retry
lookup established that it has no receipt. Station may rerun the same input to
record its current rejection. A denied receipt retains the ordinary denial or
credential-conflict code and never justifies discarding uncertain work. Root can
abandon another principal's staged administrative change for recovery; it cannot
publish that change under the other principal's attribution.

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
