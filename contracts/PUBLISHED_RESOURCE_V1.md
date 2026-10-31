# Published business resources v1 (`PUBLISHED_RESOURCE_V1`)

This contract specifies transport- and screen-independent published business
resources (`magic = 0x50425231` / `"PBR1"`) and their three-way disclosure
policy (`DisclosurePolicy`) in the Direct Control Plane (`transit-catalog`).
It decouples business resource declarations from [`APPLICATION_V1`](APPLICATION_V1.md)'s
mandatory entry screen/theme model and from `Station` `STATE_V1` 256-byte KV
records (`NRC1` in [`NAMED_RELATIONAL_V1`](NAMED_RELATIONAL_V1.md)).

## Identity, revision lineage, and semantic ownership

Every published resource definition (`PublishedResourceDescriptor`) records:

1. **Stable identity & revision lineage:**
   - `namespace_id: u64`, `resource_object: u64`, `definition_id: u64`,
     `publication_revision: u64` (starting at `1` and advancing monotonically on
     each published replacement), `previous_revision: ?u64`, `branch_id: u64`,
     `owning_application: ?u64`, and `created_at_lsn: u64`.
   - `state: ResourceLifecycleState`: `draft`, `published`, `withdrawn`, or `retired`.
   - `definition_digest: [32]u8`: SHA-256 over `"transit.catalog.published-resource.v1\x00"`
     and the canonical `PBR1` descriptor fields.
2. **Business meaning, units, and timezone pinning:**
   - `canonical_name`: case-sensitive identifier (`1..63` bytes; not restricted
     to the legacy 21-byte `Station` KV name ceiling).
   - `business_title` and `business_meaning`: human- and agent-readable semantic
     definition of what the resource measures and what assumptions it encodes.
   - `supported_questions`: structured `QuestionTemplate` descriptors mapping
     discovery questions to typed parameter bindings.
   - Per-column `SemanticUnit` (`none`, `iso4217_currency`, `si_unit`,
     `basis_points`, `percentage`, `spatial_srid`) and manifest-pinned
     `tzdb_version: TzdbVersion` ($\kappa_{\text{tz}}$ from
     `transit-fuze.DecimalArithmetic`).
3. **Typed parameters & domain bounds:**
   - Ordered `ParameterSpec` slice aligned with [`SQL_PARAMETERS_V1`](SQL_PARAMETERS_V1.md)
     (`ordinal`, `name`, logical type $\tau$, required/default flag, and
     `ParameterDomainConstraint`: signed/unsigned integer bounds, decimal128
     bounds, enumerated UTF-8 values, or maximum temporal window).
4. **Dependencies, schema, freshness SLA, and execution budgets:**
   - `dependencies`: explicit `(source_object, source_revision, columns)`
     lineage bindings (`HistoricalCatalog.DependencyColumnBinding`).
   - `result_schema: TableSchema.Schema` ($\tau \perp \kappa \perp \epsilon$)
     with `ColumnSemanticBinding` unit annotations.
   - `freshness_requirement: FreshnessRequirement` (`max_staleness_ms`,
     `require_complete_watermark`, `allow_stale_with_warning`).
   - `work_bound: WorkBound` (`max_rows`, `max_bytes`, `max_cpu_micros`,
     `max_iops`, `execution_timeout_ms`).
5. **Optional presentation bindings (`PresentationBindings`):**
   - Optional `ChartSpec`, `ReportLayoutSpec`, `SpatialLayerSpec`,
     `DrilldownSpec` (explicitly permitted target resource objects and parameter
     mappings), and `mcp_ui_template_uri` (`ui://...`).
   - A published resource requires **zero screens and zero themes**.

## Three-way authority separation (`DisclosurePolicy`)

Exposure is always explicit: creating a Table, View, Dataflow, or application
command never makes it a published business resource. `DisclosurePolicy`
separates three distinct authorities checked at `current_policy_epoch`:

1. **Computation authority:** The upstream source rights (`select_rows`)
   required to evaluate the backing query or maintained dataflow.
2. **Publication authority:** An explicit `publish_resource` administrative
   grant required to transition a resource revision to `.published` or
   `.withdrawn`.
3. **Consumption authority (`DisclosureMode`):**
   - `caller_source_rights` (`SECURITY INVOKER`): The consumer must hold
     `consume_resource` on the published resource **and** current `select_rows`
     on every upstream dependency in `dependencies` at `current_policy_epoch`.
   - `derived_publication` (`ATTESTED PUBLISHER DELEGATION`): Permits an
     explicitly authorized consumer holding `consume_resource` to inspect a
     curated/aggregated publication without holding raw-row `select_rows` on
     every upstream table, provided:
     1. A valid `PublicationAttestation` binds `publisher_principal`,
        `resource_object`, `publication_revision`, `definition_digest`, and
        `attested_policy_epoch`.
     2. The attesting `publisher_principal` **still holds** current `select_rows`
        on all upstream dependencies at `current_policy_epoch` (revoking the
        publisher's source access immediately invalidates the publication).
     3. Neither a worker credential nor a privileged gateway service identity
        can supply missing caller or publisher source permission
        (`error.ServiceCredentialAmplificationForbidden`).
   - `retained_published_snapshot` (`INDEPENDENTLY OWNED PUBLISHED COPY`):
     Reads from an independently owned, immutable published snapshot copy
     (`PublishedCopyArtifact`). Retiring an upstream operational table does not
     invalidate an active independently owned copy, whereas withdrawing the
     publication (`WITHDRAW RESOURCE`) or revoking the copy's audience grant
     immediately blocks disclosure.

## Non-amplifying disclosure boundaries and audience cache isolation

- **Parameter and filter boundary:** Consumers may only bind declared parameters
  within their `ParameterDomainConstraint` (`error.ParameterDomainViolation`).
  Caller-injected ad-hoc filter pushdowns over unexposed upstream columns are
  rejected (`error.UnexposedFilterPushdownRejected`).
- **Minimum group cardinality ($k$-anonymity) & 5-state error scrubbing:**
  Summary-only publications enforce `min_group_cardinality: u32` (redacting
  groups with `< min_group_cardinality` contributing rows to `Cell.missing`)
  and scrub 5-state `type_error` cells originating from restricted expressions
  to `Cell.missing` so crafted parameters cannot probe individual row values.
- **Drilldown boundary:** Drilldown requests must name a target resource in
  `DrilldownSpec` **and** pass the target resource's own `DisclosurePolicy`
  (`error.DisclosureBoundaryViolation`). Report-only consumers cannot obtain raw
  rows through parameters or drilldowns.
- **Audience-isolated caching:** Cache entries key by
  `AudienceCacheKey = SHA256(resource_object || publication_revision || basis_digest || params_digest || audience_policy_hash || policy_epoch)`.
  Cross-audience cache reuse is structurally impossible.
- **Lossless HTTP/Browser Snapshot Reads & Watermark-Driven Reactive Watches (`evaluatePublishedSnapshotJson`, `WatermarkReactiveWatchSession`):**
  - `evaluatePublishedSnapshotJson` streams bounded batches from `PublishedResourceStreamReader`, formats 64-bit `int64`/`uint64` and `decimal` cells as lossless JSON decimal strings (`"9007199254740993"`), and re-verifies session validity and `DisclosurePolicy` at `current_policy_epoch` **after** reading all rows and **before** disclosing the response.
  - `WatermarkReactiveWatchSession` binds a WebSocket watch to a `PublishedResourceDescriptor` (`PBR1`) and `InvestigationBasis` (`INV1`), emitting an initial snapshot on upgrade and subsequently emitting frames **only** when `source_watermark_lsn > last_emitted_lsn` (zero row scans or allocations on unchanged ticks). Session logout, external identity hold, resource withdrawal, or `policy_epoch` revocation immediately terminates the watch with RFC 6455 close code `1008` (`Policy Violation`).
