# Retire the standalone transit-node executable and package

[Milestone 3](03-live-storage-and-sql-cutover.md#p7--deliver-the-single-executable-local-profile)
· **Status: Implemented; qualification in progress** · 2026-11-14

Make `transit server` the supported way to start native authority, then remove
`transit-node` from production build targets, installed bundles and future
container publications. Applications keep the same data, authorization and
accepted-operation owners. Operators use the server's configuration, readiness,
recovery and shutdown lifecycle to inspect whether those owners are available.

**Source basis:** `560218772`. This follows the
[delivery ownership](transit-server-delivery-implementation.md) and
[Station service ownership](transit-server-station-implementation.md) removals.
It changes no milestone status or existing qualification claim.

## Decisions for review

1. **Keep the node implementation and its process boundary.** The server already
   embeds it. Remove its separate production executable without merging the
   authority into the supervisor or changing storage, SQL or Station ownership.
2. **Use the server for product integration.** SDK consumers, runnable examples,
   release proofs and deployment workflows start `transit server`. Focused
   authority tests may use an internal fixture when they need an independently
   controlled bootstrap, failure schedule or resource budget.
3. **Retire the public node override.** Remove `executables.node` and the
   `transit-node` executable-name alias. Retain private server role dispatch.
   Compile fault variants in the test graph instead of preserving a public
   override or adding a replacement `transit node` command for test injection.
4. **Use an explicit compatibility cutover.** Removing the public configuration
   field changes the current-v1 configuration contract. Update its definition and
   consumers together; do not silently reinterpret an existing installation.
   This scope covers fresh matching installations and their retained restart,
   not conversion of component-era data or cross-definition upgrades.
5. **Limit retirement to this artifact.** Keep other published components,
   application workers and Substrate controllers under their existing owners.
   Preserve historical releases, image digests and versioned installation bundles.

Decision 3 is the main scope choice beyond removing a release entry: it closes
the public configuration path that selects a standalone node. Decision 4 makes
its compatibility cost explicit. Existing installations must retain their
matching artifacts; this plan adds no automatic migration or reset.

## Current implementation and consumers

The [runtime build](../../build/runtime.zig) creates a standalone node executable
and imports its root module into `transit`. The
[private dispatcher](../../apps/transit-cli/RuntimeRole.zig) calls that same node
entry point. The [Nix release build](../../nix/transit.nix) already compiles only
`transit` for these roles and copies its bytes to `transit-node`. The
[release inventory](../../tasks/package_release.py) still requires the copy;
[image generation](../../tasks/release_images.py) and
[publication](../../tasks/publish_release.py) turn it into a separate image.

The [server](../../apps/transit-cli/docs/server.md) supports the installed local
database and an external-worker profile with local or Ursula native storage.
The external profile owns maintenance and delivery; it does not supply SQL or
direct Tables over Ursula. Retirement must preserve those supported boundaries.

| Consumer | Current dependency | Planned destination |
| --- | --- | --- |
| [Runtime graph](../../build/runtime.zig), [check graph](../../build/checks.zig) | `node_artifact` is both an executable and the source of shared module imports | Explicit node module; production composition through `transit`; test fixtures owned by checks |
| [Application test host](../../apps/transit-cli/TestHost.zig) | Imports the node's listener-free `LocalRuntime` | Same implementation, endpoint ownership and close/join rules |
| [Native service tests](../../tests/interfaces/native/growing_service.py), [authorization tasks](../../tasks/test.just) | Direct initialization, restricted caches, reply loss and authority restart | Server integration where applicable; component fixtures for intentional isolated schedules |
| [Native fixture publication](../../build/native_fixtures.zig), [artifact harness](../../tests/harness/native_artifacts.py) | An `authority` bundle containing `bin/transit-node` | Separate product-server and internal-fixture inputs with exact inventories and provenance |
| [SDK release consumers](../../tests/sdk/release.py), [SDK profile runner](../../tests/runner/external_profiles.py) | Take a node path and construct component configuration | Shared external-server setup, scoped caller credentials and retained restart |
| [Installation harness](../../tests/harness/local_installation.py), [SQL wire harness](../../tests/interfaces/sql_wire/gateway.py) | Node override paths and hard links named `transit-node` | Embedded server node; internal fixtures only for component SQL placements |
| [SQL fault build](../../build/checks.zig) | Replaces the SQL host import in a standalone node | Test-only `transit` variant with the same fault decoration in its embedded node module |
| [Example image builder](../../examples/exchange/compose.py), example launchers and Compose files | Build and invoke standalone node images from raw node JSON | Server configuration, retained installation volume and server readiness; explicit internal fixtures for component placement schedules |
| [Release installation proof](../../tests/interfaces/installation/release.py), [runtime boundary proof](../../tests/sdk/sdk_runtime.py) | Still enumerate or pass sibling node paths | Bundle/image inventory and real execution with `transit-node` absent |

## Implementation sequence

### 1 Freeze the migration inventory and contract

Enumerate every active `transit-node`, `node_artifact`, `sdk_authority` and
`executables.node` consumer, including dynamically constructed paths, environment
settings, generated configuration, SDK build inputs and container entry points.
Classify each as a product integration, a focused component proof, or historical
evidence. Record each active consumer's replacement and required assertion.

Use the [CLI/server contract](../../contracts/TRANSIT_CLI_V1.md),
[installation contract](../../contracts/APPLICATION_INSTALLATION_V1.md),
[service contract](../../contracts/SERVICE_V1.md) and
[versioning policy](../handbook/reference/versioning.md) as the owners. Specify
removal of the node override from YAML/JSON, environment settings, metadata and
examples. Superseded inputs must reject before provisioning or execution.

Retain the node's identity in installation records even though its artifact
selection becomes internal. The [identity code](../../apps/transit-cli/server/Config.zig)
currently binds role, executable bytes, definition and invocation mode. Removing
an override must not remove those checks or make old external selections appear
embedded. Define the new current-v1 identity before changing its consumers.

**Exit:** every consumer has an owner and destination; the configuration and
installation compatibility change is reviewable. Identify any server capability
missing from a product scenario before deleting its component path.

### 2 Separate reusable implementation from executable construction

Expose the node as an explicit build module with its existing direct dependencies
and Linux clock integration. Replace production references to the compile
artifact with module references. Keep `transit` private node dispatch and
listener-free application tests on that module. Source paths may remain under
`apps/transit-node`; directory renaming is unnecessary churn.

Build component authority fixtures only from the check graph, under test output
paths and names. Reuse the production module without alternate storage semantics.
Keep browser and SQL fault decorators in test-only builds. Factor composition so
an installed-server fault proof can substitute the embedded module at compile
time while running the real supervisor, provisioning and readiness lifecycle.

Preserve the runtime build boundary: `-Dchecks=false` and filtered Nix sources
must build the shipped runtime without test or SDK source trees. Update immutable
fixture manifests, hashes and imports together. Missing fixtures must fail
preparation rather than select an unrelated binary or skip a proof.

**Exit:** shared node behavior no longer depends on constructing a production
`transit-node` executable, and test fault hooks remain outside shipped code.

### 3 Migrate integrations and preserve isolated failure schedules

Extend the existing installation harness instead of introducing another server
manager. Use the local profile for installed SQL/Board/application cases and the
external-worker profile for native clients and provider-placed workers. Preserve
real disk-backed Ursula tests alongside local disk tests. Provision caller grants
through public operations and retain exact requests when their outcome is unknown.

Migrate SDK consumer runners, release/portable artifact handoffs, examples,
container builders and remaining launcher assumptions. Product proofs run the
shipped `transit` with no sibling node file or usable runtime PATH. Update process
identification, log collection, restart and joined cleanup for server-owned
children. Keep credentials out of logs and artifacts.

For each focused proof, preserve its original control conditions. Automatic
delivery or maintenance must not drain a deliberately stalled outbox, change a
retained storage cut, or hide an isolated node failure behind restart. Use the
shared internal fixture for those schedules and record its limited scope. Do not
add public fault, pause-delivery or manual-bootstrap switches for test setup.
Keep product coverage for the corresponding behavior under the server.

Remove hard-link/copy tricks that resurrect the `transit-node` basename.
Component tests use explicit fixture inputs; product tests use public server
configuration. Preserve workload counts, cache-pressure conditions, deadlines,
negative controls and outcome assertions through the migration.

**Exit:** product integrations run through the server; every retained component
fixture has an explicit isolation reason and unchanged safety assertions.

### 4 Cut over configuration and retire distribution

Apply the current-v1 change across typed configuration, settings metadata,
generated schemas, shared definition resources, signing fixtures and affected
bindings. Remove `executables.node` and node basename dispatch with their
consumers. Keep missing/foreign-definition and changed-artifact rejection tests.
The existing same-definition external runtime replacement mechanism must continue
to reject cross-definition replacement; do not widen it into implicit migration.

Delete the production executable/install target and its Nix copy. Remove the
node from release archives, manifests, image construction/publication expectations
and promotion inventories. Review installer and Homebrew enumeration wherever
derived from those manifests. Retire only the installer's own managed node link
after successful installation, following the existing retired-entry policy.
Preserve unrelated files, custom links and old versioned bundles.

Update the node README to describe the internal implementation and link runnable
usage to the server guide. Update configuration, distribution, component, build,
Nix, launcher and example documentation. Preserve dated evidence and original
artifact identities; update links only where source ownership actually moves.

**Exit:** production builds and future publications have no node artifact;
all active consumers use replacement paths. A reference audit permits internal
source names, explicit retirement/rejection checks and historical records.

## Acceptance criteria

| Scenario | Required observation |
| --- | --- |
| Installed local server | One copied `transit` supports console, Board, enabled SQL listeners, application hosting and retained restart with no sibling node executable |
| External native server | Local and disk-backed Ursula profiles preserve signed access, maintenance, delivery, readiness withdrawal and original outcomes after server/child loss |
| Authority and failure controls | Lost replies recover the original accepted identity; revocation remains effective after restart; stale owners and incompatible artifacts reject |
| Component schedules | Cache pressure, independent bootstrap, paused progress and injected SQL/browser failures retain original assertions through internal fixtures |
| Application test command | Listener-free `LocalRuntime` ownership, bounded execution and deterministic cleanup remain intact |
| Removed override and alias | Old configuration and incompatible installation records fail visibly; no fallback selection, record rewriting or data initialization |
| Build and fixture boundaries | Runtime builds without test/SDK sources; fixture inputs are verified; missing artifacts fail; no fault hooks ship |
| Distribution | x86_64 and aarch64 archives and OCI manifests omit `transit-node`; installer and SDK release tests work against the reduced bundle |
| Published image | The `transit` image starts the server, accepts and reads real data, and recovers retained data after replacement/restart |
| Cleanup | Graceful stop, forced stop and failed startup join owned children; installation data and unresolved work remain recoverable |

## Validation and delivery gates

Keep module extraction and consumer migration independently reviewable, then
land coordinated contract/distribution removal once replacements pass. Every
intermediate PR must have a coherent inventory and executable tests. Do not ship
an incomplete cutover with legacy fallback paths.

For every PR, including a plan-only PR if opened, run the final-content baseline:

```sh
nix develop --command just check fast
nix develop .#docs --command just transit-docs::install
nix develop .#docs --command just transit-docs::check
```

Implementation additionally requires these owners and affected scenarios. Use the
[task guide](../../tasks/README.md) and [suite inventory](../../tests/runner/suite.json)
for exact selection and required arguments:

| Area | Required checks |
| --- | --- |
| Contract/configuration cutover | `just check contracts`, generated definition/signing fixtures, configuration diagnostics, affected package and caller checks |
| Shared authority | Native service, growing/local service, authorization, concurrency, direct Table, maintenance and recovery suites whose fixture or build input changed |
| Installed runtime | `test::server-single-executable`, `test::server`, `test::server-faults`, `test::server-direct-faults`, `test::server-applications`, `test::server-application-faults`, `test::server-sql-lifetimes`, `test::application-test`, `test::application-test-host` |
| Startup and SQL | `nix develop .#ci-experience --command just test console-latency-gate` and `nix develop .#ci-experience --command just test server-sql-types`; affected SQL wire/component placements |
| SDKs and examples | Every consumer of the changed authority/server fixture, installed release SDK tests, real affected example binaries and Compose profiles |
| Deployment | Local launcher, both chart renderings, affected Compose and Kubernetes/Substrate lifecycle proofs; rendering alone cannot qualify provider recovery |
| Distribution | Static release build, `test::release`, `test::release-install`, `test::standalone-chart`, image construction, publication/installer negative controls and runtime build-boundary checks |

Before pushing implementation or test-infrastructure changes, run affected
`just ci clean --lane NAME` checks against committed HEAD. The migration reaches
`core`, `storage-query`, `installation-ui`, `launchers`, SDK and interface lanes;
select every affected lane from the final consumer inventory. Include `browser`
when its harness or fault fixtures change. External Compose/reference checks
remain separate gates. Exercise both release architectures; unavailable
architecture or infrastructure checks remain incomplete.

The predecessor Station change records an unresolved clean installation/UI
`ClockUnavailable` failure. Preserve that evidence, investigate it when reproduced,
and obtain a complete required-gate pass; separate constituent passes or an
inherited failure do not waive the gate. Keep latency measurements free of
concurrent heavy builds and tests.

Record executed source, artifact, storage and topology identities in the owning
[qualification history](../history/qualification/README.md), with original failures
and limits. Update current public behavior with implementation. Completion
requires the acceptance matrix and retirement inventory to pass; this plan does
not authorize registry deletion, publication or channel promotion.


### Implementation boundary refinement

The ordinary counter, byte-log, exchange and Document examples use the server.
Serving, Flight, SQL-wire, state-query and work-item physical placement scripts
remain component qualifications: their restricted caches, independently attached
Tables and stalled-delivery schedules are explicit inputs to their proofs.
They build `native-authority-fixture` through the check graph instead of creating
a production node artifact. Their standalone images remain local test outputs.
Installed server/browser/application and launcher checks separately qualify the
product composition. SDK product consumers use the server; the isolated ABI and
cross-language interop schedules retain their original authority-cache budgets.
