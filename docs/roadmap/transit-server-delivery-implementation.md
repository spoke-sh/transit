# Server delivery ownership and executable removal

[Milestone 3](03-live-storage-and-sql-cutover.md#p7--deliver-the-single-executable-local-profile)
· **Status: In progress** · 2026-11-13

Make `transit server` responsible for the delivery work required by its supported
application and query profiles, then remove `transit-delivery` from source builds,
deployment workflows and release publications. An application commits an output
once; the server advances that original output to delivery or an authoritative
terminal outcome, preserving its identity across interruption and recovery.
Operators start and supervise the product through the server command.

The existing server already owns a courier. Reuse that composition and close its
coverage gaps. Keep role selection, credentials, startup, supervision and shutdown
inside the server. No new public delivery command, deployment-managed courier,
renamed delivery executable or executable built solely to replace the deleted
daemon is part of this plan. Existing independent application binaries and focused
library/protocol fixtures retain their legitimate boundaries.

**Source basis:** `505d8ac3147dd9cdc0fa4a26c11bc8f334b2bae7`, after the
`transit-admin` removal. This is a proposed follow-up to the delivered single
executable profile; it does not reopen its historical evidence or complete
[Milestone 6](06-streams-queues-and-durable-runtime.md). Replacing native outboxes
with transactional Station/Queue semantics remains that milestone's separate
[consumer cutover](station-transaction-implementation.md#compatibility-and-later-cutover).

## Current behavior and removal inventory

| Owner | Current behavior | Required change |
| --- | --- | --- |
| [Delivery app](https://github.com/spoke-sh/transit/blob/505d8ac3147dd9cdc0fa4a26c11bc8f334b2bae7/apps/transit-delivery/main.zig) | Polls signed delivery status, submits an exact delivery request, retries uncertainty; exposes `--check` and `--once` | Delete after its consumers move |
| [Server](../../apps/transit-cli/server/Server.zig), [installation](../../apps/transit-cli/server/Installation.zig) | Provisions a dedicated courier identity and supervises the query-host courier using the same `transit` executable by default | Make this the delivery lifecycle exercised by product deployments and tests |
| [Query host](../../apps/transit-query-host/main.zig) | Implements bounded output discovery, exact pending requests and notification waits; supports selected destinations or a whole realm | Preserve the server-owned implementation and prove the required fault cases |
| [Client delivery helper](../../packages/zig/transit-client/src/delivery.zig) | One public-protocol step, also exercised by the [scheduler simulation](../../tests/verification/simulation/scheduler/scheduler_simulation.zig) | Keep the reusable protocol boundary; executable removal alone does not justify deleting this API or its tests |
| [Runtime build](../../build/runtime.zig), [check build](../../build/checks.zig), [test tasks](../../tasks/test.just) | Register/install the delivery app and pass its artifact to Station, callers and Vortex | Remove the target, context field, install edge and all consuming build/task arguments |
| [Launchers](../../launchers/README.md), [root Compose](../../docker-compose.yaml), [Station Compose](../../examples/station-ledger/docker-compose.yaml), [reference chart](../../deploy/reference/chart/README.md) | Assemble and supervise a separate delivery service, configuration, key and probe | Move product lifecycle ownership to the server; resolve reference-specific gaps before deleting its delivery deployment |
| [Release Nix build](../../nix/transit.nix), [binary inventory](../../tasks/package_release.py) | Explicitly compile delivery and include it in release archives | Remove its build and publication entries |
| [Image builder](../../tasks/release_images.py), [publisher](../../tasks/publish_release.py), [channel promotion](../../tasks/release_channel.py) | Derive image creation, required image sets and promotion from the release inventory/manifest | Verify the reduced inventory reaches both architectures, immutable images and channel updates |
| [Published chart](../../charts/transit/README.md) | Already runs only `transit server` from the `transit` image | Retain its lifecycle and prove publication works without the delivery artifact |

The server currently selects the built-in query source/requester destinations
when application hosting is disabled. Application-enabled installations select
all recorded destinations in their realm. Preserve that scope distinction and
current authorization. The product guarantee applies to supported declarations;
raw creation of an unrelated PID must not silently expand server responsibility.

## Contract and lifecycle requirements

Use the [CLI contract](../../contracts/TRANSIT_CLI_V1.md),
[application installation contract](../../contracts/APPLICATION_INSTALLATION_V1.md),
[native delivery contract](../../contracts/TRANSIT_V1.md),
[service authorization](../../contracts/SERVICE_V1.md) and
[streams reference](../handbook/reference/streams.md#commit-and-transport-are-separate)
as the owners. Update these explanations before adding any changed behavior.

1. **Activation and scope.** The server derives the required internal work from
   its supported configuration and installed applications. Newly installed roles,
   self-messages and inter-role outputs need no separate courier launch or manual
   destination update. Internal process boundaries remain an implementation choice.
2. **Authority and identity.** Retain a dedicated sequencer and scoped credentials.
   Current delivery/send permission, recorded destinations, route ordering and
   output identity remain authoritative. Associations and process ownership grant
   no additional access. Restart never regrants revoked rights.
3. **Uncertain results and recovery.** Retry frozen signed requests while they are
   pending. After process loss, reconcile authoritative sequence and unresolved
   outputs before new work. Do not replay the originating application operation,
   discard accepted work or invent a replacement destination.
4. **Readiness and failure.** Required delivery must pass current signed access
   checks and any existing initialization-dependent progress gates. An alive child
   or readable config is insufficient. Readiness does not mean an empty backlog.
   Define which affected admission/readiness gates withdraw when required delivery
   fails; preserve independent SQL/core status and safe inspection. Terminal denial
   of one output must remain distinct from loss of the service's delivery authority.
5. **Bounded work and shutdown.** Preserve bounded discovery, one original pending
   operation per sequencer, wait/backoff limits and finite recovery budgets. Cancel
   and join owned waits/processes. Accepted outputs survive graceful stop, forced
   stop and storage unavailability; none authorizes expiry or reset.

No wire/storage semantic change is expected from artifact removal itself. If a
necessary role/configuration change alters persisted compatibility, apply the
current-v1 cutover policy with explicit rejection and regenerated affected
contracts. Do not silently reinterpret old installations or weaken artifact hashes.

## Implementation sequence

### 1 Establish the server delivery proof

Extend the existing installed-server scenarios before removing any consumer.
Use [server applications](../../tests/interfaces/installation/server_applications.py),
[application faults](../../tests/interfaces/installation/server_application_faults.py),
[server lifecycle](../../tests/interfaces/installation/server.py) and
[local installation harness](../../tests/harness/local_installation.py).
Run with one copied `transit` executable, absent sibling runtime binaries and an
unavailable ambient PATH; retain explicit application artifacts as inputs.

Create an assertion-by-assertion mapping from the current callers, Station,
Vortex and launcher delivery schedules into the acceptance matrix below.
Reuse their fault proxies and independent outcome oracles. Tests launch the
server and interrupt its owned roles; they do not start a second courier or
advance outputs themselves to make a product scenario pass.

Check the existing server against the lifecycle requirements. Change
`Server.zig`, `Installation.zig` and the query-host owner only where the new
proof exposes a gap. Avoid a general scheduler rewrite or a new role-only server
mode introduced for tests. Preserve the current public command set.

**Exit:** installed query initialization and application delivery pass, including
pending-work recovery and current-permission failures, with only the product
executable supplying Transit runtime roles.

### 2 Remove delivery from release publications

After step 1, remove `transit-delivery` from the release build invocation and
`package_release.BINARIES`. Follow the derived archive, image, multi-architecture
assembly, publisher and nightly channel paths. Both
[nightly](../../.github/workflows/nightly.yml) and
[release](../../.github/workflows/release.yml) must use the reduced set; inspect
the generated inventories rather than relying on a workflow text search.

Extend [installer cleanup](../../install.sh) and its
[tests](../../tests/runner/test_release.py) to remove an obsolete managed
`bin/transit-delivery` link only after successful installation. Preserve unrelated
files/links and the original versioned bundle needed to recover old installations.
Do not rewrite existing releases, move tags or delete previously published images.

Add inventory assertions to the existing release/publication tests: no delivery
binary, archive member, manifest entry, OCI layout or publication target; the
remaining set must still be complete. Qualify the installed server and standalone
chart using the resulting artifacts on the supported release architectures.

**Exit:** new release/nightly candidates operate and package successfully without
delivery. Source consumers remain an explicitly unfinished removal obligation.

### 3 Migrate local and Compose consumers

Change launcher lifecycle ownership to one server per installation. Keep external
application workers and their supported installation/replacement operations.
Use existing installation APIs for the counter/Station example composition where
supported; identify missing registry/controller/bootstrap support before moving
that example. Do not replace the Station ledger with a simpler SQL demonstration.

Update `launchers/artifacts.py`, `common.py`, `local.py`, `compose.py`,
`station_example.py`, `updates.py`, settings and both examples' lifecycle manifests.
Remove the separate delivery role, probe, configuration generation and artifact
selection requirement. Server-internal credential ownership remains intact.
Group internal runtime updates by the server artifact; application replacement
continues to preserve its recorded identities and grants.

Migrate `test-callers`, `test-station` and the product lifecycle portion of
`test-vortex` to the server/harness composition from step 1. Keep provider-specific
Ursula tests over real disk-backed Ursula using existing native fixtures and
library operations. Label those as protocol/provider proofs; direct test-driven
delivery does not qualify automatic server delivery. Preserve fault schedules,
values, counts and outcome assertions; a changed backend is not equivalent evidence.

Old component installations must retain their original selection and recovery
files. Starting or updating them with the new layout must reject clearly unless
an explicit migration is separately implemented and qualified. Do not point a
new server installation at an old component data directory or reset it.

**Exit:** fresh local and Compose examples and their tests use the server's
delivery lifecycle, with no delivery artifact or independently managed courier.
Retained restart and application replacement pass without losing the old proof
obligations.

### 4 Resolve the reference deployment boundary

The reference chart runs external Kubernetes/Substrate workers and controllers,
with provider-specific recovery and isolation claims. The published standalone
chart has a narrower trusted placement profile. Substituting that chart does not
preserve reference qualification.

Produce a concrete composition review against `launchers/kubernetes.py`,
`station_reference.py`, the reference chart and their actual fault schedules:

| Required boundary | Resolution required before cutover |
| --- | --- |
| External worker bootstrap and native access | Show how the existing public protocol, listener/trust policy and retained identities connect externally placed workers to the server-owned authority |
| Substrate/controller placement | Preserve independent worker fencing, gVisor isolation, recorded upgrades and controller replacement without moving those workers into the trusted local host |
| Storage | Preserve local and Ursula-specific evidence separately; document any server composition capability missing for the selected backend |
| Delivery lifecycle | The server owns discovery, credentials, progress and recovery; remove the courier Deployment, Secret generation, image selection, readiness command and associated network policy |
| Retained installations | Refuse an incompatible layout while preserving its original binaries, volumes, selections and accepted work |

**Proposed direction:** reuse the coherent server for the authority and internal
services while external application placement remains with its existing provider
owner. Any missing public composition capability needs contract work and its own
qualified implementation before this step can pass. A private dispatch alias or
a replacement courier container does not resolve the dependency.

**Approved direction:** preserve the reference profile and extend server
composition (2026-11-13). The external-worker profile owns native authority,
maintenance, delivery and optional Board while the existing provider places
applications. Preserve Ursula native-history and local direct Table profiles
separately; this does not imply direct Table/SQL support over Ursula. Final
deletion still requires the actual reference schedules to pass.

### 5 Delete the executable and close the inventory

Once steps 3–4 pass, delete `apps/transit-delivery`, the runtime artifact/context
field, installation target and all check/task dependencies. Update launcher
selection validation to require the actual replacement set, preserving fail-closed
handling of incomplete or foreign selections. Update `checks.json`, `suite.json`
and invariant source mappings wherever ownership or executed tasks changed.

Update the current component directory, distribution and streams references,
node/server/query-host guides, build and launcher guides, example instructions and
reference chart documentation. Retarget links from historical evidence to the
current semantic owner or an immutable source revision without rewriting the
original experiment's commands or outcome.

Audit exact executable creation and invocation, generated manifests and images,
not just string absence. Existing delivery simulations and protocol helpers are
distinct test owners; neither may package or launch the retired daemon. Verify
`zig build transit -Dchecks=false` with test/example sources absent, following the
existing runtime source-boundary check.

**Exit:** no current build, launcher, test or publication requires
`transit-delivery`; product delivery is exercised through `transit server`.

## Acceptance matrix

| Scenario | Required observation |
| --- | --- |
| Fresh server, default and `--no-ui` | Existing initialization completes, SQL/query use works, required roles need no sibling runtime binaries |
| Application installed after startup | Self-messages and inter-role outputs deliver without adding destinations or starting services manually |
| Lost or malformed delivery acknowledgement | Retry preserves the original signed identity; destination admission and source provenance occur once |
| Kill delivery role with pending output; restart manager | Retained work reaches its original outcome; no source-operation replay, changed destination or duplicate admission |
| Revoke destination send or service delivery rights | Authoritative denial/blocked or terminal service failure follows the owning contract; restart does not restore rights |
| Ordered outputs and competing delivery | Per-route order and original output identity hold; any difference between standalone and query-host error handling is resolved in the owning semantics |
| Authority/storage interruption and pressure | Bounded retry and current recovery gates preserve accepted work; existing control progress and provider-specific evidence remain covered |
| Large retained output history and idle server | Discovery and resident work stay bounded; notifications are hints with authoritative rechecks; no backlog-sized memory or permanent busy loop |
| Graceful stop, manager SIGKILL and exhausted restart budget | Owned children/waits are joined or killed under the existing lifecycle; failure is visible and original history remains recoverable |
| Local, Compose and reference replacement | Stable application identities, current grants and the actual placement's recovery/isolation guarantees survive |
| New release and installer upgrade | No delivery publication; installed server works; only obsolete managed links are removed after success |

## Validation and review units

Use separate reviewable changes for: (1) server obligations and fault coverage,
(2) release/installer removal, (3) local/Compose and caller migrations,
(4) reference composition, and (5) final deletion/docs. Steps 3 and 4 depend on
step 1; step 5 depends on both. Each merged unit must retain executable checks for
its current artifact set. Early publication cleanup is not full completion.

For every implementation PR, run the repository's required baseline against its
final contents:

```sh
nix develop --command just check fast
nix develop .#docs --command just transit-docs::install
nix develop .#docs --command just transit-docs::check
```

Run affected real suites through the [task owners](../../tasks/README.md):
`test::server-single-executable`, `test::server`, `test::server-faults`,
`test::server-applications`, `test::server-application-faults`, `test::callers`,
`test::station`, `test::vortex`, `test::scheduler-simulation`, launcher lifecycle
checks and `test::deployments`. Preserve their invariant coverage when changing
task ownership. Server/build/startup changes also require
`just test console-latency-gate` in the pinned `ci-experience` shell and
`just test server-sql-types`. Run `just check contracts` and dependent callers
when contracts/generated bindings change.

Qualify release changes through the static release build, `test::release`,
`test::release-install`, `test::standalone-chart`, image construction and existing
publication/installer negative controls. Use matching source identities and fresh
output directories. Exercise x86_64 and aarch64 artifact inventories; standalone
chart qualification retains its currently supported amd64 scope. Validation does
not itself authorize publishing a release or moving a channel.

Before pushing implementation/test-infrastructure changes, run the affected
`just ci clean --lane NAME` checks against committed HEAD. The initial affected
lanes are `core`, `installation-ui` and `launchers`; shared client/contract changes
may add lanes under `suite.json`. Run affected Compose/reference external tasks
separately with their required Docker/Kubernetes/provider environment. Missing
infrastructure or a skipped proof leaves that gate incomplete.

Record executed results with source, artifact and topology identities in the
owning qualification account. Completion requires every removal-inventory row
and acceptance obligation to have an executed replacement or an explicit reviewed
scope decision. Do not claim the broader Station cutover or full release
qualification from this implementation slice.
