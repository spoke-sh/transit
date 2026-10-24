# Named relational definitions v1

This contract specifies the application-owned naming layer over the selected
[relational contract](RELATIONAL_V1.md). Definition publication, authorization,
query activation and result delivery are separate operations. Fuze and the query
owners retain their existing plans, source vectors, ordered arithmetic, current
rights, revision granularity and recovery semantics.

## Scope and identities

A namespace belongs to one realm, owner PID and native resource. It has an
explicit administrator, record quota and logical retained-byte quota. That native
resource owns computation metadata and progress; direct Table catalogs and
partitions have independent identities. Each native activation/progress turn
still mutates at most its own resource. The namespace does not grant native
access or replace catalog policy.

Names are case-sensitive ASCII identifiers of at most 21 bytes, beginning with
a letter or underscore and continuing with letters, digits or underscores. This
bound permits an exact name key within the native 32-byte key limit; names are
not truncated hashes. It bounds one name, not the number of retained definitions.
An explicit nonzero uint64 object identity is permanently assigned to its name.
Immutable definition revisions begin at one. Conditional replacement increments
that revision by exactly one and preserves the object and name. Name removal,
reuse and cascading deletion are outside this profile.

A definition binds an exact immutable `RelationalBundle` publication, its original
publishing peer, fingerprint and captured or maintained lifetime. The bundle
contains the qualified typed plan, source identities and schemas, and the
original caller's source-retention grants. Each grant binds the worker principal,
Table interpretation, capture selection, pin owner and immutable computation
purpose. Snapshot and history grants remain distinct. Publication
verifies the complete canonical bundle and publisher and retains its native read
version. It acquires no source data vector and starts no query. A definition
cannot change meaning when live Table names, schemas or the query name's current
revision change. Activation separately validates current source compatibility and
rights through the existing query owner. The original request publication must
still be published at activation; its retained definition pin preserves evidence,
not permission to revive an explicitly retired dependency.

Every saved definition/activation reference requires the exact shared contract
definition, namespace scope, name, object, revision and immutable record digest.
Missing or foreign definitions reject before work. Loading a saved reference
does not substitute current metadata, the current name revision or a fresh query.

## Publication and authorization

The administrator initializes immutable namespace configuration through an
authenticated external input. Publication and query-policy changes require that
same current administrator identity. Native delivery and resource grants remain
independent requirements. Definition metadata reads use the public resource read
boundary; reading a name confers no payload or execution permission.

Publication takes an explicit expected name revision. New names require zero;
replacement requires the observed current revision and the original object.
The immutable revision and current name head become visible atomically. Exact
retries recover the existing identical revision without acquiring another pin or
charging another quota reservation. Reusing an occupied revision/object for a
different proposal rejects. Older accepted definitions remain addressable after
later publications.

Authorization is a separate conditional operation against the coordinator's
existing `RQA1` policy for the publishing peer. It selects an exact definition
reference, a catalog principal and the next policy revision. The original policy
and its definition binding are archived atomically. The archive is immutable and
is keyed by peer and policy revision; current policy, not that archive, grants
execution or disclosure. Replacing a definition does not update authorization.
Updating the policy retains the query owner's existing revocation semantics.

The namespace quota counts accepted definition/name/authorization records and
the declared bytes of retained bundle dependencies. This is logical accounting,
not physical provider-byte attribution. Quota failure accepts no partial revision
and never expires old definitions, releases their dependencies or discards
accepted work. Configuration/control records and operation buffers are bounded;
point lookups do not load all retained revisions. Retention is unlimited by
default. Definition/policy archive collection is not exposed by this profile.

## Explicit activation

An authenticated Station call carries the exact definition reference and policy
revision. The application owner checks the reference, original publishing peer,
immutable authorization archive and current `RQA1` policy, then invokes the
existing captured or maintained `start` operation with the original bundle and
configured executor clients. A read-only direct status check discovers source
authority; native admission commits before later direct pin acquisition. Neither
publication nor activation may sign a replacement caller grant.
Activation preserves its existing four-mutation ceiling and commit boundary.
There is no separate UI configuration authority or alternate query executor.

The resulting query root records the request, calling peer/correlation and policy
revision. Together with the permanent authorization archive, those fields bind
the activation to its original named definition. No extra root write is needed
at admission. Later names or authorizations cannot relabel the accepted query.
Exact native retries recover the original admission. Reusing a settled call
identity for new work remains invalid under the query owner.

Explicit activation does not promise an immediate result. Captured jobs retain
their original finite basis; maintained jobs capture their initial history basis
and publish each required successor through the existing owner. A name lookup,
definition edit, policy inspection or result replay does not activate work.

## Results and recovery

`RelationalResult` verifies captured complete coverage. `RelationalRevision`
verifies maintained snapshots and complete delta transactions, including exact
previous/new identities, source vectors and current dependency rights. Named
bindings do not alter their resume positions. A consumer installs a candidate
relation only after complete coverage and saves its position atomically with
that installation. A partial transaction, unavailable predecessor or incompatible
schema cannot silently become a newer snapshot.

`NamedRelational.capturedDefinition` resolves an opened captured result's exact
named definition through its original peer/policy archive at the same retained
native snapshot. It verifies scope, immutable request, lifetime and bundle
fingerprint, charging each metadata read to the result's request budget. Current
result and source disclosure rights are checked before and after inspection.
Later name revisions cannot relabel this result. Inspection consumes no output;
the result's `freshness` comparison and checked terminal output coverage remain
distinct. Closed or exhausted readers reject this inspection.

The last complete maintained revision stays distinct from a failed successor,
pending input and the current definition draft. Explicit policy changes may deny
access to earlier results; an archived authorization is not a permission cache.
Cancellation/retirement use the existing query owner and their own-resource
control path. They do not remove definition history or dispatch external effects.

The naming layer performs no connector operations. Replay, retraction, exchange,
worker reassignment and reading a delta never dispatch or undo an external effect.
Any future sink binding requires its separate activation and reconciliation
contract. Named definitions do not enable `CREATE VIEW`, `CREATE MATERIALIZED
VIEW` or `SUBSCRIBE` syntax; those SQL families retain their separately declared
support status.

## Canonical records and commands

`transit-station-app.NamedRelationalRecords` owns the values. All records begin
with their four-byte ASCII magic and the exact 32-byte shared definition hash.
Integers are little-endian, booleans are exactly 0/1, arrays have no padding,
and structs follow declaration order. Unknown magic, incompatible definitions,
noncanonical names and trailing bytes reject. A name occupies its length:u8 and
21 bytes, with unused bytes zero. `Scope` is realm, resource, owner and namespace
as u64s. `Identity` adds name, object:u64 and revision:u64. A stored native read
version is PID:u64, input:u64 and index:u8. Publication references use the existing
72-byte `SPF1` encoding.

| Magic  | Payload after definition                                                               | Bytes |
| ------ | -------------------------------------------------------------------------------------- | ----- |
| `NRC1` | Scope, administrator:u64, record limit:u64, byte limit:u64                             | 92    |
| `NRB1` | Reserved records:u64, logical bytes:u64                                                | 52    |
| `NRD1` | Identity, peer:u64, request:SPF1, retained version, bundle fingerprint:32, lifetime:u8 | 236   |
| `NRR1` | Identity, immutable definition digest:32                                               | 138   |
| `NRP1` | Identity, digest:32, original RQA policy fields without its header                     | 203   |
| `NRA1` | Identity, digest:32, policy revision:u64                                               | 146   |
| `NRI1` | Empty initialization control                                                           | 36    |
| `NRU1` | Name, object:u64, expected revision:u64, peer:u64, request:SPF1                        | 154   |
| `NRG1` | Identity, digest:32, expected policy revision:u64, principal:u64, allow:bool           | 155   |

Lifetime is captured=1 or maintained=2. The definition digest is SHA-256 of
`transit.application.named-relational.v1\0` followed by the entire canonical
`NRD1`, including the retained native version. `NRP1` preserves the RQA peer,
request resource, catalog principal, revision, bundle fingerprint and allow bit.
The initialization configuration and budget consume two records and 144 logical
bytes. Each definition adds its 236 bytes and declared bundle length; a new name
adds its 138-byte head; each authorization adds 203 bytes. Replacements preserve
the head's fixed allocation. Counters are checked against explicit quotas before
the atomic decision is accepted.

Keys begin `00 4e` (`\0N`), then a one-byte tag. The `c`/`b` keys add namespace:u64be.
The `n` key adds namespace:u64be and the exact unpadded name. The `d` key adds
namespace:u64be, object:u64be and revision:u64be. The `a` key adds peer:u64be and
policy revision:u64be, independent of namespace, matching the underlying query
policy's coordinator-wide scope. Keys occupy at most 32 bytes.

`Control` carries `NRI1`, `NRU1` or `NRG1` in an authenticated administrator cast;
`Activation` carries `NRA1` in the original publishing peer's call. Hosts retain
the exact signed native request across uncertainty. Definition and authorization
exact retries also work after later revisions, under current administrator rights,
without changing the current head or policy. Invalid controls return their owning
error and leave the private decision unchanged. Applications own any durable
rejected-input disposition; an infrastructure failure does not fabricate one.

Typed references require the shared definition field when deserialized. The
[independent fixtures](../tests/named_relational_records.py) pin full-width
identities, layouts and digests. The [proof ledger](../tests/README.md#named-relational-definitions)
records deterministic and native execution separately. This additive namespace
does not alter existing interface-definition or query-root formats.
