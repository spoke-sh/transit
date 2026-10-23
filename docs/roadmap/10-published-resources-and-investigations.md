# 10. Published business resources and consistent investigations

[Roadmap](README.md) · **Status:** Planned

Let an application publish a delivery assessment, report or other enriched
resource that humans and agents can discover, inspect and discuss using the same
evidence. Define it independently of any screen or transport. A resource can
produce a typed result, report, conversation context or visualization without
separately maintained business semantics.

## Prerequisites and scope

Consume [historical interpretation](04-standards-and-catalogs.md),
[managed computations](05-sql-and-dataflows.md), the selected
[foreign sources](06-multi-model-and-foreign-relations.md),
[branches](07-branches-merges-and-restore.md) and the
[access plane](09-control-and-policy-plane.md). Finite resources can be qualified
before maintained activation or every foreign format is implemented. Current
application bindings and named queries are foundations, not an implemented
publication/disclosure contract for enriched resources.

## Delivery sequence

1. **Define transport-independent published resources.** Record stable identity,
   immutable definition, owning application, business meaning, units/timezones,
   dependencies, typed parameters, supported questions, result schema, freshness
   requirements, budgets and optional presentation bindings. Reuse the catalog
   and application compiler's semantic owners. The current application grammar
   requires an entry screen/theme; extract or extend the shared model so a
   resource needs neither. Define operations before adding executable syntax.
2. **Separate computation, publication and consumption authority.** Make exposure
   explicit; a Table, binding or application command is not automatically public.
   Specify whether consumers need source rights or an explicitly authorized
   derived publication permits a different audience. Validate parameter, filter,
   aggregation and drilldown boundaries against that publication policy. A
   stronger service credential cannot silently supply missing source permission.
   Define how source revocation, publication withdrawal and independently owned
   published copies affect later reads; caching must preserve these distinctions.
3. **Formalize shared statement and result ownership.** Supply schema, typed
   batches, command completion, continuation lifetime and terminal coverage for
   console, SDK, reports and MCP. Preserve five-state values and lossless wide
   integers/decimals. Display limits differ from query limits and completeness;
   interruption is not an empty successful result. Bound materialization and
   release readers explicitly; large transfers use qualified data interfaces.
4. **Bind an investigation to a retained source basis.** Multiple related calls
   select exact object/definition/branch versions and captured external inputs.
   Define the selected atomic domain or explicit multi-source basis vector;
   individually consistent queries do not establish one consistent investigation.
   Freeze accepted bindings, account for pins and lifetime, and reject missing
   history. This context survives replacement of a transport connection where
   its own lifetime permits; it confers no authorization.
5. **Publish attributable results and explicit refresh.** Bind every chart,
   report, summary and result page to the same completed revision and source
   evidence. Changing the basis creates an explicit successor; it cannot relabel
   old conclusions. Distinguish source observation time, event time, computation
   completion and requested freshness. Preserve unknown freshness and conflicts.
   Generated narratives identify their evidence and assumptions; provenance
   does not prove an upstream fact or a model conclusion true.
6. **Project the same definitions through qualified interfaces.** Generate
   schemas, descriptions and presentation bindings from shared types. Let
   applications choose exposed resources and permitted actions. Discovery is
   bounded and authorization-aware; catalogs need not fit into a model prompt.

## Completion evidence

One employee and two delegated agents inspect a published assessment. Five
related queries and a report retain one declared basis while sources change.
Explicit refresh selects a successor and preserves earlier attribution. Exercise
schema changes, source deletion, missing capture, unavailable retained history,
revocation between pages and attempted cross-audience cache reuse. A report-only
consumer must not obtain raw rows through parameters or drilldown.

Compare console, SDK and presentation output with independent typed results,
including empty results, interrupted prefixes, truncation, full-width integers,
decimals and every supported cell state. Verify bounded resident memory and
explicit cleanup independently of retained investigation/result count. No test
may infer global atomicity from unrelated source versions.
