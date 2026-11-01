# 37. ML/AI features, model artifacts and reproducible experiments

[Roadmap](README.md) · **Status:** Planned

Let applications declare feature and embedding computations, bind model artifacts
to exact data and transform revisions, and compare attributable experiments or
predictions. Users can inspect what information was available, which executable
produced a value, which evaluation supports a candidate and whether a completed
result covers the intended input.

This is planned lifecycle work beyond the existing vector/search direction.
It does not establish a training framework, automatic model deployment or a
generic SQL model invocation interface.

## Prerequisites and ownership

Build on [managed computations and bitemporal queries](12-sql-and-dataflows.md),
[resource control](13-data-structures-and-performance.md),
[search](14-vectorized-strings-and-search.md),
[multi-model/vector retrieval](18-multi-model-and-foreign-relations.md),
[branches](20-branches-merges-and-restore.md),
[publication/investigation](28-published-resources-and-investigations.md),
[reviewed publication](29-reviewed-data-collaboration.md) and
[measurement/numerical contracts](35-scientific-arrays-and-measurements.md).
Reuse [data lifecycle](../../contracts/DATA_LIFECYCLE_V1.md),
[SQL results](../../contracts/SQL_RESULTS_V1.md),
[investigation](../../contracts/INVESTIGATION_V1.md) and
[publication](../../contracts/PUBLISHED_RESOURCE_V1.md) bindings. The
[query](../handbook/reference/queries.md),
[connector](../handbook/reference/connectors.md) and
[application](../handbook/reference/applications.md) owners retain their limits.

Transit owns generic data/compute identity, authorization, progress and publication.
Training/inference frameworks, task-specific evaluation, reasoning loops and
model selection remain applications or qualified workers. Remote model/tool
invocation uses recorded connector intents and outcomes; replay cannot redispatch.
Accelerator scheduling requires its own worker/resource profile, never implicit
GPU availability in Fuze or the kernel.

## Delivery sequence

1. **Define artifacts and immutable run manifests.** Bind source basis, feature/
   preprocessing definition, model and tokenizer/artifact digests, parameters,
   executable/toolchain/environment, random seeds where applicable and budgets.
   Separate experiment, accepted run, worker attempt, checkpoint, output and
   publication identities. Mutable provider/model aliases are insufficient for
   reproducibility; retain the available provider identity and captured response
   and explicitly report when exact regeneration is unavailable.
2. **Deliver historical and serving feature semantics.** Define event/valid time,
   source arrival/knowledge time, correction policy, windows and entity identity.
   Prevent backfilled future knowledge from entering a historical evaluation.
   Offline and serving paths share definitions and numerical interpretation;
   their actual source cuts/freshness may differ and must be visible. A TTL or
   feature-age constraint is separate from source retention and authorization.
3. **Materialize attributable features and embeddings.** Bind every output to its
   source row/span/frame revision, transform and model interpretation. Define
   normalization, vector metric/dimension, missing-input and failure behavior.
   Model/transform changes create successor outputs and indexes with explicit
   coverage; mixed embedding spaces cannot silently share comparisons. Use M35
   dependency extents for invalidation and bounded backfill. Model confidence,
   calibration and predictive uncertainty remain distinct from cell validity.
4. **Recover work and reuse artifacts safely.** Freeze original run identity before
   dispatch; checkpoint only with attributable input/progress and a documented
   restart profile. Cancellation, failed attempts and missing output do not imply
   rollback or justify repeating uncertain external requests. Derivation cache
   keys cover all semantic inputs and numerical profiles; nondeterministic runs
   require explicit reuse policy. A cache hit rechecks current access to the
   authorized result/source closure and never proves reproducibility by itself.
5. **Compare and publish evaluated candidates.** Retain dataset splits, label
   versions, metrics, evaluation code, leakage checks, incomplete coverage and
   uncertainty on an exact basis. Distinguish bitwise, tolerance-based and
   statistical repeatability. Review a frozen candidate against the stated
   baseline; destination changes make review stale. Prediction publication and
   deployment activation have separate authority. Capture later observed outcomes
   without overwriting the original predictions or claiming causal attribution.

## Acceptance and qualification

Build a historical feature dataset, capture a baseline model result, introduce
a late correction and a successor transform/model, and compare both against one
retained evaluation basis. Inspect why each changed prediction changed. Repeat
through installed typed callers and one application publication surface.

- Independent temporal oracles catch future-knowledge leakage, late corrections,
  ambiguous timestamps, missing labels and incomplete source history.
- Verify retained input/model identity across worker replacement, retries,
  checkpoint resume, renamed sources and changed provider aliases. Missing
  artifacts fail explicitly; a seed alone cannot establish repeatability.
- Test changed preprocessing/tokenization, mixed vector spaces, partial backfills,
  revoked cache rights and source/result erasure under the owning policies.
- Inject lost acceptance/publication replies, cancellation races, unavailable
  accelerators, remote unknown outcomes and output corruption. Recover original
  operations without fabricating completion or replaying effects.
- Measure feature freshness, backfill cost, transfer/accelerator occupancy where
  claimed, bounded memory, warm allocations and evaluation coverage. Test the
  declared equality/tolerance with independent implementations where feasible.

## Primary references

- [Feast point-in-time joins](https://github.com/feast-dev/feast/blob/master/docs/getting-started/concepts/point-in-time-joins.md)
  distinguishes event-time retrieval from excluding later-created knowledge.
- [W3C PROV-O](https://www.w3.org/TR/prov-o/) supplies an interchange vocabulary
  for entities, activities and derivation. Importing provenance does not establish
  trustworthy execution, current permission or retained input availability.
