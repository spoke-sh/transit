# Database transaction qualification

The question is whether one local Catalog can preserve a common Table cut,
provisional statements and one original decision across failure and caller loss.
Current semantics belong to the [transaction reference](../../handbook/reference/sql/transactions.md),
[SQL session contract](../../../contracts/SQL_SESSION_V1.md) and
[direct Table contract](../../../contracts/DIRECT_TABLE_V1.md). This record keeps
finite models, component recovery and installed histories separate.

## Protected automatic DLQ transaction owner — 2026-11-01

The implementation committed as `5c8671e71141911a95d09fc5fd957ae35eae4ca9`
uses one protected standard transaction, permanent source binding and paged
pending index. Its current-v1 definition is
`2e2c775950d2d0cfa6d6ea66e078fcdfa8381c16e522c5ac7d91fb243714c7f3`.
The following pinned-shell ReleaseSafe checks ran on that implementation before
commit; their working bases precede the commit and are not clean-lane evidence.

| Invocation | Result |
| --- | --- |
| In `packages/zig/transit-catalog`: `zig build test -Dtest-filter='automatic Queue transfer' -Dtest-filter='Queue transfer plan' -Doptimize=ReleaseSafe --summary all` | 10/10 tests; 40 injected append failures across four durable logs |
| At repository root: `zig build test-local-catalog -Dlocal-catalog-filter='automatic Queue maintenance' -Doptimize=ReleaseSafe --summary all` | 2/2 tests, including the native database-policy/worker composition |
| In `packages/zig/transit-storage`: `zig build test -Dtest-filter='queue partition dead letter discovery' -Doptimize=ReleaseSafe --summary all` | 4/4 tests, including canonical destination-key routing |

The catalog schedule alternates refusal before append and reply loss after
durable append, reopens all owners, and verifies one original source binding,
decision and cleanup. Tests also cover forged payloads, separate read/append
denials, generic transaction/control bypass refusal, unrelated catalog
publication after a failed initial acceptance, abort before/after private
evaluation, quota refusal, unchanged recorded destination after policy edits,
and graph reachability before acquisition. Cleanup after a recorded decision
does not need a current clock. An aborted transfer retains its permanent source
binding and publishes neither source archival nor a destination row.

The native schedule uses a 32 MiB worker allocation budget and a 16 MiB
transaction budget, separate from provider/native caches and process RSS. It
checks that the checkpoint signer alone supplies no database authority, reclaims
two unreferenced allocations in 314 real collection steps before acquisition,
revokes/restores destination ownership, refuses adoption by another account,
and alternates two worker instances through one original decision. Independent
readback verifies the archived source and exactly one destination row with its
original value. This is in-process native/disk composition, not an installed
HTTP, process-kill, power-loss or saturation proof.

The failed development runs remain local evidence: the initial admission
allocated a maximum-sized payload buffer and exceeded its unchanged 16 MiB
budget; exact payload allocation resolves it. Reservation recovery initially
failed replay validation after unrelated publication. The native fixture first
restored a clock older than collection's new floor, then exposed discovery
encountering a prepared transaction. The fixture now advances its clock to that
floor; discovery skips prepared participants while original transaction recovery
continues. Neither budgets nor deadlines were raised to pass these checks.

Raw successful logs and SHA-256 values are:

- `/var/tmp/transit-m6-protected-dlq6.log`: `4c1c9fbb41917405b84a2b0dfbc3ad647a72e9b8a12e3db626812d9b0ec6cbda`.
- `/var/tmp/transit-m6-dlq-native3.log`: `65c6fd2d77dbbbac4055eba9d492a6593a9744138ad5f077a3873848f1079d2c`.
- `/var/tmp/transit-m6-dlq-routing1.log`: `65ea0e8413cc2bddf7705694948b7c677dbef9303080f907420c45d3c65e4b6d`.

Regeneration passes all 19 contract checks; 60 fast checks pass during the
change. The owning [direct contract](../../../contracts/DIRECT_TABLE_V1.md)
and [node configuration](../../../apps/transit-node/docs/growing.md) describe
the optional worker and exact authority/retention boundaries. Installed worker
qualification, larger-population/resource schedules and common-revision lanes
remain open. This evidence does not complete M6.

## Mixed disk decisions and frozen DLQ plans — 2026-11-01

Committed source `f3c6f162b0b02b10b418989891b545276c66d574`, definition
`8e441078693f1373d69323bfeadd5cfe8c7024ec2015819bacfb2b04eaea3865`, passes
all **13 tests** in this local catalog-package invocation:

```sh
cd packages/zig/transit-catalog
zig build test \
  -Dtest-filter='mixed transaction reopens' \
  -Dtest-filter='Queue transfer plan' \
  -Dtest-filter='transaction log source cuts' \
  -Dtest-filter='transaction log statements' \
  -Dtest-filter='transaction log terminal transfers' \
  -Doptimize=ReleaseSafe --summary all
```

The new mixed schedule combines a 512-byte KV value, a Table row, Stream append
and authenticated offset settlement, and Queue enqueue and ACK. It also retains
one read-only Stream partition in the common cut. The commit path encounters
**38 injected failures**, alternating refusal before the next WAL append and
reply loss after its durable acceptance; abort after a prepared prefix encounters
**22**. Each path reopens disk owners at every failure and reaches all seven
logs: Catalog, decision and five participants. The test checks the changed WAL
tail independently, retains the original transaction/statement identities, and
verifies values, offsets, lease state and original receipts after cleanup.
Decision recovery has no clock or old cursor-signing authority. A later abort
cannot replace the committed decision, and cleanup releases the account's
transaction reservation. These are injected append failures with orderly owner
reopen, not process-kill or power-loss schedules.

The separate `DirectQueueTransferPlan` checks preserve a global exhausted-source
key across caller/account and policy changes while committing the complete
original plan to a different digest. They exercise sorted two-Queue selection,
identity conflicts, immutable disk reopen, scope substitution, noncanonical
bytes and missing/foreign definitions. This descriptor supplies neither the
automatic scheduler nor its required catalog admission and source binding.

The raw log `/var/tmp/transit-m6-mixed-and-plan6.log` has SHA-256
`f55cd4532c2df5ab2744d9d2b21b9620f1189cb4ac4a3b5ec14be0659cf8d1a1`.
Execution took three minutes with 38 MB reported peak RSS; compilation took one
minute with 2 GB reported peak RSS. The same committed source also passes all
60 fast checks and 19 contract checks. This local invocation is not a clean-clone
CI lane or installed-caller qualification. Earlier runs exposed two test issues:
an injector left armed during the independent readback, and a foreign-definition
negative expecting the inner enum error instead of the shared JSON refusal.
Those failed runs remain failures; the command above is the completed rerun.

## Mixed workspace replay after PR #303 — 2026-11-01

Committed source `8f1c2afb781cb309325e85b8b1dd43ac50b6d76d` passes
`nix develop --command just ci::clean --lane formal`: all **14 required tasks**
complete in a clean clone, with **209.460 seconds** of recorded check time.
The PR #303 accessor compilation defect was already repaired on main by
`d61165ef7`; this change extends the replay adapter beyond that correction.

The state-only workspace model still exhausts **304 states** and detects and
replays all **eight negative controls**. Twelve separately specified concrete
Table/Stream schedules exercise both statement variants, the shared pending
slot and sequence, cross-kind operation reservations, revocation and savepoint
rollback across owner replacement. Execution reconstructs the pending request
from accepted progress; a volatile request is no longer carried through reopen.
Independent projections distinguish private Table rows and log actions from
public data. The existing state-only profile retains its 128-KiB workspace
quota; the three-participant concrete profile uses 1 MiB. Both keep the 16-MiB
resident bound.

Ignored automatic evidence is under
`.cache/ci/clean/8f1c2afb781c-transit-ci-icoou499/`. The workspace model's
`verification/transaction-workspace-model/20261101T003046-3136618/evidence.json`
has SHA-256 `6b02d3f2972c182fa883f1dc667513859934ff15cd29ff97c0ece382a9ebcc2a`;
its replay binary has SHA-256
`2180a5384049b529bc62a0950d95c71c2d5e85fbf162619e3dd1f3d2a31fbc43`.
These are local evidence references, not portable downloads.

This is finite formal exploration plus selected concrete replay over reopened
memory-backed owners. It establishes neither exhaustive mixed correspondence
nor disk/process failure, installed caller, automatic DLQ, Station runtime or
full CI qualification. Those gates retain their separate owners and evidence.

## Paired Queue terminal transfers — 2026-10-31

Implementation `b27aac9289dffd7804739b14e7ea6057ab824ba2` supports explicit
native Queue transfers through the existing transaction workspace and decision
owner. Definition
`840c402d628b33eaca53001138fdababf605d5d82b94e95731748b72fe8b8a24`
replaces the prior mixed-statement definition. The
[native transaction contract](../../../contracts/DIRECT_TABLE_V1.md#transactional-stream-and-queue-work)
owns executable operations and authority requirements.

The component run passes **109/109 protocol**, **208/208 catalog** and
**75/75 selected storage tests** in ReleaseSafe. Storage selection includes
`queue`, `Queue`, `log transaction` and `transaction decision`. The final
catalog filters, `transaction log terminal transfers` and
`transaction transfer reservations`, pass **5/5 tests**, covering the last
authorization change after the full catalog run began. All **58 fast checks**,
**19 contract checks**, the two focused native refusal checks and the full
handbook check pass. These are workspace checks, not clean dependent lanes.

Disk cases cover live NACK transfer, exhausted items whose recorded destination
survives a later policy edit, lease expiry before the common decision, and
savepoint rollback. Both operation identities stay reserved. Current destination
append denial rejects staging, buffered outcome disclosure and commit; an absent
outcome also rechecks authority before disclosure. A changed payload cannot
terminalize the source. Lost decision replies recover the original committed or
aborted outcome after reopening, under the existing 16 MiB transaction limit.
Pending payloads remain reachable through the metered retained graph.

Storage cases reject missing, mismatched and reused transfer counterparts. They
verify private FIFO advancement and preserved old roots, and reject a correctly
encoded standalone terminal WAL record before replay changes state. Source
payload validation also runs after sealing and reopening, exercising the reused
encoding buffer against a pinned cold-segment borrow. These checks do not prove
an installed transfer, automatic DLQ scheduling, arbitrary concurrent execution,
or the complete preparation/finalization fault matrix.

The component output is `/var/tmp/transit-m6-queue-terminal-checks1.log`, SHA-256
`1ccc58054dc317798d1f6a81d5c9f595517b4e42acd15b142822138c7b78d4c8`.
Final checks are in `/var/tmp/transit-m6-queue-terminal-final.log`, SHA-256
`c6662a91a63ff7c99ebf38d86618c489634c30c5c0f8d6b24965959cdb6c1289`.
The final run used the committed implementation with the separate installed
fixture being prepared in the workspace. Its production sources match the
implementation above. Owning generators, bindings and independent fixtures
complete in `/var/tmp/transit-m6-queue-terminal-generation2.log`, SHA-256
`8b4c2cda8de06c1fe8baad09b89173abd9b3396ad3b91cee0c291edd3ad41a68`;
version validation covers 158 manifests. These paths are local evidence, not
portable download links.

An earlier prototype exceeded the resident limit by opening both owners at
once; sequential owner lifetimes fixed that failure without raising the limit.
Earlier compiler/fixture failures and the first diagnostic-inventory failure
remain failed attempts. The corrected current-definition runs above supply the
passing evidence. The installed signed transfer schedule and common-revision
clean qualification remain open, as do SQL/Station composition and performance
measurements. No test duration is treated as a latency baseline.

### Installed recovery and bounded evaluation

At clean revision `d8cbca24bbc1f0ef634f0fa018faf10bbf0fb8c0`, all three
installed ReleaseSafe schedules pass using the same node and caller binaries
and the `840c402d…` definition above. Each schedule corrupts two accepted
responses, kills and restarts the node after each loss, then checks the original
saved identities and outcomes through the public signed interface:

| Schedule | Signed requests | Lost replies | Verified result |
| --- | ---: | --- | --- |
| Queue terminal transfer | 30 | `643006`, `643101` | Original paired transfer and common decision; destination payload and source FIFO successor |
| Table/KV/Stream/Queue | 85 | `642016`, `642101` | Private state, original statements, common decision and public visibility |
| Table/KV | 33 | `642012`, `642101` | Private KV read, original mutation and common decision |

The node SHA-256 is
`f3e95af8ec41b506557b05bb1d38a04b0ba787f5c678703110574e559186b171`;
the caller SHA-256 is
`7b319133263038f594348a50686b7a5b55736282f38a3c44c7cd267638574ee9`.
Local outputs are `/var/tmp/transit-m6-transfer-buffer-queue-transfer.log`
(`b78c5b35f6e5119179bb81ab9bb5b82f72ed4f97df07daa953dbf6b789239b0e`),
`/var/tmp/transit-m6-transfer-buffer-mixed-transaction.log`
(`674c75a38976eb71419a89bcb5103bb5d94c92ab126cf91216e8b37ae9404823`),
and `/var/tmp/transit-m6-transfer-buffer-state-transaction.log`
(`e383ef956f1be2610f9b8b3fdca50d8407e32dc5bc664b9f0a0005e72d70c85c`).

The installed mixed schedule first exposed overlapping transaction metadata
caches at private Queue ACK evaluation. Commit `611bf4c1a` closes those caches
before opening the partition owner. A later transfer run at `31120457a`, with
request-memory diagnostics enabled, still failed `TransactionMemoryLimit`.
Both failed installations preserve the original signed requests privately.
A disk component using the default 16 metadata pages and FIFO source and
destination reproduced that second failure. Commit `d8cbca24b` sizes private
append scratch from the verified action payload and reuses the partition's
encoding buffer for transfers. It keeps the existing 16 MiB transaction budget.

The corrected component selection passes **12/12 catalog tests**, and the
storage transaction selection passes **17/17 tests**, including cold-segment
transfer reads and decision replay. All **58 fast checks** pass. Outputs are
`/var/tmp/transit-m6-transfer-budget-fifo-green.log`
(`70654fc14fefff9b3530274eb85629f4528caf2955d4ee9c8cf92dc74a4560ac`),
`/var/tmp/transit-m6-transfer-buffer-storage.log`
(`e37a60692d0ab0b7009158e571364246533b3e3ef48ab8b9acfe75e3f7a26c8d`),
and `/var/tmp/transit-m6-transfer-buffer-fast.log`
(`2a0a1938fcb6f26f71da2f1bfeda521e9e1370d73f07eaafceeadbbec6ee9789`).
The earlier failures remain failed attempts; passing later schedules does not
settle their retained accepted work. Automatic DLQ scheduling, the full fault
matrix, clean dependent lanes and performance measurements remain open.

## Native mixed state and log statements — 2026-10-31

Implementation `95428fd6b0a1ff79a6c11ff7eca755005b274f9a` admits Stream
append/offset and Queue enqueue/ACK statements through the same workspace,
savepoint and decision owners as Table/KV mutations. The replacement definition
is `edcac1ee9f98bce6a0cb6d93c14d38566b33af3a48ef8282fa6024ea8bb964b9`.
The [direct contract](../../../contracts/DIRECT_TABLE_V1.md#transactional-stream-and-queue-work)
owns exact operations, bounds and recovery semantics.

The current-definition workspace run passes **206/206 catalog tests** and
**28/28 selected storage tests**, both in ReleaseSafe, followed by the handbook
production build. Table/Stream checks exercise private appends, savepoint
rollback, permanent operation reservations, missing prepared segment refusal and
current append-right revocation. Disk Queue checks compose ACK, enqueue and a
Table mutation, reject lease expiry on the final decision clock read, and recover
the original committed or aborted decision after reopening. Stream offset checks
reject forged coverage, recover a lost admission reply and preserve an accepted
offset through cursor-key rotation. Prepared graph traversal remains metered;
no handler runs during recovery.

Raw output is `/var/tmp/transit-m6-log-statements-checks2.log`, SHA-256
`e0788932f783e5186f1aacd92c7e1e37006c77943d720f72f35d349f38d2d1c9`.
The earlier run passed all **58 fast checks** and **19 contract checks**, then
failed compilation on an old pending-statement assertion; the corrected assertion
is included in the implementation above and subsequent full catalog pass. That
earlier aggregate remains failed. Definition-bound schemas, native/binding/browser
resources and independent signing fixtures were regenerated by their owning
writers; version validation covered 158 manifests. Generation output is
`/var/tmp/transit-m6-log-statements-generation.log`, SHA-256
`838fdec13f8dfdf63afe8cf1ddd51f21b9b149e36533f9dddc95fc7fa3bf2d45`.

The native node builds in ReleaseSafe in
`/var/tmp/transit-m6-log-statements-node-build.log`, SHA-256
`9e406caa50630b5e78ac5eb364fb3430378cd4aeb0aed2dddecf051954924b61`.
These runs began before the implementation commit with the same implementation
sources. They do not establish clean-source dependent-lane qualification or an
installed mixed transaction. The installed signed caller, atomic DLQ, SQL verbs,
Station composition and performance measurements remain open. The separate
Table/KV clean storage lane continues; it does not qualify this later cutover.

## Installed mixed state, output and input settlement — 2026-10-31

The signed [mixed transaction caller](../../../tests/catalog/tables/direct_state_transaction.zig)
and [disk/restart schedule](../../../tests/storage/tables/direct_table_service.py)
pass with clean source provenance at
`bec944ab3dd5c18437bc331fc2286ab4ab67bf26`, using the native mixed-statement
definition above. The bounded history makes **85 signed requests** and withholds
the replies for Queue enqueue statement **642016** and common commit decision
**642101**. Each lost reply is followed by a node SIGKILL/restart. The caller
retains its original transaction token, statements and commit identity verbatim.

One transaction proposes a Table row, six 1 KiB KV values, a Stream offset
commit, a Queue ACK, a Stream append and a Queue enqueue. After the first restart,
exact statement retries recover the private outcomes while public state, output
frontiers, group progress and the input lease remain unchanged. After the second,
the caller recovers the original committed decision and completes cleanup. It
checks the public state values, append receipts and actual output payloads,
observes the consumed Stream offset and acknowledged input, and claims the next
message for the same FIFO key. No actor turn or handler recomputation participates.

The recorded binaries are node SHA-256
`e5f882effbc03a9695a55e09fe41e8bfb44f26d9153093d48a3230f0b0873d82`
and caller SHA-256
`7157d942321a094ed818a6d315786b548264e7ea1796848a715da23b94e42cb9`.
They were built from the same implementation sources before the fixture commit;
the proof records their actual bytes. Raw output is
`/var/tmp/transit-m6-mixed-installed-run2.log`, SHA-256
`9344bedb4ea4e92764fbe3595835f7dc22cdb05da44409efec9fce74a0ec985a`.
This explicit-binary execution is not a committed-source clean-lane build.

The original Table/KV-only mode also passes with these same binaries: 33 signed
requests, lost replies 642012 and 642101, two SIGKILL/restarts and unchanged saved
identities. `/var/tmp/transit-m6-state-installed-current.log` records that run;
its source is marked dirty because this qualification account was being edited.
No implementation or fixture source changed during the run.

The first attempt in `/var/tmp/transit-m6-mixed-installed-run1.log` failed at
Queue claiming with `ClockUnavailable`: the new mode omitted the existing Queue
fixture's trusted-clock configuration. `bec944ab3` supplies that configuration
without changing request or proof deadlines. That attempt and its private
installation remain failed evidence. The initial caller compile used the wrong
namespace for the declaration kind; the corrected caller build passes all six
steps. All 58 fast checks, six task-ownership regressions and the CI runner
regressions also pass. Clean dependent lanes, the remaining preparation/finalization
fault matrix, DLQ, SQL/Station integration and performance qualification remain open.

## Catalog Stream and Queue read dependencies — 2026-10-31

Implementation `a679c9f3b9873523405a706be99604affcafe483` admits explicit
Stream/Queue partition read dependencies beside Table/KV state. Definition
`e43dc2b9d4e7bb5c5412694a505e50588680570ab346dde42c9745832769ebd4`
replaces the earlier definition. The [direct contract](../../../contracts/DIRECT_TABLE_V1.md)
owns selection, common-cut acquisition, conflict validation and closure semantics.
Public transactional log mutations remain unavailable.

Workspace checks of these exact implementation sources pass **202/202 catalog
tests** and **26/26 selected storage tests** in ReleaseSafe. The catalog disk
case selects one Table, two Stream partitions and one Queue. Seven fresh disk
opens recover six injected lost replies: the four original source pins, common-cut
publication and the shared commit decision. Each original source stays at its
pre-pin position; no retry advances or duplicates it. Current Queue READ denial
refuses cut disclosure and commit. After the accepted decision, read revocation
does not prevent cleanup under current control rights. Commit/abort races retain
the original committed decision. A policy fixture rejects nested guard acquisition.

Retained graph traversal reaches every original log source artifact while
asserting at most three new jobs per step. A separate case appends to a selected
Stream after acquisition: a read-only transaction retains and completes its old
cut, while a serializable transaction refuses commit and aborts its already
prepared Table output. The independent Stream append remains visible. These
checks cover catalog components and disk reopen, not installed signed mixed
state/input/output execution or process-death fault schedules.

The same run passes **58 fast checks**, **19 contract checks** and the handbook
production build. Commands and raw output are in
`/var/tmp/transit-m6-log-catalog-cuts-checks3.log`, SHA-256
`a35f14249456a886bc50500999794abcc8b7c04246c33cf31eba16d903ad5664`. Owning schema, binding, browser and independent
signing writers complete in `/var/tmp/transit-m6-log-catalog-cuts-generation.log`,
SHA-256 `4a30ecbf38ec274cd6c39bc4b26b1fd6c165fd699616f2070bb9f7f6cd473718`; version validation covers
158 manifests. These are local artifacts, not portable download links.
Earlier check attempts stopped on a missing Python launcher and a Zig formatting
check; the successful run corrects both and regenerates the diagnostic inventory.

These workspace checks are not clean dependent-lane qualification. The separate
Table/KV integration branch's clean storage lane is still executing at the time
of this record; its earlier core failure requires the queued corrected retry.
Public log mutations, atomic DLQ, Station composition, Table latency targets and
Stream/Queue/Station baseline measurements remain open.

## Stream and Queue preparation and decisions — 2026-10-31

Implementation `acbab910e33704118b4f3b2626e598dbf776fb0c` adds private log
evaluation, immutable preparations, WAL barriers and resolution against the
actual shared journal. The replacement definition is
`8a98dbe8ab42641f64a79d7103a53770b67148a32d5087afa95513cc8df0e4b7`.
The [storage interface](../../../packages/zig/transit-storage/docs/transaction-decisions.md#log-evaluation-preparation-and-resolution)
owns its current behavior and remaining host obligations. Public catalog
selection/staging of log participants and terminal/DLQ transfer remain unavailable.

Precommit checks of these exact implementation sources passed all 26 selected
log-transaction, decision-journal and tail-cache tests in ReleaseSafe. Stream disk
cases compose three append batches and an authenticated consumer offset, lose
preparation, decision and resolution replies, and reopen through both commit and
abort. Reads remain blocked behind unresolved barriers. Wrong cursor keys reject
preparation; key rotation cannot invalidate an accepted offset. Subsequent flush
and reopen preserve all batches that shared the preparation position.

Queue cases privately combine enqueue and ACK, verify the public lease remains
acquired until resolution, and recover an accepted decision without a clock.
The decision tests reject intervals spanning expiry and expiry after preparation
verification but before the final decision callback. Omitting that callback also
rejects. Memory refusal and current-rights failure preserve public roots; the
source-pin, action-directory and original journal fault cases remain included.

The five-test catalog selection (including root-module tests) isolates retained
transaction sources and prepared successors. It verifies source retention after
archive/trim, prepared action/payload/index reachability and refusal of a complete
traversal when a required private payload is missing. These are component disk
reopen and injected-reply checks, not installed process-death or power-loss proof.
The owning host still must verify the full successor graph and current rights
before decision and materialization.

`/var/tmp/transit-m6-log-final-owner-checks.log` contains the final 58-check fast
pass and both selected owner suites. Its SHA-256 is
`c84b72fab45ce9f7c105382124d04f44fd385f4d4a58636004814c8e575121d1`. All 19 contract checks and the
handbook production build passed in
`/var/tmp/transit-m6-log-decisions-checks.log`; final diagnostics were regenerated
before the final fast pass. Definition-bound schemas, native/SDK/browser resources
and independent signing fixtures were regenerated by their owning writers in
`/var/tmp/transit-m6-log-decisions-cutover.log`. Version validation covered all
158 manifests. Clean dependent lanes, installed mixed state/input/output recovery,
atomic DLQ and Table/Stream/Queue/Station performance qualification remain open.

## Retained Stream and Queue transaction cuts — 2026-10-31

Implementation `715fb3e10` adds paged retained log transaction cuts, exact original
pin/release recovery and a logical-change frontier separate from physical work.
Its shared definition is
`d5f2961e680883a4eb9d568e38a7de935779d0f17d777422612331807f5c584e`.
The [storage owner](../../../packages/zig/transit-storage/docs/transaction-decisions.md#retained-log-transaction-cuts)
defines this component's behavior; public log transaction participation and
preparation remain unavailable at that revision.

The focused owner run passed six tests, including disk reopen after lost pin and
release replies, original-cut retry after later append, current-rights denial,
73 pins with one resident page and Queue claim/ACK conflict detection. The
isolated retained-graph run passed four tests, including the root-module checks:
it follows only the transaction-pin edge, preserves the original unsealed payload
basis after archive/trim, and stops retaining it through that edge after release.
Logs are `/var/tmp/transit-m6-log-pins.log` and
`/var/tmp/transit-m6-log-pins-graph.log`.

The broader Stream/Queue owner and log storage selection passed 66 tests in
`/var/tmp/transit-m6-log-current-storage.log`. It started before the final extra
negative control was added to the pin test. That control then passed in the
four-test run `/var/tmp/transit-m6-log-pins-corruption.log`: a structurally valid
pin record that invents a logical change is rejected during recovery. These are
component runs, not installed native transaction evidence or performance samples.

Current-definition generation, all 58 fast checks, all 19 contract checks and the
documentation build passed; the latter checks are recorded in
`/var/tmp/transit-m6-log-cutover-checks.log`. Independent signing and consumer
fixtures were regenerated by their owning writers. Clean dependent lanes and
common-decision log execution still require qualification.

## Partitioned participant contract cutover — 2026-10-31

Implementation `8e27a1f7b96be79201742fd7fa24c8a975bccb14` replaces object-only
transaction directory keys with typed object/partition targets, kind-specific
guards and one preparation per log owner. Its shared definition is
`7e644f25075291fae16bb7c8789cdc5e2142233e070ea51abb7894fd1a33245e`.
The [neutral contract](../../../contracts/DATA_LIFECYCLE_V1.md#transaction-bindings-and-evidence)
owns the shapes and remaining publication obligations. Installed execution
continues to refuse non-Table participants before admission.

Precommit working-tree checks for this implementation passed the protocol
package, focused storage and catalog transaction suites in ReleaseSafe, native
refusal classification, all 19 contract checks and all 58 fast checks. The
protocol package used Debug. A separate independent signed-selection fixture
checks partition zero and maximum-u32, exact signature binding, duplicate
targets, missing ordinals, foreign scopes and conflicting kinds. A disk directory
case reopens 73 partitions of one object with no resident page cache; the grouped
action case checks one exact preparation for a two-action owner. These establish
neutral membership, not action-directory durability or mixed execution.

The first catalog run encountered a signature failure while fixtures were being
regenerated; the regenerated fixture passed its focused check and the subsequent
catalog transaction suite. The first fast run detected stale direct query
descriptor checksums; regeneration through its independent owner preceded the
58-check pass. Neither initial run is counted as passed.

The existing finite decision, workspace, storage-lifecycle and resident-owner
models passed with their migrated Zig replay fixtures: respectively 3,227, 304,
1,200 and 149 distinct states, with six, eight, six and five intended negative
controls detected and replayed. These runs retain their original bounds and
assumptions, record the precommit working tree, and do not qualify Stream/Queue
transaction adapters. Committed-source clean lanes and installed callers under
this replacement definition remain outstanding at this entry. No latency or
throughput baseline was measured by these checks.

## Finite safety models — 2026-10-28

At base `ae19b4e7931bd0d3c9793e10363f7ed3ef771592` with implementation changes
present, `just test::table-transaction-model` exhausted five finite two-transaction,
two-Table programs and detected all seven intended missing-guard controls.
The model sources were unchanged from that commit. Distinct states were 18,706
(write skew), 22,315 (publication), 25,114 (savepoint), 19,850 (private reads) and
36,378 (competing barriers). `just test::transaction-decision-model` exhausted
3,227 states and detected its six intended controls.

The pinned TLC used one worker, seed 1, fingerprint 0 and a 512 MiB heap, with a
60-second limit per configuration. Every positive configuration exhausted its
queue. Every negative run ended with the named invariant and a complete recognized
trace; timeout, compilation and malformed output are failures. These are safety
checks without fairness or eventual-completion assumptions.

Raw source hashes, commands, configurations, state counts and counterexamples
remain in `.cache/verification/table-transaction-model/20261028T212857-1617337/`
and `.cache/verification/transaction-decision-model/20261028T212858-1617334/`.
The Table specification SHA-256 is
`baa2478fc9c9c45204e33ffb416903d62187fe49998b6cbafbfbfcb7b6a9a8a8`.
The [model guide](../../../tests/verification/models/README.md#finite-local-table-transaction-model)
states symbolic-value, program, storage and failure assumptions. These runs are
not automatic production trace replay or a refinement proof.

## Integration failures retained during implementation

The initial installed gateway build failed because the console did not handle
the provisional command variant. After adding the shared outcome presentation,
the next run rejected BEGIN with `ClientTokenBudget`: SQL used the ordinary
reference reservation rather than the transaction caller-record reservation.
The following run reached BEGIN and rejected private UPDATE with
`InvalidTableStatementIntent`. Private predicate work needed its virtual evaluator
frontier, independently of the retained public source position. The fix also
selects bulk staging for private INSERT and retains workspace revision checks on
repeated buffered disclosure.

These failures remain failures. Logs are `.cache/m5-installed-transactions-first.log`,
`.cache/m5-installed-transactions-second.log` and
`.cache/m5-installed-transactions-third.log`. The failed installations are retained
privately; their credentials and raw configuration are not published. The focused
predicate-write regression then passed UPDATE, paged savepoint rollback and DELETE
against the original private row, including explicit completion of rollback.
The first isolated SDK build also failed because new source files were untracked
and omitted from its source closure; the tracked-source rerun passed. These
development observations do not substitute for committed-source qualification.

## Reproducible boundaries

`just test::sql-transactions` runs the independent HTTPS client and actual
PostgreSQL/MySQL clients against a disk-backed local node and SQL gateway. Its
finite histories cover original command identities, private cuts, savepoints,
decisions, gateway replacement, anomaly refusals and the executable three-Table
checkpoint/outbox example. It prints source provenance and command timings;
process replacement is distinct from host power loss. The application-owned fake
dispatcher tests denied/replay gates and an unknown remote result, not a real
connector or exactly-once execution.

The Catalog `transaction` test filter covers paged acquisition, bounded temporary
memory, aggregate reservations, original outcomes, retained roots, savepoints,
partial preparation/publication and disk reopen at injected lost-reply boundaries.
The storage transaction tests independently check the decision journal and Table
barriers. Current definitions, policy and ownership are required by the actual
owners. A successful finite history cannot establish arbitrary distributed
atomicity, unbounded concurrency, fine-grained predicate locking, automatic
transaction expiry or implementation refinement. Native KV/Document/Stream/Queue
participation and Station turn migration remain excluded from this Table profile.

## Installed Table profile — 2026-10-28

The complete `zig build test-sql-wire-gateway -Doptimize=ReleaseSafe -- transactions`
run passed under the pinned `sql-wire` shell at committed source
`71badbc3c5fc3d61235cb388b6944fc59c2866ad`. Its source was clean at fixture start and completion.
The configuration event records all seven executable hashes and the locked
Python/Zig/toolchain identities. Raw output is `.cache/m5-installed-current.log`;
`.cache/m5-verification-manifest.json` attributes the accompanying check logs.

The independent HTTPS client checked two-Table private reads and joins,
provisional counts, original statement retries after savepoint rollback, common
commit publication and two lost commit replies. A cancelled wait after the
recorded decision returned that decision. Competing transactions could not both
consume the other's old balance. Absent-key inserts, predicate phantoms,
ASCII_CI matches and concurrent DDL rejected the conflicting commit. Keyless
duplicate occurrences survived private mutation and rollback distinctly.

Read-only snapshots survived later commits. Gateway replacement required explicit
original-handle attachment. Revocation denied buffered repeats and COMMIT without
manufacturing an abort; an authorized rollback closed the original lifetime.
Another attachment's savepoint invalidated a retained final batch. The 40-row
private result crossed two wire batches with a delayed consumer and concurrent
public update without changing its basis. Session expiry preserved accepted
private rows for reattachment and rollback. Fixed statement/savepoint limits
refused excess SQL work while explicit cleanup remained available. DDL inside a
transaction refused without an implicit commit.

Actual PostgreSQL clients observed I/T/E state and duplicate-key failure;
MySQL observed IN_TRANS and rollback. The real console executed a TLS script
with provisional counts/rows, savepoint rollback, full rollback and read-only
commit. The three-Table example published data, checkpoint and intent together;
exact retry recovered its lost commit reply, aborted intent stayed invisible,
and the fake dispatcher preserved unknown external outcome and denied/replay gates.

The run printed 93 native command samples. Across that heterogeneous sequential
history, elapsed command time ranged from 29.603 to 7838.420 ms with median
2235.751 ms. These include durable control work and retries; they are not
isolated throughput, tail-latency or contention benchmarks. A quarter-second
read-only observer recorded 1559 samples, peak summed direct-child RSS of
776944 KiB and gateway high-water RSS of
667148 KiB across incarnations. Raw observations are
`.cache/m5-installed-resources.json`; its observer hash and limitations are retained.
The process measurements include runtime/provider capacity beyond the 16 MiB
per-transaction temporary allowance. They do not prove zero steady-state allocation.

## Component, correspondence and compatibility checks

The committed Catalog transaction filter passed 36 tests; storage transaction
checks passed 14. The common-cut regression uses disk-backed WAL and objects,
flush, compaction and Catalog reopen, preserving the logical frontier and old
WAL-inclusive cut. Quota refusal preserves pending private work; explicit abort
releases that transaction's reservation without public rows. Other histories
inject loss during preparation, decision and publication, retain original
outcomes across reopen, refuse unavailable prepared data and check paged graph
reachability. These component faults are separate from installed gateway death.

After integrating main's correspondence checks, the decision model again exhausted
3,227 states and replayed six negative controls through Zig. The workspace model
exhausted 304 states and replayed eight controls; the storage lifecycle and resident
owner models exhausted 1,200 and 149 states and replayed six and five controls.
Raw runs are `.cache/verification/transaction-decision-model/20261028T215740-1946614/`,
`.cache/verification/transaction-workspace-model/20261028T215834-1953118/`,
`.cache/verification/storage-lifecycle-model/20261029T050025-1970609/` and
`.cache/verification/resident-owner-cache-model/20261029T050032-1973401/`.
The workspace run used base `6e11bd4c4` with its adapter revision change present;
that adapter is committed in `806372169`. The storage/cache runs used committed
`810694f73`. They replay selected model counterexamples, not every production
history or a refinement theorem. The initial workspace/storage adapter builds
failed because the newly required private revision was absent; those failures
remain in `.cache/m5-workspace-model.log` and `.cache/m5-storage-lifecycle-model.log`.

All seven SQL packages, 74 protocol tests, 17 direct-query tests, the signed native
host controls, isolated Zig SDK application and Board checks passed. The grammar
suite passed 479 cases and 697 coverage obligations. Clean checkouts of
`810694f73` passed all 47 fast and 18 contract checks; reports are under
`.cache/ci/clean/810694f73516-transit-ci-jnl2vfh5/` and
`.cache/ci/clean/810694f73516-transit-ci-yzqgl3qd/`. Subsequent changes to the
installed driver added the console history without changing those library or
contract sources. No whole-CI, all-language SDK or distributed deployment pass
is inferred from these selected checks.

The exploratory debug installation reached buffered revocation and failed because
its fixture expected `AuthorityUnavailable` instead of the correct `AccessDenied`.
`.cache/m5-debug-transactions.log` preserves that failed run. The final installed
run above used the corrected exact denial assertion. No failed or skipped history
is counted as success.

The first release-mode run completed the console, anomaly, outbox, delayed-reader
and session-expiry histories, then rejected a fixture restart with
`GatewayConfigurationChanged`. It had attempted to replace the immutable execution
limits of an accepted account. The corrected schedule provisions a distinct
limited account instead of weakening that guard. The failed run remains in
`.cache/m5-installed-configuration-refusal.log`; it is not counted as a completed
installed pass. A focused recovery of that retained installation confirmed the
new account's fixed-limit refusals and explicit rollback before the full rerun.

## Closeout integration and diagnostic correction

Main through `5ae56029d` was integrated in `c28da17ef`, preserving the new gateway
architecture handoff and milestone numbering. The installed pass above predates
that merge and is not relabeled as a run of the final branch.

Final review found that a rejected ROLLBACK against an already committed decision
used serialization-abort SQLSTATE `40001`. Commit `71d478ff7` instead returns
`25000` with the known committed outcome, while a confirmed aborted COMMIT keeps
`40001`. The SQL service package passed all ten tests, including the two decision
outcomes, with that correction present. The first diagnostic build accessed the
nested decision incorrectly and failed compilation; its raw failure is
`.cache/m5-decision-diagnostic-first.log`. The corrected package run is
`.cache/m5-decision-diagnostic.log`. The full installed history was not repeated
for this diagnostic-only change.

The first closeout documentation run found the new transaction reference missing
from the site catalog and a delivery-plan label inherited in the verification
reference. The first fast run also found a handoff link missing its dated anchor.
Those failed runs remain in `.cache/m5-closeout-docs-first.log` and
`.cache/m5-closeout-fast.log`; they do not establish completed validation.

The installed output SHA-256 is
`49ce3f50e4a2afa446a68c2e17e4294434d2dbe3fcb99687c8a50c560ac7ef0a`.
The resource observation SHA-256 is
`9c6f96f6c274942c6bf0ef6026efc26ca0696984267dedcc6d170baabdf096e5`.
The corrected diagnostic test output SHA-256 is
`446eb1bfba0e7c579d72b42e3e686a5cba2419e4e81d2388c1cd17d7d003b665`.
These hashes attribute the ignored raw outputs; no credentials or generated
per-run archive is added to Git.

The corrected closeout at `6984451fe4da1378a9aab54ed708d54663bfed4e` passed all
47 fast checks in a clean checkout, including 7,965 documentation links across
671 files. Its report is
`.cache/ci/clean/6984451fe4da-transit-ci-vrtzdpcm/` and stdout is
`.cache/m5-closeout-clean-fast.log`. The handbook check passed formatting,
strict types, all nine content tests and the production build. All five Chromium
histories passed against that output at `/transit/`, covering navigation, search,
mobile accessibility, diagrams and exact downloads. Their raw outputs are
`.cache/m5-closeout-docs.log` and `.cache/m5-closeout-docs-browser.log`. These
checks qualify documentation and source consistency, not another installed
transaction execution or root-path/remote-hosting test.

`m5-closeout-clean-fast.log` SHA-256: `12c675da0660e90a5c6955262e0d3f43869a1feef1a7261ed0049c50db2f21eb`.

`m5-closeout-docs.log` SHA-256: `140408463883c073dea1fdf91a3ac8f4b7fc0e57ac003ba64d6002ab03ecc482`.

`m5-closeout-docs-browser.log` SHA-256: `b993fdbd3baf1011d26edf664bb056de6a432f2f946cbf8329f00b7388bb3e11`.
