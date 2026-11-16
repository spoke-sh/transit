# Transit storage defaults and Ursula removal

[Milestone 25](25-storage-providers-and-concurrency.md) · **Status: In Progress** · Implementation authorized 2026-11-15

Make Transit storage the default across installed, Local, Compose and
Kubernetes/Substrate deployments, remove Ursula from the current implementation,
and deliver configurable remote immutable storage. Applications retain their
definitions, accepted operations, data, progress and outcomes through the same
public owners. Operators can inspect storage placement, pending uploads and
recovery blockers through Transit.

This plan has two independently deliverable outcomes: Ursula removal with the
existing local durability profile, then a qualified S3 storage profile. The full
request is complete only when both are delivered. Implementation proceeds in logical commits in an isolated worktree. Completion
requires the full validation gates below.

**Source basis:** `424cc32e88a1b7d85a160195887fd7a7b0199756`. Recheck consumers and
qualification gaps against the implementation base before editing runtime code.

## Accepted implementation decisions

1. **One Transit storage implementation.** Evolve `transit-backend-local` and
   `transit-storage`; preserve `TransitLog` and `TransitObjectStore` as separate
   interfaces. Remove Ursula completely after its consumers and proofs move.
   Keep the existing package name during this work to avoid unrelated churn.
2. **Local durability remains the default.** Use the existing exclusive WAL and
   object owner on a persistent directory or PVC. Preserve external application
   workers, runtime controllers and Kubernetes/Substrate isolation.
3. **S3 is an optional immutable storage tier.** Start with one exclusive Transit
   owner, durable local staging and asynchronous upload. Require the local WAL,
   installation identity and recovery metadata after restart. A bucket alone
   cannot recover every acknowledged operation.
4. **Initial provider qualification is bounded.** Qualify the pinned MinIO
   server used by integration tests. The user selected MinIO on 2026-11-15
   because no AWS test account/bucket is available. AWS S3 and other compatible
   services remain unqualified until their own real-provider evidence exists.
   Shared POSIX/NFS, distributed writers, replication, failover, bucket-only restore,
   additional cloud providers and KMS/BYOK remain with their existing milestones.
5. **No automatic Ursula data conversion.** Initially support fresh native
   deployments and explicitly compatible native restarts. Reject an existing
   Ursula installation without modifying it; retain its matching binaries,
   credentials, configuration and volumes. If existing Ursula data must move,
   an explicit offline migration becomes a prerequisite to retiring that
   installation, with a separate reviewed format and recovery proof.

Implementation review reproduced a timed-out PUT arriving after DELETE against
real MinIO. Generation-specific keys protect replacements but do not fence that
late creation. The current retirement protocol therefore replaces each retired
generation's payload with a permanent empty 512-byte control envelope using
provider conditions. These envelopes must not expire; their provider storage
cost is separate from local staging/cache budgets. The current-v1 definition
changes with this format, and qualification includes the delayed PUT and a lost
retirement response before restart.

This proposes replacing Milestone 25's `UrsulaWal` delivery obligation and pulling
the single-owner S3 slice forward independently of distributed-writer work.
On acceptance, reconcile the milestone/index and relevant #109/#121/#124 scope
records through the normal authorized tracker workflow. Preserve the remaining
provider, encryption and concurrency obligations. Earlier delivered milestones
and historical evidence keep their recorded status.

## Baseline and implementation owners

| Owner | Current behavior | Required work |
| --- | --- | --- |
| [Local backend](../../packages/zig/transit-backend-local/README.md), [Backend](../../packages/zig/transit-backend-local/src/Backend.zig) | Default server owner; concrete filesystem WAL/objects, inventories, quotas and reclamation | Preserve local behavior; introduce remote placement behind its storage boundary |
| [Ursula backend](https://github.com/spoke-sh/transit/blob/424cc32e88a1b7d85a160195887fd7a7b0199756/packages/zig/transit-backend-ursula/README.md), [native node](https://github.com/spoke-sh/transit/blob/424cc32e88a1b7d85a160195887fd7a7b0199756/apps/transit-node/Native.zig) | Journal, packed pages/blocks, payloads and maintenance over Ursula | Move semantic proofs, then delete this composition and package |
| [UrsulaWal](https://github.com/spoke-sh/transit/blob/424cc32e88a1b7d85a160195887fd7a7b0199756/packages/zig/transit-backend-ursula/src/UrsulaWal.zig) | Separate component, unused by the active Ursula node path | Remove with the provider; do not turn it into a replacement dependency |
| [S3ObjectStore](../../packages/zig/transit-storage/src/S3ObjectStore.zig) | Signs requests but executes against an in-memory store | Implement actual network/provider behavior and independent conformance checks |
| [NvmeCache](../../packages/zig/transit-storage/src/NvmeCache.zig) | Heap-backed chunk cache | Implement bounded disk caching with integrity rooted in accepted descriptors |
| [Server configuration](../../apps/transit-cli/server/Config.zig), [external composition](../../apps/transit-cli/server/External.zig) | Optional Ursula branch; direct Table hosting requires local storage | Remove the branch; add validated native object-tier configuration |
| [Launchers](../../launchers/README.md), [reference chart](../../deploy/reference/chart/README.md) | Counter defaults to Ursula; Station already uses native storage; chart enables Ursula | Migrate the counter and other consumers without simplifying their application scenarios |
| [Storage observations](../../packages/zig/transit-protocol/src/Storage.zig), [Board types](../../packages/ts/transit-board-client/src/types.ts) | Backend enumeration includes `ursula` | Generate a consistent native/log/object placement and progress observation |
| [Build graph](../../build/runtime.zig), [Nix](../../flake.nix), [test inventory](../../tests/runner/suite.json) | Include Ursula client, binaries, pins, patch and provider-dependent fixtures | Remove dependencies after mapping their remaining consumers and assertions |

## Storage profile and contract gates

Update the [storage contract](../../contracts/TRANSIT_STORAGE_V1.md),
[storage reference](../handbook/reference/storage.md),
[configuration reference](../handbook/reference/configuration.md) and relevant
service types before exposing the remote profile. Preserve native authorization,
transaction decisions, original operation identities and resource lifetimes.
Storage placement must remain independent of Station and query execution.

| Data or responsibility | Local profile | Proposed S3 profile |
| --- | --- | --- |
| Accepted native/direct changes and transaction decisions | Durable local WAL and current recovery owners | Same local authority and acknowledgement boundary |
| Immutable pages, blocks, segments, payloads and retained history objects | Durable local objects | Durable local staging, then verified remote placement; safe local eviction only after recorded coverage |
| Installation identity, allocation inventories, upload/GC progress and mutable coordination | Retained local metadata | Retained local metadata; uploaded objects do not replace these records |
| Read acceleration | Existing bounded caches | Bounded verified memory/disk cache; deleting this cache must preserve recoverability |
| Physical deletion | Existing complete retained graphs and epoch/read-lifetime fences | Same authority, extended to pending uploads, remote objects and uncertain deletes |

Freeze these details in the first contract review:

- **Publication ordering:** stage and sync required bytes, then accept the
  owning WAL operation. Persist upload work so every crash boundary can resume.
  Keep staging success, logical acceptance, remote coverage and eviction distinct.
  An unuploaded accepted object is durable staging, never disposable cache.
- **Remote operations:** define immutable same-key/same-content retry, conflict,
  conditional publication, missing objects and uncertain outcomes. Resolve the
  current digest-shaped `if_match` API against provider concurrency tokens;
  do not equate content integrity with a provider token. Raw S3 adapter operations
  report actual provider outcomes; tiering must not manufacture remote success.
- **Ownership:** conditionally bind the remote namespace to the installation and
  layout on first use; reject a different installation and reconcile an uncertain
  claim before publishing objects. Recovery still requires the original exclusive
  local owner. A namespace marker is not a distributed writer fence: cloned
  authority directories, concurrent hosts and automatic takeover are unsupported
  in this profile. Do not expose deployment settings that imply those guarantees.
- **Bounds and outages:** define staging, cache, upload concurrency, request
  deadlines and maintenance reserves. During S3 failure, locally satisfiable work
  may continue within the durable staging budget; uncached reads fail explicitly.
  Refuse new ordinary work before exhausting recovery/control reserves. Pressure
  never permits data expiry, dropping uploads or eviction of the only durable copy.
- **Coverage and collection:** use bounded durable traversal of all supported
  native and direct roots, including grants, receipts, transactions, pins,
  captured results, Stream/Queue progress and payloads. Inventory uploaded bytes
  before they can become untracked remote garbage. Resolve delayed PUT/DELETE
  races under explicit storage epochs and recorded deletion intents.
- **Integrity:** retain trustworthy object/chunk digests with accepted recovery
  evidence. Hashing a just-downloaded response alone cannot prove it is the
  originally accepted content. Missing/corrupt bytes never become empty results.
- **Configuration:** use one server-owned schema for object tier, endpoint,
  region, bucket/prefix, credential references and budgets. Support temporary
  session credentials and rotation in the selected credential profile. Persist
  identity, not secret values; endpoint identity changes require an explicit
  migration, and ordinary reload cannot repoint retained data.
- **Observation:** distinguish accepted positions, upload coverage/backlog,
  staging/cache usage, provider errors, collection and recovery blockers.
  Redact credentials and sensitive provider details through the existing signed
  inspection owner. A multi-partition coverage vector is not an atomic snapshot.

Keep existing local staging barriers. This slice targets zero foreground remote
PUTs; it does not establish the broader roadmap goal of eliminating every local
immutable write from foreground execution. Batch remote transfer and coalesce
small immutable objects only under a reviewed locator/packing contract. Measure
request counts and write amplification; do not turn native page writes into one
synchronous S3 request each or claim all Milestone 25 cost invariants are complete.

## Implementation sequence

Each numbered unit is independently reviewable; split large units by owner while
preserving their exit gate. Do not delete a backend before its callers move.

### 1 Freeze scope, contracts and proof mapping

Inventory live configuration, imported modules, generated contracts, tests,
launchers, images and release dependencies. Map each Ursula-backed assertion to
its native replacement or to an explicitly retired provider-only property.
Separate semantic guarantees from Ursula-specific HTTP/stream behavior.

Record the initial S3 durability/ownership profile above, define its persistent
placement and upload states, and enumerate compatibility changes. Preserve
missing/foreign-definition rejection. Apply the current-v1 definition cutover and
regenerate schemas, bindings and signing fixtures in the implementation units
that introduce incompatible semantics; no legacy decoder or implicit adoption.

**Exit:** reviewable contracts, migration disposition and assertion map cover
every storage owner. The exact native restart compatibility is stated, rather
than assuming a package replacement preserves stored locators.

### 2 Move deployments to native storage

Use the existing Station composition to migrate the counter and remaining
examples. Update `launchers/common.py`, Local/Compose/reference lifecycle code,
root and example manifests, shared server configuration and reference chart.
Preserve worker isolation, runtime-controller identities, service-owned delivery
and maintenance, grants and original workload assertions. Retain the server PVC
as the authority's storage; do not mount an Ursula directory as native data.

Change default installations and chart values together. Reject obsolete Ursula
configuration before creating directories, provisioning new authority or changing
the stored installation identity. Never delete an old PVC on chart upgrade.

**Exit:** fresh counter and Station installations run without Ursula on Local,
Compose and Kubernetes/Substrate. Retained restart, worker replacement,
revocation, service readiness and isolation proofs pass on the actual placements.

### 3 Migrate tests and remove Ursula

Move shared service, runtime, SDK, connector and query fixtures onto the native
owner. Preserve independent oracles and fault positions for lost replies,
checkpoint/trim, stale ownership, revocation, missing bytes, payload deletion,
bounded residency and collection. Raw provider tests retire only after their
portable obligations are covered. Local process-death and I/O-error evidence
remain distinct from host power loss.

Delete `transit-backend-ursula`, `Native.zig`'s Ursula composition, its selector
and server branch, `external.ursula`, provider probes/ports/resources, obsolete
`kubectl-transit` component handling, and the harness after its last consumer.
Remove package/build registrations, `ursula-zig`, flake inputs/locks, toolchain
requirements, image pins and the cold-flush patch. Regenerate inspection types
and validators; update task/lane inventories and negative configuration checks.

Audit built artifacts and deployment manifests as well as text references.
Historical qualification records and published releases remain attributable;
replace links to deleted source with immutable source links where necessary.
Current public guides must describe the replacement profile when it lands.

**Exit:** current product builds, normal development shells, CI, examples and
deployments require no Ursula service, client or tooling. Local runtime proofs
pass with the provider absent. This completes removal, not S3 delivery.

### 4 Implement the real S3 adapter

Implement Zig HTTP/TLS transport and bounded request/response ownership around
the reviewed signing/credential profile. Cover immutable PUT, conditional
publication, HEAD, byte-range GET and authorized DELETE. Enforce exact response
status, range, length and integrity semantics; handle cancellation, lost replies,
credential rotation, throttling and bounded retries without changing content or
inventing successful publication. Never forward credentials through an unchecked
redirect. Move the existing memory loopback into explicit test fixtures.

Run conformance against the pinned MinIO server and an isolated test namespace,
including independent competing clients for provider conditional operations.
Those tests establish provider primitives, not concurrent Transit writers.

**Exit:** real network operations satisfy the selected provider contract with
fault evidence and no memory-store substitution. Provider credentials and raw
responses are absent from logs and committed artifacts.

### 5 Integrate durable tiering, cache and collection

Refactor the concrete filesystem boundary in `Backend`, allocation accounting,
page/payload owners and collectors into the reviewed native placement owner.
Retain existing local behavior. Keep metadata and required staging on persistent
storage; add a durable paged upload queue, exact retry, remote coverage records,
verified cache reads and safe local eviction. Extend the current server-owned
maintenance executor with bounded upload and remote collection work.

Prove the order: local durability, original acceptance, remote publication,
coverage recording, eviction. Exercise process death and uncertainty between
every transition. Maintain the complete retained graph across Tables, direct KV,
Streams, Queues, supported Documents, native resources and captured computation.
Exercise Document owners at their actually implemented boundary; adding new SQL
or Document semantics is outside this storage work.

**Exit:** data larger than the cache reads correctly after eviction and cache
deletion; restart from retained authority resolves uploads and deletes without
replaying application operations. Resident memory and per-turn work remain bounded
independently of retained data and durable backlog. S3 outage and quota exhaustion
preserve accepted work and control/recovery capacity.

### 6 Expose configuration and inspection in installed deployments

Wire the object tier into the existing server schema, settings validation,
installation identity, node composition and shutdown. Publish configuration
examples only after the exact fields execute. Mount credential references in
Compose and Kubernetes; keep WAL/staging volumes distinct from disposable cache
and preserve private provider access. No upload daemon, alternate SQL storage
authority or Station dependency is introduced.

Extend existing public storage inspection and Board's typed projections with
provider selection, per-owner coverage, backlog, budgets and blockers. Readiness
must verify required authority/recovery conditions and remote ownership before
dependent work; provider degradation must follow the selected outage policy,
not pretend that every cached read or every write needs the same availability.

**Exit:** an operator can configure S3, write/query supported data, observe pending
and completed transfer, restart and read evicted content through the installed
server on Local, Compose and reference deployments.

### 7 Qualify and publish the supported profile

Execute the matrix below against final artifacts and committed source. Record
commands, failures, provider versions, topology, budgets and source identities
in qualification history. Promote current behavior and limits to storage,
configuration, deployment, component and operator documentation. Remove stale
Ursula recommendations from current guidance and agent instructions while
preserving historical records. Mark only the delivered slices complete.

**Exit:** both local and S3 profiles have executable installation/recovery
evidence, complete removal inventory and public operating instructions. Any
missing MinIO or reference proof leaves the corresponding gate open.

Units 1–3 form the first delivery checkpoint. Unit 4 can follow the contract
freeze independently of deployment migration; unit 5 depends on units 1 and 4,
unit 6 joins native deployment and tiering, and unit 7 closes the complete scope.

## Acceptance matrix

| Scenario | Required observation |
| --- | --- |
| Default startup and package installation | Local SQL and applications run with only Transit runtime artifacts; no Ursula binary, service, image or ambient tool requirement |
| Native operations and mixed transactions | Original values, authoritative counts, decisions, progress and outcomes survive restart under unchanged current authorization |
| Existing Ursula or incompatible native installation | Explicit refusal before mutation; original files, volumes, credentials and selected artifacts preserved |
| Lost acceptance, upload or deletion response | Original identity/content is reconciled; no second logical operation or fabricated completion |
| S3 unavailable, slow or unauthorized | Bounded waits; visible degradation; locally satisfiable work respects staging/control budgets; required remote reads fail explicitly |
| Cache eviction, cache loss and corrupt remote ranges | Valid bytes recover through accepted descriptors; corrupt/missing bytes refuse; no partial result reported complete |
| Cold restart with pending uploads and collection | Durable progress resumes; every accepted reference resolves; in-flight/delayed publication cannot resurrect deleted data |
| Retention, pins and historical reads | All retained roots remain readable; logical expiry and physical collection remain separate; pressure does not opt into retention |
| Provider conflict and namespace collision | Independent competing operations respect conditions; a different installation cannot adopt the namespace; unsupported concurrent-owner deployment settings reject |
| Revocation while reading or maintaining | Buffered/cache/remote disclosure rechecks current rights; restart and provider success do not restore grants |
| Growth and performance | Dataset and upload backlog exceed resident budgets; bounded memory/cache/staging; zero foreground remote PUTs; reported remote requests and write amplification |
| Real deployment replacement | Persistent authority survives service/pod replacement; scoped workers and runtime controllers preserve isolation and identities |

## Validation gates

For every PR, including a plan-only PR if opened, run the baseline against its
final contents:

```sh
nix develop --command just check fast
nix develop .#docs --command just transit-docs::install
nix develop .#docs --command just transit-docs::check
```

Select affected executable tasks from [tasks](../../tasks/README.md) and the
[suite inventory](../../tests/runner/suite.json). Start with these ownership groups:

- Storage: package checks, `test::local-storage-faults`,
  `test::storage-io-faults`, `test::local-native-collection`,
  `test::local-data-collection`, `test::local-payload-service`,
  `test::node-concurrency`, `test::node-recovery` and the migrated storage/service
  assertions. Add real S3 conformance/tiering tasks and register their required
  external infrastructure before claiming those gates pass.
- Server: `test::server`, `test::server-faults`, `test::server-direct-faults`,
  `test::server-applications`, `test::server-application-faults` and
  `test::server-single-executable`, plus affected caller/SDK/connector cases.
- Deployment and packaging: existing Local/Compose/reference counter and Station
  proofs, chart/isolation checks, standalone package builds and release/image
  inventory controls on both supported architectures. Registry publication or
  channel promotion is not a test prerequisite.
- Contracts and UI: `just check contracts`, dependent caller/binding checks,
  `just transit-board::check` and affected browser proofs when inspection changes.
- Server/build/startup: `just test console-latency-gate` in the pinned
  `ci-experience` shell and `just test server-sql-types`. Preserve and report
  inherited failures; comparison with a failing control does not waive a gate.

Before pushing implementation or test-infrastructure changes, run affected
`just ci clean --lane NAME` gates against committed HEAD. Initial ownership spans
`core`, `storage-query`, `installation-ui` and `launchers`; the assertion map and
generated-contract changes determine additional SDK, interface and browser lanes.
External provider/Compose/reference proofs remain separate executable gates.

Measure matched local controls and remote warm/cold-cache cases without weakening
durability, workloads or resource limits. Follow the container campaign guide if
using or changing the nightly scorecard; preserve promoted-image selection and
separate driver/runtime identities. Planning, installation, dry runs and skipped
provider tests are not qualification evidence.
