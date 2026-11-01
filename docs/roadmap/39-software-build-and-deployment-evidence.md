# 39. Software, build and deployment evidence

[Roadmap](README.md) · **Status:** Planned

Let applications query the evidence connecting source revisions, dependencies,
builds, tests, artifacts, deployments and runtime observations. Users can ask
which deployed artifacts contain a dependency, which exact candidate a test
supports, and what changed between a successful deployment and an incident.

This milestone delivers generic versioned evidence operations and a reference
application. It does not make Transit a source forge, package manager, build
sandbox, deployment controller or vulnerability-policy authority.

## Prerequisites and ownership

Build on [Document profiles](16-document-profiles-and-gateway-exchange-lifecycle.md),
[structural search](14-vectorized-strings-and-search.md),
[graph/foreign projections](18-multi-model-and-foreign-relations.md),
[managed computations](12-sql-and-dataflows.md),
[branches](20-branches-merges-and-restore.md),
[policy](27-control-and-policy-plane.md),
[published investigations](28-published-resources-and-investigations.md),
[reviewed publication](29-reviewed-data-collaboration.md),
[deductive rules and Datalog fixpoints](41-deductive-rules-datalog-and-equivalence-graphs.md) and
[hardware design and EDA verification](42-hardware-design-rtl-and-eda-verification.md). Reuse the
[data lifecycle](../../contracts/DATA_LIFECYCLE_V1.md),
[publication](../../contracts/PUBLISHED_RESOURCE_V1.md),
[investigation](../../contracts/INVESTIGATION_V1.md) and
[SQL result](../../contracts/SQL_RESULTS_V1.md) contracts. Consult public
[applications](../handbook/reference/applications.md),
[connectors](../handbook/reference/connectors.md) and
[verification limits](../handbook/reference/verification.md).

M35's derivation/coverage conventions are reusable where applicable; ordinary
software evidence does not require scientific numerical kernels. Authority stays
with the existing owners. Imported attestations and claimed relationships are
evidence to validate, not self-authorizing declarations of trustworthy execution.

## Delivery sequence

1. **Define identities and evidence relationships.** Separate repository/revision,
   path/blob, symbol occurrence, dependency resolution, build invocation, toolchain,
   test run, artifact digest, deployment revision and runtime observation.
   Define relations such as uses, built-from, produced, tested, deployed-as and
   observed-at with issuer, capture time, validity and coverage. A symbol's name
   or path is not stable identity across revisions; record exact revision-local
   identity and explicit cross-revision mappings with ambiguity where necessary.
2. **Capture immutable manifests and attestations.** Start with Git revision/tree
   metadata, lockfiles, one SBOM profile, build provenance and one test-report
   format. Preserve source bytes and parser/profile identity through Document and
   graph projections. Bind signatures to a declared issuer/trust policy and
   verification outcome. Distinguish an imported artifact, observed build output,
   verified attestation and independently reproduced build. Secret material and
   unrestricted build logs are excluded from ordinary evidence projections.
3. **Query dependency and change evidence.** Traverse exact dependency graphs,
   match artifacts to deployed instances and compare candidate/baseline evidence
   under bounded graph/search operations. Keep declared, resolved, linked and
   runtime-observed dependencies distinct. Absence is meaningful only with a
   complete captured inventory and traversal: missing evidence must not become
   "unaffected", "tested" or "safe". Vulnerability interpretation remains an
   application policy with its own versioned advisory basis.
4. **Bind checks to reviewed candidates.** Record exact source/dependency/configuration
   basis, test selection and outcome; retain failures, skips and incomplete runs.
   A passing test for another revision cannot satisfy the candidate's check.
   Candidate changes invalidate affected evidence according to declared dependency
   rules; unknown impact requires explicit broader checking, not guessed reuse.
   Separate data publication approval, artifact promotion and deployment authority.
5. **Reconcile external progress without rewriting history.** Capture build,
   promotion, rollout and runtime observations through authorized recorded
   operations. Preserve original identities across retries and lost replies.
   Desired deployment revision, observed placement, healthy process and successful
   application result remain distinct. Delayed or contradictory observations
   append evidence; they do not overwrite the original claimed outcome.
6. **Deliver an inspectable application and interchange.** Expose bounded evidence
   queries, lineage and exact-candidate comparisons through existing SDK/result
   and publication surfaces. Dogfood Transit qualification manifests tied to
   source, toolchain, configuration, selected checks and raw artifact digests.
   Keep domain policy and application value decoding in the application; Board's
   operator inspection continues to use its public read boundary.

## Platform handoff

[Spoke Platform](https://github.com/spoke-sh/platform) is a candidate consumer.
Its reviewed source at `d88616d83e1b43dbdc5b0c85cbf47c53e417c4c0` assigns
[artifact registries and isolated builds](https://github.com/spoke-sh/platform/blob/d88616d83e1b43dbdc5b0c85cbf47c53e417c4c0/docs/roadmap/10-artifact-registries-and-isolated-builds.md)
and [published computation](https://github.com/spoke-sh/platform/blob/d88616d83e1b43dbdc5b0c85cbf47c53e417c4c0/docs/roadmap/12-dataset-access-and-published-computation.md)
to Platform. These are planned integration opportunities, not delivered services.

Define a shared evidence exchange before wiring the repositories together:
Platform publishes its authoritative operation IDs, artifact digests, deployment
revisions and scoped observations; Transit retains and queries those bindings.
Platform keeps tenant/product policy, builder isolation, promotion and service
reconciliation. Transit supplies reusable data/compute/permission semantics.
No Transit package depends on Platform source. Qualify a standalone synthetic
producer first; claim Platform integration only after an installed cross-repository
journey at pinned revisions. This plan does not change Platform's roadmap/status.

## Completion evidence

- Capture source, lockfile, build, tests, artifact, deployment and observations;
  answer dependency-impact and exact-test-coverage questions against an independent
  graph oracle. Compare two candidates on the same retained advisory/evidence basis.
- Exercise path/symbol rename, duplicate names, mutable tags, differing lockfiles,
  parallel builds, missing graph edges, cycle/budget exhaustion and incomplete
  inventories. A partial negative query cannot establish absence.
- Challenge forged/mismatched/stale attestations, untrusted issuers, unrelated test
  artifacts and changed candidates after approval. Preserve explicit trust limits;
  signatures alone do not prove honest computation or deployment success.
- Inject lost capture/promotion replies, late rollout observations, source history
  loss, cancellation and restart. Prove replay dispatches no build/deploy effect.
- Revoke access while graph results or logs are buffered; prevent cross-project
  discovery and unauthorized artifact/cache disclosure. Measure bounded traversal,
  capture-to-evidence lag and exact versus unresolved coverage.

## Primary references

- [SLSA build provenance](https://slsa.dev/spec/v1.2/build-provenance) for source,
  build execution and artifact attribution.
- [W3C PROV-O](https://www.w3.org/TR/prov-o/) for derivation interchange. Select
  and qualify actual SBOM/test schemas before advertising adapter support.
