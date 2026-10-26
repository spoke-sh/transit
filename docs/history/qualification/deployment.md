# Installation and deployment: qualification history

[Archive index](README.md) · [Tests](../../../tests/README.md)

Local launchers, Compose, reference placement, installed applications and tooling.

These records preserve their original dates, sources, failures and limits. They
do not define current interfaces or qualify later changes. Commands and then-open
work describe their recorded source; use the [task reference](../../../tasks/README.md)
and [test index](../../../tests/README.md) for current navigation.

## Direct Table Compose live views — 2026-10-24

`nix develop .#serving --command just test::reactive-views-placement compose`
passes after restoring captured-request batch reads and bounding idle worker
polling. The real browser recovers an uncertain submission across navigation,
retrieves its original result after physical service replacement, verifies a
distinct finite refresh, and clears protected data when permission is revoked
between complete candidate verification and its visible reread. The existing
query and revocation deadlines remain unchanged.

The run takes 626.83 seconds overall. Observed counter propagation, physical
recovery and query-refresh times are 4.958, 11.768 and 142.683 seconds. These are
shared-host observations, not interactive latency guarantees. Earlier Compose
attempts failed at the second refresh. The fixture now retries only explicit
pre-dispatch native capacity refusals with unchanged signed bytes and treats
optional progress-observation failures as unavailable evidence. This pass does
not qualify the reference-provider schedule.

A follow-up Compose run also passes with bounded courier error backoff. Failed
reads repeat under current authority; an uncertain delivery retains its original
signed command. The browser schedule takes 590.00 seconds, with observed counter,
physical-recovery and query-refresh times of 3.905, 9.411 and 125.308 seconds.
These runs do not isolate a performance improvement under matched conditions.

## Retained native storage in the Helm chart — 2026-10-24

In the pinned Nix shell, `python3 -B tests/deployments.py` passes chart lint and
rendered deployment checks. A native local owner and its explicit initializer
mount the same retained PVC; an existing claim is reused without another claim
being created. Only the node receives the configured credential Secret. The
chart rejects an ephemeral local path, simultaneous Ursula configuration and an
external maintenance process for the exclusively owned directory. Existing
Ursula and private-network checks remain in the same passing schedule.

The Station reference run uses a newly owned Kind/Substrate cluster. Initial
attempts exposed a seven-character/eight-character Substrate version mismatch
and a bootstrap deadlock: Helm waited for an unused native PVC, while the
`WaitForFirstConsumer` storage class waited for the initializer. Build version,
DaemonSet lookup and worker node selector now share one explicit pinned value;
the initializer deploys with the claim. The real claim binds and initialization,
native provisioning and activation of all three workers complete. The 15
reference ownership/recovery unit checks and chart checks also pass.

The subsequent run fails the **60-second initial ledger completion deadline**.
Node evidence includes storage writes canceled at the two-second request budget
while the disk-backed unit suite runs concurrently. A later inspection observes
the expected total of 12, which does not turn the deadline failure into a pass.
The failed installation is stopped with data and logs retained. After the large
disk-backed unit suite completes, a fresh reference installation passes the
original unchanged deadlines, direct ledger/query workflow, forced pod loss,
three-worker upgrades, Board provenance and persistent stop/start. Its fixture
stops and resets its own installation. A node pod reports three restarts during
the final start; the schedule proves eventual ready state and retained results,
not a restart-free startup. No provider-isolation or power-loss claim is added.

## Installed Work items physical exhaustion — 2026-10-24

In the pinned Nix shell, `just test::server-application-capacity` passes in
**165.82 s** after explicitly provisioning the direct catalog authority and
initializing its first Table. The owned ext4 image reaches actual ENOSPC with an
accepted native input outstanding. After shutdown, space release and restart,
the saved request completes with the original receipt, PID and resource and
exactly one row. Bounded recovery retries check that the complete saved request
bytes remain unchanged. The container keeps PATH unavailable and uses an
explicit pinned OpenSSL executable for the proof's independent signatures.

This run uses the `f444c2a1` definition and the stop-on-error worker policy. It
precedes the SQL namespace contract cutover. The longer installed application
schedule passed replacement and abrupt restart, then failed at migration step
22 after authority timeouts exhausted the supervisor's restart budget. It is
not counted as passed. Management retries now verify their saved request bytes,
and replacement rejection compares against the immediately preceding active
generation while preserving original logical identities.

## Work items direct storage in Compose — 2026-10-24

In the pinned serving environment, `just test::work-items-placement compose`
passes in **556.46 s**, including **210.06 s** building physical images. Native
history and direct Table data use the node's persistent local directory. Explicit
initialization precedes native provisioning, Table service configuration and
public catalog setup. Replacements open that same directory.

Separate data, publication, requester, delivery and gateway processes complete
the real browser schedule across worker, node and gateway replacement. It checks
fresh worker keys, unchanged original query recovery, full migration and
verification, schema publication, a new query and current denial. The TLS edge,
private ingress and egress probes pass. Ursula and MinIO serve only as isolated
denial targets in this topology; this run establishes no tiered cold-store data
recovery. The two finite browser queries allow 180 seconds each for complete
verified coverage. This is a bounded fixture deadline, not a latency guarantee.

The run uses the direct data migration and membership fix; it predates the
subsequent stop-on-error worker policy qualified in the next record. The Reference
fixture now has an explicit initialization job and separate native/Table PVC,
but that profile has not run: this checkout lacks the owned reference
infrastructure and matching runtime image. It remains an open execution gate.

## Work items direct storage on the reference runtime — 2026-10-24

`nix develop .#serving --command python3 -B examples/work-items/placed.py reference`
passes in **885.08 s**, including **165.31 s** of image work. The actual browser
verifies its original query in **117.006 s** and its new query after migration in
**133.614 s**. Both retain the existing 180-second finite-query bound. Only the
external physical replacement/migration wait uses a separate 600-second bound.

Three Substrate owners receive fresh registrations and conditional native key /
generation rotation. Their original roles and cross-resource grants survive.
The node and gateway reopen the same native/direct Table history on the owned
PVC. The browser recovers its lost accepted upload, observes the schema
transition, verifies all pages of the replacement query, and clears protected
state after current denial. Keyboard, responsive layout and axe checks pass.
The private gateway egress probe also passes. Namespace cleanup completes.

The fixture declares its already-owned node claim to Helm, avoiding an unused
delayed-binding PVC. Native history and direct Table data use that claim;
Ursula and MinIO remain isolated denial targets, not evidence of cold-tier
recovery. The successful run uses isolated reference metadata; the earlier run
interrupted by removal of the shared reference cache is not passed evidence.

## Direct Table exchange placement and borrowed reads — 2026-10-23

`nix develop --command zig build test-direct-captured-query
-Doptimize=ReleaseSafe -- --exchanges-only` passes under definition
`38fb0433e2dbce32b39167abb988460d09b813d8f2de519e78fbb8ca732b40e8`.
The private persistent node admits a maintained self-join over two rows, with
query progress separate from the Table catalog. The coordinator retains the
history lease. A separate producer principal saves original-caller assignment
and borrowed-read proofs, reads the exact cut, and delivers both source channels
through one logical partition. The receiver attaches complete coverage and the
verified revision reader returns count two. Recreating hosts during bounded
steps preserves progress. Cancellation closes the original lease, rejects
further borrowed reads and leaves the completed result readable.

The setup first encountered `PendingWork` when adding a producer-resource
association under active coordinator ownership. The corrected schedule suspends
the receiver, adds the optional association, resumes and reacquires a new
ownership generation while retaining the accepted query. This is a generation
replacement and discarded-proposal schedule; it does not inject lost native
receipts or restart the node after exchange acceptance.

Eighteen selected query tests pass for exchange control bytes, routing/coverage,
credit and quota limits, producer replay, immutable receiver binding and original
caller assignment. Receiver acceptance rejects a producer record addressed to
another resource. Five selected catalog tests pass, including independent
Python-signed borrowed request bytes. The full catalog ReleaseSafe suite passes
124 tests. The two local catalog/native-policy tests pass snapshot and historical
borrowed reads, exact-successor rejection, denied acquisition/release, current
policy revocation after buffering, original-caller credential rotation and reads
after lease closure.

The shared v1 definition replaces the prior envelopes and producer record;
`RXB1` now carries the immutable receiver PID/resource. Contract generation and
checks, binding resources, independent signing/codec fixtures, diagnostic mapping
checks and the documentation checks pass. This focused public schedule does not
qualify multiple exchange workers, later maintained attachments, credential
handoff, capacity or the older exchange/native caller hosts. Their migration and
full repository/installed qualification remain pending.

## Automatic local server startup

The startup implementation and executable proofs at `d61f2e0d` use one
`transit server` command for missing/empty installation creation, recorded
bootstrap recovery and ordinary restart. The [server guide](../../../apps/transit-cli/docs/server.md#first-startup-and-recovery)
owns the directory and recovery rules; [Server startup](../../../apps/transit-cli/docs/server.md) records scope.

Executed on 2026-10-20 with the pinned development shell:

- `just check` passes, including Zig unit/protocol tests, generated contracts,
  613 real CLI diagnostic cases, frontend checks and handbook build.
- `just test::server-faults` passes the core lifecycle in 94.02 seconds and the
  bootstrap/gateway/rollback schedule in 50.72 seconds. New coverage checks
  existing-only YAML/environment settings; missing and empty directories;
  preservation of files, symlinks, unknown contents and malformed records;
  SQL inspection and restart-pending reload; and empty-directory startup.
  Interrupted bootstrap resumes the original identity and exact receipt even
  with `startup.require_existing` enabled. Existing lock, missing-checkpoint,
  changed-artifact, rollback and missing-storage refusals remain covered.
- `just test::server-board` passes in 40.24 seconds, including default/headless
  startup, embedded assets, conflicts, application replacement, revocation and
  owned process failures.
- `just test::server-applications` passes in 453.834 seconds: 19 migrated rows,
  19 row steps, 21 receipts, final ownership generation 9, 52,584,448-byte maximum
  sampled manager RSS and a 3,060-byte maximum application checkpoint.

Committed-source `just ci-clean --lane core` passes all 28 tasks in
1989.02 seconds, and `just ci-clean --lane experience` passes all nine tasks in
1171.57 seconds, both at `d61f2e0d`. Their completed inventories are retained in
`.cache/ci/clean/d61f2e0de4ca-transit-ci-_78gffwf` and
`.cache/ci/clean/d61f2e0de4ca-transit-ci-lra_irgl`. The experience lane includes
real PostgreSQL/MySQL clients with required/optional/disabled TLS, owner bootstrap,
credential rotation, persistent revocation and exact recovery after reply loss
and SIGKILL. These two lanes cover 37 ordinary tasks; they are not a full-suite,
all-language or browser qualification.

The shared definition changes because the persisted settings registry changes.
Independent signing and storage fixtures, schemas and SDK resources are
regenerated together. Prior definitions reject without reset; this does not
qualify history conversion or rolling upgrades. The operator's existing
installation is untouched; lifecycle tests use disposable data. The final
follow-up changes only documentation and this evidence record, not the runtime,
contracts or test code qualified at `d61f2e0d`.

## Kubernetes tooling qualification

`just test::dev-environment` proves that the shell selects the checkout-local
reference config before creation and after removal, honors an explicit override
from a subdirectory, and leaves a personal config untouched.
`just test::kubectl-transit` runs the real Zig executable against a fake kubectl
boundary, without credentials or a cluster. It checks selectors, explicit context
and kubeconfig forwarding, native JSON, invalid flags, read failures, empty and
ambiguous resources, output bounds, a hanging child after both pipes close,
and SIGINT/SIGTERM cleanup for log following and Board forwarding.
The fake child publishes its readiness PID by atomic rename after installing
signal handlers, so the parent cannot mistake an empty file for readiness.
Discovery tests cover aligned columns across namespace lengths, exact
namespace/release selection, useful empty-selection diagnostics, and rejection
of control characters or oversized human-table fields without partial output.

The plugin's [runbook](../../../apps/kubectl-transit/README.md) and
[Kubernetes tooling](../../../apps/kubectl-transit/README.md) define its inspection-only scope.
Toolchain smoke checks verify Kind and both kubectl plugins offline.

`just launchers::reference::test-plugin` passed on Linux x86_64 against the
already-running owned Kind reference. It renders the real chart with overridden
names into a uniquely created namespace, uses an inert node Deployment plus a
CoreDNS HTTP health responder in place of Board, and verifies native discovery,
status/workload views, prefixed logs, configured origin, real port-forward traffic
and listener shutdown after interruption. The fixture proves Kubernetes wiring,
not Transit read authorization or execution. Cleanup verifies the namespace
UID before deleting only test resources. Existing reference workloads are not
restarted. Plain `kubectl get nodes` and packaged `kubectl ate get workers` also
succeeded through the environment's default reference kubeconfig.

`just check`, `just doctor`, the offline proofs and chart validation passed;
`nix flake check --all-systems --no-build` evaluated all configured systems. Native
macOS execution and complete reference recovery after these tooling changes
remain separate qualification; a successful inspection is not a recovery proof.

## Launcher qualification

Stable topology lives in root [process-compose.yaml](../../../process-compose.yaml),
[docker-compose.yaml](../../../docker-compose.yaml) and
[charts/transit](../../../charts/transit/README.md). Integration proofs consume these
files directly; generated private files contain only installation-specific
values, service configuration and provisioning material. The reference proof
installs/upgrades the chart, including its WorkerPool and optional Board and
maintenance resources. Provider setup and adversarial fault injection stay in
the harness.

`just launchers::local::test` and `just launchers::compose::test` exercise the
real launchers in uniquely named installations, with disk-backed Ursula and
the actual node, maintenance process, counter and Board. Both passed on Linux
x86_64. The native proof is part of `just ci`; Compose remains an explicit
Docker-dependent check. The proof checks:

- Direct Board access and the inspection-only upstream principal; private
  credential files and secret-free status/log output.
- Seed inputs admitted once, same-ID send retries returning the same receipt,
  conflicting retry rejection, and resumption after a lost operator receipt.
- Pending input surviving caller replacement, same PID with a fresh generation,
  and rejection of the old caller's actual credentials.
- Full stop/start with unchanged state, realm and keys; independent storage,
  node and Board restarts; no fresh bootstrap when established WAL is missing.
- Refusal to reset running resources, adopt an occupied port or running
  installation, or reactivate a permanently retired PID.
- Reconfigure an existing Board listener/public origin without resetting its
  realm or keys; probe through the correct Host header without public DNS.
  Remote HTTP requires explicit development opt-in; wrong Host/Origin still
  fails while direct reads succeed without a Board credential. Ursula/Transit keep loopback publication.
  Native Board must become ready in Process Compose and stay alive beyond the
  original 30-second probe-failure window.
- Local and Compose foreground startup stream service output and manager/container
  exits; a killed Board stays diagnosable across status calls. Other terminals can send and
  restart while `up` is attached. Ctrl-C, termination during startup, and failed
  recovery stop only the owned services and preserve the installation's data.
  Compose also checks detached startup and that a delayed foreground cleanup
  leaves a newer replacement stack running after another terminal's `down`/`up`.

Successful proofs stop/remove only their owned resources and delete their test
state. Failed proofs preserve private evidence for inspection after cleanup.
These tests establish development workflow behavior, not Substrate isolation,
clock accuracy, finite-capacity reserves, remote Docker support, or production
deployment safety. Compose uses ordinary bridges with loopback publication;
native code runs as the developer. See [launcher limits](../../../launchers/README.md).

Initial checks caught premature local readiness using a previous activation's
config, Docker internal networks suppressing host port publication, private build
output permissions preventing non-root execution, and a Board config mount
colliding with its executable path. Readiness now requires fresh worker config;
images place executable files under `/bin` with explicit executable permissions.

## M25 local application qualification

The initial profile is trusted Linux placement and a separately compiled Zig
consumer over the [neutral installation/bootstrap contract](../../../contracts/APPLICATION_INSTALLATION_V1.md).
The example builds through its own manifest, imports public packages and runs
with an empty `PATH`. Installation and domain operations use public CLI commands
and exported connections; ordinary workflow steps never edit private manager
records or use realm-root credentials.

| Executed proof                      | Result                                                                                                                                       |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `test::server-applications`         | 98.521 s; two applications, 19 migrated rows, three Table pages, 21 paged native provisioning/activation receipts, final worker generation 9 |
| `test::server-application-faults`   | 29.221 s; exact lost spawn/rotation/send/turn/activation replies, current revocation and denied/malformed management; reserved health 1 ms   |
| `test::server-application-capacity` | 16.40 s after fixture setup; accepted input across actual ext4 ENOSPC, same receipt/PID/resource after restart                               |
| Existing `test::server-faults`      | Core lifecycle 30.18 s, bootstrap/gateway/rollback faults 13.04 s; reserved health 5.20 ms                                                   |
| Existing `test::server-capacity`    | 17.28 s; accepted console query recovered after real ENOSPC                                                                                  |

The application lifecycle proof interrupts provisioning, attaches twice without
new identities, refuses conflicting intent/declarations, incompatible replacement,
invalid receipt cursors and active-role quota overflow. Installer, domain operator,
writer and inspector remain separate. A compatible configuration replacement
preserves PID/resource/principal and migration progress while the neighboring
application and pinned neighborhood processes remain running. Worker, manager,
authority and disk-store interruption preserve accepted work. The 19-row transform
is verified against its retained source through bounded pages before explicit
write release. Replaying an old migration step does not copy another page.

The largest sampled manager high-water RSS was **28,180,480 bytes**, below the
fixture's 128 MiB ceiling; the largest current application checkpoint was
**2,847 bytes**. These are measurements for two single-role applications, not a
maximum-quota or throughput qualification. Runtime limits are explicit: at most
eight roles/sixteen resources/eight callers per declaration, configured active
application/role quotas, one 256 KiB checkpoint read, eight receipts per status
page, 64 KiB management values, finite HTTP/registration/activation deadlines,
three worker-exit restarts and joined child shutdown. Retained request/receipt
history grows on disk with unlimited retention; it is not read into a resident
collection.

The fault fixture puts the real disk authority behind an **explicit test-only**
node peer. It records accepted native bytes/receipts, drops replies, kills the
manager, and requires byte-identical retry and equal receipts before fresh root
operations. That test peer uses Python and parent-death handling; the production
manager does not. A separate schedule loses migration send and committed worker
turn replies, then verifies activation and old-key fencing. Root keys are used
only by adversarial fixture steps to revoke native rights, not by the application
workflow. Inspector resource revocation, worker revocation and installer
revocation remain effective. Twenty denied requests, malformed/foreign/oversized
values and forbidden identity headers cannot bypass authentication; health uses
its reserved request capacity.

The capacity fixture reuses M24's owned 2 GiB ext4 image inside an isolated
privileged container. It waits for **domain initialization**, pauses the data
worker, admits an input and saves its receipt outside the provider volume. A
filler leaves 4 MiB metadata headroom; a 32 MiB allocation confirms actual ENOSPC.
After releasing the filler and a preallocated 512 MiB reserve, ordinary startup
and the original command recovery file complete exactly one retained input.
No existing host block device, user installation or reference cluster is changed.

`just check`, `zig build test -Doptimize=ReleaseSafe`, standalone client tests and
independent schema/SHA-256/Ed25519 fixture checks pass. These new focused/external
tasks do not expand the ordinary hosted lanes or claim a new M10 budget sample.
The selected replacement changes configuration with the same compatible binary;
M33 must additionally qualify changed executable artifacts through installed
release packages. Other SDK hosts, maximum active quotas, local multi-role
dependency graphs and distributed placement are not qualified by this consumer.
Interface publication retains its separate M23 proof; worker readiness does not
claim a published interface or verified migration result.

The first runs exposed three corrected defects: borrowed JSON strings outliving
the response buffer, pending application root operations being recovered after
built-in activation, and old worker readiness being displayed with a new fence
generation. A generic JSON tuple needed its original array wire shape preserved.
The capacity fixture initially paused before domain initialization; it now waits
for public domain evidence. Failed schedules are not counted as passes.

## Direct SQL Compose placement — 2026-10-24

`nix develop --command just test::sql-wire-placement compose` passed in 544.664
seconds on the working tree based on `b861597c4`. The deployment uses the local
node's direct Table owner and separate native SQL progress storage. Verified TLS
PostgreSQL/MySQL clients round-tripped six data types, checked Table counts and
recovered after physical gateway/node replacement with a fresh fenced native
generation. The SQL caller was denied raw-resource inspection.

The first attempt failed compilation on a remaining removed-role reference in
the query host; it supplied no deployment evidence. The corrected attempt above
completed. This is a finite local Docker Compose recovery schedule, not a
throughput comparison, power-loss proof or qualification of other placements.

## Launcher and SQL logging acceptance — 2026-10-25

At `46d42df84`, the clean launcher lane builds successfully and passes installed
persistence, exact retry, fencing, retirement, replacement, direct access and
foreground control schedules. Its missing-WAL startup case then fails an obsolete
`error:` assertion: the node correctly emits `service.failed` with `NotFound`,
exits nonzero, and the manager preserves the installation. The clean experience
lane passes Board, handbook, Node static and observability checks, then fails a
blanket assertion forbidding SQL `unavailable` during startup. The retained log
shows an actual `AuthorityTimeout`, followed by recovery of the same installation
through `initializing`, `starting` and `accepting`. Neither lane is a pass.

`7b48509ee` updates these fixture assertions to the existing operational logging
contract. The launcher requires a structured `service.failed`/`NotFound` event
and the manager's failure summary, retaining nonzero exit, owned cleanup and
saved-state checks. The SQL proof still rejects an unexplained initial
`unavailable` observation; a reported failure must carry a cause, and the final
status must be `accepting` with its error cleared. Runtime behavior and deadlines
are unchanged. The server guide distinguishes a pending first health check from
an actual failed authority observation during startup.

Both complete focused commands pass: `just launchers::local::test` covers the
installed and foreground schedules, including streamed failures and termination
cleanup; `just test::server-logging` covers text/JSON/off, terminal versus machine
stdout, SHOW and environment precedence, admission pressure without role
replacement, and gateway failure/recovery. An earlier standalone foreground
invocation omitted its build preparation and timed out while building before
reaching the repaired assertion; it is not a qualified run. The remaining
experience tasks and the other clean lanes continue separately; their completion
must be recorded before ordinary-suite acceptance.

## Dependency-package ELF loader selection — 2026-10-26

The installed SQL gateway built at `e6913e0d5` selects
`/lib64/ld-linux-x86-64.so.2`, while the CLI, node, Board and query host select
the pinned Nix loader. The gateway loads Nix glibc 2.42 through its OpenSSL
dependency. The compiler's build runner preserves the selected loader for a
root target but omits it when serializing `ResolvedTarget` or `Target.Query`
arguments for dependency packages. A target triple alone cannot carry that path.

An independent three-package control with the earlier wrapper reproduces the
loss for the default Nix loader, an explicit loader path and an explicitly empty
loader: the leaf always selects the host interpreter. The corrected build-runner
source copies the loader into the dependency options with arena-owned bytes.
The offline toolchain check traverses both target representations and verifies
all three choices in the leaf. Root and leaf OpenSSL consumers execute under the
default selection; deliberately non-runnable explicit/empty selections are
inspected without execution. Existing C/C++ thread, library, compile-only and
explicit-target controls also pass. The compiler executable remains byte-identical
(`974e6dd680194ff1305ba5890fda84e32fc8f10845ec4e9c442e792418fe315e`);
compiler, library and lockfile versions are unchanged.

With the same retained gateway bytes, invoking glibc 2.40's loader aborts during
native thread creation; invoking the pinned 2.42 loader returns the expected
missing-configuration failure. This demonstrates the invalid pairing without
claiming the same crash path as the hosted gateway's SIGSEGV. The rebuilt gateway
has the pinned interpreter. At `6957584c4`, `just test::server-logging` passes
standalone failures, terminal/piped startup, logging-off restart, SQL readiness
transitions and child logging configuration. `nix flake check`, `just doctor`,
Nix formatting and documentation links pass on Linux x86_64.

The earlier clean launcher lane at `144d4ee68` passes both tasks. The clean
experience lane at `e6913e0d5` passes its first four tasks, then fails during
logging-off startup with empty diagnostic output. A diagnostic rerun using
unchanged binaries passes; it does not erase that failure or establish a cause.
Hosted run [40258942126](https://github.com/spoke-sh/transit/actions/runs/40258942126)
passes launchers and observability but retains a unit-executable SIGSEGV, Python
public-query deadline failure and standalone gateway SIGSEGV. Complete
qualification with the loader correction remains separate from these focused
passes; the earlier Table recovery and installed-session failures remain open.

