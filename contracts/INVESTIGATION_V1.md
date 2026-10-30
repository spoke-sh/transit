# Consistent investigations and attributable results v1 (`INVESTIGATION_V1`)

This contract specifies durable investigation bases (`magic = 0x494E5631` /
`"INV1"`) and attribution receipts (`magic = 0x41544231` / `"ATB1"`) in the
Direct Control Plane (`transit-catalog`) and shared statement result surface
([`SQL_RESULTS_V1`](SQL_RESULTS_V1.md)).

## Investigation basis (`InvestigationBasis` / `INV1`)

An investigation binds multiple related queries, published resource evaluations,
reports, and participants (human analysts and delegated agents) to one frozen,
durable source basis without holding an interactive database transaction
([Milestone 5](../docs/roadmap/05-transactions-and-atomic-composition.md)) open
across user or agent think time.

### Two explicit, non-conflated basis kinds (`BasisKind`)

1. **`atomic_domain_cut`:**
   - Binds `(branch_id, manifest_cut: HistoricalCatalog.ManifestCut, tx_cut_id, commit_lsn)`.
   - Establishes a mutually transaction-consistent cut across all native Tables,
     KV stores, Documents, Streams, and Dataflows within that atomic domain
     (`isGloballyAtomic() == true`).
2. **`multi_source_basis_vector`:**
   - Binds an ordered slice of `SourceBasisEntry` items combining:
     - `native_source_cut`: `(source_object, source_revision, branch_id, commit_lsn, snapshot_pin_id)`
     - `captured_exchange_revision`: `(exchange_object, exchange_revision, payload_sha256, observed_at_ms)`
       for captured gateway/connector exchanges ([Milestone 16](../docs/roadmap/16-document-profiles-and-gateway-exchange-lifecycle.md)).
     - `foreign_source_pin`: `(foreign_object, uri, etag_or_generation, content_sha256, schema_epoch, observed_at_ms)`
       for external multi-model files ([Milestone 18](../docs/roadmap/18-multi-model-and-foreign-relations.md)).
   - Explicitly reports `isGloballyAtomic() == false`. Any operation or caller
     that requires global cross-source serializable atomicity on a
     `multi_source_basis_vector` is rejected (`error.NonAtomicBasisVector`).

### Freeze, pin lifetime, reconnect survival, and zero implicit authorization

- **Immutable revision bindings:** Once `basis_revision` is frozen, its source
  cuts, schema revisions, and external capture digests cannot be modified.
- **Explicit snapshot pin ownership (`PinLease`):** Every native source in an
  active basis holds a leased `TPINOBJ1` snapshot pin (`pin_id`, `owner_principal`,
  `acquired_at_ms`, `expires_at_ms`). Closing or expiring an investigation
  releases its `TPINOBJ1` pins while retaining the lightweight `INV1` metadata
  record so later reads against reclaimed history fail deterministically with
  `error.InvestigationBasisExpired` rather than silently reading current state.
- **Transport-reconnect survival without authorization:** `InvestigationBasis`
  survives connection replacement and is shareable across human and delegated
  agent sessions by `(investigation_id, basis_revision)`. Possessing an
  investigation handle confers **zero** execution or read permission; every
  bound evaluation re-validates the caller's own `CallerAccessContext` and
  `DisclosurePolicy` at `current_policy_epoch`.
- **Missing capture and source deletion:** Referencing an uncaptured external
  input fails with `error.MissingExternalCapture`; referencing a deleted or
  purged source fails with `error.InvestigationSourceDeleted`.

## Attributable results, 4-clock freshness, and explicit successor refresh (`ATB1`)

1. **`AttributionReceipt` (`ATB1`):**
   - Every result batch, chart, report section, summary table, and narrative
     block binds to `AttributionReceipt` (`receipt_digest: [32]u8`) covering
     `(investigation_id, basis_revision, basis_kind, basis_digest, resource_object, publication_revision, definition_digest, params_digest, schema_epoch, verified_policy_epoch, disclosure_mode, completeness)`.
   - Attaching a result or chart from a different `(investigation_id, basis_revision, basis_digest)`
     to an existing report is rejected (`error.AttributionBasisMismatch`).
2. **Four-clock temporal truth (`FourClockFreshness`):**
   - Every resource observation records four distinct timestamps/cuts:
     - `source_observation_cut_ms`: when upstream sources were observed/captured.
     - `domain_event_valid_time_ms`: business event-time (`valid_time`) watermark.
     - `computation_completion_cut_ms`: when the query or dataflow revision completed.
     - `requested_freshness_sla_ms`: the required freshness bound.
   - Evaluates to a 5-state `FreshnessStatus`: `fresh`, `stale_within_tolerance`,
     `stale_exceeded`, `unknown_freshness`, or `source_conflict`.
3. **Explicit successor refresh (`REFRESH INVESTIGATION`):**
   - Advancing an investigation creates `basis_revision = parent_basis_revision + 1`
     with `parent_basis_revision` and a structured `BasisDiffSummary` while
     preserving all earlier `basis_revision` records and their attributed
     conclusions immutably.
4. **Evidence-linked narratives without truth inflation:**
   - Every `NarrativeClaim` cites one or more `AttributionReceipt` digests,
     explicit `AssumptionTag`s (`model_inference`, `extrapolation`,
     `external_unverified_claim`, `human_annotation`), and enforces
     `provenance_establishes_truth == false`.
