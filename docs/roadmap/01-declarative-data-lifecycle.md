# 1. Declarative data lifecycle

[Roadmap](README.md) · [Current data model](../handbook/reference/data-model.md)

Let an application describe its data and dependencies, apply a supported change,
then inspect the accepted definition and operation outcome through consistent
public operations. This is planned work over existing owners, not a claim that
all data kinds already share a catalog or reconciler.

## Baseline and scope

The Table catalog already owns stable object/column identities, immutable
definitions, CREATE/ALTER/DROP, DML outcomes and native authorization bindings.
KV and Documents have resource/service APIs but no common named SQL publication
lifecycle. Named relational definitions and captured/maintained execution have
typed Zig owners with explicit activation. Dependencies, policy and progress
remain spread across their owning interfaces.

Unify the public model without replacing these owners or adding another policy
store. Server YAML remains operational configuration; data declarations and
administrative changes use their owning public operations. A new manifest, CLI
command or UI form must not become a separate source of authority.

## Delivery sequence

1. **Inventory the lifecycle contracts.** For Table, KV, Document and named
   computation definitions, record identity, naming, interpretation, dependencies,
   policy references, admission, publication, inspection, alteration and retirement.
   Distinguish supported operations, offline compilation and missing execution.
   Identify which fields and operations can be shared and which remain kind-specific.
2. **Define shared metadata and operation evidence.** Specify versioned neutral
   types for object/definition identity, expected revision, dependency bindings,
   operation identity, accepted outcome and bounded observed progress. A query's
   source vector, a Table head and a Document revision remain distinct types.
   Define unavailable, incomplete and denied observations; do not infer failure
   from a timeout or fulfillment from worker liveness. Generate the schemas and
   shared fixtures from the owning types.
3. **Implement a complete Table slice.** Adapt the existing catalog lifecycle to
   those types. Validate and show a proposed change without applying it; apply
   against its expected definition/head and inspect the exact accepted result.
   Preserve original intent through lost replies and name/schema replacement.
   Use existing SQL and typed callers to demonstrate the whole path before
   extending object kinds.
4. **Add named KV and Document lifecycles.** Bind explicit encodings, initialization
   rules and owned resources to stable catalog identities. Reuse current service
   provisioning and publication, with durable bounded recovery between steps.
   Do not promise atomicity across independent owners. Define failed/partial
   provisioning, cleanup, rename, retirement and same-name replacement. Publish
   typed operations first; expose SQL publication only for implemented grammar
   and qualified execution paths.
5. **Make dependencies and policy references inspectable.** Bind exact object and
   definition identities, record required access and distinguish metadata visibility
   from data access. Extend explicit dependency registration and RESTRICT behavior;
   never infer all consumers from names or payloads. Reuse current authorization,
   unlimited-retention defaults and owner-specific budgets. Explain a blocked
   change without disclosing unauthorized dependency data.
6. **Connect computation definitions and inspection.** Expose named query inputs,
   requested lifetime and definition revisions through the same metadata model.
   Link to existing activation and outcome evidence; distinguish a definition
   from a running computation and a completed result from current freshness.
   SQL/SDK adapters and Board projections consume these shared public operations.
   Board changes follow its explicit capability and UI review boundaries.

Each numbered slice needs an independently reviewable contract and usable caller
path. Avoid waiting for every data kind to be implemented before proving the
Table path. No parsing or metadata milestone counts as complete publication.

## Completion evidence

- An application can create a Table, inspect its definition, write/query rows,
  alter the schema and recover the original accepted change after losing a reply.
- Named KV and Document objects expose explicit interpretation, initialization
  state, current rights and lifecycle outcomes through the qualified typed path.
- Repeating an inspection or loading a definition starts no work. Applying a
  competing change rejects the stale expectation; recreating a name never
  retargets an earlier operation or dependent definition.
- Independent caller fixtures agree on definitions, outcomes and permission
  failures. Test revocation, interrupted provisioning/publication, missing
  dependencies and object/dependency counts beyond resident caches.
- The handbook states each object's executable lifecycle and demonstrates how
  to distinguish defined, published, pending, complete and unavailable evidence.
  These are review questions; the implementation must define exact status types.

## Boundaries and follow-on work

This milestone does not add automatic maintained-query scheduling, arbitrary
cross-resource transactions, historical SQL, branches or a universal health
boolean. [Managed computations](04-sql-and-dataflows.md) add service-owned
activation and maintenance; [historical catalogs](03-standards-and-catalogs.md)
extend the same identities and interpretation model. The kernel stays generic.
Definitions and reads never grant rights or dispatch external effects.
