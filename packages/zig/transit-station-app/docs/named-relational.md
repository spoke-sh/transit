# Named relational definitions

`NamedRelational` publishes immutable names for captured and maintained Table
queries. It composes the query package's existing owners above Station. Publication,
authorization and activation are separate calls; looking up a name starts no work.
SQL compilation uses the shared Fuze relational parser and explicit authorized
catalog definitions to produce the frozen `RelationalBundle` first.

Configure one realm, native resource, owner PID, namespace, administrator and
record/byte quota. The resource holds computation metadata and progress; direct
Tables have independent catalog resources, audiences and partitions. Names are
case-sensitive ASCII identifiers of at most 21 bytes. Nonzero uint64 object
identities permanently belong to one name; immutable revisions begin at one.
Native grants and catalog policy remain independent requirements.

1. Prepare the canonical bundle with exact direct Table definitions and original
   caller grants for its worker principal, source cuts and pin identities. A
   captured query uses snapshot grants; a maintained query uses history grants.
   Stage that bundle with `station.PublicationUpload` in the
   `query_request` domain. The publishing peer will also call activation.
2. Initialize the namespace from its explicitly configured administrator.
3. Publish a `Proposal` with name, object, expected name revision, original peer
   and exact bundle publication reference. Publication validates the complete
   bundle, retains its native version, and returns an immutable `Reference`.
4. Authorize that exact reference with an expected query-policy revision, catalog
   principal and allow flag. This archives the definition binding and updates the
   existing query policy atomically. Editing a definition does not update policy.
5. Send the returned `Activation` in an authenticated Station call from the
   original publishing peer. Supply the worker's configured direct Table clients
   to `activate`; they authenticate its saved grants without impersonating the
   caller. `activate` returns the captured or maintained root;
   result readiness follows the owning query's complete-coverage contract.

`Control.encode/decode` supplies bounded administrator casts for initialization,
publication and authorization; `NamedRelational.control` validates their real
native origin. `Activation.encode/decode` supplies the separate peer call.
Applications schedule captured/maintained continuations and use their existing
explicit cancellation, wake and retirement controls. Invalid administrative
operations leave the private decision unchanged. The host handles their rejection
without treating storage/allocation failures as accepted terminal outcomes.

`lookup` reads the current reference. `definition` reads an exact immutable
revision. `attribution` resolves a query root's original peer and policy revision
to its named definition, even after later publications. These metadata methods
require an authorized public resource reader. Metadata and archived policy do not
grant result access. `RelationalResult` and `RelationalRevision` recheck every
current dependency, including sources contributing no rows.
The complete result retains its original direct Table cuts after pin closure.
Independent Table cuts do not form a catalog-wide atomic snapshot. A published
definition or a completed captured result alone does not establish freshness
against later row changes.

For an opened captured `RelationalResult`, use `capturedDefinition`. For an opened
maintained `RelationalRevision` result or delta, use `maintainedDefinition`.
Both read the original authorization archive and exact definition at that reader's
retained native cut. They check the computation scope, request reference, lifetime
and bundle fingerprint, and recheck current result/source rights before returning.
Their bounded metadata reads use the reader's request budget and consume no output.
Use the reader's `freshness` method to compare the actual source cuts with current
logical row progress; read through terminal `next` to verify complete output.
The definition, source freshness and complete delivery are separate observations.
These methods start no work, cannot produce a maintained consumer checkpoint,
and reject closed or exhausted result readers.

Publication retries return the original revision and pin without another quota
charge. Authorization retries return the original binding without reinstalling
an older policy. A conflicting expected revision or changed accepted proposal
rejects. Preserve the exact native request during unknown admission; a fresh call
identity is new work. Saved references require the exact shared contract definition,
not just a v1 label. The original request must still be published when activated.

Save a host's exact `Session.Pending` before dispatching a publication or policy
commit. After worker key rotation, the old signature can no longer submit that
command. Use `AuthorizationClient.read(.{ .receipt = original_request })` with
the current credential to inspect its original acceptance. A present receipt
resolves that exact native request; a missing receipt leaves the saved operation
unresolved. Neither a current name lookup nor re-signing the proposal substitutes
for this evidence. Worker replacement preserves the named reference, original
query grants and separate activation requirement.

Publication uses three mutations and authorization uses three. Existing activation
uses at most four. Histories use point-addressed durable records; one operation
does not load all names or revisions. Supply an explicitly bounded decode workspace;
insufficient workspace or namespace quota rolls back the whole proposal, including
its pin. Logical quotas account for definition records and declared bundle bytes,
not physical storage or the complete retained native resource cut. History has
unlimited retention by default; this profile exposes no definition deletion or
archive collection.

The typed Zig and Station message boundary supports this naming profile. SDK,
Board and SQL `CREATE VIEW`, `CREATE MATERIALIZED VIEW` and `SUBSCRIBE` adapters
do not expose it. Interactive caller pages keep their separate ephemeral lifetime.
The naming layer performs no connector operation or implicit external dispatch.
See the [exact contract](../../../../contracts/NAMED_RELATIONAL_V1.md) and
[captured](../../transit-query/docs/relational-capture.md) and
[maintained](../../transit-query/docs/relational-maintenance.md) query guides.
