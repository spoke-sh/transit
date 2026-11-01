# Storage and recovery: qualification history

[Archive index](README.md) · [Tests](../../../tests/README.md)

WAL, immutable objects, segments, native persistence, retained roots and physical collection.

These records preserve their original dates, sources, failures and limits. They
do not define current interfaces or qualify later changes. Commands and then-open
work describe their recorded source; use the [task reference](../../../tasks/README.md)
and [test index](../../../tests/README.md) for current navigation.

## Original workload result delivery over the signed service — 2026-11-01

Commit `41e517fa2dd60b993fab0f7f5517496f18c80aaa` exposes the existing original-result
owner through signed `workload_result.open` and `workload_result.page` actions.
The coordinated current-v1 definition is
`fddf3f8395a3626c57f1c0626de4d6bb37c783d861b00befe41d5132475957c3`.
The [delivery contract](../../../contracts/DIRECT_TABLE_V1.md#original-workload-result-delivery)
owns current semantics and limits. Independent Python/OpenSSL vectors cover open
and saved-position requests for both native selection kinds; Zig verifies their
signatures and rejects changed connections, limits, positions and account scopes.

Candidate catalog checks, selected by `-Dtest-filter='workload result'` and
`-Dtest-filter='workload token settlement'`, pass **6/6** in ReleaseSafe. They
include the prior disk, allocation-failure and post-buffer revocation schedules
plus signed request and result validation. Contract checks pass **19/19** and fast
checks **60/60**. The HTTP probe's four controls also pass after adding bounded
result-action labels. Two initial caller builds failed on the append-kind enum
conversion and decoded-row accessor; both were corrected before the complete
runtime build passed. These failed builds are not runtime proof.

A clean detached checkout at `/var/tmp/transit-m6-workload-results` runs:

```sh
nix develop --option eval-cache false -c zig build transit-node direct-table-proof \
  test-local-catalog -Dlocal-catalog-filter='shared refusals' \
  -Doptimize=ReleaseSafe --summary all
nix develop --option eval-cache false -c python3 -B tests/runner/launch.py \
  tests/storage/tables/direct_table_service.py zig-out/bin/transit-node \
  zig-out/bin/transit-direct-table-proof workload-result
```

The build passes **13/13 steps and 2/2 selected host tests**. The installed
physical-disk profile passes **595 requests**, with three withheld responses
(original claim, result open and result page) and two SIGKILL/restart boundaries.
Each partition has a 257-frame prefix, exceeding one native recovery step.
Pending result probes retain verified replay progress and reach the original
receipt on a subsequent bounded request.

Six token-bound saved workloads cover Stream append/consume, Queue enqueue/claim
and empty Stream/Queue selections accepted before the later payloads. The caller
checks independent values 10/20/30 across two-row pages, saves the second-page
positions, and resumes those exact positions after replacement. Original empty
selections remain empty; final empty pages retain complete coverage. The original
one-second Queue leases are reported expired after the configured ten-second
clock uncertainty has elapsed. Refetch does not renew or repeat the claim.
Token settlement then verifies the same native outcomes. The saved bindings and
positions remain byte-identical across phases; normal driver cleanup removes the
successful private installation. Failed installations would be retained.

| Artifact | SHA-256 |
| --- | --- |
| Clean `transit-node` | `1bd56c984974ce063769001fdd20a7fde693cc3459135bbe47e1799af03c9446` |
| Clean `transit-direct-table-proof` | `13f405b969643980c48bfb59ad99602a0f60523aa2448e2adcc74701630ca841` |
| Original saved bindings | `ff0410979be01965afd117e540197eb2e89fe4398f2e47a2b00daa791fda9283` |
| Saved delivery positions | `bd45871ee73b65ac2c9234817ada8dcbbd60670b937684d3a2c14002b9cde5e5` |
| `/var/tmp/transit-m6-workload-result-wire-owner1.log` | `d5ac3ed5f2ecbeb1e2575779a2ce9a290d725d8b4300f83c4f2b60cffd3b5c6c` |
| `/var/tmp/transit-m6-workload-result-wire-contracts1.log` | `07b775f52f1da87af9e385c35d9b9f325e47c586328fb604af5f9cd6613a2daf` |
| `/var/tmp/transit-m6-workload-result-wire-fast1.log` | `c2ad91a656aece86b1c280ed7844fa3ba4e45fb1c3cc42cf131061ee18cbdb2b` |
| `/var/tmp/transit-m6-workload-result-clean-build1.log` | `6358c80fb83d1eeb0eb06b60fc7a07e44cd44c0069d03d37b287389b72f40c44` |
| `/var/tmp/transit-m6-workload-result-installed1.log` | `dec43309cfaffa8a985449b35d68db25e58969451aae7c1f4dea19b4d404402a` |

This qualifies native result delivery and replacement recovery on local disk.
It does not qualify SQL projection freezing, SQL result recovery, workload SQL,
provider recovery, performance budgets or the complete common-revision M6 gate.

## Original workload result owner and consumption handoff — 2026-11-01

`5f939724449af97f2d21e76724233f79c9bf6e1e` adds the in-process
`DirectWorkloadResult` owner; `1fdf4c76e` adds authenticated offset-work preparation.
These compose existing native operations without adding a wire action, persisted
record format or SQL result variant. The current definition remains
`befd3999375f040599091d9e91793e16b274e32388cf8dc47d74813a2a706ddd`.
The [catalog package guide](../../../packages/zig/transit-catalog/README.md)
describes the implemented boundary and its unexposed service wiring.

The ReleaseSafe catalog selection `zig build test -Dtest-filter='workload results'
-Dtest-filter='workload token settlement' -Doptimize=ReleaseSafe --summary all`
passes **5/5** after each change. The final disk schedule verifies append/enqueue
payloads and original consume/claim selections across replacement. It closes
incomplete local deliveries, reopens from the beginning, reads multiple batches,
and verifies that a previous page survives another fetch and scratch reset.
Expired claim leases remain expired; reading never renews or repeats the claim.
Revocation after buffering withholds rows and terminal metadata without advancing
the cursor. A too-small byte budget refuses its row without advancement. All read
paths leave the accepted WAL frontier unchanged.

Original empty consume/claim selections remain empty after later appends and
replacement. A completed grouped consume prepares the exact original generation
and authenticated cursor into a saved workload body; after another replacement,
the native owner commits that handoff and recovers its original receipt. A forged
authentication value fails without advancing the WAL. An incomplete consume or
a completed positional consume cannot fabricate grouped settlement work.

The result-owner commit also passes **19/19 contract checks** and **60/60 fast
checks**. The handoff follow-up passes **60/60 fast checks**. Early compile runs
rejected shadowed fixture names and an incorrectly mutable payload slice; these
were corrected before executed tests passed. No installed SQL result recovery,
projection freezing or protocol-adapter completion is claimed by this component
evidence, and it does not close the common-revision milestone gate.

Follow-up `c1685ec75` adds owned-page cleanup and saved delivery positions for
service composition, still without a new wire action. The same **5/5** catalog
selection and **60/60** fast checks pass. Each row kind resumes its original
second-page position after a fresh open. Injected failure at each of the first
three output allocations leaks no page storage and leaves its cursor unchanged;
post-buffer revocation and terminal output also use the leak-checking allocator.
Append positions seek within the bounded frozen payload, while Stream page
validation remains with its authenticated native owner. An initial formatter
rejected the reserved Zig word `resume`; the method is named `seek`.

| Raw local log | SHA-256 |
| --- | --- |
| `/var/tmp/transit-m6-workload-result4.log` | `8947300753ab3817f06b63ab6be55aa121ec06975ec940bbd765177f919a9814` |
| `/var/tmp/transit-m6-workload-result-contracts1.log` | `07b775f52f1da87af9e385c35d9b9f325e47c586328fb604af5f9cd6613a2daf` |
| `/var/tmp/transit-m6-workload-result-fast1.log` | `08f61b2ff5991f24aa332730f02e9f7d27c3b13579bdb9ed57c1dc5c2d4f647b` |
| `/var/tmp/transit-m6-workload-handoff2.log` | `82d637ee4539c0ac87704393c6d024b5411c89e868466aa04311ba1b9e2cf090` |
| `/var/tmp/transit-m6-workload-handoff-fast1.log` | `1ea4abc6eed537041106985ee004ca98eddf1231eb4240477e77bc47c96cfcc0` |
| `/var/tmp/transit-m6-workload-position1.log` | `b8e94c425035fcff18d1345e671e0db39281cb7460b61eee94c8765ef5fc3c3b` |
| `/var/tmp/transit-m6-workload-position-fast1.log` | `d7d31295cb6c1c30b14fbc3c03b355d3d1be167b94692c4b294687da7844b9f5` |

## Frozen workload tokens and native terminal settlement — 2026-11-01

Implementation `30643158f` adds complete Stream/Queue workload references to the
existing Catalog client-token owner. Installed caller registration follows in
`b54da41b036fccecf4a998c2878f389957f527fb`. The branch was rebased onto
`f49a3da6502ac8d3e12347a3812d6d81404d8d47` before this batch; earlier records retain
their original source attribution. The shared current-v1 definition is
`befd3999375f040599091d9e91793e16b274e32388cf8dc47d74813a2a706ddd`.

The [direct contract](../../../contracts/DIRECT_TABLE_V1.md#durable-client-token-bindings)
and [Streams reference](../../handbook/reference/streams.md) describe the delivered
semantics. Token acceptance verifies the entire immutable body, current rights,
account scope and retained-byte reservation before reserving the original native
identity. Settlement reads the existing bounded partition owner and requires a
matching success or durable closure. Neither absence, incomplete recovery nor a
sticky cancellation flag supplies completion. The host preserves verified replay
progress across a pending terminal probe. SQL recovery excludes these typed
workload tokens until its workload result consumer is implemented.

Candidate component checks for this batch passed in the pinned shell:

| Owner | Command/selection | Result |
| --- | --- | --- |
| `transit-catalog` | `zig build test -Dtest-filter=workload -Dtest-filter='direct client log token' -Doptimize=ReleaseSafe --summary all` | **7/7** |
| `transit-sql` | `zig build test -Doptimize=ReleaseSafe --summary all` | **11/11** |
| Root | `just check contracts` | **19/19** |
| Root | `just check fast` | **60/60**, including 10,059 local documentation links |

The catalog disk schedule covers Stream and Queue success/cancellation over four
openings. It loses token acceptance, native data/control append and final
bookkeeping replies independently. It checks unchanged bindings, conflicting
native reuse, insufficient reservation, unavailable readers, absent receipts,
incomplete replay, revocation after buffering, sticky cancellation, exact settled
retries and accepted body/source reachability. Independent Python vectors verify
signed references and their commitments; those envelope fixtures do not claim
that their synthetic content descriptors exist in storage.

Earlier local runs exposed two fixture mistakes. The one-frame recovery control
initially completed because open had already read initialization; adding another
independent accepted frame makes that control genuinely incomplete. The lost-reply
injector initially covered data I/O only; cancellation uses reserved control I/O,
so the corrected fixture intercepts both capabilities. Production recovery steps,
deadlines and durability remain unchanged. An initial compile rejected two
shadowed identifiers, and the first fast run rejected formatting of the new
hexadecimal enum tag. All these runs are retained; none is counted as passed.

Raw local component logs and SHA-256:

- `/var/tmp/transit-m6-workload-token5.log`:
  `da82464f2a0ff66a701f6084e5d2d777bf5960ceaa202c8c336441d2e43f13a7`
- `/var/tmp/transit-m6-workload-token-sql1.log`:
  `746cf669ebbfeef20cd1fd97ab3277c62ef207a36958ff4e9212fc61142428f5`
- `/var/tmp/transit-m6-workload-token-contracts1.log`:
  `07b775f52f1da87af9e385c35d9b9f325e47c586328fb604af5f9cd6613a2daf`
- `/var/tmp/transit-m6-workload-token-fast2.log`:
  `d2526d2e49dd3c28413767133502a7531bda7e74385d3f08828ba47cc46a8621`

On clean `b54da41b0`, the installed `test::direct-workload-token` scenario
**passed** with 559 signed requests. It retains exact saved bindings, injects
lost token-binding, native-execution and terminal-bookkeeping replies, and
performs three SIGKILL/restarts over a 257-frame prefix per partition. The cold
terminal probe advances bounded recovery through a conflict response before
settlement; neither an absent receipt nor that response settles the token.
Late cancellation returns the original successful empty consume/claim. This is
process-replacement evidence, not a power-loss or performance qualification.

The clean build command was `zig build transit-node direct-table-proof
test-local-catalog -Dlocal-catalog-filter='shared refusals'
-Doptimize=ReleaseSafe --summary all`: **13/13 build steps and 2/2 tests** passed.
The installed command was `python3 -B tests/runner/launch.py
tests/storage/tables/direct_table_service.py zig-out/bin/transit-node
zig-out/bin/transit-direct-table-proof workload-token`, in the pinned shell.

| Artifact | SHA-256 |
| --- | --- |
| Node | `5bbd2f51bb7502eeab7151b08ed0f3e160c03698f7966adb26ff0a7b77e5f38e` |
| Proof caller | `31acee2b3ebe4c77a0a9ffc3c783a4f312f6512e8eff9ad66711a8d8a26c05cd` |
| Original saved bindings | `fc1a1fabf55cb54b6059f66a637240ba25d406eaf95b14057c86550429f9b72e` |
| `/var/tmp/transit-m6-workload-token-runtime1.log` | `ce2508ca1fa1dea6ede78a532dd5656fb353ab9b2ad732f0c5d7434236a6811e` |
| `/var/tmp/transit-m6-workload-token-installed1.log` | `5d4248c7119839f775cde3439dd6eb282bce1c3e42ccae78b7a04d38bc5bcd79` |

The private installation `/var/tmp/transit-table-workload-token-exeh4026`
retains the signed attempts and original binding file. SQL result reopening,
workload grammar, replacement Station services, performance and common milestone
qualification remain separate open gates.

## Workload terminal closures and installed Queue regression — 2026-11-01

Implementation `3549e606e` (identical change committed as
`97b573e69a4eb5e3a67d4f88a1d72d45fb23635d` in the qualification checkout)
adds native Stream/Queue cancellation and narrowly qualified producer/lease
refusals in the partition's existing receipt directory. The current-v1 cutover is
`54060530ffe325fd2288d8ede718720381390c5fafb60ea617eea37e1110dfad`.
Schemas, bindings, independent signing fixtures and public owners move together.
No SQL workload intent, result-reopen or Station replacement gate is closed here.

The following ReleaseSafe checks pass inside the pinned shell:

| Owner | Selection | Result |
| --- | --- | --- |
| `transit-protocol` | `zig build test` | **111/111** |
| `transit-storage` | partition cancellation; log transaction Queue/queue/terminal | **8/8** |
| `transit-catalog` | direct Stream/Queue cancellation, composition, waits and signed fixtures | **11/11** |
| Root | `just check contracts` | **19/19** |
| Root | `just check fast` | **60/60**, including 10,041 documentation links |
| Root | `zig build transit-node direct-table-proof -Doptimize=ReleaseSafe --summary all` | **10/10 build steps** |

The component selections use repeated `-Dtest-filter` arguments for the names
shown, plus `-Doptimize=ReleaseSafe --summary all`. The protocol package does not
support `test-filter`; its complete suite ran. A separate direct-contract rerun
also checks mandatory closure fields and foreign definitions against independent
fixtures. The reflector shares one closure definition across both response unions.

Disk tests lose the cancellation append reply, reopen, recover the same closure,
and reject late mutation or changed-content reuse. Existing acceptance wins
cancellation. Closure preserves offsets, logical change position, clock and
Queue state. Catalog tests preserve the global operation reservation across
partition/kind conflicts, current rights, waits, mutation and replacement.
An unavailable clock leaves settlement unresolved; confirmed lease expiry records
a refusal, does not ACK, and remains observable without a live clock. Ordinary
successful mutations retain their existing receipt lookup count. The initial
retirement fixture incorrectly reused a definition revision and was corrected to
stage a real successor before the passing run; its failed log remains retained.

On clean `97b573e69`, the actual node and signed caller pass the installed
`queues` profile with **976 requests**, four lost replies (`633001`, `633002`,
`633004`, `633008`) and 78 expiry probes. It exercises FIFO heads, wait timeout
and acceptance, original empty claims, ACK, retired-lease expiry, retained
payloads through tiering, explicit result release and terminal retention through
SIGKILL/restart. This existing profile is a cutover regression, not an installed
cancellation race proof or a large cold-recovery performance measurement.

```sh
python3 -B tests/runner/launch.py tests/storage/tables/direct_table_service.py \
  zig-out/bin/transit-node zig-out/bin/transit-direct-table-proof queues
```

The matching node/caller SHA-256 values are
`9a1d27f070f62eadeb7df75d9c4c393383a2f633f7da967e56fd330976375651`
and `88fc6e5a4c293fbb04f24caab9ae22c2289707bd360b5a1fcabdbf95c4931875`.
Raw logs under `/var/tmp/` have these hashes:

| Log | SHA-256 |
| --- | --- |
| `transit-m6-closure-catalog5.log` | `b5e1c2f4ab3e688aee0a965f902f4a5ce1bd30fe2aa5511280855de383401097` |
| `transit-m6-closure-storage4.log` | `97820e8732953657ada8ff57602491816afc404282a5ffbbb5f1d9eed60e51d8` |
| `transit-m6-closure-protocol2.log` | `7ae0c976fb8e6c6b272f0244da2f798345fff03117eaf0c36c1bc99d59f7c963` |
| `transit-m6-closure-contracts1.log` | `38c89b1c5af4901c53fbd095590a44fd12cf3179214105e0db633f822cef7033` |
| `transit-m6-closure-fast1.log` | `4617c6294c1a76249b449124121729ecad87c5ea4a1042fbb5b6a1f4322275af` |
| `transit-m6-closure-fixture-shapes2.log` | `05d6554837fd716bc8cea4a73dde7f1b14febfa7a4fbb77d193676683d7a2d7b` |
| `transit-m6-closure-runtime2.log` | `2db87328e6011d07f00bb00647dce059fefd51f0fe20a2ca061a4d40499ca6ae` |
| `transit-m6-closure-installed-queues1.log` | `dd4ab8b5af9d59b28dc19fe021a1f79d6c4cd35b14c0a2c86ae71c3b568f627c` |

## Combined bounded reads and Queue scheduling — 2026-11-01

On clean source `ed290f0ab`, the whole-object, bounded-range, private-candidate,
paged-bitmap, derived-page, Queue schedule/partition and log transaction
selections pass **44/44** in ReleaseSafe. This combines the read-path changes,
exact membership lookup and shared canonical request types. Execution reports
44 seconds and 31 MB peak RSS; compilation reports one minute and 1 GB.
The command is the whole-object selection below with
`-Dtest-filter='queue schedule'` added. The raw log
`/var/tmp/transit-m6-combined-storage-test.log` has SHA-256
`35a70724072499287926862cc0f91010b0e61ef2f01b0cbc97db348f54838b53`.
This pass does not close the separately recorded installed cold recovery failure.

## Bounded whole-object reads — 2026-11-01

Implementation `25710d9be` combines descriptor and payload retrieval for bounded
index-page and bitmap reads. The local provider opens one descriptor per read;
the composed provider path detects a conditional publication between metadata
and payload retrieval. Both return caller-owned bytes within the existing
output bound. Expected content, definition, page/container and disk chunk checks
remain in place. No resident cache, timeout, stored format or definition changes.

In a separate checkout on `1932cea7f`, the implementation later committed as
`5bd0c237c` passes **39/39 storage tests** and **6/6 native backend tests**. Inside
the pinned shell, the ReleaseSafe selections are:

```sh
cd packages/zig/transit-storage
zig build test \
  -Dtest-filter='whole-object' -Dtest-filter='bounded range reads' \
  -Dtest-filter='candidate objects' -Dtest-filter='paged bitmap' \
  -Dtest-filter='derived page eviction' -Dtest-filter='queue partition' \
  -Dtest-filter='log transaction Queue' -Dtest-filter='log transaction queue' \
  -Dtest-filter='log transaction terminal' -Doptimize=ReleaseSafe --summary all
```

```sh
cd packages/zig/transit-backend-local
zig build test \
  -Dtest-filter='direct data acceptance' -Dtest-filter='direct data candidates' \
  -Dtest-filter='direct Stream settlement' \
  -Dtest-filter='native policy revocation after Table' \
  -Dtest-filter='native storage fence after Table' \
  -Doptimize=ReleaseSafe --summary all
```

Storage execution reports 37 seconds and 30 MB peak RSS; backend execution
reports two seconds and 16 MB. An instrumented real-disk check counts two file
opens for a small object through the combined path and three through the composed
metadata/range path. A failing owner allocator permits no new allocations during
these reads. Empty/missing objects, short buffers, caller lifetimes, multi-chunk
content/checksum corruption, private derivation, missing accepted index pages,
quota reserves and current native policy/storage fences are exercised.

The first fast check refuses the changed diagnostic source inventory. After
reviewing the explicit bounds/corruption mappings and unchanged canonical binding
types, the inventory is regenerated and all **60 fast checks pass**. This remains
component evidence, not an installed cold-recovery or whole-milestone result.
Raw logs under `/var/tmp/` have these SHA-256 hashes:

| Log | SHA-256 |
| --- | --- |
| `transit-m6-object-reads-test2.log` | `3b43badc6b6813af16b494a728d6a9f90d1def757165a2b278a45caf57bb89b3` |
| `transit-m6-object-reads-backend1.log` | `6dfa57eaa4a48f49b0eeba251c9d0fd796478a802ea9d002884d52f13353ab76` |
| `transit-m6-object-reads-fast2.log` | `7b8465af36d122296ca5dad1f8d08c7de5bd37411ea2e54bdb59c98e1264e36d` |

## Exact Queue timer membership — 2026-11-01

Implementation `b56101dac` separates exact membership completion from earliest
event selection. Membership stops only after reading and validating an exact
currently eligible occurrence. Earliest selection still checks every possibly
earlier source; incomplete or stale observations cannot establish absence or
membership. It changes no format, cache, deadline or work-budget setting.

On base `1932cea7f` with the identical implementation patch, the pinned-shell
ReleaseSafe storage selection passes **30/30 tests** in two minutes with 31 MB
peak test RSS:

```sh
cd packages/zig/transit-storage
zig build test \
  -Dtest-filter='queue schedule' \
  -Dtest-filter='queue partition' \
  -Dtest-filter='log transaction Queue' \
  -Dtest-filter='log transaction queue' \
  -Dtest-filter='log transaction terminal' \
  -Doptimize=ReleaseSafe --summary all
```

The disk case establishes exact active-buffer membership with one provider read,
while earliest-event selection under the same small work budget still refuses.
Stale and different later events cannot match; a missing source still refuses.
Existing disk reopen, frozen merge-input, lease and transaction cases also pass.
The raw log `/var/tmp/transit-m6-schedule-membership-test1.log` has SHA-256
`3bff51849ea3103c37c5b4b47db63160b2f1e2ad66d8095b00ff32ad311c245d`.
This is component evidence. The [cold Queue baseline](performance.md) remains
failed until a separately attributed installed run completes.

## Queue replay cache provenance — 2026-11-01

Implementation `16484c8136d5f804fd7f5e303a7999b14c7817e0` retains only
provider-verified immutable index pages between Queue replay transitions. Newly
staged pages, unflushed batch reads and reads served by the private derivation
overlay are discarded at that boundary. It changes no stored format, definition,
page-count budget, recovery-step limit, authorization boundary or deadline.
The [storage owner](../../../packages/zig/transit-storage/README.md) describes
the cache's limited evidence.

The following pinned-shell ReleaseSafe selection passes **27/27 tests**, with
one minute reported execution and 29 MB peak test RSS:

```sh
cd packages/zig/transit-storage
zig build test \
  -Dtest-filter='derived page eviction' \
  -Dtest-filter='queue partition' \
  -Dtest-filter='log transaction Queue' \
  -Dtest-filter='log transaction queue' \
  -Dtest-filter='log transaction terminal' \
  -Doptimize=ReleaseSafe --summary all
```

The changes were tested in a separate checkout based on `e58935ced`, immediately
before committing the identical patch as `d0eb64bbd6e3939fa9355f320565e0ee1b7f845d`
and applying it as the implementation commit above. Definition remains
`2e2c775950d2d0cfa6d6ea66e078fcdfa8381c16e522c5ac7d91fb243714c7f3`.
This is focused component evidence, not a clean-source lane or performance run.

The new disk case removes an accepted item-index page, reconstructs the same
candidate bytes from WAL, and requires recovery to refuse the missing provider
page with both one and 16 resident cache pages. Restoring the original bytes
makes the unchanged WAL recover successfully. Separate cases prove that a
private overlay read and an unflushed batch cannot survive as verified cache
entries. Verified provider pages remain cache hits across derivation without
additional provider reads or backing allocations. Existing Queue scheduling,
original-receipt, lease, retention and transaction replay cases also pass.

The raw log `/var/tmp/transit-m6-replay-cache-test1.log` has SHA-256
`a41469d277370bc43b0fe49abc42ca7871d6c53391adaa94286f85df317c353d`.
The original cold-baseline timeout remains recorded in
[performance evidence](performance.md); these checks alone establish no latency
improvement or successful recovery of that installation.

## Allocation-journal cancellation and installed browser gate — 2026-11-01

The allocation-journal change committed as
`1c4106d5470cc028fe6e9c444d1be94f7f5e0573` protects one bounded append group
through sync, then restores cancellation before object/marker publication. It
changes no timeout, lease, storage format or contract definition. The focused
checks ran on that implementation before its commit, on base
`41c66c2838298344773afe413e2f10a49dc22f24`; the installed check below built
clean committed `1c4106d54`. All use definition
`8e441078693f1373d69323bfeadd5cfe8c7024ec2015819bacfb2b04eaea3865`.

Inside the pinned Nix shell, in `packages/zig/transit-backend-local`, these
ReleaseSafe selections pass:

| Command selection for `zig build test … -Doptimize=ReleaseSafe --summary all` | Result |
| --- | --- |
| `-Dtest-filter='allocation journal cancellation' -Dtest-filter='direct data creation sync failures' -Dtest-filter='batched native and direct publications'` | 4/4 tests, 25 seconds execution |
| `-Dtest-filter='allocation' -Dtest-filter='direct collection' -Dtest-filter='batched native and direct publications' -Dtest-filter='direct data creation sync failures'` | 23/23 tests, two minutes execution; eight deletion-sync and 29 marking-sync fault schedules recover |

The cancellation case delivers real cancellation during sync for native/direct
inventories and single/batched writes. Each preserves an accepted journal tail,
reports cancellation at the next cancellable boundary, retries on the same
healthy owner and reopens correctly. Genuine write/sync faults keep their
existing recovery-required behavior. Raw local logs are
`/var/tmp/transit-m6-allocation-cancel1.log` (SHA-256
`60813df3364c253c7edc5268865d0ee7ad1c823bdbbaee5081e8701813aa006f`)
and `/var/tmp/transit-m6-allocation-cancel2.log` (SHA-256
`b0959149a694dba0dc20b8eef71bcb3695a23e706b5168211a8786e439964708`).
The same implementation passes 60 fast checks, the handbook build and 10,028
documentation links across 710 files.

The clean-source `zig build test-declarative-browser -Doptimize=ReleaseSafe
--summary all` run is **an aggregate failure**, with 10/12 build steps complete.
Its main installed browser scenario passes original-claim reply loss, callback
concurrency/restart, key rotation, process death, revocation, active watches,
81 durable identities, bounded pagination, buffered policy changes and production
origin checks. The separate documented-example fixture then runs `migrate plan`
after core readiness but before the local SQL rendezvous exists. Its retained
server log records core ready at 10:55:31.446 and SQL accepting at 10:55:31.640.
Core readiness does not promise SQL readiness under the CLI contract. This
failure is distinct from the earlier allocation-recovery failure during identity
population; neither earlier failure is erased by this partial pass.

The installed run uses CLI SHA-256
`5375fa9e87f7f46a3c1605280652522461d93f0d7d37e2fd6db4ff81025942e1`,
admin `4be92c5cf7bb7c3419a8eeb17944cc030d9d5250b44cff90eb314fc0297018b3`
and fault-node `df494dfc49af5bb29766bc64c990fc11fde4ba90327beea4eb2cef92b26e8b08`.
The raw log `/var/tmp/transit-m6-browser-allocation-fix1.log` has SHA-256
`b2766bc4c6578c8bb07526db383910527f3cd112877addac2d32a625bdb1b11b`;
private example state remains at `/var/tmp/transit-browser-nfvwecjd` with those
attributions. This is focused component and partial installed evidence, not a
completed browser lane, later-definition qualification or whole M6 pass.

### Browser readiness and original native receipt follow-up

The corrected browser driver waits for both core readiness and the initialized,
bound local SQL account before invoking migration. It removes only the disposable
SQL status observation before starting a new process, so an old accepting status
cannot satisfy that check. A native administrative request is retained before
dispatch; a disconnected response triggers read-only receipt lookup for that exact
request, never submission with a fresh sequence. No runtime deadline changes.

A readiness-only rerun failed on a disconnected native authorization response.
The private node log at `/var/tmp/transit-browser-yvluwibt/node.stderr` records
sequence 66 accepted at position 78 with `response_written=false` and `WriteFailed`.
The driver trace is `/var/tmp/transit-m6-browser-readiness1.log`. That failure
remains separate from the earlier startup race and allocation-journal failure.

The subsequent complete driver invocation passes both the main browser scenario
and documented migration/configure example, including its embedded production
HTTP/WebSocket listener. It uses the same three `1c4106d54` ReleaseSafe binaries
and definition listed above, with the modified driver (SHA-256
`d4c81920160b0f1f197c135ee0b4ee6cc50bf024e7ce2a968e2ef90d6b02432b`).
The pinned-shell command is `python3 -B tests/runner/launch.py
tests/interfaces/http/declarative_browser.py CLI ADMIN FAULT_NODE`, with those
matching executable paths supplied explicitly. Raw output is
`/var/tmp/transit-m6-browser-recovery2.log`, SHA-256
`cece8da0e98061ea3c3acd11e71f16bab3f77e1538e6ac31b001307e714b3229`.
This qualifies that driver against the recorded runtime; it is not evidence for
the later protected-transfer definition or the entire browser lane.

## Integrated causal Document map trees — 2026-11-01

The first integrated storage slice connects canonical causal map changes to
`DocumentPartition` evaluation, private `.tseg` candidates and one fenced WAL
acceptance. The [Document contract](../../../contracts/DOCUMENT_V1.md#integrated-causal-map-tree-storage-slice)
and [partition guide](../../../packages/zig/transit-storage/docs/document-partitions.md)
describe the supported profile and numeric bounds. The initial implementation source is
`c781c542240dd83006f294fd845bd717b00778aa`, based on `origin/main`
`c8d060cb2dfcf3bc531ef2e41fcdf7d4f172c2d5`. The integration source
`5b81ed75dad317052a008ea5e7db7efc92e89dc2` merges `origin/main` at
`f49a3da6502ac8d3e12347a3812d6d81404d8d47`, including the upstream shared
definition cutover and client recovery work; Document implementation files are
unchanged by that merge.

Focused checks inside the pinned Nix shell pass:

- The complete `transit-document` package tests reject every truncated canonical
  prefix, exercise full-width dot ordering and borrowed wide values, and verify
  concurrent-register permutations, observed removal, detached descendants and
  refusal without changing the prior snapshot.
- The storage test `document partition evaluates` uses disk-backed WAL and object
  storage with 12 operations, a 160-byte field name and a 5,000-byte value. An
  injected lost append reply is followed by closing and reopening both stores.
  Original-operation recovery and duplicate causal changes under new operations
  preserve the original revision. Later edits, empty conflict alternatives,
  retained old reads, authenticated paging, byte/step exhaustion, wrong-path and
  cursor tampering, revocation after buffering and pin release pass. A foreign
  shared definition and an invalid dependency after an earlier candidate edit
  refuse without publishing partial state.
- The catalog graph check marks accepted logical directories and segments,
  leaves an unpublished candidate unmarked and refuses a corrupted descriptor
  marker before collection can reinterpret it as an opaque leaf. The serialized
  maintenance cursor retains its existing shape. The focused local catalog
  branch tests also pass, including collection and revocation after buffering.

These are component and local-owner checks. No installed direct Document API,
SQL or language binding is qualified by them. The representation uses paged
map/register records with chunked values; this does not establish persisted BP
topology, adaptive shredding, collaborative list/span editing, versioned merges,
logical checkpoints, collection routing/scans, Document transaction participation
or Station migration. Zero steady-state allocation and large-workload performance
remain unqualified. The installed Document service continues to use Station.

Clean-source lane results and raw evidence:

- Before integrating the upstream definition cutover, `just ci clean --lane storage-query` passed all 29 tasks at `c781c542240dd83006f294fd845bd717b00778aa`
  in 12,888.33 seconds. The clean evidence bundle is
  `.cache/ci/clean/c781c542240d-transit-ci-v25q779e/`; its
  `storage-query.meta.json` SHA-256 is
  `e23e80d607915e203da4322a8ed978996786ade703e45bde7c050250144e0e5f`.
  This result qualifies that source only.
- On integration source `5b81ed75dad317052a008ea5e7db7efc92e89dc2`,
  `just ci clean --lane core` passed all 28 tasks in 3,700.59 seconds. The
  evidence bundle is `.cache/ci/clean/5b81ed75dad3-transit-ci-smlovii7/`;
  `core.meta.json` SHA-256 is
  `7cb0135030c99d473a27d2bf161ca8c022bd704541d99d9e77096ab3607bc65e`.
- On the same integration source, `just ci clean --lane storage-query` passed
  all 29 tasks in 7,104.78 seconds. The evidence bundle is
  `.cache/ci/clean/5b81ed75dad3-transit-ci-c4axzfjh/`; its
  `storage-query.meta.json` SHA-256 is
  `02b7177dd341a78a0d219ff7c2fe5d1f123f38b15968beb3d6102a25988e86a2`.
  This includes the local catalog graph/maintenance schedule, installed Document
  recovery, and 139 initialized KV/Document resources with typed values and the
  original receipt verified before and after node SIGKILL/restart.

The clean runs use the pinned Nix development shell. The merged-source runs set
`ZIG_GLOBAL_CACHE_DIR=/tmp/transit-m7-core-zig.vE4sij` for compiler artifacts;
clean checkouts and disk-backed durability fixtures remain under `/var/tmp`.
No durability fixture is moved to tmpfs. Full multi-lane release qualification
was not run.

An earlier clean storage/query attempt at `8fb332f73` passed its first 11 tasks
but failed to compile the local catalog branch fixture because its
`DirectDeclaration.Intent` omitted the mandatory object kind. The same omission
exists at the plan base. Commit `c781c5422` identifies that fixture as a Table;
upstream independently includes the same fix at the integration base. It does
not add a runtime default or broaden its scope. The failed checkout and
logs remain at `/var/tmp/transit-ci-j4aprhyz`, including
`src/.cache/ci/runs/storage-query-4gc0v5fy/012.log`. This attempt is not a passing
lane; subsequent tasks did not run. Local artifact paths are not portable
download links.

## Bounded immutable publication groups — 2026-10-30

The [publication mechanism](../../handbook/internals/storage-runtime.md#sharing-a-content-directory-barrier)
shares directory barriers within explicit groups of up to eight immutable objects.
Native and direct index pages use these groups. Allocation inventory, quota
reservations, creator/reclamation fences and accepting WAL barriers retain their
own obligations. A group returns references only after every publication is
durable; a failed group may leave a subset visible for exact retry.

At runtime source `53df6efd2ec89d5ec5784d914ddc991ac00a74a3`, the complete local
backend ReleaseSafe suite passes **57/57**, and the registered
`just test::storage-io-faults` Debug selection passes **11/11**. Only qualification
documentation is uncommitted during these workspace runs. Independent probes
count `3n + 2` object-publication sync calls for `n` new objects: **26
instead of 40 for eight objects**, and five for one. Inventory/WAL syncs are
additional. Tests cover duplicate pages, unchanged output on failure, opposite
lock orders, every sync failure in two-object groups, partial writes, reopen,
exact retry and inventory preceding all visible native/direct content.
A compiled production negative control omits the batch content-directory
barrier and fails the intended directory-sync assertion (`expected 2, found 1`).

At `6419ea8ee966fd0f699242565cb2c4a4614afa25`, the complete source-clean formal
lane passes all 14 tasks. Object publication exhausts **397 distinct / 1,575
generated states** for one object and **3,907 / 19,439** for two; all ten
independent guard-removal controls detect their expected invariants.
The complete disk process-death suite passes **165 SIGKILL schedules**, including
15 new two-object cuts. Its earlier run completed those cuts but failed the
stale total-count assertion; the successful rerun uses the corrected 165 count.

Raw workspace evidence is under `.cache/write-publication/`: the successful
`storage-process-faults-final.log` has SHA-256
`f5d27addaab2910276c69ff97cded7626c1840dfc8f56ce73b0d6db14cd6f00a`;
`negative-batch-barrier.log` has
`865e6a0c27073539d6b317f948c9876ee756e352520d794a60b81c80b0c7ae00`.
The final `rebased-backend.log` and `rebased-storage-io.log` have hashes
`3bd948b302f08c02454cb3e0db9f6249593c185cc024da6d787f00b6c5052fed` and
`c11438c559b52f63807865836ca85a8179ca8daa2d15fc5cef89f0b7829db3dd`.
Formal completion and per-model source/configuration hashes are retained in
`.cache/ci/clean/6419ea8ee966-transit-ci-ah45bxsb/`.
These local artifacts are not portable download links.

The finite model covers one/two objects under truthful sync and atomic replacement,
not arbitrary group sizes, inventory/acceptance composition or implementation
refinement. Injected disk errors and SIGKILL preserve the operating system;
physical power loss remains untested. The
[console attempts](performance.md#bounded-publication-console-attempts--2026-10-30)
do not establish an end-to-end speedup or the interactive write target.

After rebasing onto Document storage base `a4e695de6`, the complete clean formal
lane passes again at `0cadac4e784a968fe2283e73e86e318245c6e073`. Its evidence is
`.cache/ci/clean/0cadac4e784a-transit-ci-4g2ymv5b/`. Earlier formal attempts failed
Table-only fixture compilation after Stream/Queue categories were introduced;
explicit refusal of those registrations restores the fixture's Table scope,
without extending its proof to Stream/Queue behavior.
All **48 fast checks** pass after reconciling the generated diagnostic inventory
with the rebase; fast checks do not execute the disk or installed-server suites.

Clean-source integration runs at that same revision retain two failures:

- **Interfaces:** TLS and the full Unix/HTTP/HTTPS SQL allocation controls pass.
  Native SQL passes its smaller lost-admission, lost-commit and settlement cases,
  then its original 67-row INSERT exhausts the 300-second helper deadline after
  repeated 10-second `commit_saved` request timeouts. The original operation and
  fixture remain at `/var/tmp/transit-sql-database-1pabj51r`; no new-token replay,
  split statement or increased deadline is used.
- **Installation/UI:** Board/docs checks, Node bindings, observability and server
  logging pass. The single-executable default SQL workflow passes exact values
  across restart. Its subsequent Board fault/restart fixture exhausts the
  supervisor restart budget after an intervening `HttpConnectionClosing` error;
  the aggregate task and lane fail. The installation remains at
  `/var/tmp/transit-server-proof-ft0ye3u9`.

Logs are `.cache/write-publication/rebased-interfaces.log` and
`rebased-installation-ui.log`; the clean checkouts remain at
`/var/tmp/transit-ci-im3qfz2e` and `/var/tmp/transit-ci-tbizpy4w`.
Neither lane is qualified, and subsequent tasks in each lane do not execute.
These failures do not establish their cause or a regression relative to the base.

## Direct Document protocol, succinct algebra, `.tseg` shredding, and `DocumentPartition` — 2026-10-30

Delivered packages `D0`–`D4` of [Milestone 7](../../roadmap/07-document-storage-and-station-decoupling.md)
on top of `origin/main` at `796e7fe86`:

- **`transit-protocol` (`D0`):** `DocumentDeclaration`, `DocumentOperation`, and
  `DocumentRead` with `fixtures/document-v1.json` and reflected
  `contracts/data-lifecycle-v1.schema.json`.
  `(cd packages/zig/transit-protocol && zig build test)` passes **85/85 tests**,
  and `python3 -B tests/runner/launch.py tests/interfaces/native/contract.py --data-lifecycle < contracts/data-lifecycle-v1.schema.json`
  verifies independent Python/Zig canonical JSON and HMAC-SHA-256 read cursor
  agreement.
- **`transit-document` (`D1`):** `SuccinctTree` ($2N$-bit Balanced Parentheses
  `SBPT0001` topology with two-level `@popCount` rank/select and excess
  summaries), `SpanText` (span-based collaborative UTF-8 text beyond 96B with
  interior span splitting, range tombstones, and 24-permutation convergence),
  and `VersionedMerge` (five-state cell algebra, raw-frame provenance, and
  commutative 3-way structural merges).
  `(cd packages/zig/transit-document && zig build test)` passes **14/14 tests**,
  including zero heap allocations during `SuccinctTree` navigation.
- **`transit-storage` & `transit-backend-local` (`D2`–`D3`):** `DocumentDeclaration`
  (`DDECL001`), `DocumentInitialization` (`DINIT001` `.genesis`),
  `DocumentShredder` (5-state subcolumns with `RBC1` bitmaps,
  `utf8_binary`/`ascii_ci`/`ebcdic_cp037` zone maps, and `SuccinctTree`
  residual topologies), `DocumentEvidence` (`DEVID001`), `DocumentRead`
  (`DREAD001`), `DocumentPartitionRecord` (`DOCPART1`), `DocumentRecovery`
  (`DCHECK01`), `DocumentStorageRoots`, and `DocumentPartition`, wired into
  `DataStore.trimUnit`.
  `(cd packages/zig/transit-storage && zig build test -Dtest-filter="document")`
  passes **13/13 tests** across disk reopen, duplicate operation and replica
  sequence retries, finite merge-window checkpoints, retained revision reads,
  WAL archival, recovery checkpoints, and physical WAL trim.
- **`transit-catalog` (`D4`):** `DocumentAuthority` and `DirectStorageGraph`
  reachability walking for `DINIT001`/`DOCPART1` partitions.
  `(cd packages/zig/transit-catalog && zig build test -Dtest-filter="document")`
  passes **6/6 tests**.
- **Remaining limits:** Interactive multi-object `DocumentTransaction`
  participation, SQL/Fuze lowering, and the public consumer cutover removing
  `transit-station-document` remain gated on `D5` and the Milestone 5/6
  common transaction decision for Station turns.

## Stream compaction visibility and retained candidates — 2026-10-30

The implementation committed as `4b5735304` passes the storage package's
`zig build test -Dtest-filter='stream partition' -Dtest-filter='log read'`
and the root `zig build test-local-data-collection -Doptimize=ReleaseSafe`,
inside the pinned Nix shell. These runs used the implementation worktree before
commit; they are not committed-source clean-CI evidence. The native executable
SHA-256 is `07a95a63622913e356ebe887673eb61d5a11234c6a3981745ed72c9037b5da3f`.

The disk compaction case preserves full collation keys sharing a long prefix,
tombstones and a frozen source cut through later appends, lost replies,
checkpoint/trim and restart. Bounded reads distinguish hidden offsets from
returned rows, including empty incomplete pages. A lagging group assigned after
work starts blocks candidate publication; revocation also refuses publication.
Cancel closes only unpublished maintenance. Earlier pinned reads keep their
original visible rows and accepted append receipts remain identical.

The native retained-graph case checkpoints a partially built candidate, collects
and reopens it, then completes compaction. A later checkpoint allows collection
of the superseded private bitmap while old and new pinned visibility remain
readable. Its two collection passes take 73 and 664 bounded steps and reclaim
3 and 294 allocations. The explicit age-expiry case also passes all four
collection/reopen stages (167, 1,707, 1,840 and 502 steps); the existing Table
cases pass at 225 and 2,177 steps. These are fixture counts, not throughput
guarantees. Sparse payload rewriting and signed public payload composition are
outside this evidence.

The new definition passes all 18 generated contract/independent fixture checks.
The bounded notification owner committed as `9bb6b063e` passes `zig build test`
in `packages/zig/transit-io`: register/recheck ordering, broadcast, cancellation,
absolute deadlines, capacity refusal, ticket reuse and zero backing allocation
for its warmed ticket directory. It does not yet qualify an installed consume
wait. Final committed-source integration qualification remains separate.

## Shared object content-directory barrier — 2026-10-29

At runtime source `b7d2980048305c66449b340861b114bb2a0e1024`, payload and
checksum names share one directory sync before descriptor publication. The
[mechanism and assumptions](../../handbook/internals/storage-runtime.md#sharing-a-content-directory-barrier)
preserve individually durable puts, per-key locking, exact retries and the
descriptor's file/directory barriers. There is no wire or stored-format change.

Executed with the pinned development shell on Linux x86_64:

- `just test::object-publication-model`: **397 distinct / 1,575 generated
  states**, queue exhausted; all five independently removed sync obligations
  violate their expected invariants. The model is safety-only, with one key,
  one candidate, exact retries and three abstract files. Logs/configurations,
  source hashes and traces are in `.cache/verification/object-publication-model/`.
- `just test::storage-io-faults`: **8/8 tests pass**, including a bounded probe
  identifying payload/checksum/descriptor file syncs and their two directory
  syncs, real partial writes, failures at each remaining barrier for immutable
  and conditional puts, reopening and exact retry. New-object publication uses
  **five calls instead of six**, with no dropped probe entries. This counts
  application sync calls, not device commands or an I/O latency lower bound.
- A temporary production negative control removes the shared content-directory
  barrier. The compiled probe fails with `TestExpectedEqual`; restoring the
  barrier passes. This is a selected executed regression control, not automatic
  model-counterexample replay or complete refinement.
- `just test::local-storage-faults`: **150 SIGKILL schedules pass**, preserving
  WAL data/fences/trim and original Table receipts, pins, archives, compaction
  and checkpoints. New cuts stop after either content link before the shared
  directory barrier. Descriptor file/directory cuts retain their semantic
  positions after renumbering. An initial run reached all schedules then failed
  its stale aggregate count of 149; the corrected count is 150, with no fixture
  size or timeout reduction.

Raw workspace logs under `.cache/io-publication/` include `io-faults.log`
(SHA-256 `4d1b9b15b16d6ae1c9c9bfb173a7dc07eab37f8f5bdb9c144f27fd3642b771a8`),
`disk-faults.log`
(`96ce9b56607bb1da5ffab331d3c6a4ad5305d3906ede5816e9187a13532472af`)
and `removed-content-barrier.log`
(`6c3183c2e5b3afdae8e4b5c73403bb31468ed94aefc6f84e5054ba7dd664bf99`).
The [console comparison](performance.md#shared-content-directory-barrier--2026-10-29)
records actual installed and TLS component workloads separately.

`just ci clean --check fast` passes all **47 checks** at
`5595d15cce200e90949439b8436a8eac85f58e58`, which adds only proof selection,
artifact retention and diagnostic inventory updates to the runtime revision.
Evidence is `.cache/ci/clean/5595d15cce20-transit-ci-nwvtqejq/`. Earlier fast
attempts exposed the missing formal-lane assertion and changed helper inventory;
those registrations were corrected before this clean pass. Fast checks do not
compile or execute the disk fixture.

A separate source-clean checkout at the same `5595d15cc` revision compiles and
runs `just test::local-storage-faults` without inherited workspace build
artifacts; all **150 schedules pass** again. The checkout is
`/var/tmp/transit-ci-mz30itrq/src`; its earlier failed fast-check attempt was
followed by a clean checkout of the corrected revision before this execution.
`.cache/io-publication/clean-disk-faults.log` has SHA-256
`96ce9b56607bb1da5ffab331d3c6a4ad5305d3906ede5816e9187a13532472af`.

The model assumes truthful sync and atomic replacement and excludes inventory,
WAL acceptance, concurrent reclamation and arbitrary object batches. Disk error
injection and process death preserve the operating system/page cache; neither
is a physical power-loss experiment. Cross-object batching, transducer
composition and conditional liveness remain separate obligations in #211.

## Direct request allocation and response lifetime — 2026-10-28

The question is how much private request memory remains owned when a direct
Table response starts transmission. At `74b555d8413a9b376e4a41718d445cfc2ec0cfe5`,
opt-in native request diagnostics place an allocation probe below the complete
handler allocator. Parsing, catalog work and serialization share an arena that
survives until the response finishes. The installed physical-disk
`just test direct-table-maintenance` schedule passes, but seven-row scans retain
up to 9,613,056 bytes at response time. Snapshot and storage observations retain
up to approximately 2 MiB. These are handler allocations, not whole-node RSS.

At `c15ddd1f50c47fb68c0fff7517b46b9c606d5700`, serialization allocates its exact
output independently. Parsing and catalog scratch are released before either a
success or error response is sent. The existing final authorization fence runs
before disclosure and frees a withheld response on failure. The new installed
oracle compares counted live bytes with the independently received HTTP response
length for every observed Table response; all must match.

Both sources pass the complete installed schedule with the same caller binary,
258 retained row values, seven-row pages and sixteen complete scans per arm.
They enable request metrics and use the same existing HTTP fixture. The active
arm also verifies overlapping flush progress, ten packed segments, fixed targets
after SIGKILL, retained cuts after another restart and idle convergence.

| Automatic-flush observation | Shared request arena | Independent response |
| --- | ---: | ---: |
| Scan responses | 624 | 624 |
| Maximum live handler bytes at scan response | 9,613,056 | 3,335 |
| Maximum peak handler bytes during a scan | 9,613,056 | 9,273,723 |
| Scan backing allocation attempts | 4,642 | 5,260 |
| Total scan acquired bytes | 4,233,772,544 | 4,257,742,350 |
| Node CPU during phase (seconds) | 20.40 | 20.36 |
| Complete-scan median (seconds) | 1.214 | 1.215 |
| Node RSS after phase (bytes) | 53,825,536 | 53,940,224 |

This reduces the response's private memory lifetime. It adds a separately owned
output allocation and does not eliminate working allocations or establish a
latency improvement. Both runs have uncontrolled host/cache state; inspection
traffic varies and has its own operation totals. Provider/cache allocations,
socket buffers, stacks and maintenance remain outside this probe. A pre-write
snapshot is not a post-cleanup leak check or an aggregate admission limit.

All six local catalog/maintenance checks pass at `c15ddd1f5`, including decoding
responses after their work arenas are destroyed and denying already-buffered
results after revocation without leaks. A new output-allocation failure occurs
after an INSERT commits: inspecting its original operation finds the committed
receipt, and independent reads verify the one expected row. No replacement
mutation is submitted. Both revisions also pass the full handbook build and all
41 committed-source clean fast checks.

The exact baseline binaries run separately against the new driver as a negative
control. It fails the request-memory validation gate after the disabled arm,
reporting 1,059 invalid observations; the candidate passes that same gate.
The original negative-control installation, exact executables and source record
remain private at `/var/tmp/transit-table-maintenance-rsmxoz2i`.

Raw logs are under `.cache/milestone3/`:

| Log | SHA-256 |
| --- | --- |
| `native-request-memory-installed.log` | `325963915773dcb55477262c4b7b7065d602fd7f4c932c0f0468d7fb9d7be119` |
| `native-response-lifetime-installed.log` | `378519935ee5e95ae3286eceb0a69f96d1282d9dafe8db33de8ebbbb92d33eca` |
| `native-response-lifetime-catalog.log` | `8ced5a8f9106d851eb51b8992a35e25e4ab612cbbec914034b2a2ec1f62a4aa9` |
| `native-response-lifetime-negative.log` | `3a155486fe4cc4fb0bc3ab178fa06f700ead9d10cceba6793e3d1c5fa690dcd5` |

Baseline and candidate node SHA-256 identities are
`4e507a6406d67086e7a6e5b113cb7ee622652d2cece8915bd1520ca1b4c0d180` and
`06019a634b1ab69c5bb545208cc602016e539c537fc2b0a9b4c2b617ed9c1a38`.
Both use caller SHA-256
`334b1e52093210148e4b53c64123661335d61e4526598129731e7541178bbc1e`.

### Temporary dispatch ownership after the SQL runtime cutover

The continuation at `70a552d3411eafc3fe56a63693bb9fbc1b767ef5` integrates the
merged database-owned SQL runtime. All six local catalog/maintenance tests, the
installed physical-disk maintenance schedule, the full handbook check and all
41 committed-source clean fast checks pass. This requalifies the independent
response lifetime under the combined definition; it does not establish a cap
on working allocations.

The next question is whether temporary read owners and encoding buffers must
remain in the typed result's arena. A new one-cell oracle against production
source `5dbf59c93` retains 3,165,880 backing bytes for a 220-byte encoded row and
fails its 64 KiB output bound. Candidate `26051844f24e6a54ff0e5fb55312dc6f5ea492fe`
uses the catalog's reclaimable allocator for temporary work and keeps returned
values in the output arena. The same oracle passes with 480 backing bytes, then
independently decodes the row after another dispatch and destruction of the
catalog and read owners. The four selected package tests pass in ReleaseSafe;
this fixture-specific bound is not a general request limit.

Both `70a552d34` and `26051844f` pass the same installed maintenance schedule,
using identical caller binary, drivers, phase configurations and toolchain lock.
Each arm checks sixteen complete reads of the same 258 rows across three Tables.
The candidate again preserves ten packed segments, original/flushed/maintained
cuts through SIGKILL and restart, exact fixed targets and idle convergence.
All six local catalog/maintenance tests pass, including output allocation failure
after an accepted INSERT and denial after response buffering without leaks.

| Automatic-flush scan observation | Request-owned temporary arena | Reclaimable temporary work |
| --- | ---: | ---: |
| Scan responses | 624 | 624 |
| Maximum peak handler bytes per scan | 9,229,679 | 2,598,328 |
| Total acquired scan backing bytes | 4,256,335,748 | 2,359,678,738 |
| Scan backing allocation attempts | 5,252 | 56,884 |
| Maximum live handler bytes at response | 3,331 | 3,336 |
| Node CPU during phase (seconds) | 20.82 | 20.81 |
| Complete-scan median (seconds) | 1.248 | 1.254 |
| Node RSS after phase (bytes) | 54,931,456 | 54,902,784 |

The peak drops by about 72%; backing allocation attempts increase by about
10.8 times as formerly nested arenas now release through the backing allocator.
The disabled-maintenance arm likewise lowers peak scan memory from 9,227,701 to
2,598,276 bytes; its node CPU changes from 23.34 to 23.98 seconds and median scan
from 1.377 to 1.422 seconds. These single runs do not establish a latency or RSS
improvement. Host/page-cache state is uncontrolled, and concurrent inspection
traffic differs. Every observed response still retains exactly its independently
received HTTP length; the few-byte output differences reflect observations.
Counts exclude separately owned provider/cache memory, socket buffers and stacks.
The result lowers private working memory, while aggregate request admission,
independent control reserve and whole-owner memory remain separate gates.

Reproduce the focused oracle with `zig build test
-Dtest-filter="direct dispatch retains encoded output" -Doptimize=ReleaseSafe`
in `packages/zig/transit-catalog`, then run `just test direct-table-maintenance`
and `zig build test-local-catalog -Doptimize=ReleaseSafe` from the root, inside
`nix develop`. Baseline production code uses the new oracle as a negative
control; the candidate includes it in committed source.

The complete handbook check and all 41 committed-source clean fast checks also
pass at `26051844f`. Raw logs remain under `.cache/milestone3/`:

| Log | SHA-256 |
| --- | --- |
| `dispatch-output-baseline.log` | `6d33dad88eb26a16923095087edfa031dd6c4a4c750163ffd380364c2ba132e8` |
| `dispatch-output-candidate.log` | `b67b7a1e9bc582e7f7d96f63deef78ba026d72403d0030e925822ec5869a151a` |
| `m3-integrated-lifetime-installed.log` | `02add8a64126711e60f076f28c87fbd4f9eedd0ae0c7a3daf801482664346097` |
| `m3-dispatch-scratch-installed.log` | `cc46463b38f61bbd017152ed90b8807015d1efdca622ceb0026db75ce4b1a71f` |
| `m3-dispatch-scratch-catalog.log` | `ec272d2d4aa3cb5e50f2d1ddc941475dff95124cb035f86c22045b478b8976f4` |

Baseline and candidate installed node SHA-256 identities are
`4a9302bc89ab950ceb072979da5cd14c858418364c5f11a8d8d739e08d5df369` and
`6e4667ce0c81af1a839ecba92c4c72323aab6ad02694cf8f5fdac545124daca5`.
Both use caller SHA-256
`d0c112df6eea920eed6e1a0a0e7f46c1ce3e8b51a770658c0b9575b8c4c05490`.

### Direct request admission and reserved recovery memory

At `d39d5a2d4ce14b2eef5d7e05dd2092daaf59e241`, the local listener meters
parsing, private catalog work and successful response buffers through one
request budget. Ordinary requests have a 128 MiB individual ceiling and share
256 MiB across the listener; Table controls share an independent 64 MiB reserve.
The [public node limits](../../../apps/transit-node/docs/growing.md#public-surface-and-limits)
describe the refusal and original-operation recovery behavior. The budget owns
no idle slab. Temporary work releases capacity before transmission, and the
serialized response releases it after the joined write returns.

The seven tests in `zig build test-local-catalog -Doptimize=ReleaseSafe
--summary all` pass inside `nix develop`, against the local disk backend. The
extended signed dispatcher schedule reserves every ordinary request byte, proves
that a lookup fails allocation, and inspects the original committed INSERT after
its reply allocation was deliberately lost. Pin release also succeeds while
ordinary capacity is exhausted. Each control response survives destruction of
scratch with only its encoded byte length charged; cleanup returns its accounting
to zero. The existing final-authorization, retained-row, collection, maintenance
and restart checks remain in the same run.

The additional memory-owner unit holds an actual response buffer across another
request's refusal, independently allocates control bytes, verifies the retained
contents, then frees the response and admits the next ordinary allocation. This
is allocation-lifetime evidence, not an installed slow-socket or cancellation
fault schedule. Provider caches, native requests, socket buffers, stacks and
maintenance are outside this request budget. Whole-owner memory, combined
foreground/maintenance pressure and the complete installed fault matrix remain
unqualified by these tests.

The recovered fixture change at `2c7fbab25` also passes the Debug local catalog
schedule without increasing the stack limit. The preceding main revision's
[core and growth CI failures](https://github.com/spoke-sh/transit/actions/runs/40729895693)
crash in the nested catalog authorization schedule. The fixture now keeps its
large retained protocol responses in leak-checked heap owners, including the
error-path temporaries created by `expectError`. This changes test ownership,
not the public response representation.

At `d39d5a2d4`, the ReleaseSafe node build, complete handbook check and all
41 committed-source clean fast checks also pass. These selected results do not
establish a complete clean integration pass or a latency improvement. The host
also runs independent qualification work; elapsed times are not performance
evidence. Raw logs remain under `.cache/milestone3/`:

| Log | SHA-256 |
| --- | --- |
| `resumed-catalog-debug.log` | `49493e94584878da19e48628a90acf31d42692305d9e67faa172b808772a4bf2` |
| `request-memory-catalog.log` | `7260441e19149f2938db1129fec708468c205fac9b21bac1dcd17f4d19b3e65d` |
| `request-memory-docs.log` | `94fac7ba87ad0f2c996743345f7c00d250ac0ac1bedea13ad2b4f696bf5a7ea4` |
| `request-memory-clean-fast.log` | `d6f31e074f5977d09bac0dcd51cf9a11b6b132c3aabe7da4ac03bb08e484c354` |

The clean `experience` lane at `d39d5a2d4` passes Board checks, the handbook,
Node binding checks and observability, then fails `server-logging` during
installation startup. The manager exhausts its native bootstrap retries with
`AuthorityTimeout` on `associate`; the SQL lifecycle/revocation checks are not
reached. The failed installation remains private at
`/var/tmp/transit-server-proof-5qehq38t`. The cause is not isolated by this run;
it is not a passing lane or evidence that the new Table budget was exhausted.
Its complete log is `.cache/milestone3/request-memory-clean-experience.log`,
SHA-256 `7a204757a2c5c4c9d11f7509a5187c544441008a25f3aa5a511aa69bc053d7ca`.
The final public-limit clarification and this section's initial account at
`ca8a914bd` also pass the complete handbook check; its log is
`request-admission-final-docs.log`, SHA-256
`f38fc1ee57095141ebdd7f2d3a99f49eae0e2601c82e9782c51d3ba23ad52d67`.

### Installed slow clients and reserved recovery

The follow-up asks whether ordinary capacity stays bounded while HTTP body reads
or response writes remain blocked, and whether the original accepted operation
can still be inspected. The complete `just test::direct-table-service` schedule
passes 2,128 typed calls with the pressure driver committed at `def07bd0026c`.
The node uses production source `05fda5b01`, shared definition
`ce60856690e2f9c5d0dbc62a1c07f8331aba8909ce35e29c6f314064e444d9eb`,
ReleaseSafe, the pinned Zig toolchain and physical disk under `/var/tmp`.
The new caller first independently verifies the retained 64 KiB row and its
original cut. Pressure reuses that signed immutable scan and the exact saved
accepted-operation inspection; it submits no replacement mutation.

Two incomplete body readers exhaust a 1 MiB ordinary budget. Separately, a
client pipelines the same scan without consuming responses until the server's
joined write retains exactly its 89,125-byte serialized response. Partial body
readers then exhaust the shared capacity. Both schedules exercise disconnect
and the configured five-second request deadline, require a typed `StorageQuota`
refusal, resolve the unchanged original outcome through the independent control
reserve, and observe ordinary use return to zero without replacing the owner.

| Schedule | Ordinary limit (bytes) | Observed peak (bytes) | Control peak (bytes) | Ordinary use after cleanup |
| --- | ---: | ---: | ---: | ---: |
| Incomplete bodies, disconnect and deadline | 1,048,576 | 714,596 | 883,253 | 0 |
| Retained response plus bodies, disconnect and deadline | 2,962,856 | 2,962,856 | 783,069 | 0 |

The response schedule chooses its limit from the independently observed complete
scan's private peak, within the public configuration bounds. The body schedule
can refuse a growing allocation before consuming every byte. Socket buffers,
provider caches, stacks, native requests and maintenance remain outside this
budget. The recorded CPU/RSS/I/O observations are not a matched performance
comparison; concurrent host work prevents latency attribution. The original
CRUD/DDL, history, retained-reader, namespace, lost-reply, current-revocation and
restart assertions all pass after restoring the default request configuration.
The method belongs in the [storage test guide](../../../tests/storage/README.md).

The separately executed local catalog suite also passes with the observation
test committed at `0e8f04473`. It checks finite maintenance failure categories,
counter saturation, preservation of the last failure after a successful step,
and unchanged durable position/allocation accounting. Its existing disk schedules
settle four Tables in 120 maintenance units, preserve retained obligations across
collection/reopen/revocation, and reach idle for both collection owners. These
results precede the rebase and do not qualify the new combined definition.

The clean `experience` lane at `05fda5b01` passes Board checks, documentation,
TypeScript bindings, observability and server logging, then fails the installed
single-executable SELECT after successful CREATE, INSERT and two ALTER commands:
`Conflict (55000): SqlServiceError`. Its installation remains private at
`/var/tmp/transit-defaults-tq0vxi2z`. A separate installed direct-SQL schedule also
fails its first SELECT, with state at `/var/tmp/transit-server-proof-aj15zj1h`.
Two diagnostic attempts fail earlier in bootstrap with `AuthorityTimeout`, with
and without owner request metrics. They execute no query and do not identify the
cause of the SELECT failure. Their private installations remain at
`/var/tmp/transit-server-proof-s9msgnhg` and
`/var/tmp/transit-server-proof-ywdmj45x`. No failure is a successful timing sample.

Raw logs remain under `.cache/milestone3/`:

| Log | SHA-256 |
| --- | --- |
| `closeout-request-pressure-v2.log` | `f2652d760b20a28dde6ddedac3f4180734a6d019e17b9a4a054c268e2af85b6b` |
| `closeout-owner-observation.log` | `c9c279891075cd1611aff19ef9806b2c353257ae958802496a7dd13b7e237bae` |
| `closeout-clean-experience.log` | `23aa0c57aea85c3a8a614f0bcd82e0e9b105501e705bd7ca8de3acf5d8054610` |
| `closeout-direct-tables.log` | `e26bb6858ea02cf79481de6d34692217c244d8b53e5c53ad6f1b215d785dc6db` |
| `closeout-sql-conflict-trace.log` | `3f6a33ede9a5edee24fd6f50de69c525b1ea496de0508d0f51c86dc08fa3a11d` |
| `closeout-sql-conflict-transport.log` | `e6e522dc7f81eb5027dd44a6cc3677079442542e0f1fe4e4f5ae75194cc6f7db` |

After rebasing onto `2eea90c65`, the combined source at `8c16c4d7a600` uses
definition `8d33a5642dfcc05496cfe1b6558cdc07246ec5f17790750a5f28cfe9c81b3a8f`.
All 41 fast and 18 contract checks pass in clean checkouts. The raw log
`closeout-rebased-clean-contracts.log` has SHA-256
`f0967c3a686b042db59258a6a9411fff9afca6bcd4756eccb2d415ed7e67e5a4`;
automatic completion records remain under `.cache/ci/clean/`. These scopes
validate the regenerated definition and resources, not installed integration.

## Reusable private Table maintenance workspace — 2026-10-28

The question is whether sequential maintenance units can reuse bounded private
storage without obtaining more backing memory after admission. The baseline at
`e01dcc6e03e49203c57e056ae27cd2ee25f38c0a` adds the shared allocation probe;
the candidate at `6e6f9dc4471d5eb75db97325bb0b3fc8c397c336` admits one slab
under the existing maintenance byte budget. Both run
`zig build test-local-catalog -Doptimize=ReleaseSafe --summary all` inside
`nix develop`, sequentially against the real local disk backend. The baseline
passes six tests and the candidate passes seven, including the new disabled-work
and cold-admission refusal checks. An earlier baseline attempt at `60ec2468a`
fails compilation because a restarted fixture omitted its allocator; it supplies
no runtime result.

| Private boundary observation | Baseline | Reused workspace |
| --- | ---: | ---: |
| Total scheduled units across four Tables | 122 | 122 |
| Startup backing allocations | Included in work count | 1 |
| Work backing allocations | 6,954 | 0 after the first unit |
| Work growing resize/remap attempts | 21 / 0 | 0 / 0 after the first unit |
| Backing allocations during sixteen idle units | 1,114 | 0 |
| Peak requested private bytes in the four-Table schedule | 4,229,884 | 4,229,884 |
| Peak occupied slab bytes, including headers/alignment | Not applicable | 4,230,400 |
| Retained private backing after work | 0 | 134,217,728 |

The candidate seals the parent allocator after its first unit. The subsequent
121 work units and sixteen idle units must complete without allocation or
growing resize/remap attempts. Removing the admitted workspace deliberately
trips the sealed probe before catalog access. Discovery/recovery hints are
discarded once while the workspace survives; this is not a process restart.
Original receipts, logical positions, history floors and retained rows remain
unchanged. Automatic collection's existing clock-failure, revocation, reopen
and eventual-idle assertions also pass.

Reuse changes the memory lifetime: the whole 128 MiB backing reservation stays
admitted until the joined maintenance owner is destroyed. It is not equivalent
to the approximately 4 MiB occupied by this schedule, nor to resident pages.
The separate physical-flush case reports 29,397,310 peak private bytes in the
baseline and 37,786,214 in the candidate. The complete test processes report
rounded maximum RSS of `36M` and `282M`; those include other cases, simultaneously
retained fixture workspaces and teardown. These increases must remain visible
alongside the allocation reduction. Neither these single runs nor their elapsed
times establish an installed speedup or aggregate memory improvement.

The probe excludes engine caches, provider buffers, collection, foreground
requests, stacks and the kernel file cache. The
[qualification method](../../../tests/storage/tables/maintenance.md#private-maintenance-allocation-boundary)
requires separate installed CPU/RSS/I/O and foreground observations. The complete
request-arena and concurrent-admission gates remain open.

Raw logs remain under `.cache/milestone3/`; the exact identities are:

| Variant | Log SHA-256 | Test executable SHA-256 |
| --- | --- | --- |
| `maintenance-memory-baseline.log` | `f8f05813dea4f7017825d60240fe450ffb028f0e3fd907536efdeebc7b57023b` | `ec9c18b7c2a8602015ef3484dd0c9b43a651739d1c96c8a925902fae17fa2f7d` |
| `maintenance-memory-reuse.log` | `a53bec7435a1019e99babf4bc3cc9d563911b57822b2eed4986be0cefc7aaafc` | `42479a66901861d9cf9c73005397e13ed7c9b577fe602b94f7d5409c7c54773c` |

### Installed cost of the initial workspace

The same `6e6f9dc44` candidate passes `just test direct-table-maintenance`,
including independent values for all 258 rows, foreground overlap with flushing,
fixed targets after SIGKILL, retained cuts after restart and idle convergence.
Flushing produces ten segments in 8.062 seconds; subsequent archive/compaction
recovery and verification take 22.417 seconds without rewriting packed segments.
Total task time, including compilation, is 341.95 seconds.

Compare the automatic-flush arm with the earlier `77f9fb503` clean growth run.
Both retain profile SHA-256
`86a6a118af09e4fe8433c77b6c2699c18f3938ea4f4237f2434585c7527aa023`, sixteen
independently checked scans and identical fixture limits. Each is a single run
with uncontrolled host/cache state, so small timing differences are not evidence
of a speedup or slowdown.

| Active flush observation | Before retained workspace | Initial workspace |
| --- | ---: | ---: |
| Scan duration minimum / median / maximum (seconds) | 1.147 / 1.203 / 4.748 | 1.142 / 1.215 / 4.131 |
| Node CPU during phase (seconds) | 20.37 | 20.29 |
| Node RSS after phase (bytes) | 53,850,112 | 187,965,440 |
| Node lifetime peak RSS (bytes) | 74,219,520 | 194,596,864 |
| Node kernel write-byte increase | 11,550,720 | 11,550,720 |

The candidate's disabled-maintenance arm ends at 53,911,552 resident bytes.
The active arm's approximately 128 MiB additional RSS prevents accepting this
candidate as an aggregate resource improvement. Reduced backing allocation
counts have not produced a clear installed latency or CPU improvement.
The pinned Zig allocator's typed allocation helper fills the whole returned
slice with `undefined`, which poisons unused capacity in ReleaseSafe builds.
This supplies an initialization mechanism to investigate; occupied private bytes
and admitted capacity remain distinct quantities.

The candidate log is `.cache/milestone3/maintenance-workspace-installed.log`,
SHA-256 `a34214bc6349dcccfc1d8086f9b3abe1207180abb4b57f8ab6a8428b13b7d109`.
Node and caller SHA-256 identities are respectively
`2dcd2460dd35a6b9bb3362b96a7b5c387630fa1b9a3f67a00b66d8e02c57762a` and
`d6d1f6b5e2787edb1c8ceab27d19fe89cc0c90f87c42b0fcb62bb0e87469ddf6`.
The baseline record remains in
`.cache/milestone3/current-77f9fb503-clean-growth.log`, SHA-256
`88b0a047c4268c2f80100eef885c1153752f76b730e91b89aecc2d4c62cf4f8b`;
that lane is incomplete because its final duplicate catalog growth schedule was
deliberately interrupted. Its completed maintenance task remains distinct from
lane completion.

### Admission initialization control

At `79c04aec0`, `Slab.init` obtains raw aligned backing through its supplied
allocator, charges the full capacity and initializes its own metadata without
filling unused payload bytes. Ordinary borrower allocations, `reset(true)` and
full-reserve destruction retain their initialization/erasure behavior. The
standalone memory package passes all 18 tests in ReleaseSafe. A prefilled backing
control verifies untouched unused bytes, full budget/probe charges, erasure on
reset and zero remaining charges after destruction. Restoring the previous
initializer makes only that new check fail; the other 17 checks pass.
These are package controls, not an installed RSS result for this follow-up.

The subsequent installed schedule passes at
`bcaecb7015d0c5d83798b23fe9621b2ec5d527c9`, with all retained-value, restart,
fixed-target and idle assertions. Flush convergence takes 8.080 seconds and
archive/compaction recovery plus verification take 22.157 seconds. Active reads
have minimum/median/maximum durations of 1.087/1.194/4.079 seconds; node CPU
is 19.98 seconds. Active RSS after the phase falls to 92,319,744 bytes and
lifetime peak RSS to 98,619,392 bytes. The disabled arm ends at 53,919,744 bytes.
Kernel write-byte growth remains 11,550,720; kernel reads are 200,704 bytes in
this run, reinforcing the uncontrolled-cache limitation. All 41 committed-source
clean fast checks also pass at that revision.

The follow-up removes most of the initial reserve's extra RSS, but the remaining
approximately 38 MB increase over the original baseline has no clear measured
CPU/latency benefit. **The retained maintenance workspace is not adopted.** The
local owner returns to its existing per-unit byte budget and releases private
allocations after every unit; allocation instrumentation remains. The shared
slab-initialization correction retains its independent memory-owner tests and
full accounting/erasure behavior. This decision makes no zero-allocation or
aggregate node resource claim.

The follow-up log is
`.cache/milestone3/slab-admission-installed-maintenance.log`, SHA-256
`1eaac401d896faa04f5845ccd11f595d1ec1b85178d3fa374d4ff666c6848a95`.
Node SHA-256 is
`5f18a7bb7fe4ea689fb604a4d675f898a81c40d65ecdbe8063505d74bdf1027f`;
the caller remains `d6d1f6b5e2787edb1c8ceab27d19fe89cc0c90f87c42b0fcb62bb0e87469ddf6`.

The final per-unit implementation at
`749e9ae89a49c4d417317760d1305e114669277b` passes the same installed schedule.
Active RSS returns to 53,841,920 bytes, with lifetime peak RSS of 75,329,536
bytes. Active scan minimum/median/maximum durations are 1.160/1.214/4.131
seconds; node CPU is 20.62 seconds. The disabled arm ends at 53,694,464
resident bytes. Kernel reads remain zero and writes increase by 11,550,720
bytes during flushing. The original 258 rows, ten packed segments, fixed
maintenance targets, restart checks and idle convergence all pass. Flush
convergence takes 8.146 seconds and archive/compaction recovery plus
verification take 22.443 seconds. The full handbook build and all 41
committed-source clean fast checks also pass at that revision.

These observations support releasing the private memory between units; they
do not establish improved latency over the baseline. The final installed log is
`.cache/milestone3/maintenance-budget-restored-installed.log`, SHA-256
`0e3e76741426b613ee53635259c11c47228db6e2ef076c4022c66e74fca4e058`.
Node SHA-256 is
`fa18e100992cbf8f424dc48aaf1411b95187b86f0a2af3a813cec2e1666a2787`;
the caller and profile identities remain unchanged.

## Installed packaging recovery and repository qualification — 2026-10-28

At frozen source `4d778efa9ffc5a8ad3e012bcecee1cc9887621db`, the committed-source
clean core lane passes all 28 tasks. The clean experience lane passes Board,
handbook, Node bindings, observability and server logging, then fails the
single-executable packaging check: the bare console's five-statement input
exceeds its existing 90-second deadline. Later experience tasks and the queued
growth lane do not run. The core and experience schedulers were deliberately
paused while separate focused qualifications ran; their elapsed times are not
normal CI cost measurements.

The failed private installation is preserved at
`/var/tmp/transit-defaults-76to68v2`, with a stopped pre-reopen copy at
`/var/tmp/transit-m3-single-before-_fcw13_j`. Reopening the original directory
with its original executable and configuration preserves installation and
provisioning identity. Public operation inspection finds CREATE 81 and INSERT
130 applied, and ALTER 178 active. A subsequent observation reports ALTER 178
applied under that same identity; no statement is resubmitted. Read-only
`DESCRIBE packaging_probe` verifies schema revision 2 and the ADD-time default
of 7. The later default change and SELECT were not submitted by the timed-out
console. This establishes original-operation recovery, not successful completion
of that packaging attempt or the cause of its timeout.

Executable SHA-256 is
`83bad48fa4670ef0212c57cf69545e968bf82f9632cddaad339277115b6aff30`, under shared
definition `2ff943e62985cd5e79c0928bd2aadfc24b7a4a118d95acb85959b909f8ff3188`.
A fresh diagnostic control with those identical executable bytes and the
`21fd03b93` driver passes the default startup/console, segment publication and
restart-value checks. Its five-statement console phase takes 29.449 seconds;
the unchanged deadline is 90 seconds. Half-second public recovery-health
observations remain ready during that control. The driver now retains partial
console stdout/stderr on failure and each startup's stderr separately. This
control excludes the later Board interruption schedule and does not replace
the failed clean lane or qualify subsequent implementation changes.

Raw records remain under `.cache/milestone3/`:

| Record | SHA-256 |
| --- | --- |
| `rebased-4d778efa9-clean-core.log` | `a646aa911e29ee23ed4a321e3852cbf013cdddfc1c4d2a47aae91915b554ebf4` |
| `rebased-4d778efa9-clean-experience.log` | `236fea7ce9ff141defc42980e938bc0ca7223a2d50b148f3edf2b02ae8c6f852` |
| `single-executable-original-inspection.log` | `3f807b5d3203f81dba61881383d295182f09903dee2cbfe1e69fc2fe08d988d8` |
| `single-executable-control.log` | `4f663b846acfd066ffb3102ddb498013ab4b7d06b84e6079c0f02f924951bb9f` |
| `single-executable-health.jsonl` | `4e0b71f5263b90dce73af1eeb110f954611bb3fe4218c0de75cd4cd09a7c3eba` |

### Headless shutdown observation

The later clean experience run at `77f9fb503` passes its first five tasks and
the default single-executable workflow, then exceeds the headless fixture's
20-second shutdown deadline. Its manager logs completion after approximately
31 seconds. The private installation at `/var/tmp/transit-server-proof-pjh7mc58`
has no database-wire listeners; attributing that delay to active wire draining
is unsupported. The log `current-77f9fb503-clean-experience.log` under
`.cache/milestone3/` has SHA-256
`87605dd07a1a7573b1055d114b94481f4da846c7c5b9b3d0b988f7125cd5a468`.

After preserving a stopped copy at
`/var/tmp/transit-m3-headless-before-ilnf3rgp`, two diagnostic reopens use the
same installation, configuration and executable SHA-256
`c0f0e320308d82f7a1544df5cca78d75a8444c2a3e172759407adc5521c4904e`.
Both reach local SQL admission before SIGTERM. Shutdown takes 0.827 seconds
with process-state observation and 0.821 seconds with signal/wait/exit tracing;
both managers exit zero and every owned role joins. Installation/provisioning
identities remain unchanged; no SQL is submitted. The diagnostic log is
`.cache/milestone3/headless-shutdown-inspection.log`, SHA-256
`ec73c5d9159f862220192bafb251f21515bcb58999dacef89b7f880b962f66e8`.

The complete [GitHub experience lane](https://github.com/spoke-sh/transit/actions/runs/40683696166/job/122801112580)
also passes at merge source `cd68d6c63310c04637e741cf26272d87bc2da95c`,
including default/headless packaging and browser checks. These later results
do not reproduce or establish the cause of the earlier local shutdown failure.
No production or fixture deadline changes.

## Collection progress across clock failure — 2026-10-28

At `aa8b68bae61281d108502899aabe952ce766b1e8`,
`zig build test-local-catalog -Doptimize=ReleaseSafe --summary all` passes all
six disk-backed local catalog/maintenance checks. The existing automatic
collection schedule now makes the trusted clock fail while both native and
direct collectors wait for reader grace, then removes the clock entirely.
Neither case advances the accepted native position or either collection's
persisted progress, and both known orphan objects remain present. Restoring the
clock continues the existing revocation, regrant, reopen, fixed-target, eligible
deletion and eventual-idle assertions. The six-minute grace is unchanged.

The raw log is `.cache/milestone3/collection-clock-local-catalog.log`, SHA-256
`75bc334572823d2eabf94a655b6f92a25a81e786d21b8668f4f20e88602928e6`.
All 41 fast checks also pass. This exercises the local owner's controlled clock
and durable progress, not a wall-clock process-death schedule or the complete
installed failure/resource matrix. It does not close the broader maintenance
qualification gate.

## Foreground reads during automatic Table flushing — 2026-10-28

At clean source `4d778efa9ffc5a8ad3e012bcecee1cc9887621db`,
`just test direct-table-maintenance` passes on physical disk with ReleaseSafe
binaries. The [method](../../../tests/storage/tables/maintenance.md) compares
sixteen full scans with Table maintenance disabled and sixteen with automatic
flushing enabled. Each scan independently verifies all 258 values across the
same three retained Table cuts, using seven-row pages and one resident node
page. At least one completed scan overlaps observed flush progress while rows
remain pending. No new pins or mutations are submitted by the reader.

| Observation | Table maintenance disabled | Automatic flushing |
| --- | ---: | ---: |
| Scan duration, minimum / median / maximum (seconds) | 1.602 / 1.679 / 1.780 | 1.496 / 1.607 / 5.085 |
| Whole measured phase (seconds) | 27.028 | 31.052 |
| Node user + system CPU during phase (seconds) | 36.00 | 28.68 |
| Node lifetime peak RSS (bytes) | 111,304,704 | 121,298,944 |
| Node kernel write-byte increase | 0 | 11,550,720 |

The first two active scans take 5.085 and 3.670 seconds. The remaining scans take
1.496–1.679 seconds; the lower active median does not erase the initial delay.
Automatic flushing produces ten independently verified segments in 8.158 seconds
including restart. The subsequent archive/checkpoint/compaction schedule passes
SIGKILL recovery, fixed-target preservation, original retained reads, unchanged
packed segment files and idle convergence in 25.624 seconds. Total task time is
360.81 seconds including compilation.

The raw runner log is retained as
`.cache/milestone3/rebased-4d778efa9-foreground-maintenance.log`, SHA-256
`4bb0a7940e7fa5ae477e183ef5ab561c756b005cdf22c26db34d8815461a7051`.
Its machine-readable resource record includes every sample, configuration,
process-incarnation check and source/toolchain identity. Node SHA-256 is
`cf3880021c1ce6c9ed2ce90cdea3144ab2eca0824f82c561c3f95a93702c2163`;
caller SHA-256 is
`9023ab44ecf31eab02f2dfced7a4d8b23fe280691251423f2c28dc6361d5c15b`.

Both arms retain default native/direct collection eligibility. Host page cache
and warmup differ, and the active phase includes flush convergence. CPU/RSS/I/O
cover the node, not the separate caller and proxy; lifetime peak RSS is not a
maintenance allocator peak. These observations demonstrate retained-read
correctness under concurrent progress, not a matched implementation speedup,
tail-latency guarantee, zero-allocation path or aggregate resource bound. Larger
Table populations, foreground writes and archive/compaction contention remain
separate qualification obligations.

### Response allocation follow-up

At clean source `89e88a39be4eacbb0b5250c177dd8285771a3258`, direct Table
responses count their encoded size before allocating output, replacing the
unconditional 16 MiB response allocation. The wire bound, request-owned lifetime
and final authority fence remain unchanged. The protocol suite passes 64/64,
including exact escaped-byte bounds, refusal before allocation and backing
failure. All six local catalog/maintenance checks and all 41 fast checks pass.

The same installed maintenance task passes again. Its retained-source profile
SHA-256 (`86a6a118af09e4fe8433c77b6c2699c18f3938ea4f4237f2434585c7527aa023`),
both driver hashes, toolchain lock, row/page counts and configuration overrides
match the preceding run. The observations are:

| Observation | Table maintenance disabled | Automatic flushing |
| --- | ---: | ---: |
| Scan duration, minimum / median / maximum (seconds) | 1.247 / 1.319 / 1.421 | 1.058 / 1.208 / 4.220 |
| Whole measured phase (seconds) | 21.311 | 24.862 |
| Node user + system CPU during phase (seconds) | 22.65 | 20.02 |
| Node lifetime peak RSS (bytes) | 60,338,176 | 75,059,200 |
| Node kernel write-byte increase | 0 | 11,550,720 |

All 32 retained scans verify their values. Flushing again produces ten segments,
in 8.230 seconds including restart. Archive/checkpoint/compaction recovery,
original snapshots, unchanged packed segments and idle convergence pass in
22.623 seconds. Raw evidence remains in
`.cache/milestone3/response-sizing-foreground-maintenance.log`, SHA-256
`786e78f999e47f71c8b3c7163a521979c021eab41733fbc542b5fbfc0f2e114b`.
Node SHA-256 is
`a127427e4d39b540fd91dee46d41de5e03d23748cf9fed1b1507f8d63137a66a`;
caller SHA-256 is
`334b1e52093210148e4b53c64123661335d61e4526598129731e7541178bbc1e`.

The fixture/source identities make the workload comparable; they do not control
host load or cache state between runs. Lower observed CPU, RSS and scan times
are not a multi-run speedup estimate. Serialization now makes two passes over
each response, which still allocates its exact output. Large-response CPU cost,
concurrent foreground writes and aggregate admission bounds remain unqualified.

## Installed storage settings — 2026-10-28

At `cf0209275fc0d6c75f50419268fe7418049472a3`, `just test server` passes the
existing installed configuration and complete local server lifecycle on physical
disk. The configuration schedule now checks all fourteen storage settings through
`transit_settings()`: defaults, byte/duration normalization, accepted configured
values separated from active values, restart-pending flags and the actual node
configuration after restart. An archive work limit above eight is rejected without
replacing the accepted configuration or changing the running node. The existing
exact reload retries, competing generations, history-index recovery and refusal
of missing retained configuration remain in the same passing schedule.

The enclosing server trace also passes console results, interrupted original
operation recovery, role/manager replacement, revocation and DROP/name reuse.
Its runtime is 324.16 seconds, excluding the build; this is one correctness
schedule, not a latency benchmark.
Raw log: `.cache/milestone3/storage-settings-server-retry.log`, SHA-256
`33396ca75ef95c406de1c6337f1e547329b668b392289a1d1ca1309134fae905`.

The first attempt at `e897fb493` failed in the fixture: console discovery validated
the deliberately invalid local file before connecting, so no reload command
completion existed. The corrected schedule uses its saved public connection to
ask the running configuration owner to reject that file. Its assertion still
requires a recorded rejection and unchanged accepted/active settings. The failed
log remains `.cache/milestone3/storage-settings-server.log`, SHA-256
`c8a5fb5422f7ea6850ee0f2ca272d4483599f22e13ded4f146b960737e38a00f`;
its private installation remains `/var/tmp/transit-server-proof-4ixihwpl`.
The successful fixture is removed by its ordinary cleanup.

This establishes the settings lifecycle, not live backend/path, quota-use,
maintenance-failure or Board inspection. The complete combined clean-source
qualification remains separate.

## Original SQL diagnostic outcome recovery — 2026-10-27

Two retained physical-disk diagnostics are reopened with their original
ReleaseSafe executables and shared definition
`47c035195248bf570ed52323112b2a32622ee69714ffb7719124218e034b1b2b`.
All five executable hashes match their original reports before restart; private
copies preserve both installations before recovery. Current-definition binaries
are not used against these older installations. Public operation inspection and
independent row readback establish the following, without replacement mutations:

- The instrumented `8b19eaebb` run (`--repeat 1 --rows 8`) had timed out during
  its three-row INSERT. All eleven original operations are terminal after
  restart. The INSERT's original receipt reports three matched/changed rows;
  SELECT verifies keys 0–8 at 100 and the three inserted negative keys at 1, 2
  and 3, for exactly twelve rows.
- The instrumented node-only `ff2d2e45e` run, with other roles at `8b19eaebb`
  (`--repeat 2 --rows 8`), had timed out on the second `delete_absent` case.
  Nineteen original operations are terminal, but operation 990 remains
  `uploading` across repeated inspection after restart. It has no Table-owner
  operation or outcome: this is incomplete SQL admission. Public cancellation
  using its original identity moves it to `abandoned`, with cancellation
  requested, no owner outcome and zero matched/changed rows. Another restart
  preserves that state and all nineteen preceding operation records. SELECT
  verifies exactly keys 0–8 at 100 before and after closure. Abandonment is not
  an applied DELETE or a Table cancellation receipt.

The original reports remain ignored under `.cache/milestone3/` as
`current-instrumented.json` (SHA-256
`c0622d3647ec0cb5aa738ffd38b7598eb22b35feb47bc5a13e4b9f4c26bc23e8`)
and `staging-diagnostic.json` (SHA-256
`7692cfb0b8f105c335fb4232a6487f35ad1af84457792fcd5d1dbc07c8b9701a`).
Recovery records are `instrumented-original-recovery.json`, its independent
`instrumented-original-recovery-verification.json`,
`staging-diagnostic-original-recovery.json`,
`staging-diagnostic-original-closure.json` and
`staging-diagnostic-closure-restart.json`.

Both original 30-second submission failures remain failed latency controls.
These recoveries distinguish accepted Table work from incomplete SQL upload;
they do not resolve the actor-ledger admission cost, qualify current binaries,
or establish the milestone's final matched performance comparison. The
[runtime replacement handoff](../../roadmap/06-streams-queues-and-durable-runtime.md#inherited-station-cutover-obligations)
retains those separate obligations.

## Installed named resources and native owner recovery — 2026-10-27

The installed local resource matrix passes with shared definition
`ed98a1fb80bc80e2534856d1eea5caeae705df1bff8e0347aa20009c935f58de`,
ReleaseSafe and physical-disk fixtures under `/var/tmp`. The named-resource and
Document runs start at `733863df1`; owner recovery runs after the rebase onto
`68a4c5a75`. The rebased runtime, contracts and these fixture sources are
byte-identical to the pre-rebase source (`git diff --quiet` over their owners).
The rebase adds planning and independent statement-result formal checks, not a
different storage definition or native runtime.

- `just test direct-named-resources` passes named KV/Document provisioning,
  original saved bindings, current revocation and dependency protection through
  eight withheld staging replies, four withheld dependency replies and eleven
  abrupt node replacements (107 typed catalog calls). Its growth schedule then
  initializes and independently reads all 139 KV/Document objects through
  eight-entry directory pages. All typed values and the first original receipt
  survive another SIGKILL/restart (1,437 typed catalog calls).
- `just test document-local` passes worker/node deaths during staged
  publication, accepted change and checkpoint recovery. The finish uses one
  resident page and verifies exact retries at `node`, `accept`, `checkpoint`
  and `collect` boundaries. The fixture observes 519 native turns, at most four
  mutations per turn and values at most 256 bytes. Phase times are 5.179 seconds
  staging, 35.849 acceptance, 184.663 checkpoint and 453.778 final recovery.
  These are single-run costs under the existing native state contract, not a
  database latency target or a claim of improved runtime throughput.
- `just test local-owner-recovery` passes original receipts, allocation-queue
  recovery, the bounded in-process reopen budget and abrupt process restart.
  Losing the native journal sync acknowledgment for an atomic input/KV/block/
  output/effect turn still recovers one original receipt, the current and
  retained old blocks, two consumed inputs and one pending output/effect pair.
  Replay records no new effect attempt and dispatches no external effect.

Raw logs are the ignored `.cache/milestone3/named-resources-ed98.log`,
`document-local-ed98.log` and `local-owner-recovery-ed98.log`. This closes the
installed resource/replacement matrix in milestone 3 P1.4. It does not qualify
connector dispatch, transaction-backed Station replacement, the complete SDK
matrix, host power loss or the final common-revision clean lanes. Native turns
and direct Table acceptance remain separate atomic domains.

## Selective automatic Table compaction — 2026-10-27

The implementation and checks committed at `1b826f09f` replace unconditional
automatic relocation with bounded whole-input selection. The shared definition
is `ed98a1fb80bc80e2534856d1eea5caeae705df1bff8e0347aa20009c935f58de`;
saved roots require the new skipped-segment cursor and reject missing fields.
The [contract](../../../contracts/TRANSIT_STORAGE_V1.md#resumable-table-maintenance-targets)
distinguishes considered inputs from rewritten rows and physical collection.

Inside the pinned Nix shell, the storage package's
`zig build test -Doptimize=ReleaseSafe -Dtest-filter='Table maintenance' -Dtest-filter='Table compaction' --summary all`
passes **10/10** checks. The disk fixture retains a 64-row packed segment and a
mostly live eight-row segment, rewrites one eight-row segment with only two live
rows, and merges two two-row segments. Exactly two new segments are accepted;
all current values and the original 84-row snapshot survive. After the initial
lost skip reply, each remaining unit uses a new disk owner. Lost replies preserve
skip and relocation progress; each unit returns at most 24 candidate directory
entries with a four-row relocation limit. Separate cases
refuse private allocation and revoked publication, retain whole inputs when the
encoded-byte budget is too small, and reject fabricated completion, skipped
unexamined inputs and a missing persisted cursor. The first disk-test attempt
incorrectly counted fixture-setup row decoding as selection work; the corrected
test measures the counter delta across selection.

The catalog's `-Dtest-filter='direct storage responses'` selection passes
**4/4**, including the response test's 19 malformed observations and its flush
checks. Generated contract checks pass **18/18** and fast checks **40/40**.
These are selected checks, not a new complete package or clean-lane result.

`just test direct-table-maintenance` then passes against the actual ReleaseSafe
node on physical disk. Three competing Tables flush 258 WAL rows into ten
segments in **7.952 seconds**, including owner restart. Archive/checkpoint and
selective compaction settle after SIGKILL during accepted work; original WAL,
post-flush and post-maintenance snapshots survive another restart. The ten
packed/lone segment files retain their exact names and SHA-256 contents:
**zero new segment objects and zero additional retained segment bytes** result
from this maintenance pass. Repeated settled observations show no further Table publications.
Convergence and row verification take **25.285 seconds**. This installed workload
qualifies skipped inputs; the sparse rewrite and merge cases above are component
checks. Timings are single shared-host observations, not a matched speedup or
foreground latency bound.

Raw logs remain under ignored `.cache/milestone3/` as
`selective-compaction-final-tests.log`, `selective-compaction-response-tests.log`,
`selective-compaction-contracts.log`, `selective-compaction-final-fast.log` and
`selective-compaction-installed.log`. Power loss, aggregate foreground contention,
larger sparse inputs, full dependent SDK/browser qualification and final clean
lanes remain separate gates. Retained history can prevent object reclamation;
this pass does not change retention or establish zero total maintenance I/O.

At `e9aee40c9`, `just test local-storage-faults` passes **149 SIGKILL
schedules** with the same `ed98a1fb` definition on physical disk. The existing
101 WAL/object/archive/compaction/checkpoint schedules remain. Forty-eight new
schedules kill automatic archive target creation/completion and compaction
target creation, each of two skipped dense segments, and completion. Each
transition is interrupted before acceptance, during a partial WAL write, after
each of four sync boundaries, after publication and before reply. A separate
Python oracle fixes the expected roots, target cursors and completed frontiers;
it checks current/pinned values, the original receipt, logical history, segment
identity, continuation after restart and an idle final unit. Archive completion
does not grant physical WAL trim. The raw log is the ignored
`.cache/milestone3/maintenance-target-faults-ed98.log`; the verification catalog
also passes with 77 invariants, 75 classified bounds and 15 SDK scenarios.
These are process-death boundaries with the host/page cache still alive, not
power-loss evidence or the remaining aggregate contention/failure qualification.

The complete storage package subsequently passes **137/137** ReleaseSafe tests
against runtime source `81739ed54`, before the rebase onto `c8cf71496`. The
pinned-shell command is `zig build test -Doptimize=ReleaseSafe --summary all`
from `packages/zig/transit-storage`; the raw log is
`.cache/milestone3/storage-full-ed98.log`. Test execution takes approximately ten
minutes with a reported 38 MiB maximum RSS. This includes the retained read,
schema, ordered interval, archive, checkpoint, compaction and WAL/object checks.
It does not qualify the subsequently merged shared-memory/SQL changes or the
complete installed/SDK lanes.

## Local foundation repository qualification — 2026-10-27

The complete workspace `just check all` passes at clean committed source
`15c35f00549f217aac0650c0a2929c9a47af7f3b`. This includes 36 fast checks,
compiled diagnostic/grammar controls, the pinned toolchain check, 18 contract
checks, the complete native components/fixtures/faults aggregate, CLI diagnostics,
PTY history/input checks, Board's 101 tests and the documentation site's nine
content tests plus production build. The log is
`/var/tmp/transit-m2-completion-check-all2.log`. Native execution has its own
completed source/outcome record and takes 1,424.891 seconds; the integrated
collection account above identifies that record. A successful build is not
substituted for the executed native tests.

Committed-HEAD `just ci clean --check all` also passes at the same source. Its
check phase takes 1,955.787 seconds; the native aggregate within it takes
1,439.382 seconds and exits zero. Clone, checkout, pinned shell and locked
frontend dependency preparation all complete successfully. The retained record
is `.cache/ci/clean/15c35f00549f-transit-ci-i29fxeah/preparation.json`, SHA-256
`e39d1e3bea36bb0b967908d4c8b1831b47a914df225291893ac60917f1029bf8`;
its sibling `checks/` directory retains the per-check records and diagnostic
logs. The complete output is `/var/tmp/transit-m2-completion-clean-all2.log`.
This scope repeats repository validation from an isolated checkout without local
outputs. It is not the seven hosted CI lanes or a claim that every installed,
SDK, provider, capacity or browser schedule ran at this source. Those boundaries
retain their own executed records and delivery owners.

The earlier workspace attempt at `6a72588c5` fails in diagnostic outcome review:
`('unmapped outcome', 'query.caller')` for the new permanent exchange-credit
budget error. Its log remains `/var/tmp/transit-m2-completion-check-all.log`.
The manually reviewed expectations added by `15c35f005` cover query caller,
Board, Flight and inspection projections, including existing dispatched-outcome
and access-denial precedence. The focused rerun passes 3,417 projections across
24 surfaces and its mutation controls; no diagnostic assertion is weakened or
expectation automatically regenerated. The later complete run includes this fix.

The evidence-only follow-up `e99b6ae6d` changes three documentation files. Its
link check, content tests, strict types/format/lint and complete production site
build pass (`/var/tmp/transit-m2-completion-measurement-docs.log`). Runtime code
and contracts are identical to `15c35f005`. Native growth qualification is recorded
[separately below](#native-growth-with-an-explicit-extended-time-guard); this
repository-check record does not convert its earlier timeout into a pass.

## Retained direct-data graph and physical collection — 2026-10-27

At clean source `15c35f005`, the complete native aggregate passes, including the
integrated local Table/catalog collector, backend sync-failure cases and owned
process-death schedules. This qualifies the composition of `DirectStorageGraph`
with `DataCollection`; the earlier allocation/root-walk records below qualify
its prerequisites separately. The [storage internals](../../handbook/internals/storage-runtime.md#retained-direct-data-graph-and-physical-collection)
defines the model and reasoning, and the [maintenance guide](../../../packages/zig/transit-backend-local/docs/maintenance.md#direct-table-and-catalog-collection)
defines its component operations and limits.

The physical-disk Table fixture explicitly expires history while preserving
pinned unflushed and flushed rows, a live history anchor, admitted work and
original receipts. Its first pass removes an obsolete archive frame while keeping
those retained dependencies. After pin release and further explicit expiry, a
second pass removes the old pinned archive frames and segment. Reopen verifies
the original receipt and values, then completes the previously admitted work.
Current-policy denial still prevents retained reads and receipt disclosure. The current aggregate reports 205/1,967 bounded steps and
24/928 confirmed reclaimed allocations for its two passes. These are observed
fixture/progress counts, not minimum collection throughput or universal object
counts. The signed catalog-policy composition also passes, reporting 1,068 steps
and one confirmed reclamation while retaining the complete catalog control chain.

Eight deletion sync-failure and 35 marking sync-failure schedules recover the
last durable private progress. Corrupt or incomplete graph metadata, quota
refusal, missing required history, unfinished/newer content reuse and omitted
time/grace authority cannot establish permission to delete. Permanent operation
identity reservations, saved direct-intent references and unknown namespaces
remain protected. Both native and direct collector harnesses pass 15 owned
SIGKILL schedules, preserving accepted roots and unrelated objects while resuming
exact descriptor/payload/checksum/marker deletion and allocation FIFO progress.
Process termination and injected errors do not simulate losing the only disk or
prove arbitrary filesystem rollback.

`just check native` runs the aggregate through the pinned shell; the focused
operations are `just test::local-data-collection`, `just test::local-catalog` and
`zig build test-local-native`. The complete aggregate's retained source/outcome
record is `.cache/checks/native-all.json`, with its log in
`.cache/checks/runs/native-all-2oqj3d_6/001-validate.log` (SHA-256
`e065e9e8c7d0b80baabe969ea5463ffc36d00951e73d31a2359598b425b71772`).
It exits zero after 1,424.891 seconds. The enclosing repository log is
`/var/tmp/transit-m2-completion-check-all2.log`; its later frontend/site checks
are separate outcomes. The pinned Zig build prints diagnostic stderr under
`run test w` with a `failed command` label even on these successful test steps;
the runner's completed exit-zero record establishes this aggregate outcome.

Collection remains an explicit local component operation. Automatic installed
scheduling and public progress presentation are not qualified by these tests.
The work/mark graph is paged and each transition has explicit resident/work
bounds; no constant total I/O or latency guarantee follows from that bound.

## Disk ingestion and commit matrix — 2026-10-27

The complete ReleaseSafe ingestion matrix passes at clean source `1b9ccb12c`:
**384 raw write/readback samples**, with one discarded warmup and 31 recorded
observations per arm. Table fixtures start with 128 or 1,024 rows and insert
sixteen 1 KiB rows through point/WAL or bulk/segment acceptance. Native fixtures
start with 16 or 64 turns and prepare/commit one further turn. Every write is
followed by independent fresh-process verification of original and new values,
receipts, retained pins and native input/output progress.

At the 1,024-row Table baseline:

| Entry / ingestion path | Owner ingestion median / p95 ms | Final WAL append median / p95 ms |
| --- | ---: | ---: |
| Warm / point | 466.355 / 1,576.511 | 3.072 / 3.850 |
| Warm / bulk | 476.678 / 505.204 | 2.921 / 3.597 |
| Cold / point | 507.989 / 1,989.104 | 3.217 / 3.812 |
| Cold / bulk | 522.221 / 535.448 | 3.061 / 3.816 |

Both Table paths append one acceptance record with three WAL syncs. Point/bulk
WAL bytes are 23,616/3,840, while staged object bytes are 67,566/88,155 across
67/68 puts. Requested object ranges/bytes are 612/597,132 and 613/598,032.
Tracked peak write allocations are 23,050,633 and 67,016,007 bytes. Bulk reduces
WAL bytes without a consistent reduction in total owner latency or retained
storage. These standalone Table owners omit the installed native authorization
and direct-data allocation adapter; their zero inventory-WAL counters do not
establish that installed Table writes have no allocation-log cost.

At 64 native turns, preparation median/p95 is 494.104/1,114.347 ms warm and
510.551/2,030.872 ms cold; commit is 3.085/3.599 and 3.070/3.331 ms. Preparation
includes two authority appends (3,584 bytes, six syncs), **43 allocation-inventory
appends (16,512 bytes, 129 syncs)**, 43 object puts (53,551 bytes) and 227 object
ranges (273,210 bytes). Commit adds one authority append (2,304 bytes, three
syncs), with no object puts or inventory appends. The phases have 26,850 and
23,600 tracked peak allocation bytes. The counters distinguish the two logs;
no synthetic native append-only timing is inferred from the complete phases.

The 1,024-row Table starts with 6,074,707 retained bytes / 11,937 files and ends
with 6,194,493 / 12,181 through point writes or 6,195,850 / 12,185 through bulk.
The 64-turn native fixture grows from 5,829,470 bytes / 11,738 files to 5,935,693 /
11,953. Maximum write-child RSS across the matrix is 33,908 KiB for Table and
8,680 KiB for native. Tracked operation allocations, executable RSS, allocated
filesystem blocks and retained logical file sizes are separate measurements.

The pinned Zig `0.17.0-dev.2267+48abf1a34` build runs on the shared Linux x86_64
AMD Threadripper 3960X host, CPU 0, with physical `/var/tmp` ext4 fixtures. Warm
and cold states are observed for every fixture file immediately before each
child. Affinity does not isolate filesystem, frequency or other host activity.
These samples establish owner-level values, I/O attribution and observed
percentiles; they do not establish installed SQL latency, concurrent group
commit, confidence intervals, host-RAM growth or power-loss survival.

Reproduce inside the pinned shell with
`just test::storage-ingest-benchmark --output .cache/storage-ingestion.json`.
The report is `.cache/storage-ingestion-completion.json`, SHA-256
`e5d53ca6af61ad6f7f8454acfa1ea87441732b298b4ac8bad3aa3088af76cdd1`;
the log is `/var/tmp/transit-m2-ingestion-completion.log`. The frozen executable
hash is `567d6bf36c3e7f821c4d4d6f7246a3ca64c0e02092d099bd684f800eb906e59f`.
The driver/common-driver hashes are
`7b01be614d7e83fd4e6353c5e4948a34c47cd3414623295fbca42b7c46ffcb2a` /
`128ef906f2251a5c48341cffcbad76fe92cf63622ff883189183f97addea9b18`;
the probe hash is
`8e8cb93f6037975bc6ac4e006f4d548a224a72e9232b2493dccc274ced974a4b`.
Earlier matrices preserve their sources and outcomes; differences across those
runs are not controlled performance comparisons.

## Disk owner recovery and read matrix — 2026-10-27

The complete matched ReleaseSafe owner matrix passes at clean source
`1b9ccb12c`: **768 raw samples**, including one discarded warmup and 31 recorded
observations for each owner/size/path/checkpoint/cache arm. Table fixtures have
128 and 1,024 rows; native fixtures have 16 and 64 turns. The independent Python
oracle checks complete counts, sums and payload digests, retained source identity,
input/output progress and no publication during reads. Cache observations require
all fixture file pages warm or absent immediately before each child starts.

At 1,024 Table rows, the original retained four-row interval and complete scan
give these read-phase times:

| Fixture entry | Full scan median / p95 ms | Ordered interval median / p95 ms |
| --- | ---: | ---: |
| Warm | 575.080 / 582.862 | 10.753 / 11.816 |
| Cold | 696.305 / 722.611 | 15.184 / 18.567 |

The scan requests 384 segment ranges, 1,312,768 segment bytes and 4,225 index
misses across 64 segments; the interval requests 12 ranges and 41,024 bytes
across two segments. Including index and retained-handle objects, those read
phases request 6,361,502 and 140,469 bytes respectively. A Table checkpoint
reduces logical recovery from 65 records/240 object ranges to one record/eight
ranges. Warm logical recovery median/p95 changes from 22.526/24.806 to
0.856/1.283 ms; cold changes from 60.879/64.486 to 2.849/3.722 ms. Physical WAL
startup still verifies 65 or 66 records; checkpointing does not remove that gate.

The 64-turn native baseline/checkpoint read medians are 190.281/189.980 ms warm
and 218.156/210.578 ms cold. Their p95 values are 197.322/214.396 and
226.825/245.890 ms. Native physical-open medians remain about 70–73 ms. The
straddling authority segment remains, and startup validates 2,345/2,350 separate
allocation-inventory frames in addition to 199/200 authority frames. Native
checkpointing provides no material read/startup benefit or physical reclamation
in this fixture. Maximum executable RSS across recorded samples is 9,624 KiB
for Table and 7,656 KiB for native; these observations are not deployment limits.

The host is a shared AMD Ryzen Threadripper 3960X with ext4 storage under
`/var/tmp`, affinity to CPU zero and compiler `0.17.0-dev.2267+48abf1a34`.
Each Table owner uses one index page and separate 128 KiB encoded/decoded
allowances; the native owner uses one page. The 2 GiB child virtual-memory
ceiling is separate from those caches. The standalone Table fixture omits the
installed native-authority/allocation adapter; native counters include both
authority and allocation WALs. File-page conditioning does not isolate device
caches, filesystem metadata or unrelated host load.

Reproduce with `just test::storage-benchmark --output .cache/storage-owners.json`
inside the pinned shell. The raw report is
`.cache/storage-owners-completion.json` (SHA-256
`48ed0425311df73b8bb2b0faf6a6c024c4b21f7e839b642f542cee8718946d79`);
the log is `/var/tmp/transit-m2-owners-completion.log`. The executable hash is
`567d6bf36c3e7f821c4d4d6f7246a3ca64c0e02092d099bd684f800eb906e59f`.
The report retains driver/probe/lock hashes, every observation, phase counters,
tracked allocations, process metrics, cache attempts and fixture commitments.
The [measurement guide](../../../tests/performance/storage/storage_benchmark.md)
owns these scopes and independent controls. This is not installed SQL, provider
or concurrent-writer qualification, and does not establish a p99 or host-RAM
growth claim. Earlier matrices retain their original sources and outcomes.

## Local bounded-growth requalification — 2026-10-27

The complete Table growth matrix passes at clean source `d75f0ac7b`, using
ReleaseSafe, 16 KiB values, one resident index page, a 512 KiB encoded cache and
a separate 128 KiB decoded allowance. Both setup and cold readback run under
the unchanged **128 MiB process address-space ceiling** and 1,800-second child
guard. The report is `.cache/storage-growth-table-completion.json`; the log is
`/var/tmp/transit-m2-growth-table-completion.log`. Reproduce inside the pinned
shell with `just test::storage-growth --owner table --output .cache/storage-growth-table.json`.

| Observation | 2,048 rows | 8,192 rows |
| --- | ---: | ---: |
| Retained file bytes | 44,906,256 | 193,003,856 |
| Allocated disk bytes | 114,282,496 | 507,817,984 |
| File count | 26,125 | 120,998 |
| Setup seconds | 54.156 | 1,065.057 |
| Cold physical open / logical recovery / read seconds | 0.008 / 0.100 / 0.821 | 0.043 / 0.677 / 3.888 |
| Setup peak virtual / resident KiB | 76,916 / 34,232 | 76,916 / 34,232 |
| Readback peak virtual / resident KiB | 11,692 / 7,796 | 11,692 / 7,796 |

Both sizes have the same tracked setup allocation peak, **67,015,751 bytes**;
readback peaks at **312,449 bytes**. The larger fixture exceeds the child memory
ceiling in retained file lengths, not just filesystem block allocation. Every
value, payload digest, original receipt and retained snapshot size verifies;
file hashes and allocation remain unchanged. The driver and kernel page cache
are outside the child ceiling. The standalone Table fixture does not include
the installed adapter's native authority or allocation-inventory costs. The
filesystem is ext4 (`stat -f` reports the ext family as `ext2/ext3`). These single
observations are not latency percentiles, an installed benchmark or a claim
that the data exceed host RAM.

The frozen executable SHA-256 is
`e458dbcf62a125667697cccd8776c4d3ae47d90a9bff54c54ed577e94072e359`;
the report retains compiler, driver, probe, lock and fixture hashes. Its compiler
is `0.17.0-dev.2267+48abf1a34`. Later changes through `261bfaca2` add tests and
documentation, without changing this runtime or probe.

The separate native run at `c15e6344b` remains **failed**: 512 turns complete
with 74,165,126 retained bytes, but the 2,048-turn setup exceeds its 1,800-second
guard. Its report is `.cache/storage-growth-native-completion.json` and log is
`/var/tmp/transit-m2-growth-native-completion.log`. The smaller native fixture
does not exceed 128 MiB; neither that partial result nor the complete Table
matrix establishes native growth beyond the ceiling. The failure must remain
distinct from any measurement under a different execution guard.

### Native growth with an explicit extended time guard

The complete native matrix **passes** at clean source `e99b6ae6d`, using the same
frozen ReleaseSafe executable as the Table growth matrix above. It retains the
512/2,048-turn fixtures, 16 KiB blocks, one resident index page and enforced
**128 MiB child address-space ceiling**. The explicit `--timeout 7200` changes
only the per-child time guard. It does not make the earlier 1,800-second profile
pass or establish a latency SLO. The signed engine operations use a deterministic
fixture clock (`unix_ms = 100`); this is not installed scheduling or wall-clock
deadline qualification.

| Observation | 512 turns | 2,048 turns |
| --- | ---: | ---: |
| Retained file bytes | 74,157,775 | 346,805,395 |
| Allocated disk bytes | 417,820,672 | 1,958,170,624 |
| File count | 121,188 | 570,288 |
| Init-loop seconds | 1,174.068 | 6,489.274 |
| Cold readback process seconds | 2.750 | 11.895 |
| Cold physical open / logical recovery / read seconds | 0.694 / 0.004 / 2.030 | 3.245 / 0.010 / 8.588 |
| Setup peak virtual / resident KiB | 11,216 / 8,704 | 11,216 / 8,828 |
| Readback peak virtual / resident KiB | 10,260 / 7,756 | 10,300 / 7,796 |
| Largest tracked setup / readback phase peaks, bytes | 25,486 / 26,870 | 25,480 / 26,908 |
| Accepted position | 1,543 | 6,151 |

Independent verification checks every KV value and block, consumed inputs and
emitted outputs. Sums are 2,219,264 and 35,615,744; the value digests are
`3ef5d651cccdb41d305d27e2644dadd78400d9e664ab158c6b7ab339a8a793f1` and
`57bd73bf47d5f712bb8b0021bd86352af393bb3adfe0f48a09b007af6a84a213`.
All 102,005/478,067 fixture file pages are observed nonresident before readback,
on the first conditioning attempt at each size. Conditioning takes 24.472/114.260
seconds outside the child read timers. Complete file hashes and allocation remain
unchanged afterwards. The larger fixture exceeds the enforced process ceiling
in retained file lengths, independently of its allocated filesystem blocks.

The init loops append 1,542/6,150 authority records (4,626/18,450 syncs) and
24,228/114,048 allocation records (72,684/342,144 syncs), alongside the same
number of immutable object puts. Cold physical startup validates 1,543/6,151
authority and 24,235/114,055 allocation records. Recovery and reads append to
neither log and publish no objects. Tracked owner allocations, image memory and
filesystem bytes have distinct boundaries. The Python fixture/oracle and kernel
page cache are outside the child ceiling. These single observations establish
the selected finite growth profile, not a percentile, host-RAM or throughput
bound. Low-rate process/frontier inspection occurs during setup only; the
monitor does not touch fixture files during cold conditioning or readback.

Reproduce inside the pinned shell with
`just test::storage-growth --owner native --timeout 7200 --output .cache/storage-growth-native-long.json`.
The report is `.cache/storage-growth-native-long-completion.json`, SHA-256
`f482549ead8a938e55016477566c019b23958e9ea24c826e104027c65d31e26d`;
the log is `/var/tmp/transit-m2-growth-native-long-completion.log`. The complete
command exits zero and removes its private fixtures only after verification.
The driver now retains failed fixtures and their frozen executable; this does
not recover the files deleted by the earlier failed driver's cleanup.

The executable SHA-256 is
`e458dbcf62a125667697cccd8776c4d3ae47d90a9bff54c54ed577e94072e359`;
the growth/common-driver hashes are
`6c0ffd8b03f4f759f12164d0346f9d1901d8f32f10415d185e8cb32f407fe786` /
`128ef906f2251a5c48341cffcbad76fe92cf63622ff883189183f97addea9b18`.
The probe hash is
`8e8cb93f6037975bc6ac4e006f4d548a224a72e9232b2493dccc274ced974a4b`,
and the lock hash is
`865faed173c5a710f77c231ce13c427bfe9eeaf3900e7edc7fa7e9d6233b1264`.
The pinned compiler is `0.17.0-dev.2267+48abf1a34`, CPU affinity is 0, and the
physical fixture directory is on `/var/tmp` ext4 on the same shared host.

## Segment membership selectivity — 2026-10-27

The range-reader control in `be360c2f0` holds the row count at 256 and varies
distinct int64 values across 4, 16, 64 and 256. Values are multiples of 4,096;
the 2,048 absent probes are the odd integers from 1 through 4,095, all inside
every group's min/max. The matched control changes only the decoded membership
mask to all ones. The real encoded predicate and integrity/projection path still
run; each arm independently returns no rows. Every present value is also queried
and checked against its exact expected multiplicity.

The 64-bit mask sets 7, 27, 60 and 64 bits respectively. False positives request
22, 379, 1,803 and 2,048 predicate pages out of 2,048; the control requests all
2,048. Each page is 2,432 bytes. The fixed filter therefore saves 4,927,232,
4,059,008, 595,840 and zero payload bytes respectively. The
[performance reference](../../handbook/reference/performance.md#segment-membership-filter-selectivity)
records the rates and sizing ratios. Both four- and sixteen-value fixtures
enforce fewer than 25% false positives as a deterministic regression ceiling;
no universal workload bound follows. The saturated control prevents treating
this fixed filter as an adaptive or large-distinct-count index.

In the pinned shell, `zig build test -Dtest-filter='TSeg membership' --summary all`
from `packages/zig/transit-fuze` passes **22/22** selected/dependent tests in
seven seconds, with 9 MiB reported test-process MaxRSS and no allocator leaks.
Raw output is `/var/tmp/transit-m2-membership-selectivity.log`. The compiler's
runner prints a `failed command` label for diagnostic stderr, but exits zero
with all eight build steps successful; there is no failing test in this run.

This experiment measures payload range requests against an in-memory immutable
source, excluding common metadata reads. It does not measure physical disk I/O,
installed latency or probabilistic confidence intervals. The representation and
runtime implementation are unchanged. The contract now states its exact fixed
filter and distinguishes the embedded sorted array from the live paged key index.

## Document conflicts, tombstones and retained revisions on disk — 2026-10-26

The Document crash schedule in `f96727c0a` passes against the local backend;
`d75f0ac7b` also places the matched Ursula control's WAL and cold store under
`/var/tmp`. That path is on ext4 on this host; the development shell's `/tmp`
is tmpfs. Both runs use ReleaseSafe, the same signed caller and fault schedule,
and the unchanged phase deadlines. Production source is unchanged from
`c15e6344b`.

Each run kills and replaces three workers and their node, loses accepted replies
at four publication/collection boundaries, and verifies the original exact
receipts. Independent reads check two concurrent scalar values and their causal
dots, a removed map entry, and a deleted sequence anchor whose successor remains
visible. A retained earlier revision still exposes the original scalar, map entry
and character. Checkpoint resynchronization, stale-generation rejection, revoked
reads, retirement cleanup and the unchanged output count also pass. The final
recovery uses one resident page. Both runs observe 5,530 reads and 519 turns, with
at most four mutations per turn and 256 bytes per mutation value.

| Observation | Local WAL/objects | Disk-backed Ursula |
| --- | ---: | ---: |
| Stage / accept / checkpoint / finish (seconds) | 5.228 / 34.750 / 185.688 / 426.340 | 2.972 / 20.374 / 33.585 / 45.701 |
| Retained WAL or hot bytes | 3,202,272 | 8,388,608 |
| Immutable object or cold bytes | 26,526,915 | 37,559,346 |
| Object files or cold objects | 33,656 | 143 |

Reproduce inside the pinned shell with `just test::document-local` and
`zig build test-document -Doptimize=ReleaseSafe -- --backend ursula`.
Raw logs are `/var/tmp/transit-m2-document-local2.log` and
`/var/tmp/transit-m2-document-ursula.log`. The first local run, retained at
`/var/tmp/transit-m2-document-local.log`, fails a fixture assertion that assumed
the first sequence step returned a character. The corrected assertion explicitly
traverses the deleted anchor before reading its successor; no runtime change or
deadline increase resolves that failure.

These are single executions of an external component recovery schedule, not
latency percentiles, installed lifecycle qualification, host power-loss evidence
or a claim that both backends have equivalent physical layouts. Current semantics
remain in [Documents](../../handbook/reference/documents.md); the
[runtime test owner](../../../tests/runtime/README.md) describes reproduction.

## Local recorded effect outcomes after trim — 2026-10-26

The local-owner test source retained in `61848d307` adds two outcome schedules
over the current native WAL and immutable objects. Each schedule opens the same
physical directory five times with one resident page. A lost dispatch reply
leaves an authorized attempt; exact retry recovers its original receipt without
new pages or acceptance. An unknown observation survives checkpoint and physical
WAL trimming. After the caller retires, a lost terminal reply recovers either
the recorded result or explicit closure with an unknown outcome. Another
checkpoint, trim and reopen preserve that terminal receipt, the original attempt,
the retired caller and its unchanged input count. Conflicting later evidence and
another dispatch reject.

In the pinned shell, `zig build test -Dtest-filter='local effect attempts' --summary all`
from `packages/zig/transit-backend-local` passes **2/2** tests in **12 seconds**
with no allocator leaks. The initial run rejects the fixture's incorrect initial
generation of one; the corrected fixture claims generation zero, matching a new
unassociated process. Logs are
`/var/tmp/transit-m2-local-effect-recovery.log` and
`/var/tmp/transit-m2-local-effect-recovery2.log`. The invariant registry check
also passes. Production runtime source is unchanged from `c15e6344b`.

This qualifies durable connector observations at the local owner boundary.
It does not contact an external service, exercise a connector process, simulate
host power loss or establish remote cancellation/exactly-once effects. Reopen is
orderly in this case; the separate process-death schedules retain their own
scope. The [storage contract](../../../contracts/TRANSIT_STORAGE_V1.md#native-authority-on-local-storage)
and [local backend](../../../packages/zig/transit-backend-local/README.md) own the
current persistence semantics.

## Shared segment Arrow value ownership — 2026-10-26

`TSegReader.SharedGroup` transfers a verified `BufferedGroup` into a reference
counted owner. Its compatible plain columns expose Arrow value arrays whose
buffer directories are owned and whose payload bytes retain the original group.
Array slices and C exports keep that owner alive after the reader and original
group reference close. The allocator must outlive every reference; reference
counting neither supplies allocator thread safety nor retains a durable snapshot
or authorization. Five-state metadata stays in the shared group. The Arrow value
child alone represents non-value states as null and is not the full logical
cell export.

The Fuze `test` target with `TSeg` and `Arrow IPC` filters passes **47/47**
selected tests in the pinned development shell. Pointer identity establishes
unchanged UTF-8 payload addresses through slicing and C export/import. Import
consumes the C handle; repeat import rejects, and repeat release is harmless.
The selected projection rejects a compressed integer column's plain export while
its ordinary bounded decode remains usable. Cancellation halfway through a
second projected range releases the partial group, preserves earlier Arrow
values and permits a later complete read. IPC round-trip compares values after
the original reader closes; IPC serialization is a copy, not zero-copy exchange.

Exhaustive allocator-failure schedules cover owner transfer, directories, slices,
C export/import and IPC writing. A nested C-export case fails every allocation
while constructing two child arrays and verifies cleanup of completed children.
Every truncated output capacity in the existing IPC compute fixture returns
`WriteFailed` without leaks or duplicate frees. These checks found retained-array
and partial-child leaks in C export, plus partially constructed record-batch
metadata leaks in the pinned IPC writer. Guarded build-time source patches fix
those paths without modifying the fetched dependency cache. The ordinary Arrow
compute selection also passes **93/93** tests.

Reproduce with `zig build test -Dtest-filter=TSeg -Dtest-filter='Arrow IPC'
--summary all` from `packages/zig/transit-fuze` inside `nix develop`. Local raw
evidence is `/var/tmp/transit-m2-shared-arrow-cancellation.log` and its preceding focused
runs. The allocation-failure IPC reader uses a disposable arena to own partial
FlatBuffer metadata. This does not qualify arbitrary foreign IPC input, compressed
IPC writer failures, full five-state C export or concurrent host allocators.

## Direct-data allocation and content-reuse inventory — 2026-10-26

On merged `ceb109a03` plus the direct-data inventory, the complete local backend
suite passes **34/34 tests** (39 seconds, reported MaxRSS 54 MiB) after replacing
the shared definition with
`eaf59de84b753ede2b5dc94abce538a75c2ba1e69c0cf4f025a47fa99f65735c`.
The earlier inventory-only run passes 6/6 and the first integrated direct-data
and paused-I/O run passes 7/7, including each package root test. Reproduce with
`zig build test --summary all` in `packages/zig/transit-backend-local` inside the
pinned Nix shell. Logs are `/var/tmp/transit-m2-data-allocations-test.log`,
`/var/tmp/transit-m2-data-inventory-integration.log` and
`/var/tmp/transit-m2-data-inventory-native.log` respectively.

Disk cases cover exact retry without another intent/reservation, newer reuse
after an accepted native storage fence, rejected stale epochs and conflicting
metadata, old-marker removal refusal, carry/consume/trim and reopen. A 193-key
inventory completes within a tracked 128 KiB allocator budget, releases all
allocations and advances empty prefixes at most 64 records per step. Corrupt
digests, foreign definitions, reserved/key padding and wrong key hashes reject.
Missing mandatory inventory directories or missing queue history with existing
markers reject without manufacturing replacement history.

Every observed sync in initial inventory publication, newer-epoch reuse and
integrated object creation is failed separately, followed by reopen and exact
retry. An existing object always has matching latest inventory evidence. Newer
reuse consumes control capacity when ordinary quota is exhausted; exclusive
reopen's accounting equals an independent recursive sum of file lengths. The
paused private-sync schedule still completes native reads and quota-reserved
control publication before the creator resumes. Existing native collection,
standalone payload, signed Table revocation and storage-fence cases pass with
the new owner layout. These are finite component and syscall-failure checks,
not direct-data process-death or filesystem power-loss qualification.

The inventory supplies neither retained-root reachability nor physical Table
deletion. All-owner cuts, durable marks/work, live pin/history traversal and
collector recovery remain open. No ingestion performance improvement is claimed
for the added durable inventory writes.

Diagnostic inventory, semantic mappings and compiler-inferred boundaries pass,
as do 6,432 documentation links and diff whitespace. Native, host, browser and
SQL schemas/signing fixtures are regenerated for the new definition. The first
full workspace `just check` stops at formatting the definition enum identifier;
the formatter correction changes no definition bytes or behavior. The original
log is `/var/tmp/transit-m2-data-inventory-check.log`; the corrected rerun is
`/var/tmp/transit-m2-data-inventory-check-final.log` has no retained final outcome.

The separate pre-inventory clean core run at committed `0e28a8345` (the same
tree as merge `ceb109a03`) passes its `check-core` phase, including unit tests,
92 storage and 15 native collection SIGKILL schedules, CLI/console tests and
6,428 documentation links. Its remaining core-lane tasks have no retained final outcome;
this is not a complete clean-lane pass. The workspace `just check` at that
revision was interrupted with exit 130 after the checkout changed during the
PR merge; remaining checks did not finish. Logs are
`/var/tmp/transit-m2-pr-final-clean-core.log` and
`/var/tmp/transit-m2-pr-final-check.log`. Neither run qualifies the new inventory
revision or closes the milestone's final clean-CI requirement.

The temporary log paths above record the original execution locations. Those
files are no longer available after the workspace reset; no later completion
result can be inferred from them.

## Local standalone payload ownership — 2026-10-26

On `09d24daa8` plus the payload adapter and immutable-publication confirmation,
the local backend's focused payload run passes **7/7 tests** (33 seconds,
reported MaxRSS 16 MiB), including the package root test. It verifies accepted
declarations, a lost creation reply and disk reopen, the 64 KiB limit, quota
refusal, two independent creator lanes, current-identity rejection, corrupt
markers/content, unlimited retention, opted-in retirement, repeated deletion and
the permanent creation marker after checkpoint/reopen. The physical adapter does
not publish native readiness or deletion completion on its own.

The creation schedule discovers **eight sync barriers**, fails each one and
reopens the owner. Only verification resolves the original bytes; no PUT or new
native acceptance occurs. Two deletion-sync failures resume the same accepted
retirement and preserve the attempt fence. The verification schedule fails each
of **seven recovery barriers** and proves that native state and PUT counts remain
unchanged. Missing bytes remain unavailable, never an empty or recreated payload.

The storage confirmation control passes **2/2 tests**, including the package root
test. It independently checks the five object-publication barriers in order:
content file, checksum file, content directory, descriptor file and descriptor
directory. Each injected failure propagates. Confirmation rejects conditional
identity, missing objects and corrupt empty-object data. These are local disk
and syscall-boundary observations, not a filesystem power-loss model.

Reproduce in `nix develop` with the local backend's `zig build test
-Dtest-filter="local standalone payload" -Dtest-filter="local payload"
--summary all`, and the storage package's `zig build test
-Dtest-filter="immutable confirmation" --summary all`. Diagnostics and local
documentation links pass. Installed local payload routes and automatic lifecycle
reclamation remain separate integration work; no complete milestone or clean-CI
claim follows from these focused cases.

## Local native allocation and physical collection — 2026-10-26

On `78d43b93a` plus the local collection implementation, pinned local-backend
`zig build test --summary all` passes **17/17 tests** (three minutes, reported
MaxRSS 48 MiB). The first run of the retained-block
case used a stale fixture generation and failed before collection; the corrected
fixture reads the actual process generation. These are component disk proofs.

`zig build test-local-native-collection-faults -Doptimize=ReleaseSafe` passes
**15 SIGKILL schedules**: all eight observed sync boundaries, four physical
unlinks, FIFO publication, private-state publication and lost completion reply.
Each schedule kills a real blocked child, reopens the same disk bytes, resumes
the exact pending identity and verifies the physical absence of its descriptor,
payload, checksums and allocation marker. Native accepted position/process state
and unrelated Table-owned bytes remain intact. Repeated reopen preserves the
completed result. The Python parent independently verifies the exact allocation
marker bytes, definition, object length and both hashes before the schedules.
This does not simulate filesystem rollback or power loss.

The owner tests cover retained history, incomplete-mark abort after an authorized
trim, old-epoch creators, exact allocation retries, unpublished content, corrupted
private state/allocation markers, control reserve under ordinary quota pressure,
and independent retained block values after compaction, checkpoint and restart.
Revocation still denies the retained read. The FIFO carry test discovers and
injects every sync boundary in one carry operation, then reopens and proves that
cursor advancement retains ownership exactly once. The storage package's focused
immutable/publication run passes **5/5**, including both deletion-directory sync
failures, identity/kind rejection and unchanged unrelated objects.
Missing allocation history rejects without recreating a queue or resetting
persisted objects.

Reproduce with `just test::local-native-collection`; the root unit suite includes
the native owner and process-death cases. The shared definition is replaced and
schema, signing and host/browser artifacts are regenerated together. Application
tests pass **52/52** after regenerating the new definition's signing fixture;
native/host and browser contract checks, diagnostics and documentation links pass.
The initial `just check` caught stale Table-query/signing fixtures. The run that
had compiled the old signing fixture was stopped after its failure; its remaining
disk checks are incomplete. Repository and clean-lane qualification remain
separate from these executed cases. This
does not close Table maintenance, standalone payload ownership, installed local
collection scheduling, or the full storage milestone.

## Encoded Boolean segment programs — 2026-10-26

On `cdf5cdda7` plus bounded program selection, pinned Fuze `zig build test
--summary all` passes **369/369 tests** (one minute, reported MaxRSS 84 MiB).
The encoded path and the decoded program share the existing predicate machine.
Explicit masks exercise multi-column conjunction, disjunction and negation,
comparing selected values/order with complete decoded groups. Noncandidate groups
perform no payload reads. A bound NULL remains unknown under NOT and therefore
does not select a row. Logical lowering preserves instruction order and binds
the supplied declared collation.

A synthetic two-column five-state page puts a later type error in the first
physical column and an earlier conflict in the second. Encoded evaluation reports
the earlier source row and its original instruction. A true left operand of OR
does not hide the right operand's error; swapping atoms updates the instruction
coordinate without changing source ordering. Malformed programs reject before
I/O. Allocation-failure enumeration covers multiple outcome vectors and late
projected decoding. Every outcome vector, selection ordinal and decoding
workspace shares the configured resident allowance.

These controls extend the preceding component evidence. They do not establish
SQL pushdown, cross-column correlation-aware pruning, disk/latency improvements
or complete milestone qualification. Repeated atoms may reread a column, and
projection of predicate columns may read those pages again. No stored or wire
definition changes.

## Encoded column predicates and projected segment filtering — 2026-10-26

On merged `d553aa9c` plus this increment, the pinned Fuze selection
`zig build test -Dtest-filter=TSeg -Dtest-filter=column -Dtest-filter=physical
--summary all` passes **78/78 tests**. The public
`just test::storage-segments` passes **70/70 Fuze tests** and **2/2 disk-backed
Table segment-range tests** (two minutes, reported MaxRSS 39 MiB for storage).
The latter preserves existing live-owner read/cache behavior; it does not wire
the new predicate API into SQL. The complete Fuze `zig build test` also passes
**365/365 tests**.

Independent TCP1 byte fixtures check bitpacked offsets, RLE runs and dictionary
codes. Outcomes distinguish true, false, unknown, type error and conflict across
all ten codecs. Explicit byte-order masks cover UTF-8, ASCII case folding and
CP037, including prefixes, NUL and accented text. Direct malformed COMP-3 bytes
produce an error outcome without changing source bytes. Truncated/trailing data
reject even when every predicate result would be discarded. Dictionary and run
controls count one physical-value evaluation per entry/run; each retained row
outcome occupies one byte. Allocation-failure enumeration checks partial owners.

Verified segment controls compare pruned selections with unpruned values and
independent masks. Four two-row groups require three metadata reads plus four
payload reads for a narrow projected filter; two excluded groups request no
payload. Source destruction preserves selected strings and row coordinates.
A 64-row group with 2 KiB strings fits one selected projected row within a
16 KiB decoded budget; materializing the complete column fails that same budget.
Synthetic five-state segment metadata confirms that nonmatching bounds cannot
hide an earlier conflict, and state selection retains its alternative stamps.
Schema, projection, page integrity and allocation gates also cover empty groups.

These are component correctness and allocation/range controls, not installed
latency/RSS measurements. The reader trusts its immutable footer's statistics,
does not validate pruned payloads, and acquires neither retention nor current
rights. Multi-column program lowering, query LIMIT semantics, shared hash/order
collation propagation and direct SQL integration remain separate work. Stored
formats and the shared definition are unchanged.

## Bounded row-index mutation batches — 2026-10-25

On `72c77bcb` plus bounded index batching, storage-package tests run with the
pinned compiler establish the following component results:

- `zig build test -Dtest-filter='ordered full key batches' --summary all`:
  2/2 pass. Sixty-four short-key inserts stage 22 pages / 16,527 encoded bytes,
  compared with 134 pages / 90,160 bytes using individual index updates. Mixed
  64-byte terminals and 65-/4,096-byte extensions retain exact earlier roots;
  duplicate requests and candidate-budget exhaustion reject.
- `zig build test -Dtest-filter='Table index batches' --summary all`: 2/2 pass.
  One 64-row accepted Table batch stages 111 pages / 69,628 bytes including its
  receipt, versus a scalar four-index control's 533 pages / 336,381 bytes for the
  same accepted key/locator set. Independent values and identities are checked.
  A lost acknowledgement recovers the original result without further staging;
  duplicates inside and beyond the first private batch preserve all accepted
  roots, the original receipt and the unchanged WAL boundary through recovery.
- `zig build test -Dtest-filter='Table acceptance recovers'
  -Dtest-filter='admitted point and bulk UPDATE' -Dtest-filter='keyless'
  --summary all`: 4/4 pass, including key exchanges and exact retry/reopen.

Staging counters describe acknowledged index payloads, including immutable
content deduplication. They do not establish provider writes, disk amplification,
latency or RSS improvements. After batching physical relocation,
`zig build test -Dtest-filter='retained Table key ranges'
-Dtest-filter='Table acceptance recovers' --summary all` passes 4/4 (12 seconds).
The public `just test::storage-key-ranges` then passes 11/11 storage tests (two
minutes, reported MaxRSS 43 MiB) and 5/5 catalog tests. On `765b287b`, the storage
command `zig build test -Dtest-filter='frozen SQL' --summary all` passes 3/3
(14 minutes, reported MaxRSS 39 MiB). `just test::direct-table-service` also
passes 1,418 typed calls covering CRUD/DDL, retained sources, three restarts,
lost replies, history/pins and current revocation. Final repository/clean
qualification remains pending.


## Retained ordered Table ranges — 2026-10-25

On `0c3ca45e` plus the Table range integration and shared-definition cutover,
these pinned-shell executions pass:

- Storage package `zig build test -Dtest-filter='retained Table key ranges'
  --summary all`: 3/3 tests, 37 seconds, reported MaxRSS 37 MiB. Real-disk tests
  compare independently specified values/order across mixed WAL/segment rows,
  flush, deletion, schema rewrite, DROP, one-page/no-page caches and restart.
  Composite negative-integer/text keys follow separately authored UTF8_BINARY,
  ASCII_CI and CP037 orders. Interval changes, foreign-source cursors, a first
  row above its byte budget and current denial after buffering reject; empty
  intervals also require current rights.
- Catalog package `zig build test -Dtest-filter='retained reader binds'
  --summary all`: 4/4 tests. Owned decoded pages preserve original schema and
  source metadata; interval/order/cursor substitutions reject without changing
  sequential coverage. Allocation-failure enumeration checks cleanup.
- Catalog package `zig build test -Dtest-filter='retained key range'
  --summary all`: 4/4 tests. Python/OpenSSL supplies independent signed request
  bytes and the interval fingerprint; changed cursor source/bounds reject.
- Root `zig build test-local-catalog --summary all`: 2/2 tests, four minutes.
  The signed owner path includes matching/empty ranges, delegated and borrowed
  reads, substituted borrowed sources and current permission revocation before
  returning buffered rows or empty results.
- Protocol package `zig build test --summary all`: 59/59 tests, including
  rejection of the predecessor shared definition. `just contract::check`,
  `just transit-board::check`, `just transit-docs::check` and the diagnostic
  mappings/error-boundary/outcome tasks pass after coordinated regeneration.

The storage root requires `ordered_rows`; the shared definition is
`cd12a1e21afce782c2926a900dfe473fe96bcee962a98cb8670d06dfbed3aa89`.
This rejects predecessor stored semantics rather than defaulting an empty index.
The focused range run first encountered a fixture compile error (the test used
an owned-row union as a struct); the signing test first expected cursor validation
before request-context validation. Both fixture mistakes were corrected before
the passing runs above. These are component/signed-owner results, not whole-suite,
SQL inequality-pushdown, many-segment or host-loss qualification. On the completed `72c77bcb` range source, the storage command
`zig build test -Dtest-filter='Table recovery' -Dtest-filter='Table segment ranges'
--summary all` passes 5/5 (seven minutes, reported MaxRSS 37 MiB). It rejects a
missing mandatory ordered-root field and a missing accepted ordered-root object
before exposing state. A four-row interval from a retained 512-row source reads
563,420 segment bytes and incurs 58 index-cache misses; its same-source scan
reads 1,093,934 bytes and incurs 393 misses with one resident index page. Every
row/value is independently checked. With subsequent index batching, the same
fixture reports 48/320 index misses and unchanged segment-byte counts. The
counters exclude provider chunk checks and device/cache effects; no latency
comparison is inferred from these concurrent development runs. Final
repository/clean checks for this definition cutover remain pending.


## Ordered full-key index component — 2026-10-25

On `c4c5e753` plus the ordered-index changes, the pinned-shell command
`cd packages/zig/transit-storage && zig build test
-Dtest-filter='ordered full keys' --summary all` passes 3/3 tests (5 seconds;
12 seconds after adding rejection of children beyond the full-key bound).
A separately sorted array is the oracle for 96 keys, including zero bytes,
strict prefixes and lengths around 64-byte boundaries through 4 KiB. The tests
compare point values, inclusive/exclusive bounds and missing-bound seeks, then
overwrite/delete entries, revisit the original root and remove the final entry.

A real-disk case reopens 33 keys sharing a 128-byte prefix with no resident
page cache, verifies the earlier root, rejects a corrupt reference and preserves
the accepted root after a one-byte candidate budget fails. This establishes the
index component; Table acceptance, collation encoding, public range traversal,
recovery and whole-process memory measurements require separate integration
evidence.

## Bounded local WAL seek reuse — 2026-10-25

`nix develop --command sh -c 'cd packages/zig/transit-storage && zig build test
-Dtest-filter="disk WAL" --summary all'` passes 3/3 tests on `c1772a86` plus the
seek changes (11 seconds). After real disk reopen, 256 one-frame reads of one
segment decode exactly 256 frames and perform one segment-directory scan. Every
payload is checked against the independent formula `17 * lsn + 3`. Five repeated
tail reads decode exactly five frames; corrupting that cached coordinate's disk
payload then produces `CorruptWalFrame`, never an old cached value.

A second schedule covers forward/backward reads across rolling files, eviction
through more partitions than the eight descriptor slots, partial/full trim,
below-floor refusal and subsequent append with preserved LSN identity. The cache
holds coordinates only. Cold random access can still scan preceding frames;
reopen still validates all retained history. These counts establish this bounded
local read optimization, not group commit, host-loss recovery, safe retention
decisions or installed end-to-end latency.

## Verified segment range reader — 2026-10-25

The live `TablePartition` integration passes the disk-backed focused test with
512 rows, 2 KiB text values, one resident data-index page and default 256-row
groups. From a 1,094,026-byte segment, a cold point reads 563,420 bytes in five
ranges (header, trailer, footer and two columns); an adjacent warm point reads
zero additional segment bytes. Crossing groups reads two more column ranges.
After destroying caches and recovering the owner, a complete same-root scan
checks all 512 identities/values against their input ordinals and payload and
reads 1,093,934 segment bytes in seven ranges. Actual live decoded arena blocks
remain below 4 MiB for this fixture. These byte counters exclude tree/WAL I/O,
the local provider's 64 KiB chunk-verification amplification and filesystem cache
effects; they are not latency or whole-process memory guarantees.

The test also checks owned rows after eviction/recovery, zero retained segment
cache, and a one-byte decoder allowance refusing the read without changing the
accepted root or original receipt. Its first run fails when the fixture tries
to observe CREATE with a newly constructed INSERT binding; retaining the original
CREATE binding fixes that test, without relaxing the identity check. The passing
command is `cd packages/zig/transit-storage && zig build test
-Dtest-filter='Table segment ranges' --summary all` inside `nix develop` (2/2
including the package root test, 37 seconds). `just test::storage-segments`
composes the focused Fuze and storage checks. Installed SQL, full repository
checks and committed-source clean lanes require their separate evidence.

On baseline `b720c488` plus the segment-reader changes, the pinned-shell command
`cd packages/zig/transit-fuze && zig build test -Dtest-filter=TSeg --summary all`
passes 26 selected tests. New cases verify metadata-only opening, projection
without unrelated page reads, independent expected text values, returned-value
ownership after destroying the reader/source, encoded and actual decoder-arena
budgets, transport errors, page/footer corruption, overflowed offsets, forged
counts with valid checksums and allocation-failure cleanup. The in-memory source
records exact requested ranges; this is not disk or installed-query evidence.

The first allocation-failure enumeration reports nondeterministic allocation
counts because the backing allocator can resize an arena block in place. The
corrected enumeration disables backing resize and passes every allocation
failure, retaining leak checks. The full Fuze package suite passed before the
owned bounded-group addition; the 26-test run covers that final addition.
The reader preserves existing TSEG bytes and the shared contract definition.
It does not supply ordered paged keys, source retention, asynchronous reads,
zero-copy Arrow, complete encoded operators or physical collection.

## Snapshot pins against competing checkpoints — 2026-10-24

`nix develop --command sh -c 'cd packages/zig/transit-storage && zig build
test -Doptimize=ReleaseSafe -Dtest-filter="disk checkpoint races"'` passes the
disk-backed checkpoint race test. Two independently recovered Table owners
compete for the same WAL frontier. An accepted pin with a lost reply defeats a
stale flush; recovering that flush preserves the original unflushed row. When
the flush wins, staged snapshot bytes do not become an accepted pin and retry
cannot substitute a newer cut. Release wins and checkpoint wins are both
exercised; a lost release reply survives disk reopen without resurrecting either
released owner or losing any of the four accepted rows.

This proves conditional checkpoint publication and durable pin ownership. The
local native owner still refuses physical history collection; this test does
not qualify destructive GC, compaction or WAL trimming. The first test attempt
left its injected lost-reply flag enabled for subsequent operations; the
corrected schedule passes. A separate invocation using `--build-file` failed
during build configuration and supplied no test evidence.

## Data operation contracts and local WAL persistence — 2026-10-22

In the pinned Linux development shell, `zig build test` in
`packages/zig/transit-protocol` and `packages/zig/transit-catalog` passes after
adding the neutral [data lifecycle contract](../../../contracts/DATA_LIFECYCLE_V1.md).
Its independent JSON fixture checks complete retry bindings, full-width IDs,
mandatory definitions, commit succession and unflushed snapshot coverage.
These are descriptor checks; they do not qualify an installed acceptance or
snapshot-pin service.

`zig build test` in `packages/zig/transit-storage` passes its 13 component cases,
including seven tests over actual temporary POSIX directories. The new cases
exercise:

- 73 partitions and rolling segment files with an eight-entry cache; restart
  uses a 32 KiB allocator and returns at most two frames per requested page.
- A log with 65 one-MiB payloads; restart and a tail read fit a 2 MiB owner
  allocator, independently of retained history size.
- A durable fence with no append, complete trim without LSN reset, stale epochs
  and invalid trim boundaries.
- Incomplete unacknowledged final frames, damaged earlier segments, missing
  acknowledged tail files, checksum corruption and preserved incompatible logs.
- Exclusive directory ownership and an injected file-sync error after a complete
  frame write; the live owner refuses further work and restart recovers the
  uncertain frame.

The [local persistence contract](../../../contracts/TRANSIT_STORAGE_V1.md#local-wal-persistence)
specifies the tested profile. These tests do not simulate host power loss,
filesystem rollback, distributed fencing, authorization races, durable pin
acquisition or installed SQL execution. Physical trim still requires an owning
retention decision. The installed service backend is unchanged by these tests.

The subsequent object-store component suite passes seven additional disk cases.
They exercise stale observations across independent handles, concurrent CAS,
immutable/conditional kind binding, cross-chunk reads, data/checksum corruption,
513 objects with a 16 KiB owner allocator, missing/foreign definitions and six
sync failures around staging and descriptor replacement. That allocator bound
excludes the fixed chunk/checksum stack buffers and caller output.

`zig build test-local-objects` passes three twelve-process races (create,
conditional replace and competing immutable writes), exact immutable retries,
stale CAS and reads from fresh processes. The Python oracle checks exactly one
winner in each race and the actual stored bytes. It is included in `just test::unit`.
These cases qualify local POSIX locks and publication under the exercised
schedules; they do not establish distributed object-store behavior or safe
physical collection. The [object contract](../../../contracts/TRANSIT_STORAGE_V1.md#local-object-persistence)
states the deletion and retention boundary.

Table component recovery additionally passes a 5,001-frame replay across every
bounded log page, repeated replay without duplication, and refusal of reads,
writes and flushes after a missing accepted prefix. Allocation-failure enumeration
checks that row-visibility allocations precede the durable append. A real disk
case writes a raw `TSEG` file, reopens the WAL/object providers, and reads both
flushed rows and a three-frame unflushed suffix through one-frame log pages.
Registered Tables own cloned schema storage and reject implicit definition or
partition replacement and epoch regression. The storage and catalog package
tests pass 23 and 89 cases respectively at this revision. This does not qualify
bounded memtable residency, historical snapshot pins or installed SQL cutover.

The subsequent storage-format cutover passes the storage, Fuze and catalog
package tests. New cases preserve three keyless rows with identical values
through flush and selective deletion/recovery; reject an unavailable pre-flush
snapshot; reject foreign WAL/segment/deletion/manifest definitions, including
artifacts with recomputed valid checksums; and reject schema or deletion-vector
substitution before a point lookup. A complete older short WAL header is
incompatible, not a truncatable torn tail. Schemas, binding resources and
independent signing fixtures are regenerated for the replacement shared
definition. The old identifier remains in protocol rejection tests.

## Table partition acceptance and retained read pins — 2026-10-22

In the pinned development shell, `zig build test` passes in
`packages/zig/transit-storage` and `packages/zig/transit-fuze` after adding
[`TablePartition`](../../../packages/zig/transit-storage/docs/table-partitions.md).
The storage cases exercise:

- Exact point/bulk retry after a lost reply and real disk reopen, with altered
  concrete content rejected under the original binding.
- A staged two-row segment denied by the final injected policy fence: no rows,
  receipt or WAL frame becomes accepted. A later authorized retry accepts both.
- An underlying append that persists and then reports uncertainty: reads and
  flushes refuse until recovery reconstructs the accepted operation.
- Two competing Table roots: the stale candidate cannot publish; recovery sees
  the winner and the original expected-data position remains stale.
- 129 rows and receipts through one resident index page, flush and deletion,
  then replay and a 128-row scan. The scan performs one segment read and one
  row-group decode, rather than one per row. Earlier read roots retain their
  original WAL row after checkpointing.
- One 64-row statement containing 8 KiB values, with an accepted WAL frame above
  512 KiB and a column page above 256 KiB. Exact segment reads agree; a group with
  an unencodable long sort key remains eligible for range scanning.
- Lost durable pin acquisition replies, disk reopen, unflushed read preservation
  through flush/deletion, altered-frontier rejection, current denial and durable
  idempotent release. Interrupted pre-publication pin staging leaves no pin; 129
  durable pin records exceed the one-page cache.
- Allocation-failure enumeration confirms that visibility allocations occur
  before the durable acceptance record.

The supporting immutable-index proof reopens 513 keys with one resident page,
scans without a cache, preserves an earlier root, rejects missing/corrupt pages
and cannot publish a failed private candidate. These are component proofs over
the stated cache/operation bounds, not a total process RSS measurement.

The guard is injected in these tests; they do not establish a live native policy
adapter, catalog name/DDL publication, installed direct SQL or distributed
transactions. This owner retains all WAL and objects and has no physical GC or
trim operation. Pin tests therefore do not qualify a collector removing data
concurrently. Existing actor Table callers remain until the public cutover.

The subsequent `transit-backend-local` package suite passes composition checks
using an actual native credential, signed original-subject proof and resource
grant. An unrelated accepted native input leaves the data fence valid; two data
partitions accept independently. Revocation rejects the old policy epoch, a
native storage fence rejects the old storage epoch, and current resource
retirement denies through the existing lifetime/dependency rules even when role
permissions still exist. Native publication cannot acquire the exclusive side
while a data authority guard holds its shared fence.

A real native grant is revoked after private Table segment/index staging and
before final acceptance. The whole batch remains absent, including its receipt;
current observation is denied. Regrant permits the same exact operation, which
survives replay. A separate physical-quota test denies data objects and log
acceptance without changing the partition, while an explicitly selected control
operation can use the reserve. These checks qualify the local adapter, not a
public direct Table endpoint or SQL cutover.

`nix develop --command just test::unit` and
`nix develop --command zig build test-local-native-service -Doptimize=ReleaseSafe`
pass after adding the shared authority fence. The public service proof covers
signed native reads/turns, invalid replies, exact retry after restart, revocation
and local maintenance; it does not exercise the unfinished direct Table route.

## Native authority over local storage — 2026-10-22

`nix develop --command zig build test-local-native` passes against temporary
POSIX directories using the existing core authority engine and the new
[local adapter](../../../packages/zig/transit-backend-local/README.md). It covers:

- Lost native append replies followed by exclusive reopen and exact retry,
  without another process or repeated staging.
- 129 paged keys and immutable block bytes recovered through a one-page cache.
- Data quota exhaustion preserving the old head and caller sequence, with a
  control checkpoint still admitted through the reserve.
- One turn atomically publishing a KV mutation, an immutable block, consumed
  input, an output and an undispatched effect intent. Before commit none is
  visible; after a lost reply/restart all are recovered. Physical history trim
  preserves the exact receipt, and current resource revocation denies a later
  block read and clears its output buffer.
- Competing private candidates from two engine instances: one conditional WAL
  acceptance, one conflict, and the same recovered winner.
- Exclusive native ownership, foreign owner markers and refusal to initialize
  native authority alongside unrelated existing object data.

The root unit suite passes after carrying control-reserve eligibility in the
core's prepared transition. The local package joins that suite and standalone
package checks. These are native storage/authority component proofs; they do
not qualify installed node/launcher composition, a Document service lifecycle,
standalone payload publication, retained-root physical collection, power-loss
behavior or direct Table SQL execution.

`zig build test-local-native-service` subsequently passes the existing signed
public-client fault corpus against `transit-node` with `local_directory`. The
fixture starts no external storage service. It checks signed paged reads and
turns, malformed replies, a lost turn receipt, node SIGKILL/restart, exact receipt
recovery and current revocation, with one resident page and one CPU. It also
checks real native WAL and immutable object files. HTTP admission, snapshot
registration, retries and lane synchronization are shared with the Ursula node
in `NativeServer.zig`. A subsequent run with local request metrics enabled also
checks bounded numeric provider counters, actual read/write byte accounting and
diagnostics across restart. A Debug run times out in Station recovery at its
240-second schedule limit. The prescribed `just test::growing-service` ReleaseSafe
run subsequently passes the complete caller, maintenance, Station, query and
quota corpus with the new definition. Station recovery takes 64.844 seconds;
the timeout is unchanged. `just check` also passes, including root units,
generated contracts, frontend checks and the documentation build.
The local service target additionally runs maintenance inside the exclusive
node owner, using the existing public caller's lifecycle assertions. It checks
accepted-floor WAL trimming, restart after trim, cancellation of pending effects
and outputs without dispatch, resource/dependent retirement, preservation of an
independent resource, revocation across restart and resumed trimming after a
new grant. The independent Python reader verifies the on-disk trim metadata's
checksum. This does not qualify local immutable-object collection, standalone
payload publication, the launcher default or direct Table SQL storage.

The subsequent `just test::server` ReleaseSafe run passes the source-built local
launcher's complete core lifecycle corpus in 434.74 seconds. It observes real
`.twal` and immutable `.data` files beneath `data/native`, and verifies that no
MinIO, Ursula or separate maintenance process is launched. Existing SQL reads,
writes and DDL run over native state in that local store. The corpus covers
configuration reload and recovery, independent console snapshots, lost replies,
child/manager interruption, retained operation identity, current revocation
across restart, missing-storage refusal and intentional DROP/name reuse without
recreating default data. Two earlier runs expose fixture assumptions: a removed
provider process selector and an opt-in retry which omits `HttpCapacity`. The
fixed fixture faults the live requester and retains the same signed request
through bounded capacity retries, with unchanged deadlines.

The installation layout cutover replaces the shared definition and regenerates
contracts, bindings and signatures. Missing/foreign definitions, including the
preceding local-node definition, reject before reopening accepted work. This
source-built launcher evidence does not establish the Nix bundle's clean-build
qualification, standalone payload ownership, local object collection, direct
Table segment execution or completion of declarative data lifecycles.

## Integrated storage foundation

The [matched campaign](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/mutation_latency/results/2026-10-19/README.md) compares
`ee88a131` with runtime `29765ef0`, using ReleaseSafe and sequential disk fixtures
after builds finish. Its record (archived)
preserves commands, source/binary hashes, raw reports, intermediate controls and
failed attempts. Both real SQL wire campaigns complete 400 reads and 36 mutations
with cross-protocol readback. The final console controls include narrow, wide and
nested mutations, 100 reads, and retained history with 21 mutations plus 92 reader
queries. Empty/LIMIT 0 reads regress and node HWM increases; see the report for
sample sizes, cache differences and limits on attribution.

At `29765ef0`, `just test::typed-tables` passes the complete native deployment
schedule in 524.817 seconds: all 28 logical descriptors, typed defaults/NULLs,
prepared parameters, catalog replacement, retained snapshots, exact lost-reply
recovery, current denial and node/provider restart. Four-row disclosure takes
17 requests through `nextBatch(8)` versus 25 through independent row pulls;
LIMIT 0 and empty predicates use 15 and 17 respectively through either path.
Those observed counts define explicit regression ceilings in the native harness.
Buffered revocation still prevents the next disclosure. These counts apply to
this fixture, not arbitrary query shapes or cardinality.

Normal Flight/ADBC and the Flight fault schedule also pass against runtime
`29765ef0`. They cover real finite statements, full-width/NULL rows, independent
Python/C ADBC consumption, diagnostics, exact retry, delayed concurrent fetches,
control progress, slow HTTP/2 clients, current SELECT denial after a returned
batch, interrupted duplicate fetch, gateway/worker/node/store restart and
permanent retirement. The record retains their logs and commands. Two fault-run
attempts fail in Nix before execution because cached shell derivations cannot be
recreated; the successful retry disables the evaluation cache in the actual
Flight shell. These setup failures are not counted as executed fault proofs.

The separate offered-load controls both admit two of 48 scheduled commands and
explicitly refuse 46, with no uncertain outcomes. Initial revocation is also
refused; its retry completes after the burst. Exact receipt retries, current
denial, drain and restart pass. This evidence does not establish uninterrupted
control admission at write saturation or a throughput SLO.

The current-definition 1,024-key cold-storage proof passes with two decoded pages
(34,064 resident cache bytes), 758 created pages and 195 segments. The
[retained record](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/mutation_latency/results/2026-10-19/pages-packed-s3-1024-2-batch8.json.gz)
includes checkpoint/trim, provider/process restart, 16 MinIO objects, adapter
write-peak RSS of 18,436 KiB and separate recovery/provider observations. Pending
source changes are recorded in its provenance. This is primitive storage/recovery
evidence, not an isolated service benchmark or a whole-provider memory bound.

Complete ordinary qualification runs separately with `just ci-clean` against
committed HEAD; the PR records its exact revision and outcome. Focused proofs
and matched measurements do not substitute for that gate.

The native latency probe records a completed trace after forwarding the response,
including any downstream write failure. Its unit checks explicitly join that
recording before inspecting the trace; receiving HTTP bytes alone does not join
the proxy handler. Counts, retained-event bounds and payload exclusion remain
unchanged.

The clean language-ring attempt at `799b2e6b` rejects a Table block read in its
test proxy: its route allowlist omits `/v1/blocks`, so the installed Python worker
correctly reports `InvalidAuthorityResponse` for the proxy's HTML error. The
proxy now forwards all three current native routes while still rejecting raw
double slashes. Lost-receipt, unavailable-read, exact-retry and cross-language
value checks remain unchanged; the failed attempt is not a completed ring proof.

The first clean attempt at `321be45a` passes `check-core`, then fails to compile
the transition-property driver because its test store lacks the new block
interface. The delivery/storage simulation stores require the same update;
the storage fixture's fault-injection `begin` also collides with the backend
publication hook and is renamed `beginFault`. These test-only adapters now own
and verify block bytes without changing production behavior. Their in-memory
maps do not model physical segment placement or reclamation. The failed clean
attempt does not establish completion of the ordinary suite. Focused reruns with
the pending fixture changes pass 40 transition traces / 1,687 steps, 14 delivery
traces / 749 events, six resource smoke traces / 112 events and eight scheduler
traces / 542 events, including identical replay for the simulation schedules.

The next clean attempt at `f3fee42f` passes its first 15 tasks, including the
isolated Zig SDK and packaged runtime boundary, then detects SQL-wire fixture
drift. The committed gateway bytes already use the current definition; two
independent Python-oracle inputs still name the previous definition. Updating
those inputs makes the unchanged fixtures match; the independent comparison and
shared gateway/PostgreSQL/MySQL package suites pass. This partial clean attempt
also does not establish completion of the ordinary suite.

The clean attempt at `569b71d2` passes its first 17 tasks, then detects a
saved-command fixture that omits the new `blocks: null` field. The ABI export
oracle now requires that field; the shared SDK recovery oracle compares the
ordinary HTTP representation while still requiring byte-identical retries and
unchanged saved bytes. Populated bodies remain part of the comparison.

The installed Python Station schedule then exposes two Debug stack overflows
on its declared 8 MiB worker. Recursive saved-envelope decoding copies the bulk
body through typed JSON frames; block reads copy their response through the
timeout selection queue. Import now decodes the signed request and body
separately into owned operation storage, retaining public validation and exact
canonical-byte checks. The transport keeps one bounded response slot and queues
only completion status. Cancellation joins its producer before releasing any
raced owned response. The maximum 128 KiB saved-operation regression executes
import on an explicit 8 MiB thread; client package checks also cover nested
response ownership, response budgets and timeout cleanup. Neither fix increases
the advertised stack requirement or changes the current contract definition.

With those pending fixes, the installed Python Station runner completes the
shared schedule: 46 Table terminal outcomes, 219 queue drain turns, 41 logical
query rows in six independently consumed Arrow streams (41,992 bytes), 275
publication/receipt rounds, retained output after handle destruction, current
denial, expiry and exact host/provider restart recovery. Two lost/unavailable
outcomes reconcile with unchanged signed attempts and two unavailable reads
repeat within the original progress budget. The subsequent `just test::client-abi`
passes native/port ownership, malformed input, wide identities, lost/invalid
replies, seedless host-loss retry, disk restart and revoked recovery. This focused
installed-consumer run is separate from complete committed-source qualification.

At `067d40de`, `just check` passes and clean CI completes 35 tasks before
`test::growing` fails to compile: its final corruption fixture still references
the removed single-stream page-store name. It now derives the physical segment
from the accepted catalog root, deletes that segment only after restart checks,
independently verifies its absence and requires reopening to fail with
`PageUnavailable` without changing journal position or creating pages. The
focused rerun passes all four disk phases with 64 retained values, one decoded
page (17,032 cache bytes), captured views, grants and exact receipts. The failed
clean attempt is partial qualification, not a completed ordinary suite.

At `a3a61f8a`, `just check` and `just test::flight-faults` pass. Clean CI passes
43 tasks, including all core checks, growing services, native concurrency, full
block publication, physical collection and public queries. The combined Table
writer then passes its console mutation/recovery schedule but fails when its
manual delivery helper races the background courier: the observed pending output
has already been delivered, so the authority returns `OutputAlreadyResolved`.
The helper now treats only that validated rejection as a step with no delivery,
matching the public courier; other errors still propagate. Accepted identities
and unknown-outcome handling are unchanged. The new storage proof executables
also use streaming stdout so redirected evidence cannot overwrite earlier log
bytes. This interrupted clean run does not establish a complete ordinary pass.
The focused `just test::table-query-writer` rerun with the corrected helper passes
in 93.545 seconds: 116 turns, two recovered initialization receipts, interleaved
durable/interactive snapshots, saved console recovery, cancellation races and
current policy/native denial. Installed SDK variants are unselected in this run.

At `15195190`, focused catalog, typed Table and SQL gateway schedules pass, but
the full SQL wire schedule stalls during its 40 KiB row. The account worker first
receives repeated `StorageQuota` refusals, then exceeds its captured turn deadline
and stops with `StateViewExpired`. Routine turns eligible for recovery had been
charged exclusively to the 64 MiB control reserve despite available ordinary
capacity. Allocation now uses ordinary capacity first, reserving fallback access
for eligible work when ordinary capacity cannot fit it. The ledger records the
actual charged class for exact carry and release. Unit and disk regression cases
cover this accounting without raising quotas or deadlines. The interrupted wire
run is incomplete and does not establish a pass for its wide-row or later cases.
The focused adapter unit suite and disk collection rerun pass with the accounting
fix: the quota-pressure checkpoint reserves 3,223 control bytes, retains that
charge through the first collection and provider restarts, then releases it after
history trimming and the second collection. The two cycles reclaim 216,440
accounted bytes with one decoded page. This fixture adds the checkpoint and is
distinct from the earlier recorded collection run below.

At `fe87e9a4`, root checks and the Flight fault schedule pass. Clean CI passes
50 tasks, including the complete SQL wire and maintained-query schedules, then
fails the exchange corruption fixture. Its injector changes an exchange chunk
returned incidentally by a broader KV scan; the caller filters that entry out.
With Table records now stored as blocks, the scan includes different neighboring
entries. The injector now targets the explicit point read that consumes the
segment bytes, retaining the digest-rejection and unchanged-acceptance checks.
The focused rerun with that correction passes both one-partition/one-worker and
seven-partition/three-worker layouts in 675.342 seconds of native execution.
It verifies corruption, lost producer/acceptance replies, every recorded handoff
boundary, missing/denied restore, source expiry and disk restart. The interrupted
clean run remains partial qualification; the fixture correction changes no
runtime behavior or proof limits.

At `081170b0`, root checks and the complete clean `core`, `growth`, `experience`
and `launchers` lanes pass (75 tasks across those four lanes). The two bindings
lanes fail in installed C Station and Python catalog consumers with `SIGSEGV`;
the ordinary qualification is incomplete. A retained C core dump identifies
another Debug stack overflow during Table creation: the observation and deadline
frames still copy the bounded block response by value. The client now gives
those frames one heap-owned response slot, joining the transport before ownership
transfer or error cleanup. Client package tests pass, including a maximum
128 KiB response on an explicit 8 MiB thread, ownership across a subsequent
exchange, corrupted-body rejection, owned nested responses and timeout cleanup.
This changes neither the declared stack requirement nor the wire definition.
The focused `just test::typed-tables --cold --sdk python` rerun passes with the
response-slot correction: 538.710 seconds of fixture execution, installed
synchronous and asynchronous catalog lifecycles, exact saved-intent recovery,
nested values, prepared parameters, current denial and provider/owner restart.
This SDK-selected run does not select the separate 28-type native matrix.

At `1ed89190`, root checks pass but the Flight fault schedule exhausts its fixed
8 MiB request workspace while reading a retained result. Replacing an idle HTTP
connection can leave a per-call response slot behind a retained allocation;
fixed allocators cannot reclaim that slot out of order. The client now reuses a
response arena across exchanges and releases it on destruction. The regression
fails before this correction, then passes 64 maximum-size block replies plus
corruption rejection while replacing connections within the same 8 MiB workspace
and 8 MiB calling stack. A separate failing-allocation/budget regression verifies
that local failures clear earlier wire diagnostics without contacting the peer.
The client package suite passes with both corrections. The failed Flight run
remains incomplete qualification; no workspace, stack or deadline is increased.

At `efb7cee9`, root checks and Flight faults pass, but the clean Python relational
consumer overflows its 8 MiB Debug calling stack while opening Table sources.
A retained core identifies large scan copies in `RelationalTables.open`,
`TableScan.open` and `TableScan.openResource`. Scan caches now have one owned heap
allocation, charged through the supplied query allocator and released on failure
or destruction. Shared-lease aliases retain independent caches. Query package
tests and the durable query recovery schedule pass. The installed Python
relational rerun passes in 56.066 seconds of fixture execution: synchronous and
asynchronous clients, both source layouts, repeated opens/pages/closes, current
denial, lost-host rejection and ordered overflow. The same clean attempt also
exposes the probe trace synchronization race described above; neither failed
lane establishes complete qualification.

## Segment storage and physical collection

Reproduce the focused schedules with `just test::storage-collection`,
`just test::native-blocks`, `just test::block-storage` and `just test::pages` in
the pinned development shell. The native overlap schedule is
`just test::node-concurrency`. Cold storage and actual disk pressure have separate
tasks, `just test::pages-cold --keys 1024 --cache 2` and
`just test::growing-capacity`.

The disk segment, native block and concurrency proofs pass with current native
v1 definition `1dbbcfbb8c493a1e1a1ef340811178dfb7068830b58f9412d97881d61ab75a9f`.
Segments privately group pages/blocks, reserve encoded bytes, verify provider
readback and close before reference publication. Page fault schedules reject
lost creation replies, incomplete coordinates and corrupt readback; old roots
survive provider SIGKILL, root checkpoint and history trim. The 64-key fixture
uses two cache slots and creates 48 pages in 15 segments. It reports adapter and
provider RSS separately; this is not a whole-provider cardinality bound.

`test-storage-collection` passes on disk Ursula with one resident page. Two
collection cycles reclaim 217,905 accounted encoded bytes in the recorded run,
including unreachable candidates and an old current segment after relocation.
The harness independently observes that old segment's 404 response, then verifies
both current and retained values after provider/process restarts. It injects
corrupt reachable bytes during marking and loses a successful delete reply.
Neither incomplete marks nor elapsed volatile-read grace without a durable time
fence permits deletion. Absent and unsealed candidates receive permanent closed
names; delayed creation conflicts and only their data charge is released.
Quota and candidate-budget refusal preserve the accepted head and accounting.

Core/backend unit checks exercise resource-scoped ownership traversal across
branches and serialized resume, ownership-class mark reuse, exact quota release,
epoch conflicts and relocation without logical revision changes. An early
mark-key review found that shared captured catalogs must distinguish the selected
resource and ownership class; those regressions now have explicit checks.
These tests use an injected trusted clock to cross the full grace interval.
They do not prove host power-loss behavior, backup erasure, immediate WAL shrink,
or asynchronous cold-object deletion. The integrated measurements and native
consumer proof above have separate scopes; committed-source clean CI remains
the final integration gate.

The [physical capacity record](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/storage-foundation-capacity-2026-10-19.json)
passes with 72 retained 256-byte values and one decoded page (17,032 resident
bytes). Actual ext4 ENOSPC denies writes without advancing position 96. Releasing
only the preallocated 1 GiB reserve permits revocation, expiry, effect closure,
drain and checkpoint/trim through position 130. Provider SIGKILL/restart retains
all values and the completed maintenance issues only GET/HEAD. The two preceding
Debug setup attempts exceed the unchanged 120-second phase deadline; the task
now selects ReleaseSafe, matching the service-load proofs. This run records its
pending harness changes and is separate from committed-source clean CI.

## Table records on native blocks

The Station (120 tests), catalog (83 tests), query (138 tests), core and client
package suites pass for Table rows, index nodes, schemas, metadata and immutable
predecessors stored through the native block index. Schedules cover private
visibility, exact retries, block/header/digest corruption, retained revisions,
current denial after cached reads, large multi-turn records and reservation
cleanup. The current v1 identifier and generated consumers are replaced together;
`just contract::check` passes after regeneration.

The disk native-block proof also passes with the new definition and explicit
`InvalidBlockBody` rejection before writes. `test-growing-service` also passes
the retained Station Table and query recovery schedules, including poisoned
reads, cold storage, one resident page on recovery and quota/control reserves.
The earlier Table/disclosure definition (`b61c36…`) completed the native
typed-Table deployment proof in 524.664 seconds,
including all 28 logical descriptors, supplied-host lost receipt recovery,
original/replacement catalog identities, current denial, retained queries and
node/provider restart. Early runs exposed a saved pending request
missing its body, an obsolete expectation of multiple recovered Table turns,
and a supplied host treating a moving read cut as fatal. The fixtures retain
the complete pending command and count the bulk successor; the host retains
exact pending bytes across ordinary contention. Those failed runs are not
reported as completed service proofs. End-to-end latency and physical
reclamation require their separate remaining schedules.

The query, shared gateway, PostgreSQL and MySQL package suites pass with bounded
result disclosure. At that earlier definition, the native four-row scan used 19 requests through
`nextBatch(8)`, versus 27 through independent row pulls; LIMIT 0 and empty
predicates retained the same 17 and 19 requests. These are historical counts;
the current metadata/block prefetch changes that path. Buffered revocation rejects the
next disclosure. PostgreSQL unit schedules cover one-row portal suspension,
revocation before and after materialization, and malformed empty batches.
The complete real SQL driver proof also passed at that earlier definition,
including TLS, settings reload, role changes, credential rotation, detached
writes, schema changes and drain. Its 40 KiB input exceeded the original wire
wait, then completed under its original identity after 2,086.9 seconds. This
exposes the remaining small-message ingress cost; it is not a passing latency
budget. Current-definition full native/SQL qualification belongs to the separate
committed-source CI result, not these earlier package/service observations.

## Native bulk resource publication

On October 18, 2026, `just test::native-blocks` passes with 16 records and 128 KiB
in one turn over disk Ursula. The independent Python/OpenSSL peer drops a staging
reply, then an accepted commit reply, kills the node and provider, and reconciles
the original signature without a body or new provider writes. A second turn
replaces/deletes values while a retained read version keeps the originals.
Corrupt/missing bytes reject. A provider barrier holds a block read while a
revocation commits; the read discloses no body. Restored rights and another
node/provider restart preserve the retained data. The first attempt supplied a
view deadline outside the native trusted-time lifetime bound and failed; the
fixture now requests a valid 30-second view without changing authority limits.

Core schedules additionally exercise complete-body validation before writes,
private preparation without visible progress, atomic metadata/output acceptance,
volatile snapshot and retained-version roots, failed read-body cleanup and
current permissions on historical receipts. This evidence does not establish
physical reclamation or Table performance; those require their own schedules.

## Immutable block codec and index

On October 18, 2026, protocol, core and Ursula backend package tests and
`just test::block-storage` pass. The disk fixture publishes a full 128 KiB
batch, retains old and successor roots with one resident metadata page, and
checks both after provider SIGKILL/restart. Lost staging replies, corrupt
readback and missing bytes prevent publication; subsequent good reads retain
the original values. Unit schedules cover each block/page staging failure,
canonical base64, owned parser bytes and independent digest vectors.

This proof exercises the generic index and backend beneath a conditional test
journal. Native resource authorization, Table integration and physical
reclamation require separate proofs; this result does not establish them.

## General Table schema foundation

`just test::table-schema` checks independently generated Python schema bytes and
13 row/default/constraint cases, then executes the Zig schema and logical-type
tests. The 2026-10-05 run passes 28 tests. It covers nonzero/nonreused column IDs,
omitted nullable cells, explicit NULL versus DEFAULT, required fields, reordered
assignments, integer overflow, Unicode scalar length, unsupported key types,
all logical families as non-null typed defaults, nested optional missing versus
source errors/conflicts, truncated envelopes, foreign definitions, canonical
flags, ownership and allocation failures. The Python oracle imports no Transit
implementation and fixes a complete schema encoding and SHA-256 fingerprint.

The Fuze package's `zig build test` also passes with these schema tests enabled.
This is pure model/codec evidence. It does not qualify generalized native Table
storage, SQL execution, catalog routing, DDL publication or restart recovery.
Those remain separate implementation and proof obligations in
[Typed Tables](../../handbook/reference/tables.md) and [#75](https://github.com/spoke-sh/transit/issues/75).

The subsequent physical-row/key run passes 34 focused tests; the evolution run
passes 33, including shared schema/type dependencies. Independent Python bytes
add a complete physical row, layout fingerprint, equality key and digest. Cases
exercise signed-zero key normalization with exact stored IEEE bits, object/layout
mismatch, nested ownership, distinct duplicate-row identities, metadata-only
rename/default changes, nonreused dropped IDs, required-field tightening,
overflow/inexact conversion rejection and key-index rebuild requirements. These
remain pure envelopes/transitions, with no disk/publication claim.

Station's package suite passes the general `TableData` candidate tests on
2026-10-05: 72 keyed rows across multiple index levels, stable key updates,
same-value/zero-match counts, duplicate keys and row identities, retained roots,
32 KiB values, unkeyed duplicates, a synthetic digest collision, write failure
after staging and allocation-failure cleanup. Index deletion separately removes
a 512-key permutation, checks retained roots, prunes empty branches, rejects
read denial and preserves the accepted root after partial candidate storage.
These use in-memory immutable test stores. They establish candidate semantics,
not durable Table head publication, a performance comparison or disk recovery.

The scalar SQL name resolver passes 20 focused tests including shared logical
type dependencies. It normalizes all 37 selected aliases in upper/lower case,
retains INT8's eight-bit meaning, checks decimal/VARCHAR/temporal parameters and
rejects unqualified padding, binary lengths, FLOAT precision and time-zone forms.
These are resolver tests; native DDL admission is not established by them.

The Fuze package suite passes seven general DDL tests, including the reported
nullable CREATE example, a realistic five-column schema, composite keys, escaped
Unicode names, recursive type/default constructors, exact scalar/temporal values,
map ordering/duplicate rejection, incompatible constraints, bound ALTER/DROP
identity, complete input consumption and allocator-failure cleanup. The first
run exposed a duplicate-key diagnostic falling back to `InvalidPrimaryKey`; the
compiler now retains `DuplicatePrimaryKeyColumn` before binding. This is compiler
evidence, not console execution or independent ANTLR lifecycle qualification.

The first repository check at this checkpoint stops at a missing mapping for
`DuplicateMapKey`. Reviewed mappings now cover 113 SQL compiler causes, including
general DDL/type failures. A second mapping run exposes the bounded schema-default
writer error; its owner now projects `TableSchemaTooLarge` with an executable
oversized-default test. The Fuze package suite, diagnostic mappings and inferred
error-boundary checks pass after these corrections. DDL diagnostics preserve the
original cause and location and leave unknown/allocator failures unclassified;
compile rejection never acquires uncertain-write recovery advice. This does not
constitute a full repository-check or clean-CI pass.

The Station package suite passes 65 tests after adding private Table overlays
and captured-KV page storage. A small keyed insert stages only its row and final
index leaf and composes a test head/outcome in exactly four private writes.
Forty rows exercise multiple index levels, a 4 KiB row, lost pre-commit staging,
retained roots and released Publication staging quota. Negative cases cover
same-ID content changes, foreign/missing manifests, current denial, cross-resource
reads, malformed/truncated pages, record limits, allocator failures and rollback
when turn composition exceeds four writes. Initial development runs reject an
extra Zig semicolon and a test that incorrectly expected different publication
inputs to have identical attribution; both are corrected before the passing run.
These use captured-turn in-memory stores, not a disk-backed Table service or
native head/admission/recovery integration. Logs are in the owned campaign
`/var/tmp/transit-table-75-_el6xx0v/table-pages-test3.log`.

The page checkpoint passes full pinned `just check`, including the existing
generated/native contracts, diagnostic boundaries, CLI cases, frontend checks
and handbook build (`pages-check.log` in the same campaign). Subsequent namespace
hardening separately rejects orphan committed/private records before manifest
creation. The head checkpoint passes **68/68 Station tests**: actual head/schema
publication, a four-write small insert, stale replacement rejection, irreversible
retirement with retained data, count/identity constraints and malformed envelopes.
Independent Python bytes fix head/page/manifest encodings and namespace keys;
`just test::table-schema` and root checks include fixture drift. The head test
run takes 904 ms with 22 MiB reported maximum resident memory; this is a test
process measurement, not a runtime performance result. Full checks and clean CI
for subsequent head/transaction changes are separate obligations.

The single-row publication coordinator passes **72/72 Station tests**. New cases
cover exact small-write publication, same-value/absent counts, retained rejection
after conflict removal, receipts after retirement, changed-intent rejection,
7 KiB staged rows with discarded pre-commit proposals, competing-write fencing,
cancellation/current denial, nonreused reservations and later work. Allocation
failures and a turn with three preexisting private writes restore the complete
original proposal. Independent Python bytes cover the 158-byte write receipt
and its full-width key; malformed/foreign records reject. The final suite reports
1 s and 23 MiB maximum resident memory in `table-write-final-test.log` under the
same campaign. This remains in-memory captured-turn evidence, without native
SQL admission, predicate/multi-row publication, disk recovery or latency claims.
Cancellation retains unfinished Publication quota pending explicit cleanup.

Extracting logical predicate atoms/programs from file execution into the shared
`LogicalPredicate` owner passes the Fuze package suite and semantic mapping gate.
Existing finite predicate fixtures still exercise the same comparison, state,
Boolean, ownership and error behavior. This refactor adds no Table SQL admission.

The typed DML compiler checkpoint passes **187/187 Fuze tests** and **72/72
Station tests**. It covers reordered/defaulted multi-row INSERT, duplicate
unkeyed values, stable assignment IDs, key updates, NULL/Boolean precedence,
all-row DELETE, exact decimal/date comparisons, nested values, Unicode bindings,
complete-input rejection and allocation failure. Schema insertion/patch validation
also rejects an oversized schema before column-index workspace access. An initial
Zig compile rejects a shadowed helper name; the corrected run passes. Diagnostic
checks cover 18 inferred boundaries and 116 SQL codes; the mapping gate first
rejects duplicate ownership of shared predicate errors, then passes with one
source owner and the separate typed-DML projection. Documentation validation
passes 5,285 local links across 520 files. These are compiler/captured-turn proofs,
not native multi-row admission, ANTLR qualification or durable SQL execution.

Key-addressed SQL patches pass **188/188 Fuze tests** and **73/73 Station tests**.
Only a complete conjunction of primary-key equalities qualifies for the point
path; extra predicates, repeated keys, OR and NOT retain finite-scan semantics.
Retry identity binds the supplied key and assignments, independently of current
unassigned cells. Tests replay updates after intervening changes and deletes
after key recreation, and reject changed keys/assignments under the same identity.
The wider-schema fixture initially tries to open a Publication cursor after
private publication and correctly receives `PublicationReadAfterMutation`;
it now commits publication before validating the head in a fresh captured turn.
The test explicitly preserves that gate. Documentation validation passes 5,285
links across 520 files. Logs are `key-patch-fuze-test.log`,
`key-patch-station-final.log` and `key-patch-docs.log` in the same campaign.
These remain compiler and in-memory captured-turn checks, without native SQL,
disk recovery, whole-statement publication or performance qualification.

The finite statement coordinator passes **189/189 Fuze tests** and **78/78 Station
tests**. It discards and recomputes every proposed turn while testing later-row
duplicate rejection, all-or-nothing multi-row publication, predicate key updates,
same-value/absent counts, unkeyed duplicates, competing-write fencing, cancellation,
retained roots, exact receipts after conflict removal and allocation cleanup.
Forty rows grow multiple index levels, including a 6 KiB value. Independent Python
bytes fix the resumable progress envelope and namespace key. Typed intent tests
bind assignment values, schema, predicates and the 4 MiB operation limit while
ignoring SQL whitespace/keyword case. An initial Station run rejects the use of
the user-key deletion API for a reserved framework progress key; the coordinator
now uses the existing framework write API without weakening key protections.
The final Station suite reports 5 s and 23 MiB maximum resident memory, not a
runtime latency measurement. Logs are `statement-fuze-test.log`,
`statement-station-final.log` and `statement-docs.log` in the same campaign.
These are in-memory captured-turn proofs. Native admission, schema rewrites,
cancelled-page cleanup, disk faults and clean committed-HEAD qualification remain
separate obligations.

Closed-candidate cleanup passes the root `zig build test` (**660/660 tests**,
with other cached suites) and the final **81/81 Station tests**. Tests discard
each cleanup proposal, recover unfinished Publication quota, skip hundreds of
unused reserved IDs and preserve accepted roots, receipts and nonreuse floors.
They reject cleanup of active/applied work, changed cursor identity/ranges,
malformed/foreign cursor bytes and current access denial. Independent Python
bytes fix the 93-byte cleanup cursor and key. The final Station run reports 5 s
and 24 MiB maximum resident memory. Logs are `cleanup-station-test.log`,
`cleanup-oracle-test.log` and `cleanup-docs.log` in the same campaign. These are
captured-turn unit checks and existing root tests, not new disk cleanup, native
admission or physical-erasure evidence.

The schema publication coordinator passes **86/86 Station tests**. Captured-turn
cases cover add/drop/rename columns, stable/nonreused identities, future-only
defaults, required-field validation, exact numeric/key conversions, character
limits, empty Tables, stale schema rejection, competing writes and cancellation.
Late NULL, missing-field, character-length, overflow and inexact-conversion
failures retain the old schema/root and original rejection after data changes.
Every proposed ALTER turn is discarded once before recomputation; retained rows
decode through the original schema. A 6 KiB source cell and 5 KiB typed default
exercise large schema and rewritten-row Publications without reading private
descriptors. Allocation failure, current denial and changed progress revisions
reject without publishing a successor. Final evidence is
`alter-station-final.log` and `alter-docs.log` in the same campaign. These checks
cover schema publication helpers; catalog rename/DROP/dependencies, native caller
admission, disk recovery and performance qualification remain unproved here.

The coordinator tree passes full pinned `just check`, including native/generated
contracts, all diagnostic gates, unit/CLI checks, frontend suites and the handbook
build (`schema-coordinators-check2.log`). Its first run stopped at the new typed
intent scratch-buffer `WriteFailed` cause. That owner now retries within the
bounded value envelope, projects a full-envelope limit as `MutationBatchTooLarge`,
and has a reviewed control-flow mapping plus tested 4 MiB guidance. The passing
run includes that correction. This remains a working-tree check, not committed
clean CI or qualification of subsequent catalog/runtime integration.

General catalog metadata passes **31/31 catalog package tests**. New cases cover
owned UTF-8 names through 255 bytes, full-width IDs, immutable schema references,
hashed-name collision-bucket keys, inline/chunked staging, discarded proposals,
retained revisions, same-revision content changes, foreign/missing manifests,
orphan adoption rejection, poisoned reads and allocation-failure cleanup.
Independent Python bytes fix metadata, manifest, name digest and namespace keys.
An initial compile used removed Zig array-repeat syntax; the fixture now constructs
the name with a comptime loop. The next test found an incorrect hand-calculated
maximum; the independently fixed envelope is 436 bytes. Final evidence is
`metadata-catalog-final.log` and `metadata-docs.log` in the same campaign.
These are codec and in-memory storage checks. Live catalog routing, name
publication, DDL lifecycle, native clients and disk evidence remain separate.

General namespace resolution passes **35/35 catalog package tests**. The new
cases exercise independent metadata/data/schema permissions, administrator
restoration, twenty-object pagination, stale cursors, exact names, mismatched
bindings and heads, malformed pages, poisoned reads and paged DROP dependencies.
History references remain distinct from dependencies that restrict DROP. Control
records also have independent Python byte fixtures. Testing exposed a proposed
name key beyond native KV's 32-byte bound: keys now use a 13-byte digest bucket
and a complete object ID, with full stored-name comparison for equality. Final
evidence is `catalog-namespace-final.log` and `catalog-namespace-docs.log` in the
same campaign. Fixtures install definitions explicitly; these tests do not prove
CREATE/ALTER/DROP admission, dynamic native routing or durable recovery.

General captured-turn lifecycle proposals pass **43/43 catalog package tests**.
CREATE/name/schema publication, RENAME, RESTRICT DROP, same-name replacement,
absent-DROP binding, current policy revocation and original receipt retries are
exercised through the actual general catalog coordinator. Every CREATE/ALTER
staging phase is cloned, cancelled and cleaned; subsequent operations preserve
nonreused identities/revisions and recover staging quota. An ALTER on existing
NULL data rejects without changing the live definition; a subsequent defaulted
column rewrite preserves row identity and values. Final ALTER publication is
asserted to use exactly four writes. Repeating discarded DDL/cleanup proposals
reproduces the same result and mutations. Historical lookup rejects published but
unaccepted metadata. An initial new row fixture used an incorrect scalar union
shape; the corrected typed atom representation passes. Evidence is
`catalog-ddl-final.log` in the same campaign. RESTRICT uses a separately maintained
blocking index; the test asserts one page regardless of preceding history
references. These remain in-memory proposal
proofs; signed routing, disk/restart and caller/performance qualification are not
established by this checkpoint.

Catalog-bound DML routing passes **46/46 catalog tests** and **86/86 Station
tests** (`catalog-dml-final.log`, `catalog-dml-station.log`). A small keyed INSERT
publishes in exactly four writes; exact-key UPDATE uses the point path and
preserves matched=1/changed=0. Multi-row INSERT and predicates with additional
conditions select the finite coordinator. Tests preserve original outcomes after
DROP/name reuse, reject changed metadata at occupied operation IDs, fence DDL and
DML in both directions, allow original cancellation after action revocation and
deny receipt disclosure after inspect revocation. Another catalog cannot inspect
those outcomes merely by sharing the same native resource. Read permission is
separate from inspection. These routing proofs still do not qualify native
command transport, console latency or installed SDK behavior.

The catalog lifecycle/DML integration tree passes full pinned `just check`,
including generated native/ABI contracts, all diagnostic gates, unit and CLI
proofs, frontend suites and documentation build (`catalog-integrated-check2.log`).
The first run stopped at stale inventory after removing a duplicate schema
validation call; regenerated reviewed inventory passes. This is a working-tree
check, not native general-Table disk qualification or committed clean CI.

Bound logical cell encoding passes **190/190 Fuze package tests**
(`bound-value-test1.log`). It shares the canonical FVL1 cell implementation and
validates exact fixed integer-row bytes, full-width integers, floating signed
zero, decimal, nested list/array/map, JSON and admitted cell states. Every encoded
prefix truncation and trailing byte rejects; allocation-failure schedules release
the enclosing request arena. This helper does not establish a schema binding or
enable a new native request format by itself.

Recorded catalog continuations pass **47/47 catalog package tests**
(`catalog-continuation-test.log`). The native-origin test fixture admits work
through external input, resumes exact recorded CREATE and finite DML from the
configured owner, and rejects first admission, foreign process origin, external
input through the continuation entry point, changed intent and changed principal.
Policy revocation preserves pending work with zero writes; restoration permits
the original continuation to finish. This is coordinator input validation, not
evidence of a wired native self-message scheduler or disk restart.

Compact schema-bound DML payloads pass **194/194 Fuze package tests**
(`dml-codec-test2.log`). Independent Python bytes fix FDM1 with Unicode/defaulted
values. Tests preserve complete plan fingerprints and DEFAULT/NULL/predicate
distinctions, own nested data after source destruction, reject changed schemas
before value decoding, cover every truncated prefix and reject malformed
tags/counts/row states/lengths. Allocation-failure schedules include the separately
owned schema and value arena; the initial compile caught that missing schema
owner field before the corrected pass. Example int64 INSERT and point UPDATE
payloads leave room for the planned 141-byte command header within the 243-byte
Station frame payload. This is a size assertion, not native transport latency
evidence or proof that the planned command header is implemented.

Typed Table command bodies pass **50/50 catalog package tests**
(`table-command-final2.log`). Independent Python bytes fix the 141-byte header,
full-width identities, immutable metadata commitment and Unicode rename payload.
CREATE, every selected ALTER action, RENAME, bound/absent DROP and typed DML
round-trip exactly. Tests reject all DDL truncations/trailing bytes, foreign
definitions, changed metadata/schemas and foreign scopes. Actual encoded int64
point INSERT/UPDATE/DELETE fit the 243-byte Station payload. Allocation-failure
testing exposed nondeterministic allocation counts with a DML owner nested inside
another arena; retaining DML's explicit independent owners removes that layer and
passes the full failure schedule. These are codec and size proofs; native
submission, continuation scheduling and transport latency remain separate.
The first independent-fixture run failed: it used plain SHA-256 instead of the
specified Publication chunk-chain commitment, and its strict metadata fixture
reader omitted the new command fields. The corrected fixture and reader pass;
the failed `table-command-final.log` is not qualification evidence.

Explicit receipt routes and reference-only recovery pass **86/86 Station** and
**51/51 catalog** tests (`receipt-route-station-final.log`,
`receipt-route-catalog2.log`). STW1 is now 159 bytes with a mandatory point/finite/
ALTER route. Independent bytes and rejection tests cover missing/unknown routes
and invalid ALTER row counts. Exact saved DML references inspect, cancel and
clean their original work without resending rows; current scope/principal/policy
checks remain. DML reference controls and the wrong low-level cancellation path
reject ALTER, while catalog cancellation clears its Table and object together.
The old 158-byte helper record is rejected; the coordinated native/current-v1
cutover and regeneration remain required before enabling the general profile.

Authorized command-basis resolution and staged delivery pass **59/59 catalog
tests** (`table-upload-final2.log`). Historical command resolution retains the
original accepted schema after DROP/name reuse and checks current permissions.
The independent Python fixture fixes the 239-byte upload status. Tests cover
part boundaries and exact duplicate checks, four-write chunk completion,
namespace/principal collisions, foreign origins, every unadmitted cancellation
phase, recorded self-origin admission, finite DML counts, denial/restoration
boundaries and terminal retries after body collection. Every injected native
read failure during binding/admission poisons the proposal and leaves it empty.
Private seal/bind results cannot supply committed publication/admission evidence.
The first extended run preceded fixture regeneration and failed two missing-field
checks (`table-upload-final.log`); the regenerated independent fixture passes in
the cited rerun. These are captured-turn tests; native behavior scheduling,
signed client transport, disk restart and performance remain unqualified here.

The general owner hooks and native controls pass **65/65 catalog tests**
(`table-behavior-final.log`). The guard/initializer/handler sequence executes
uploaded CREATE and inline point/finite DML, schedules one durable output per
pending step and preserves identical decisions with replacement handler instances.
Initialization and point INSERT each use four writes. Current policy revocation
records a denial without rescheduling; exact external resume finishes after
restoration. Tests reject foreign origins, process-origin first admission,
malformed/truncated bodies, foreign definitions and noncanonical part padding.
Injected failures across every point-mutation read propagate without committing
an input rejection. Malformed published request bytes receive a disposition;
corrupt Publication evidence propagates its integrity failure instead. These
tests use a dynamic-map captured-turn fixture and do not claim disk-backed host
replacement, deployed client integration or console end-to-end support.
Full pinned `just check` also passes on this owner-hook tree
(`table-behavior-check.log`): generated contracts and binding drift gates,
diagnostic inventory/mappings, unit and CLI checks, independent byte fixtures,
frontend checks/tests and the documentation production build. Existing frontend
lint warnings remain warnings. Committed-HEAD clean and disk qualification are
still separate required gates.

Offline typed intent persistence passes **70/70 catalog tests**
(`table-intent-final2.log`). Independent Python bytes fix TCI1 for a full-width
Unicode rename. CREATE and finite DML restore original command/schema/reference
without source access; destruction of input buffers cannot change restored work.
Tests reject every truncated prefix, missing/foreign definitions, changed schema
commitments and substitution of upload parts, namespaces, digests or coordinator
controls. A 20,000-byte typed value exercises the large-workspace path, and the
restore/decode allocation-failure schedule leaves no leaked owners. An initial
extended test used an incorrect UTF-8 atom field name and failed compilation;
the corrected test uses the shared typed byte atom. Signed submission, durable
console persistence and cross-language recovery integration remain separate.

The general signed caller passes **73/73 catalog tests**
(`table-client-test2.log`). Canonical prepared envelopes retain exact inline,
begin, part, resume and cancellation payloads; missing/foreign top-level and
native definitions, changed connection fields and extra saved bytes reject.
Signature, scope, reference and intent-step substitution failures reject before
network access. Metadata methods validate their connection before opening a
source. The initial compile rejected the Zig-reserved name `resume`; the API is
`prepareResume`. All caller entry points compile, including current-cut outcome
batches and bounded notification waits. These tests do not yet qualify successful
HTTP submission, wait scheduling or disk-backed general-owner recovery.

The shared SQL preparation path passes **74/74 catalog tests**
(`table-client-compile.log`). `just test::typed-tables` then passes through the
signed client, actual GenServer hooks and authorized delivery courier against
disk-backed Ursula with eight resident authority pages. The schedule covers
five-column CREATE, aliases/defaults/nulls/decimal cells, typed INSERT/UPDATE,
same-value matched/changed counts, atomic multi-row conflict rejection, ADD/
RENAME/DROP COLUMN, finite DELETE, DROP/name reuse, unkeyed duplicates and an
original retained receipt after replacement. Accepted send and owner-commit
replies are lost; exact saved native requests recover identical receipts after
node/store replacement. The passing run takes **35.891 seconds** and observes
140 turns, at most four mutations and 256-byte native values
(`typed-table-native4.log`). This is scenario duration, not a mutation benchmark.

Three earlier runs failed: the fixture first used a path-only directory handle
for fsync, then omitted the native courier needed to deliver recorded self-output.
The final fixture uses a readable directory descriptor and signs/persists exact
courier delivery requests; no authority or publication gate was relaxed.
Inspection uses the shared typed row reader, not SQL SELECT. This proof does not
qualify the deployed query host, console, language SDKs, every logical family,
every ALTER case, memory growth, host power loss or the final current-v1 cutover.

Extracting the source-independent `LogicalQuery` plan and pull executor passes
**194/194 Fuze tests**, the semantic mapping gate and all **190 real file-query
CLI cases**, including the unchanged 192 MiB/96 MiB streaming memory case.
Existing plan fingerprints, counts, failure evidence and file-tail verification
remain unchanged. This checkpoint enables reuse of the same operators by typed
Tables; it does not yet establish a native Table SELECT adapter.
Logs: `logical-query-extract.log` and `logical-query-file-proof.log`.

The general Table SELECT compiler passes **201/201 Fuze tests** and the semantic
mapping gate (`table-select-final.log`, `table-select-mappings2.log`). Cases cover
all 128 explicit/wildcard column positions, 255-byte names, exact decimal/date
predicates shared with DML, nested projection, aliases, finite aggregates over
limited inputs, complete-input rejection and allocation-failure ownership.
Selected-prefix execution stops at LIMIT without claiming tail exhaustion;
complete-source execution still propagates a tail read failure. Development runs
caught obsolete Zig repetition syntax, an extra semicolon, a predicate-module
name collision and an unmapped LIMIT cause; the final tree preserves the existing
syntax/range diagnostic causes. This remains compiler/operator evidence, not
native Table SQL reads, installed callers or relational join qualification.

The signed general `TableQuery` adapter passes **94/94 query-package tests**
(`table-query-test2.log`) and the expanded native disk schedule. The latter now
executes SQL projections, exact typed primary-key lookup, COUNT, LIMIT 0 and
request/row/result-byte budget failures. A held query rejects current catalog
read denial; another keeps its original object, schema and rows through UPDATE,
column evolution, DROP and name reuse. Authority/store replacement invalidates
the original snapshot, and a separately opened query reads the new object.
The final run passes in **36.709 seconds**, with 142 owner turns and unchanged
four-mutation/256-byte native bounds (`typed-table-select-native4.log`).

The first expanded run failed its restart diagnostic assertion: cleanup replaced
the original `QueryExpired` with a generic transport conflict. The query handle
now retains the actual failed request's native cause before cleanup; local errors
do not inherit another operation's rejection. Subsequent native runs pass. The
first full check stopped at missing outcomes for the new query diagnostic cases;
reviewed caller/Board/Flight/inspection cases now pass **2,922 projections across
30 declared surfaces**. These remain signed Zig fixture proofs, without deployed
console/host, all-family/SDK, cardinality-growth, latency or host-power-loss claims.
Full pinned `just check` passes on the corrected query tree
(`table-query-check2.log`), including generated contract/binding drift, native and
CLI checks, semantic outcome cases, frontend checks/tests and the documentation
build. Existing frontend lint warnings remain nonfatal. This does not replace
committed-HEAD clean qualification or the remaining deployment migration.

The supplied `transit-query-host` catalog role now passes the same disk proof
with a courier scoped to its single PID (`typed-table-host4.log`). The expanded
run takes **64.017 seconds** and observes 219 owner turns, at most four native
mutations per turn and 256 bytes per value. A second wide Table receives CREATE,
typed INSERT, a defaulted-column rewrite, finite UPDATE and DROP without another
worker. Restarting with the same activation marker rejects; fresh ownership
preserves the original outcome. The test also withholds an accepted native turn's
receipt, kills that host and finishes the original saved operation under a newly
fenced activation. The duration is a fault scenario total, not a latency benchmark.

The first deployed run exposed `StaleStateResource` during concurrent current
metadata reads. The fixture now retries only bounded read/preparation calls;
it never retries a captured scan on a newer cut or replaces an uncertain send.
The next run passes in 61.996 seconds before the explicit host fault was added.
The fault run initially failed because the proxy counted killed hosts' closed
notification waits as forwarding failures. The final proxy separately counts
those downstream disconnects and still fails actual upstream errors. Earlier
failed logs are `typed-table-host1.log` and `typed-table-host3.log`; all logs remain
in the campaign above. This qualifies the supplied catalog/courier binaries,
not the still-separate local server, console or SDK migration, nor power loss.

The general console recovery-file owner passes **28/28 CLI lifecycle tests**
(`table-recovery3.log`). A 48 KiB typed default makes the immutable intent larger
than the mutable record limit; progress stays below 8 KiB and retains exact signed
upload bytes through close/reopen. Tests cover the exclusive lock, unknown-send
state, invalid successor checkpoints, retained original disk progress, completed
intent cleanup, orphan non-adoption, altered referenced bytes, changed scope,
missing/foreign compatibility definitions and invalid signatures. This is local
file-owner evidence, before console dispatch integration. The first run crashed
because Zig's immutable atomic publication requires `link`, while `replace`
requires a replace-enabled temporary file; the corrected owner passes. These
tests do not simulate filesystem power loss or establish native SQL outcomes.

The console and local server now execute general catalog Table SQL through the
same signed caller and frozen typed query reader. The expanded native disk proof
passes in **91.741 seconds**, with 297 owner turns, 66 sends, at most four native
mutations and 256 bytes per value (`typed-table-console5.log`). It runs the actual
console through wide CREATE, typed INSERT, duplicate rejection, exact counts,
EXPLAIN, SELECT, ALTER, DELETE and DROP. Lost upload replies reconcile the exact
signed request; read-only `.status` does not send or change saved progress;
cancellation of the original upload leaves no inserted row. The supplied host's
lost accepted turn and fresh activation checks remain in the same run.

The full local server suite passes in **34.74 seconds** (`typed-server3.log`).
It covers current permission revocation, bounded observation pressure, capacity
fallback versus denial, retained exact recovery through process/store restart,
and DROP/recreate across restart without recreating the default Table. An earlier
run exposed installation of private recovery before preparation authorization;
preparation now succeeds before a new intent replaces saved work. A denied
statement preserves the prior recovery bytes and does not block later reads.
Separate startup evidence also confirms that dropping the default Table survives
restart (`typed-local-startup1.log`).

Full pinned `just check` passes (`typed-console-check3.log`), including 586 real
CLI diagnostic cases, **2,948 outcome projections across 34 surfaces**, generated
contract/binding checks, native units, frontend checks and documentation build.
CLI lifecycle checks pass **29/29**, including exact logical formatting. Earlier
development runs caught the wrong CLI artifact in the proof, obsolete fixture
shapes and narrow SQL expectations, and an invalid test assumption that a fully
reconciled upload must retain its first pending request. Those runs remain in the
campaign; the passing tests assert actual replay bytes and original operation
identity instead. These durations are scenario totals, not latency benchmarks.
This checkpoint does not establish power-loss durability, all-family caller
qualification, the final compatibility cutover or committed-HEAD clean CI.

The console's direct `catalog_v1` configuration and parser-derived completion
pass the expanded native proof in **91.213 seconds**, with the same 297 owner
turns, 66 sends, four-mutation and 256-byte bounds
(`catalog-console-native1.log`). The real signed fixture discovers a created
Table, completes its column from the SELECT suffix and obtains ALTER continuations.
The server suite passes in **35.61 seconds** (`catalog-console-server1.log`),
including SELECT and `.info` through a catalog-only read-only connection without
write recovery. Neither path needs the former fixed Table workspace fields.

The query package passes **97/97 tests** (`table-assistance4.log`), including
production-parser continuations, typed assignment/aggregate suggestions,
unsupported continuation filtering, 255-byte/quoted/Unicode names, terminal
control suppression and allocation-failure cleanup. Full pinned `just check`
passes on the integration tree (`catalog-console-check1.log`); the final local
suggestion filters and configuration diagnostic additions also pass focused query
tests and **592 real CLI cases** (`catalog-console-diagnostics1.log`). Generated
query/Board schemas and validators include the catalog assistance profile.
Development compile failures caught a shadowed parser helper, a remaining optional
client dereference and optional return coercion; no failed build is counted as
passing evidence. The bounded catalog search returns at most eight suggestions
from at most 128 pages and does not claim complete catalog enumeration.

The durable execution-witness checkpoint passes **205/205 Fuze tests**, **86/86
Station tests** and **75/75 catalog tests** (`table-witness2.log`,
`table-witness-transit-station5.log`, `table-witness-transit-catalog5.log`). Exact
key/cell formatting, schema attribution, input ordinal checks, malformed witness
rejection and current-policy disclosure are executable cases. A real catalog
transition retains the same stored witness through read revocation/restoration,
DROP and name reuse; a withheld presentation cannot be encoded over the receipt.
The independent Python storage oracle now includes the mandatory 95-byte witness
and a nonempty rejected-key fixture inside the 254-byte receipt.

The expanded disk-backed native/console proof passes in **103.074 seconds**
(`table-witness-native1.log`), with 318 owner turns, 69 sends, at most four
mutations per turn and 256 bytes per native value. It checks the original row/key
for a conflicting finite UPDATE, read-policy redaction/restoration, a rejected
INSERT after DROP/recreate and disk restart, structured console facts, the human
duplicate-key message and the failing column/value for SET NOT NULL. Existing
lost send/turn replies and supplied-host loss checks remain in the same run.
This total is not a point-latency benchmark or power-loss proof.

Full pinned `just check` passes (`table-witness-check2.log`), including 592 CLI
diagnostic cases, 2,948 outcome projections, generated contracts, native units,
frontend validation and the documentation build. Development runs caught an
obsolete 159-byte oracle, a shadowed local name, an
incorrect test accessor and diagnostic fact ordering drift. Each failed run is
retained in the same campaign and is not counted as passing qualification. The
receipt extension remains part of the pending coordinated current-v1 cutover;
it does not establish compatibility with prior builds or complete caller migration.

General Table rendering now passes **30/30 CLI lifecycle tests**
(`table-output4.log`). A valid 256 KiB source cell projected eight times produces
more than 8 MiB of escaped JSON; the test independently decodes every output
cell through a 16 KiB stream and confirms it remains an incomplete row prefix.
Vector/splat writes and failures before/after draining the buffer preserve bytes
and sticky failure state. The focused build also compiles the real console.

The expanded native/console proof passes in **110.906 seconds**
(`table-output-native1.log`), with 350 turns, 83 sends and unchanged four-mutation/
256-byte native bounds. Its additional 64-column projection crosses multiple
output-buffer drains and verifies all escaped values plus the final marker.
Inventory and semantic mapping checks pass (`table-output-mappings1.log`).
Initial development builds caught Zig's nested-name shadowing rule and the
mutable vector required by `writeSplatAll`; those failed builds are retained.
These checks do not replace the final full-type/caller and clean-CI gates.

The Table header/EXPLAIN location checkpoint passes **206/206 Fuze tests**,
**30/30 CLI lifecycle tests** and the real console build
(`table-locations-fuze1.log`, `table-locations-console1.log`). Cases cover
SELECT/CREATE/ALTER/DROP/INSERT/UPDATE/DELETE header offsets and ensure editor
continuations do not suggest IF after ALTER TABLE or a derived relation after
plain SELECT. Catalog/query tests supply no usable transport and establish that
invalid headers fail before metadata acquisition.

Full pinned `just check` passes (`table-locations-check1.log`). The expanded
native proof passes in **110.858 seconds** (`table-locations-native1.log`),
checking actual console error coordinates for SELECT and EXPLAIN, including a
failure after schema acquisition. All 350 turns, 83 sends, four-mutation bounds,
large-output checks and recovery cases remain in that run. These checks do not
qualify complete contextual highlighting or all compiler binding witnesses.

The unbound literal checkpoint passes **211/211 Fuze tests** and **98/98 query
tests** (`sql-literal2.log`, `sql-literal-query1.log`). It retains exact nested
syntax and source spans, binds the full signed int128 boundary and canonical map
order, attributes nested overflow/duplicate keys/unknown union alternatives,
rejects recursive or oversized direct syntax before allocation, and exhausts
partial-allocation failures. Existing typed editor continuations still pass.
Semantic mapping and source-inventory gates pass; this is parser/binder evidence,
not completed contextual classification or runtime/transport qualification.

During the general SQL syntax checkpoint, the full check and a focused catalog
run both stop at `NondeterministicMemoryUsage` in the saved-intent allocation
schedule (`sql-syntax-check1.log`, `sql-syntax-catalog1.log`). The schedule now
refuses in-place resize/remap so arena growth allocates reproducibly; normal
restore tests retain the ordinary allocator. The complete catalog suite passes
**76/76 tests** (`sql-syntax-catalog2.log`). This repairs fault scheduling without
changing the recovery implementation or counting either failed run as passed.

The general SQL syntax/classification checkpoint passes **217/217 Fuze tests**,
**98/98 query tests** and full pinned `just check` (`sql-syntax8.log`,
`sql-syntax-query2.log`, `sql-syntax-check2.log`). Every scalar alias, recursive
constructor positions, ALTER/DROP/EXPLAIN, malformed prefixes and comment-safe
numeric spans have role assertions. A 4,092-byte dense statement fits the fixed
256 KiB classification workspace. Name/value binding tests retain exact source
positions, and completion refuses metadata for a different source. An earlier
query test exposed that source-scope check; two development cases also used an
incorrect expected overflow error and a default of the wrong type. Those failed
runs remain in the campaign.

The expanded native console proof passes in **113.504 seconds**
(`sql-syntax-native1.log`), with 350 turns, 83 sends and the same four-mutation/
256-byte native bounds. Actual SELECT/EXPLAIN, DML and DDL errors identify the
failing source token after binding; the lost-reply/turn, restart, witness and
large-output assertions remain. This scenario total is not a latency benchmark,
a completed transport migration or committed-HEAD clean CI.

Canonical Table state predicates pass **218/218 Fuze tests** and **98/98 query
tests** (`sql-state-fuze1.log`, `sql-state-query1.log`). SELECT, DELETE and
completion use the shared grammar's NULL/MISSING/VALUE/TYPE_ERROR/CONFLICT names,
including NOT. Matching ordinary value/null rows does not relax storage admission
for missing values, source errors or conflicts. This corrects the new Table
parser's missing VALUE case and its inconsistent ERROR spelling; it does not add
an error-state storage profile.

The neutral Table schema checkpoint passes **224/224 Fuze tests**
(`table-schema-json3.log`). The independent Python fixture fixes both neutral JSON
and FTS1 for the same schema; the reflected JSON Schema validates it and rejects
foreign/missing definitions and wrong identity/container shapes
(`table-schema-json-oracle1.log`). Full-width identities, UINT128, exact decimal,
floating signed zero, recursive descriptors/defaults and ownership after source
destruction round-trip unchanged. The allocator schedule releases every partial
conversion. A legal 60,000-element nullable array default exceeds the ordinary
logical JSON envelope size but fits this schema's 2 MiB wire bound; its canonical
schema remains below 64 KiB. Oversized input rejects before allocation. The
focused suite reports 78 MiB maximum RSS including that large JSON case; this is
process-level test evidence, not an isolated transport memory measurement.

Initial development runs caught the neutral parser's `InvalidJsonShape` rejection
rather than a raw enum error, allocation failure escaping as `WriteFailed`, and
an uninstantiated optional/array reflection branch. The corrected encoder reports
OutOfMemory for its allocating writer; reflection separates those Zig metadata
variants. Generated resources and failed logs remain in the same campaign. The
codec does not by itself enable the general Table ABI, port or SDK callers.
Full pinned `just check` passes on this checkpoint (`table-schema-json-check1.log`),
including generated logical resources, the independent schema oracle, native and
CLI cases, frontend validation and the documentation build. This is not the
pending committed-HEAD clean-CI gate.

General catalog listing now returns inline metadata/head entries without reading
schema defaults or row data. The focused catalog and query suites pass **77/77**
and **98/98** tests (`catalog-list2.log`, `catalog-list-query1.log`). A source that
refuses schema reads still lists the live name, while lookup fails and a retired
head is rejected. The disk-backed native/console proof passes in **109.611
seconds** (`catalog-list-native1.log`), including distinct JSON names across a
page and the existing lost-reply/restart checks. It retains 350 turns, 83 sends,
four mutations per turn and 256-byte native values. This qualifies listing and
rendering behavior, not the remaining neutral caller migration or clean CI.

The shared general neutral caller checkpoint passes **90/90 catalog tests**
(`table-neutral-values4.log`). Typed CREATE/INSERT/UPDATE/DELETE produce the same
saved bytes as SQL, including reordered/omitted fields, DEFAULT versus NULL and
point versus finite predicates. All selected evolution forms, stale object/name/
schema rejection, recursive binary input, full-width identities/quotas, metadata
ownership, malformed pages and allocation-failure cleanup have direct checks.
One session retains one original intent; failed compilation/export leaves it
loaded, and stale references reject without reading or dispatching.

The expanded disk-backed bridge/console proof passes in **137.612 seconds**
(`table-neutral-native2.log`), with 424 turns, 109 sends, at most four mutations
per turn and 256-byte native values. It covers typed nested binary/UTF-8/exact
decimal input, composite-key conflict, typed ALTER/rename/DROP, a stale typed basis
and original outcome recovery after handle restart and same-name recreation.
Progress calls are at most **1,380 encoded bytes** in this scenario; they carry a
small reference and signed step rather than the full saved intent. This is an
observed framing bound for this workload, not a point-latency benchmark or installed
SDK qualification. The fixture invokes the shared Zig bridge directly.

The first native attempt failed with `InvalidDiagnostic` while projecting a
pending ALTER. The existing diagnostic validator allowed cancellation only for
row-mutation identities, despite the general Table owner using catalog identities
for pending DDL. Zig and TypeScript now permit the exact catalog identity only
with recorded pending domain evidence. Unknown, merely saved, input-rejected or
terminal catalog work still rejects that action. **31/31 protocol tests** and
**7/7 TypeScript diagnostic tests** pass, including the new evidence/identity
guards (`table-pending-diagnostic-protocol1.log`,
`table-pending-diagnostic-ts1.log`). Failed native/compiler logs remain in the
campaign. These helpers do not complete ABI/port/SDK migration or the coordinated
current-v1 definition replacement.

The final repository `just check` for that neutral caller checkpoint passes
(`table-neutral-check2.log`). The subsequent recursive schema generator passes
**33/33 protocol tests**, **91/91 catalog tests**, unchanged binding drift checks,
and the pinned TypeScript compiler fixture. The fixture accepts recursive values
and independent root namespaces while rejecting numeric wide integers, malformed
nested children, foreign/unresolved references and invalid identifiers. The real
Table action/result graphs retain recursive list children and diagnostic scalar
codecs (`table-schema-graph1.log`, `table-schema-graph-catalog1.log`,
`table-schema-graph-bindings1.log`). This qualifies generation; enabling the general
catalog ABI and installed language callers remains a separate migration.

The general catalog C ABI/port checkpoint passes **18/18 binding tests** and
**92/92 catalog tests** (`table-general-abi6.log`, `table-general-catalog1.log`).
ABI checks cover owned results, local compile locations, preserved loaded intent
after failed compile, busy exclusion, signature rejection before dispatch and
uncertain transport with the original signed sequence. Framing checks reject
oversized and unterminated work and leave non-catalog profile bounds unchanged.
All **33 generated Station schema roots** compile with the pinned TypeScript Ajv
validator (`table-general-schema-ajv1.log`). Recursive host bounds apply to the
catalog field; unrelated actions keep their existing generation bounds.

The disk-backed scenario now invokes the actual Station port/C ABI instead of a
test-only bridge. It passes in **135.663 seconds** (`table-general-abi-native2.log`),
with 424 turns, 109 sends, at most four native mutations and 256-byte values.
It prepares and reloads a nested 300 KiB binary input above the old raw-client
framing bound, without dispatching that large upload. The smaller typed write,
ALTER, rename, DROP and name-reuse/restart scenario executes; exact lost-send,
lost-turn and supplied-host recovery controls also pass. Maximum progress request
size is **1,392 bytes**, including the port envelope.

The first port run encountered `StaleStateResource` between dependent reads
during ALTER progress. The ABI now restarts only that exact native rejection for
reads/local preparation, at most eight times within its configured deadline,
freeing failed workspace each time. It never retries a submit, cursor conflict
or denial. The successful second run includes this correction. These are focused
public ABI proofs; all-language migration, complete end-to-end type coverage,
global current-v1 replacement and committed-HEAD clean CI remain open.

The TypeScript general Table checkpoint passes `just bindings::node-check`,
including **48 Station boundary tests** (`table-general-node-check3.log`). The
catalog cases cover full-width identities/values, owned nested defaults, all eight
independent rights, signed zero, malformed metadata and foreign intent attribution,
empty continuing pages, large binary requests, fragmented 1.2 MB responses and
uncertain replies retaining exact prepared text. The shared port grows response
storage geometrically within its selected profile and releases it between calls.

The installed Node tarball proof passes in **163.200 seconds** together with the
disk-backed native/port scenario (`table-general-node-native2.log`): 478 turns,
125 sends, at most four native mutations and 256-byte values. The consumer runs
outside the checkout using installed packages and their packaged native host.
It executes general CREATE, reordered typed nested INSERT with exact decimal,
same-value UPDATE with matched=1/changed=0, ALTER with default, stale-basis
rejection, DELETE, DROP/recreate and original saved-intent status after replacing
the caller. The original object is 12001 and the replacement is 12002.

The first installed run rejects a valid configuration because its SDK limit
excluded the native row header. The adapter now validates the wire integer bound
and leaves the narrower record profile to shared native admission; the rebuilt
tarballs pass. Raw failed logs remain in the campaign. Documentation checks pass
5,288 local links; the verification catalog and CI task-inventory checks pass.
This is installed TypeScript evidence, not qualification of the other language
callers, all logical-family value paths, the final definition cutover or clean CI.

The repository `just check` passes after the ABI and TypeScript checkpoint
(`table-public-callers-check1.log`). The Python general Table migration passes
strict mypy for **25 source files**, including the installed example API owners
(`table-general-python-types3.log`). Focused value checks exercise immutable nested
descriptors/cells, full-width integers, exact decimals, signed zero, invalid float
widths, malformed pages and intent attribution, 300 KiB binary preparation,
uncertain submission and joined cleanup after async cancellation. They run again
from installed wheels outside the checkout.

The combined native/port and installed Node/Python sync/Python async proof passes
in **211.345 seconds** (`table-general-python-native2.log`): 586 turns, 157 sends,
at most four native mutations and 256-byte values, with original lost-send,
lost-turn and supplied-host receipt-loss recovery. Each language executes CREATE,
typed nested INSERT, no-op UPDATE (matched=1, changed=0), ALTER/default, stale-basis
rejection, DELETE and DROP/recreate. A replacement caller reloads the original
intent and reads its original applied outcome, independent of the reused name.
Python sync retains object 12011 after replacement 12012; async retains 12021
after replacement 12022. Node retains 12001 after replacement 12002.

The first installed Python run stopped on a fixture's hard-coded principal; the
corrected fixture checks its configured identity. That failed run remains in
`table-general-python-native1.log` and does not qualify the Python scenario.
Documentation links, verification declarations and CI task ownership pass
(`table-general-python-{docs,verification,ci}1.log`). Other language migrations,
complete logical-family path coverage, the coordinated definition replacement
and committed-HEAD clean CI remain open.

Exact general historical-definition inspection passes **95/95 catalog tests**
(`table-historical-catalog5.log`). Tests cover inline and chunked metadata through
ALTER, DROP and name reuse; current inspection revocation/restoration; absent
revisions; published-but-unaccepted ALTER candidates; missing original receipts;
incompatible bytes; conflicting representations; and allocation-failure cleanup
for owned schemas and neutral results. Corrupt immutable-history attribution is
an integrity diagnostic without advice to prepare a replacement declaration.

The matching general ABI, generated schemas, TypeScript and Python callers pass
full `just check` (`table-historical-check2.log`), **50 Station boundary tests**,
Python's strict **25-file** type check and focused value checks. Initial checks
stopped on compiler name shadowing and the diagnostic-inventory review gate;
those failed logs remain in the campaign. The reviewed inventory and semantic
mapping gates pass with the correction.

The rebuilt installed Node/Python sync/Python async proof passes in **212.738
seconds** (`table-historical-installed1.log`). Besides the preceding lifecycle,
exact-recovery and fault schedule, the native port reads original, altered and
renamed definitions after DROP/recreate. Installed callers inspect the original
metadata and schema after replacing their handles, verify absent revisions and
confirm that historical results carry no live head. Bounds remain four mutations
and 256-byte native values across 586 turns and 157 sends. This checkpoint does
not qualify unmigrated languages or the remaining cutover, query paths and
performance/growth gates.

The SDK logical-boundary correction passes **51 Station tests**, strict Python
type checking across **25 files** and focused Python value/ownership checks
(`table-sdk-bounds-{node,types,python}1.log` in the same campaign). Regression
cases accept conflicts at depth 15, reject one more list level, reject invalid
conflict counts/dot ordering, count both MAP keys and values, and reject aggregate
payload/type budgets. A direct call through the built native logical codec
independently accepts and round-trips the depth-15 conflict with two alternatives.
These checks do not expand the supported Table schema depth or establish a new
installed-package, full-repository or clean-CI pass.

The Rust general Table caller passes **7 focused library tests** from both the
source crate and freshly installed source-crate artifacts. Its owned logical
models preserve exact wide numbers, float bits, recursive states and native
budgets. Catalog checks reject foreign compiled identities, malformed metadata
pages, invented affected-row counts and malformed receipts; an injected worker
panic after dispatch retains uncertainty. The installed fixture also checks
compiler rejection of overlapping mutable borrows and reuse after consuming close.

The actual native/port plus installed Rust lifecycle passes in **181.875 seconds**
(`table-rust-installed1.log`), including nested typed INSERT, no-op UPDATE counts,
ALTER/default, stale-basis rejection, DELETE, DROP/name reuse, accepted historical
definitions and exact saved-intent recovery through a replacement caller. Across
478 turns and 125 sends, maximums remain four native writes, 256-byte values and
1,392-byte progress steps. Lost-send, lost-turn and supplied-host receipt-loss
schedules pass. Installed crates use their packaged native libraries after source
vendor directories are removed, with no native-library override.

Source checks are in `table-rust-general2.log`; packaging, documentation and
verification logs share the `table-rust-` prefix. The first verification check
found an obsolete test anchor; the updated declaration references the replacement
malformed-response/worker-panic test and the general fixture actually run by the
Python, Node and Rust tasks. Documentation checks pass **5,288 local links**;
verification checks cover **59 invariants, 53 bounds and 13 SDK scenarios**. Other
SDK migrations, query paths, fixed-profile removal, final definition replacement,
performance/growth gates and clean CI remain unqualified by this checkpoint.

The retained DROP RESTRICT witness passes **96/96 catalog tests** and the
independent Python record oracle (`table-drop-witness-catalog4.log`). The rejected
operation stores its exact dependency identity, kind and owner in **242 bytes**;
other operation records encode an explicit empty blocker in **225 bytes**.
Tests reject truncation, foreign definitions, absent blocker evidence and
contradictory reason/kind pairs. All four blocking dependency kinds retain their
original attribution after registry replacement/removal, DROP/name reuse and
inspection revocation/restoration. Exact terminal retry writes nothing.

The native/port/console proof passes in **147.866 seconds**
(`table-drop-witness-native1.log`). It registers an actual blocking writer,
observes a rejected DROP with all three original diagnostic facts, removes the
dependency, retires/recreates the name and reloads the original rejected intent
through a replacement native-port handle. The original evidence is unchanged.
Across 439 turns and 117 sends, maximums remain four writes, 256-byte values and
1,398-byte progress steps; lost-send, lost-turn and supplied-host receipt-loss
schedules still pass. This run does not include installed SDK consumers.

Regenerated shared diagnostics, ABI/port contracts and frontend validators pass
full `just check` (`table-drop-witness-check2.log`), including **2,948 semantic
projections across 34 outcome surfaces** and **592 real CLI diagnostic cases**.
Initial checks caught missing void-tag serialization, an outdated byte fixture,
a test attempting dependency registration while DDL is fenced, and a synthetic
diagnostic receipt missing its now-required blocker. Failed logs remain in the
campaign and are not qualification; the corrected tests preserve the pending-DDL
fence and include explicit blocker provenance in the reviewed outcome manifest.
The final coordinated shared-definition cutover and clean CI remain outstanding.

Ruby's shared port validator accepts generated recursive local schema references
with root isolation and rejects missing/external references, unsupported siblings,
non-consuming reference cycles and cyclic host values. The independent recursive
fixture passes in the pinned bindings shell (`table-ruby-schema2.log`) and is
wired into the installed raw-client consumer without adding output to its machine
protocol. This is focused source-level validator evidence; the general Ruby Table
API and installed-package schedule remain separate qualification work.

The Ruby general Table caller passes its installed lifecycle in **168.021 seconds**
(`table-ruby-installed1.log`): recursive typed INSERT, exact decimal/binary/UTF-8
values, no-op UPDATE counts, ALTER/default, stale-basis rejection, DELETE,
DROP/name reuse, historical schema reads and exact intent recovery through a
replacement caller. Across 493 turns and 133 sends, maximums remain four native
writes, 256-byte values and 1,398-byte progress commands. Lost-send, lost-turn and
supplied-host receipt-loss schedules pass. The consumer loads isolated installed
gems without source or native-host overrides.

Installed Ruby value checks cover all logical families, wide integers, signed
zero, depth-15 conflicts, MAP key accounting, aggregate byte/node/name budgets,
owned frozen results, malformed metadata/receipts, exact uncertain commands and
interrupted-wait ownership through joined close. Actual child exchanges accept
600,000-byte catalog payloads and fragmented replies while rejecting the same
request at the unchanged raw-client line bound. Generated recursive schemas are
exercised through the packaged port, including malformed replies and child loss.
The rebuilt raw-client schedule passes separately (`table-ruby-raw1.log`),
including saved lost-receipt recovery, seedless restart and revoked retry.

Full pinned `just check` passes (`table-ruby-check1.log`); documentation checks
cover 5,293 links across 523 files and verification retains 59 invariants, 53
bounds and 13 SDK scenarios. The original fixed-profile Ruby runner/query APIs
remain to be removed or migrated with the other query surfaces. This checkpoint
does not establish the remaining SDK migrations, final definition replacement,
matched performance/growth or committed-HEAD clean CI.

Java's generated-schema validator now resolves bounded local recursive references
with independent roots and fails closed on missing/external references, unknown
keywords, reference cycles and cyclic host values. The independent Java 21/Gson
fixture passes with `-Xlint:all -Werror` (`table-java-schema2.log`) and is wired into
the installed raw-client schedule. The first focused compilation exposed Gson's
optional annotation dependency through a fixture-only parser call; using the
existing Gson parsing API avoids adding a runtime dependency. This is source-level
validator evidence, not an installed Java general Table qualification.

The Java general Table API passes its installed lifecycle in **166.945 seconds**
(`table-java-installed1.log`): typed nested INSERT, wide exact decimals,
unchanged-value UPDATE counts, ALTER/default, stale-basis rejection, DELETE,
DROP/name reuse, accepted historical definitions and original saved-intent outcomes
through a replacement caller. Across 493 turns and 133 sends, maximums remain
four native writes, 256-byte values and 1,398-byte progress commands. Lost-send,
lost-turn and supplied-host receipt-loss schedules still pass. The external
consumer uses independent packaged JARs and their native artifacts.

Installed Java value checks cover all logical families, exact integer/float bits,
owned binary/lists, aggregate node/name/data bounds, depth-15 conflicts, MAP child
accounting, strict metadata/continuations and original compiled identity. Actual
owned ports carry 600,000-byte payloads in both directions, reject malformed
receipts and retain in-flight ownership after future cancellation until joined
close. Allocation-loss injection retains uncertainty. The raw-client installed
schedule separately passes recovery, seedless restart, disposal and revoked retry
(`table-java-raw1.log`). Its schema checks include large canonical hex without
recursive regex stack growth; raw frame and nesting bounds remain unchanged.

Focused logical checks additionally exercise fifteen nested MAPs through the
catalog JSON nesting limit while the unchanged raw JSON limit rejects the same
wrapped data (`table-java-logical3.log`). The initial package compilation found a
Java name collision with the existing Station `State`; explicitly naming
`Catalog.State` fixes it, and rebuilt Station/example JARs pass. Documentation
checks cover 5,298 links across 524 files; verification retains 59 invariants,
53 bounds and 13 SDK scenarios. Source/package logs share the `table-java-`
prefix in the same campaign. This checkpoint does not claim a new full repository
or clean-CI pass; other SDK/query migrations and final qualification remain.

.NET's generated-schema validator resolves bounded local recursive references
with isolated roots and rejects missing/external references, invalid siblings,
unknown validation keywords and non-consuming cycles. Data depth and reference
hops are bounded separately to prevent uncatchable stack exhaustion. Independent
nullable/integer/recursive-array fixtures run inside each installed raw-client
consumer without changing its machine output. The rebuilt NuGet packages and
installed raw recovery/cancellation/disposal/revoked-retry schedule pass with zero
compiler warnings (`table-dotnet-schema-{build,raw}1.log`). This qualifies the
shared validator and raw client; the general .NET Table API remains separate work.

The .NET owned logical models pass the isolated NuGet fixture
`tests/dotnet_logical_values.py` with zero compiler warnings. It restores four
exact local artifacts into a clean consumer, records SHA-256 identities, removes
consumer source/package caches, then tests all descriptor/atom/cell families,
Int128/UInt128 extremes, exact decimal coefficients, signed-zero bit equality,
owned binary/collections and structural hashes. Depth-15 conflicts, MAP key
accounting and aggregate child/name/data limits are exercised in both codec
directions; large binary values exceed the old raw-body size. Recursive schema
checks run in the same consumer. The real `bindings::logical-dotnet` task and
full .NET SDK task include this fixture.

Logs are `table-dotnet-logical-{build2,values1,installed1,docs1,verification1}.log`
in the same campaign. The original build and round-trip review found that owned
JSON numeric nodes must use the decoder's exact unsigned representation; numeric
descriptor fields now round-trip directly without serialization or coercion.
Documentation checks cover 5,301 links across 525 files; verification retains
59 invariants, 53 bounds and 13 SDK scenarios. The Ruby/Java guides also correct
the complete saved-intent bound to the generated **4,327,031 bytes**, distinct
from the 4 MiB mutation body. These are local/installed codec results, not general
.NET Table runtime, full-repository, performance or clean-CI qualification.

The .NET general Table client passes the installed lifecycle in **167.021 seconds**
(`table-dotnet-catalog-installed2.log`): nested typed INSERT, exact wide decimal,
unchanged-value counts, ALTER/default and stale-basis rejection, DELETE,
DROP/name reuse, accepted original schema and exact original outcome through a
replacement client. The shared fixture records 493 turns and 133 sends with
maximums of four native writes, 256-byte values and 1,398-byte progress commands.
Lost-send, lost-turn and supplied-host receipt-loss checks pass. The consumer
restores four independently packaged NuGet artifacts, records their hashes,
removes source/package caches and runs with no source-library overrides.

Installed value checks cover full-width identities, owned schemas/collections,
immutable diagnostic copies, missing/foreign definitions, exact compiled identity,
strict original metadata and resource-cut continuations, malformed successful
receipts and 300,000-byte saved-intent copies. Fifteen nested MAPs exercise the
catalog's 96-level JSON limit while the unchanged raw limit rejects the same
wrapped value. Real native HTTP cancellation retains busy ownership until joined
disposal; this does not claim admitted-mutation cancellation or allocator injection.
The separate installed raw-client recovery, seedless retry, cancellation/disposal
and revoked-retry schedule passes (`table-dotnet-catalog-raw1.log`).

The first installed attempt failed to compile its test consumer because a
STRUCT was passed through the fixture's scalar helper. The corrected consumer
first passed isolated installed value checks (`table-dotnet-catalog-values2.log`)
then the complete lifecycle; the package build itself had passed with zero
warnings (`table-dotnet-catalog-build1.log`). These logs share the existing
campaign directory. Full `just check` passes (`table-dotnet-catalog-check1.log`),
including generated contracts, unit/CLI checks, frontend tests and the documentation
production build. Documentation checks cover 5,303 links across 525 files;
verification retains 59 invariants, 53 bounds and 13 SDK scenarios. C/C++ and BEAM
catalog migrations, other enabled query routes, the coordinated definition cutover
and final clean/performance qualification remain required before issue completion.

The BEAM generated-contract validator passes independent recursive nullable,
signed-integer and array fixtures inside the installed Erlang raw-client
boundary test. It rejects missing/external references, invalid siblings, nested
root definitions, unknown rules, empty unions, non-consuming cycles and excess
data/reference depth. Separate roots remain isolated. A 600,000-byte canonical
hex fixture and Unicode scalar-length cases cover the linear string checks.
The public raw Erlang and Elixir schedules both pass recovery, seedless retry,
owned I/O/disposal and revoked retry after rebuilding all eight OTP artifacts
with warnings as errors (`table-beam-schema-{build,raw}1.log`). This qualifies the
shared validator and raw callers, not the pending general BEAM Table API.

Erlang and Elixir logical models pass `just bindings::logical-beam` from six
independent installed OTP artifacts (`table-beam-logical-installed1.log`). The
fixture records SHA-256 identities, compiles external Erlang consumers with
warnings as errors, removes consumer Erlang source, and runs both language APIs
without native/source overrides. Coverage includes all scalar/recursive families,
128-bit extremes, exact decimals, float widths/signed zero, nonfinite/width
rejection, five distinct cell states, ordered conflict alternatives, aggregate
name/node/data bounds, depth-15 conflicts and MAP key accounting. A 300,000-byte
binary exceeds raw-body size; a sub-binary ownership check proves that extracted
UTF-8 does not pin a megabyte of unrelated caller data. Elixir nested field,
element and alternative structs round-trip through the same codecs, with a
separate finite projection bound before logical validation.

The first strict build rejected an unused internal type declaration; it was
removed and all eight OTP artifacts rebuilt successfully. The independent model
fixture passed first (`table-beam-logical-values1.log`), then the registered task
rebuilt packages including their guides and passed again. Elixir formatting passes
(`table-beam-logical-format1.log`). Documentation checks cover 5,309 links across
527 files; verification retains 59 invariants, 53 bounds and 13 SDK scenarios.
These logs use the same campaign directory. This is installed codec evidence;
general BEAM catalog/query, full repository and final clean/performance checks
remain separate qualification.

The general Erlang and Elixir Table callers pass the installed disk-backed
lifecycle in **199.752 seconds** (`table-beam-catalog-installed1.log`): nested
typed INSERT, exact decimal and binary values, unchanged-value counts,
ALTER/default and stale-basis rejection, DELETE, DROP/name reuse and recovery of
the original outcome and accepted historical schema through a fresh client.
The shared fixture records 547 turns and 149 sends, with maximums of four native
writes, 256-byte values and 1,398-byte progress commands. Lost-send, lost-turn and
supplied-host receipt-loss checks pass. Separate compiled OTP artifacts are
installed outside the checkout, hashed and exercised through each public API;
consumer Erlang source is removed after compilation with warnings as errors.

Installed boundary cases cover full-width identities, strict metadata and
continuation cuts, missing/foreign definitions, exact compiled attribution,
malformed successful receipts and definitive authorization rejection. Actual
owned ports carry a 600,000-byte request/response and parse fifteen nested MAPs
through the catalog's 96-level JSON bound; the raw bound remains unchanged.
Killing the waiting process leaves admitted work busy, and close waits for the
native child to finish and exit. These tests do not inject allocator exhaustion
or establish remote cancellation. Immutable generated contract metadata is
cached per client; current grants, source cuts and outcomes still come from
native reads. The raw Erlang and Elixir recovery/disposal/revocation schedules
also pass (`table-beam-catalog-raw1.log`).

The first isolated boundary run passed Erlang, then found Elixir's missing reverse
admission-receipt conversion in the shared fixture adapter. After correction,
all eight OTP packages rebuilt with warnings as errors
(`table-beam-catalog-build3.log`), both isolated boundary schedules passed
(`table-beam-catalog-values2.log`), and the complete lifecycle passed. Elixir
formatting passes (`table-beam-catalog-format1.log`). Logs share the existing
campaign directory. C/C++, other query routes, the coordinated definition
cutover and final clean/performance qualification remain required.

Full `just check` passes for the BEAM catalog increment
(`table-beam-catalog-check1.log`), including generated-contract drift, native/CLI
checks, frontend tests and the documentation production build.

The C11/C++17 logical models pass `just bindings::logical-c` from six independently
installed, hashed pkg-config artifacts (`table-c-logical-installed1.log`). The
fixture compiles external consumers with warnings as errors, removes their source
and runs without source-library overrides. **146 independent neutral fixtures**
round-trip scalar boundaries and recursive values from the existing Python
integer/decimal/temporal/UUID/bit oracle. Separate public model checks cover every
family, signed/unsigned 128-bit extremes, float widths and signed zero, all five
states, owned input/child lifetimes, 300,000-byte binary copies, aggregate
name/data/node limits, depth-15 conflicts and MAPs, cyclic construction views,
unknown tags, malformed UTF-8/hex/numbers, surrogate escapes, duplicate decoded
JSON keys and every truncated prefix of a valid nested value.

The first compiler pass found an ambiguous internal numeric helper; the first
consumer attempt found a shared fixture's import-time command-line assumption.
The next run exposed undefined foreign-enum loading for an unknown C tag. Public
tags now use uint32 carriers and reject unknown values normally. The corrected
isolated consumers pass (`table-c-logical-values3.log`), followed by the registered
task with freshly packaged guides. The affected Arrow fixture still passes all
**106 PyArrow cases** (`table-c-logical-arrow1.log`). Documentation checks cover
5,318 links across 529 files; verification retains 59 invariants, 53 bounds and
13 SDK scenarios. Logs share the existing campaign directory. These are owned
codec/package checks, not C/C++ general catalog, query, allocator-fault or final
clean/performance qualification.

The logical C exports also pass the generated definition-binding gate. The
generator now discovers all public `transit_*` function prefixes, and the logical
header includes Station's generated symbol mappings. The installed fixture
requires those mappings at compilation and proves a foreign-definition logical
symbol cannot link. Rebuilt installed C/C++ consumers and all 146 neutral fixtures
pass (`table-c-logical-definition-installed1.log`); generated ABI/resources pass
(`table-c-logical-definition-generate1.log`).

The C11 and C++17 general Table callers pass the installed disk-backed lifecycle
in **193.286 seconds** (`table-c-catalog-installed1.log`): SQL and typed CREATE,
nested typed INSERT with exact decimal/binary data, unchanged-value counts,
ALTER/default and stale-basis rejection, DELETE, DROP/name reuse, original
outcome recovery and accepted historical definitions through a fresh client.
The shared fixture records 547 turns and 149 sends, with maximums of four native
writes, 256-byte values and 1,398-byte progress commands. Lost-send, lost-turn and
supplied-host receipt-loss checks pass. All six independent pkg-config artifacts
are hashed, installed outside the checkout and exercised with consumer sources
removed. Copying Client, Compiled, Prepared or SavedIntent fails compilation.

**41 installed boundary cases** pass (`table-c-catalog-values3.log`) through a
forwarding native-library fixture: exact full-width metadata and intent
attribution, historical identities, strict page cuts/continuations, missing or
foreign definitions, duplicate JSON fields, 600,000-byte typed requests and
saved replies, malformed/oversized/uncertain receipts and definitive denial.
An input containing 1,024 rows of 128 shared one-MiB cells rejects at the aggregate
action bound without reaching native dispatch; the C serializer materializes one
bounded cell at a time. Deferred POSIX waiter cancellation keeps the actual SDK
worker busy; close joins the blocked call, and original prepared bytes survive.
The shim controls replies and does not establish durable authority or remote
cancellation. No allocator-exhaustion claim follows from this schedule.

The first boundary-consumer compilation used incorrect public factory names;
after fixing the fixture, the isolated compile and all cases pass. Both raw C
and C++ recovery/disposal/revocation schedules also pass
(`table-c-catalog-raw1.log`). C and C++ package checks and all eight C-family
artifacts/examples pass (`table-c-catalog-build3.log`); generated resources pass
(`table-c-catalog-generate1.log`). Logs share the existing campaign directory.
The remaining query/runner migrations, coordinated definition cutover and final
clean/performance qualification are separate work.

Freshly packaged C/C++ guides and all eight artifacts pass
(`table-c-catalog-build4.log`); the rebuilt isolated boundary schedule again
passes all 41 cases (`table-c-catalog-values4.log`). Full `just check` passes for
this catalog migration (`table-c-catalog-check1.log`), including contract drift,
native/CLI checks, frontend tests and the documentation production build.

Native typed-preparation admission passes **97/97 catalog tests**
(`table-typed-budget-test1.log`, 33 MiB test-process peak RSS). A shared neutral
input describing 512 MiB of decoded binary rows now rejects during conversion
under the four-MiB intent allowance, with less than 32 MiB of tracked cumulative
allocation including arena overhead. Repeated borrowed defaults still fail
complete canonical intent admission. Existing SQL/typed byte-equality and
exhaustive allocation-failure cleanup checks pass. This is a conversion-memory
regression proof, not a whole-node or concurrent-workload RSS guarantee.

TypeScript and Python now reject aggregate schema/DML conversion before building
the complete JSON batch. Tests share one MiB binary values across 1,024 rows and
128 schema columns; bounded access/conversion counters detect late rejection
without allocating the entire invalid input. TypeScript's 52 adapter tests and
type/lint checks pass (`table-node-budget-check1.log`). Fresh independent Python
wheels pass isolated catalog value/recovery/lifetime checks
(`table-python-budget-values1.log`), and strict mypy passes all 25 source files
(`table-python-budget-types1.log`). This extends local preparation evidence;
the earlier disk-backed lifecycle evidence remains separately recorded.

Rust and Ruby aggregate conversion checks pass from independently installed
artifacts (`table-sdk-budget-values2.log`). Rust's **8 library tests** include
an oversized prefix followed by an invalid logical value, verifying that aggregate
admission stops before that later conversion. Ruby counts conversions over shared
large cells, then completes the existing strict metadata, receipt-loss and joined
cancellation cases. The first installed Rust compilation found a test helper
using the old budgetless signature; the corrected rebuilt artifacts pass.
`table-sdk-budget-build2.log` records the package builds. The combined installed
run subsequently stopped at an unrelated Java fixture variable-name collision;
its later language entries are not passing evidence from that run.

The corresponding native schema-conversion guard passes **225/225 Fuze tests**
(`table-schema-budget-test1.log`). A shared neutral schema describing 64 MiB of
binary defaults rejects after the first bounded default exceeds the 64-KiB
record allowance, using less than 4 MiB of tracked cumulative allocation. The
existing legal 60,000-element nullable default and exhaustive partial-allocation
cleanup schedules still pass. Complete schema validation retains its independent
descriptor, identity, nullability and framing checks.

Java and .NET aggregate conversion checks pass from independently installed
packages (`table-sdk-budget-values3.log`), after renaming the colliding Java
fixture variable. Erlang and Elixir pass the corresponding installed checks
(`table-sdk-budget-values4.log`). Each schema/INSERT fixture places an invalid
logical value after an oversized valid prefix and verifies rejection before that
later conversion. BEAM checks both the serializer's exact budget error and the
public API's normalized preparation error. The first BEAM fixture expected the
internal phase at the public boundary and failed; correcting that expectation
does not change the API's existing error normalization. Strict values, large
frames, uncertain receipts and joined worker-lifetime schedules also pass.
These are local preparation and boundary checks, not another disk-backed
lifecycle or whole-runtime memory measurement.

Full pinned `just check` passes the aggregate-admission checkpoint at `1dd2a19e`
(`table-sdk-budget-check2.log`), including generated contracts, native/CLI tests,
frontend checks and the documentation production build. The first full run stops
on diagnostic inventory drift from the two new early budget checks. Both causes
already have explicit SQL diagnostic mappings; after reviewing and recording the
changed propagation owners, the independent mapping gate and full rerun pass.

The general logical-plan codec passes **229/229 Fuze tests**
(`table-logical-plan-test3.log`). Independent Python bytes bind the row descriptor,
ordered typed predicate, output names, LIMIT and existing plan fingerprint.
Checks cover every scalar comparison family, exact 128-bit boundaries, negative
floating zero, recursive schema ownership, every truncated prefix, wrong
definitions/source/schema, malformed tags and exhaustive allocation failures.
The first extended scalar fixture used nonexistent width-specific float atom
fields; using the shared float atom fixes that compile failure. These tests
qualify the local `FQP1` codec, not durable query integration.

Restartable logical steps pass **235/235 Fuze tests**
(`table-logical-stream-test3.log`). All four finite operators run at each page
width from one to eight with recursive rows and canonical plan/checkpoint
replacement after every page. Independent expected rows/aggregates match emitted
Arrow bytes. Additional checks cover a 12-column int128 result, independent
Python checkpoint bytes, all five cell states, full-width counters, LIMIT 0,
empty continuation/completion, eager predicate failure, source-order overflow,
wrong bindings/ordinals, malformed progress and whole-row budgets. Allocation,
output and cancellation faults preserve the original checkpoint and exact retry
bytes. These are local restart simulations, not native retained-cut recovery.

The shared pull/step row operators also pass **190 real file-query cases**
(`table-logical-stream-file1.log`), including independent codecs/results,
gzip, quotas, cancellation/cleanup, immutable capture and the 192-MiB input under
a 96-MiB address-space limit. The operator refactor retains existing file-plan
fingerprints and full-source verification after LIMIT.

Full pinned `just check` passes the logical-plan/step checkpoint
(`table-logical-query-check3.log`), including native/CLI tests, generated
contracts, frontend checks and the documentation build. Its first run catches
the new decoded-row width check's missing file diagnostic mapping. The second
catches the corresponding missing independently reviewed outcome entry. Both
are corrected: the error preserves incomplete output, identifies a schema/row
integrity mismatch and directs the caller to the operator without inventing a
saved command. The third full run passes all mapping and outcome assertions.

Canonical logical Arrow decoding passes **239/239 Fuze tests**
(`table-logical-inspect-test2.log`). All 46 independent scalar fixtures retain
exact canonical value bytes after input and workspace are overwritten. Recursive
ownership, all five states, full-width conflict identities and exhaustive partial
allocation failures pass. Every truncated prefix, foreign schema/definition,
extra batch/stream, wrong row count and invalid physical state/kind/payload
relationship rejects. The first run finds a test variable shadowing the shared
schema; renaming that variable fixes the compile failure.

The independent Arrow schedule passes **106 PyArrow 23.0.0 cases**
(`table-logical-inspect-arrow1.log`). Its 45 neutral bridge cases also round-trip
through the new Zig decoder and compare complete logical JSON values. PyArrow
checks the emitted physical layouts independently. These results qualify the
local canonical segment decoder; they do not establish general external IPC
import, neutral ABI import or durable query integration.

The general Table source adapter passes **102/102 query package tests**
(`table-query-source-test4.log`). Public CREATE/INSERT/ALTER/DROP transitions in
the private-turn reference store build 19 rows with 13 columns, nested lists,
int128 boundaries and a composite primary key. A retained source returns the
original rows in three bounded pages after column rename, DROP and name reuse;
logical steps and the owned Arrow decoder preserve their exact values. New
capture rejects the old declaration, including when supplied old retained data.
Complete composite-key equality returns one or zero rows without an ordinary
scan. Current read revocation rejects both before paging and after populated or
empty point-page computation. Exhaustive decoder/page allocation failures clean
up partial ownership. Python independently supplies recursive declaration bytes
and their fingerprint (`tests/table_catalog.py`). The first run's three new tests
used angle-bracket LIST syntax; using the contract's `LIST(type)` spelling fixes
them. These are component and retained-cut reference simulations, not native
durable job admission, disk recovery, SDK integration or performance evidence.

Full pinned `just check` passes the logical decoder and general Table source
checkpoint (`table-query-source-check1.log`), including generated contracts,
independent fixtures, native/CLI tests, frontend checks and the documentation
production build. The source fixture is regenerated and checked by the existing
Table catalog oracle. Committed-HEAD clean CI remains a separate final gate.

Source mismatch kinds now pass **241/241 Fuze tests**
(`table-logical-kind-test3.log`). All original KV/Document mismatch kinds map by
name into logical error evidence without becoming schema types. Unknown kinds,
Document text/character, full-width conflict identities, owned byte values and
partial allocation failures retain their meaning through canonical value, JSON
and Arrow decoding. The first focused run finds an obsolete Zig enum-reflection
field and one assertion using descriptor tags; both are corrected before passing.

Independent boundary checks pass **126 PyArrow cases** and **111 native ABI/port
logical fixtures** (`table-logical-kind-boundaries1.log`). The codec success line
initially prints its previous 91-case total; the executed assertion is 111, and
the message is corrected. All ten SDK artifacts rebuild. Installed Python and
Node each pass the 111 fixtures; C/C++ pass 170 owned-model cases, and .NET,
Erlang and Elixir pass their logical-model and recursive-schema suites
(`table-logical-kind-installed1.log`). Installed Python/Rust/Ruby/Java value,
partial-failure and ownership checks pass, including all nine Rust library tests
(`table-logical-kind-sdk-values1.log`). These model checks do not rerun the
node-backed catalog lifecycle or qualify durable logical query routing.

Full pinned `just check`, TypeScript's 53 adapter tests/type/lint/format gates,
and Python strict typing pass (`table-logical-kind-{check,node-check,python-check}1.log`).
Generated schemas and ABI resources are regenerated and checked. The observed
kind extension is part of the pending coordinated definition cutover; these
local passes do not replace final committed-HEAD clean qualification.

Explicit requester-to-catalog policies pass **104/104 query package tests**
(`table-query-policy-test3.log`). Independent bytes cover declaration and catalog
targets, full-width catalog IDs, the required current definition, every truncated
prefix, extra bytes and obsolete unqualified records. Public reference-store
transitions install one requester-to-principal mapping and use it for two Tables,
including one created afterwards. Tests reject realm/resource/owner confusion,
PID-as-principal inference, disabled or declaration-only delegation, and changed
mappings without a policy revision. Current catalog read revocation still denies
the unchanged requester policy. These checks do not establish native general-Table
job admission. The first run uses the definition enum instead of its canonical
bytes and misses two existing policy constructors; the second exposes a stale
fixed-length wrapper check. All are corrected before the passing run.

Full pinned `just check` passes this policy checkpoint
(`table-query-policy-check1.log`), including migrated example controls, independent
fixtures, generated contracts, native/CLI checks and frontends/documentation.
The policy record replacement is part of the pending coordinated definition
cutover; committed-HEAD clean qualification remains outstanding.

The declaration-target policy replacement also passes the actual ReleaseSafe
`just test::unified-query` disk-backed recovery schedule
(`table-query-policy-durable1.log`). KV returns 41 rows in six segments in
**22.32 s**, the existing Table route returns 41/six in **22.67 s**, and Document
returns 12/two in **225.34 s**, including 177.06 s of Document provisioning.
All three preserve exact uploads after unavailable sends, current-policy denial,
source/requester/node/disk-store replacement after staging, complete manifests
and released source pins. Native and port SQL inspection/parameter comparisons
pass. No installed language SDK or general-Table durable route is claimed by this
run; its binaries were built before the subsequent logical-template changes.

General logical parameter templates pass the **250-test Fuze suite** through
full pinned `just check` (`table-logical-prepared-check1.log`). The tests cover
21 scalar comparison descriptors, exact 128-bit and decimal values, negative
floating zero, temporal/UUID values, independent canonical plan bytes, compound
predicates at the 64-instruction bound, 13-column projection, derived input LIMIT
and ordered SUM shape. Source/name/schema changes reject before result allocation;
ordinals, descriptor conflicts, malformed positions, unsupported comparisons and
oversized text/operands retain their actual failure. Owned plans survive releasing
input and template storage, including exhaustive partial-allocation schedules.
The first run finds a copied arena state before later growth, plus a reserved
identifier and a too-generic expected parser error in new tests. Ownership transfer
and test inputs/expectations are corrected. The second root-unit run passes its
246-test intermediate suite. The third focused run finds the existing file plan
budget test expecting `WriteFailed`; it now requires `PlanTooLarge`, and the final
root suite passes all 250 tests without leaks.

SQL and file diagnostics identify the 8192-byte bound-plan identity limit; codec
caller-buffer exhaustion remains distinct. The semantic mapping and executed
outcome matrices pass with those deliberate mappings. `just test::file-query`
passes **190 real CLI cases** (`table-logical-prepared-file1.log`), including the
192-MiB input under a 96-MiB address-space limit. Logical template compilation is
local, with no implicit lookup, snapshot or admission. These passes do not claim
migration of the neutral parameter, SDK, Flight, Board or console routes, nor a
new named PREPARE/EXECUTE contract. Committed-HEAD clean qualification is pending.

Composed request-arena decoding passes **250/250 Fuze tests** and **105/105
query tests** (`table-request-arena-{fuze,query}1.log`). One request arena decodes
the independently encoded recursive Table declaration, clones its descriptor,
decodes its bound logical plan and decodes an owned UTF-8 operand. Each input
buffer is overwritten afterwards; complete values and fingerprints remain valid.
Exhaustive partial-allocation failures release the enclosing arena exactly once.
Foreign definitions still reject before allocation. Existing separately owned
decoders delegate to the same implementations and retain their previous failure
cleanup and canonical-byte checks. These are package/ownership checks, not native
job integration or a fresh full-root/clean-checkout qualification.

The logical durable-record codec and embedded neutral values pass **252/252
Fuze tests** (`query-record-fuze2.log` in the same campaign). A structurally
valid counter record that contradicts its immutable plan rejects on binding;
changed bindings and impossible counter shapes reject separately. Neutral text
and JSON remain valid after source buffers are overwritten, including exhaustive
allocation failures and exact uint128 scalar round-trips. The earlier
`query-record-fuze1.log` passes 251 tests before the neutral ownership case.
Native query integration is in progress: its package compilation is not yet a
pass, and neither this check nor the codec alone establishes durable admission.

Catalog definition diagnostics pass **98/98 catalog tests**
(`catalog-definition-witness1.log` in the same campaign). A stale read returns
the exact expected and observed metadata references at its authorized check.
Successful reads clear earlier evidence, and revocation clears it before denial.
This is reference-store unit evidence; native query caller migration and
disk-backed qualification remain separate checks.

Logical binding diagnostics pass **253/253 Fuze tests**
(`logical-binding-names3.log`). A 255-byte quoted Unicode identifier with an
escaped quote survives release of its original SQL buffer and projects into a
structured diagnostic. Unknown qualifier and source failures retain their
original token offsets. The first two runs catch pinned-compiler syntax and
shadowing errors, fixed before this pass. Native query caller tests are still
being migrated; this package pass does not qualify their integration.

## Local storage process-death boundaries — 2026-10-26

`nix develop --command just test::local-storage-faults` passes 42 SIGKILL
schedules on Linux x86_64 after rebasing onto `2be8eab3`. The root unit task also
runs the [Zig owner fixture](../../../tests/storage/local/local_storage_faults.zig) and
[independent Python oracle](../../../tests/storage/local/local_storage_faults.py). A child completes real
filesystem operations, signals the selected boundary and waits on a private
pipe. The parent verifies it remains alive, kills it without cleanup and opens a
fresh owner. EOF, a missing boundary or an unexpected child exit fails the proof.

The 26 WAL schedules cover a 13-byte incomplete append, frame and directory
syncs, metadata rename/sync, durable fencing, partial and whole-log trim, each
prefix-file deletion and completed acknowledgement. Every schedule checks
exclusive ownership while the original owner remains alive. Fresh readers check
literal accepted payloads and exact LSNs/epochs; Python independently decodes
and hashes the persisted metadata. Complete unacknowledged frames remain
uncertain recoverable work, while the incomplete tail never becomes an accepted
row. Repeated trims remove exactly the eligible files, preserve retained reads
and the next LSN, and allow a successor append after reopening.

The original trim implementation fails the schedule killed immediately after
publishing its floor: the repeated boundary returns success while an obsolete
prefix segment still exists. The correction resumes physical removal when the
requested boundary equals the persisted floor. It preserves the existing
authorization precondition and uncertainty/reopen gate; it neither advances that
floor nor changes persisted bytes or the shared contract definition.

The 16 object schedules cover conditional replacement and immutable creation at
all six syncs, descriptor publication and completed acknowledgement. Fresh
public reads must return the complete old or new value as appropriate, with
independently computed size and SHA-256. Retrying the original condition/content
preserves the published result, and a conflicting immutable value rejects.

These are process-death tests with the operating system and page cache retained.
They do not establish power-loss recovery, disk exhaustion, filesystem rollback,
automatic Table retention, retained-root/orphan collection or performance.
Full repository and committed-source CI qualification remain separate gates.

## Declarative data lifecycle, codecs and collations

Source-audit correction (2026-10-22): the checks below exercise metadata
transitions and standalone codec helpers. They do not prove resource-backed
named provisioning, direct data-plane admission, verified computation completion
or freshness after row changes. The current caller path and these limits are
described in the [data model](../../handbook/reference/data-model.md).
The earlier observations below are retained with this narrower attribution.

Working-tree verification in the pinned Nix development shell exercises the
shared state-declaration model (`Table`, `KV`, `Document`), orthogonal column
encoding ($\epsilon$) and collation ($\kappa$) descriptors, direct idempotent
`apply` / non-mutating `preview`, dependency and policy-reference inspection, and
managed computation lifecycle tracking:

- `zig build test` in `packages/zig/transit-fuze` passes 274/274 unit tests,
  including canonical `"FTP1"` column-descriptor trailer encoding/decoding,
  fingerprint sensitivity to physical codecs and collations, incompatible
  encoding/collation rejection, and `.physical` schema change classification.
- `zig build test` in `packages/zig/transit-catalog` passes 40/40 unit tests,
  including named `KV` and `Document` two-phase provisioning/publication,
  cross-kind name collision rejection, direct idempotent `apply` and non-mutating
  `preview`, forward/reverse dependency pagination, `DROP RESTRICT` enforcement,
  policy-reference redaction for callers lacking `.read`, and managed computation
  freshness transitions (`fresh` $\to$ `stale` $\to$ `invalidated`) across
  upstream schema evolution and drops.
- `just contract::station-generate`, `just contract::table-service-generate`, and
  `just bindings::generate` regenerate and verify the Station ABI, table-service
  schema, and SDK host binding contracts.

## Storage hierarchy, `.tseg` segments and multi-writer OCC

Source-audit correction (2026-10-22): the earlier observations below are component
evidence. Memory stores and provider loopbacks do not establish disk crash
recovery, real S3 behavior, a disk-backed NVMe cache or independent-writer CAS.
Paired codec round trips do not establish interchange conformance or correct
collation throughout query execution. The recorded counts are historical;
they are not a new execution of the suites.

Working-tree verification in the pinned Nix development shell exercises the
four-tier storage runtime (`TransitLog`, `TransitObjectStore`, `TableMemtable`,
`NvmeCache`, `TableManifest`, `PartitionLease.OccCoordinator`), the `.tseg`
(`"TSEG"` v1) hybrid OLTP/OLAP segment format, `.tdel` (`"TDEL"` v1) deletion
vectors, all 10 physical column codecs (`PhysicalCodecs.zig`), collation-aware
zone maps and sort keys (`Collation.zig`), and long-lived Ursula partition
streams (`UrsulaWal.zig`):

- `zig build test` in `packages/zig/transit-fuze` passes 332/332 unit tests,
  including round-trip encoding/decoding across all 10 `TableSchema.Encoding`
  codecs (`plain`, `bitpacked`, `rle`, `dictionary`, `fsst`, `comp`, `comp_3`,
  `zoned`, `ibm_hfp`, `ebcdic`), lossless 5-state `.type_error` capture for
  corrupted `COMP-3` nibbles and invalid `IBM_HFP` frames, collation-aware
  `ZoneMap` range pruning and $O(\log N)$ embedded PK B-tree lookups across
  `utf8_binary`, `ascii_ci`, `ebcdic_cp037` (`'a' < 'A' < '0'`) and `icu_root`,
  and `.tdel` deletion vector union/encoding verification.
- `zig build test` in `packages/zig/transit-storage` passes 6/6 integration and
  unit tests, including `LocalWal` 64-byte-aligned `"TWAL"` v1 frame CRC-32C +
  SHA-256 verification, `(writer_epoch, policy_epoch)` fencing, LSN conflict
  rejection, torn-tail truncation on crash recovery, `S3ObjectStore` AWS
  Signature Version 4 (`AWS4-HMAC-SHA256`) conditional CAS (`If-None-Match`) and
  byte-range signing, `NvmeCache` SHA-256 corruption detection/reload and
  scan-resistant `.metadata_or_index` retention, `TableMemtable` read-your-writes
  snapshot lookups, `.tseg`/`.tdel` segment flushing and WAL crash recovery, and
  `OccCoordinator` automatic manifest rebasing for concurrent writers with
  disjoint primary keys versus `WriteWriteConflict` rejection for overlapping
  primary keys.
- `zig build test` in `packages/zig/transit-backend-ursula` passes 10/10 unit
  tests, verifying that `UrsulaWal` reuses a single long-lived partition stream
  across sequential `TWAL1` appends and enforces epoch fencing.

## Local WAL observation cancellation — 2026-10-25

A focused disk test cancels opening the metadata for an accepted partition after
nine partitions evict it from the eight-slot cache. Before the fix, that canceled
read makes even a different cached partition return `WalRecoveryRequired`.
The interrupted load publishes no descriptor and has not changed a disk file.
It now leaves the owner usable; corruption and other storage failures retain
their existing recovery gate.

`nix develop --command zig build test -Dtest-filter=canceling` in
`packages/zig/transit-storage` passes. The first schedule verifies the unrelated
partition, original payload and a subsequent append after cancellation. The
second cancels sync after recovery truncates an incomplete unacknowledged tail:
the owner must refuse further work until reopened, then preserve the accepted
frontier and accept its successor. The first schedule failed against the prior
implementation with `WalRecoveryRequired` as expected. These component results
do not establish the cause of every installed request timeout or replace the
remaining clean installed lifecycle qualification.

## Local storage syscall-error schedules — 2026-10-26

`nix develop --command just test::storage-io-faults` passes five tests, including
the package import check and four fault tests covering 37 schedules. Six WAL
write schedules inject `NoSpaceLeft` before bytes, after a 13-byte torn header
and after a complete frame, on both an existing segment and rollover. Seven
append schedules inject `InputOutput` at every file/metadata/directory sync.
The open owner rejects further operations until reopened; recovery preserves
accepted literal payloads, LSNs and epochs, retains complete uncertain frames,
rejects stale epochs and permits the exact successor position.

Eighteen conditional/immutable object schedules inject `NoSpaceLeft` before,
during and after writes to each staged payload, checksum file and descriptor.
Fresh owners observe the original complete value or absence, then retry the
original condition/content successfully and reject stale/conflicting writes.
The existing six sync-error schedules cover old/new descriptor visibility.
Partial writes reach actual temporary-directory files, but the syscall errors
are injected; these tests do not exhaust the host filesystem, simulate device
loss or prove power-failure durability. No production runtime changes accompany
this expansion. Diagnostic inventory, verification catalog, format and local
documentation checks pass.

## Complete local WAL startup validation — 2026-10-26

A new disk regression creates three partitions with 128 single-frame segments
each, then asserts that opening verifies all 384 frames before any caller read.
The former implementation verifies only 128 and fails that assertion: nested
recovery enumeration advances the same directory descriptor used by the outer
startup iterator, skipping entries after its buffered page. Later reads can
recover omitted partitions, but cannot establish the required startup gate.

An independent directory handle for the startup walk restores full enumeration
without retaining all filenames or partition descriptors. The regression also
checks all partition tails and literal last-row values without additional
recovery, then corrupts a later partition and requires opening to reject.
`zig build test -Dtest-filter='opening validates every partition'
-Dtest-filter='canceling' --summary all` in `packages/zig/transit-storage`
passes 4/4 through the pinned development shell. This is a startup integrity
check, not a claim about recovery after host power loss.

Before the subsequent traversal optimization, the broader disk selection
(`disk`, `recovery truncates`, `missing acknowledged`, `missing and foreign`,
and `canceling` filters) passes 33/33, including the 73-partition cache-eviction
and greater-than-64-MiB recovery cases. Both public local-storage fault tasks
also pass again: 42 process-death and 37 syscall-error schedules.

## Direct local WAL segment traversal — 2026-10-26

The same three-partition, 384-segment fixture now checks directory work as well
as literal payloads and complete startup coverage. Its baseline includes the
startup enumeration correction above: both implementations verify all 384
frames. Before optimization, recovery records 771 segment-directory scans and
eight-row sequential pages add 384 scans. After optimization those counters are
3 and 3 respectively, with all 384 frames read and independently checked. The
new three-scan recovery assertion fails against the baseline with 771 observed.

Recovery retains only the minimum/maximum segment positions and count from one
directory pass per loaded partition. Verified contiguous LSNs name subsequent
files, and the visited count detects overlapping files that this direct walk
would otherwise skip. Reads track the next physical position separately from
the requested position: jumping forward from a cached EOF must still enter the
actual successor segment. Gap, interior overlap, noncanonical filename,
later-partition corruption and forward/backward/evicted/trimmed hint cases pass.

Through the pinned shell, package `zig build test` with filters `disk WAL`,
`recovery truncates`, `missing acknowledged` and `canceling` passes 9/9. The
separate `disk log`, `disk fence`, `disk recovery` and `missing and foreign`
selection passes 6/6, preserving small-allocator recovery beyond the partition
cache and former 64 MiB ceiling. Counts include each executable's import test.
`just test::local-storage-faults` passes all 42 process-death schedules again;
`just test::storage-io-faults` passes all 37 syscall-error schedules (5/5 tests).
Diagnostic inventory/mappings, verification catalog, formatting and local
documentation checks pass.

These counters exclude the outer startup walk and filesystem metadata/device
I/O. Each cold partition load still enumerates the entire directory; trim still
uses repeated enumeration. No persistent segment index, throughput, latency or
whole-process residency result is inferred, and no stored format or acceptance,
fencing, trim-authority or uncertain-append contract changes.

## Retained Table cross-segment range control — 2026-10-26

The `retained Table key ranges skip unrelated disk segments against a complete
same-cut scan` test adds a disk-backed control to the ordered-range implementation
at `20442897`, rebased onto merged WAL recovery at `18010d95`. It writes eight
64-row bulk segments with signed integer keys and 2,048-byte text values. Row
identity order deliberately differs from key order. The range and complete scan
open separate disk owners against the same durable snapshot, clear the one-page
index cache and begin without a cached segment. The scan checks every row's key
and payload independently; both paths find the same four selected values.

The interval crosses two segments and uses two two-row result pages. It requests
280,488 segment bytes in ten ranges, versus 1,121,952 bytes in forty ranges for
the complete 512-row scan. Immutable index misses are 70 versus 2,109. Two versus
eight row groups are decoded; each cached group uses less than 1 MiB in arena
backing allocations. Segment counters exclude index and snapshot objects,
filesystem checksum reads and device amplification. OS caches remain available;
this is not a cold-device, installed-query, RSS or latency measurement.

Reproduce through `nix develop --command just test::storage-key-ranges`, or select
that test in `packages/zig/transit-storage` with `zig build test
-Dtest-filter="retained Table key ranges skip unrelated" --summary all` inside
the pinned shell. The focused case and import check pass. Full-repository and
committed-source clean checks remain separate qualification.

## Selected Table segment decoding — 2026-10-26

On merged baseline `5e77e1b2`, `18132128` adds selected physical column decoding
and explicit borrowed-byte validation; `558c9863` adds the owned encoded-group
reader. The live Table point path uses these readers while physical, identity
and key-range scans retain full-group decoding. No wire/storage definition changes.

`nix develop --command just test::storage-segments` passes 59 Fuze checks and two
storage/import checks. The column tests compare every supported encoding against
explicit logical cells, including all five states, recursive strings and conflict
counter/replica provenance. Independent literal TCP1 fixtures cover plain mixed
states and bitpacked/RLE/dictionary streams. They reject malformed skipped values,
truncated suffixes, invalid row selections and foreign definitions. Existing
independent CP037, rational HFP and mainframe page fixtures still pass; this is
not comprehensive external conformance for every codec.

Reader checks cover projected ranges, source/reader/cache destruction, repeated
selections without source reads, page corruption, mismatched footer row counts,
actual allocation budgets and exhaustive allocator failures. A skipped 16 KiB
symbol-table string still consumes transient validation memory: a 4 KiB combined
budget refuses it, and a 32 KiB budget succeeds with less than 4 KiB retained
output. Selection therefore does not bypass validation or promise zero decoding
of skipped values. The format and shared definition are unchanged.

The disk control writes 512 rows with 2,048-byte text values, reopens with one
resident index page and reads 256-row groups. Selected point decoding retains
3,898 arena bytes (also its decoded peak), plus 530,562 bytes of encoded pages and
their directory. Full-group decoding retains 891,024 arena bytes and uses transient
encoded-page scratch. These numbers exclude footer metadata, index pages, returned
row copies, allocator overhead and process RSS; the decoded-only reduction is not
the reduction in total resident memory.

The cold point requests 563,420 segment bytes in five ranges, the adjacent point
requests zero more, and the complete same-root scan requests 1,093,934 bytes in
seven ranges. Every scanned key/payload is checked against the input fixture.
Current and retained-snapshot points succeed within 16 KiB of decoded memory;
full-group decoding refuses that budget without changing accepted roots or the
original receipt. Returned rows survive eviction/recovery. The existing
cross-segment interval control also passes with unchanged byte/range counts.

The pinned Debug build runs on Linux x86_64 with the host filesystem cache
available. This establishes component ownership, bounds and read counts, not
cold-device traffic, CPU/latency improvement, installed throughput, SQL inequality
pushdown, encoded predicates, maintenance or complete clean-CI qualification.

## WAL append inspection cancellation — 2026-10-26

The [disk-backed regression](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/wal-append-inspection-2026-10-26/report.json)
fails against `9ab5fb64a`: cancelling the open of an existing segment causes the
next tail read to return `WalRecoveryRequired`, although no write occurred.
The corrected owner remains usable after cancellation at both open and length
inspection. Independent partitions retain their acknowledged rows and the next
append uses the unchanged successor LSN.

Focused cancellation/sync tests and all `disk_wal_test` cases pass through
`nix develop` and the package's `zig build test -Dtest-filter=...` selection.
Injected `InputOutput` and cancellation at all three existing-segment and four
new-segment append syncs still require reopening; recovery retains complete
uncertain frames. This does not weaken corruption, incompatible-definition or
post-mutation recovery gates.

A separate installed trace records a cancelled native append followed by
`WalRecoveryRequired` and supervisor replacement. It does not identify the
cancelled syscall, so it does not establish that this particular cancellation
preceded mutation. Installed SQL and complete clean-lane qualification remain
separate obligations.

## Private object I/O and native progress — 2026-10-26

Commit `5b10004c3` separates private immutable-object I/O from the local
backend's journal/quota mutex. Reservation still serializes, disk publication
still locks by key, and final native/data acceptance retains its authority and
epoch checks. A separate short mutex protects disk-object attempt counters.
Concurrent missing-key attempts can conservatively reserve twice until reopen.

`nix develop --command zig build test-local-native --summary all` passes all
11 tests (49 seconds of test execution). The new regression pauses an actual
private object sync, completes immutable reads and a quota-reserved checkpoint
before releasing it, then reopens and verifies both outcomes. Ordinary staging
still rejects at the exhausted data quota. Replacing only `Backend.zig` with
its preceding implementation makes that regression fail at its control-completion
wait while the other ten tests pass. The controller's literal error-name matcher
does not recognize Zig's shortened build output; the raw record retains that
classification, and manual review identifies the sole intended failure location.
The source is restored byte-for-byte after the control.

Focused storage tests pass all four selected cases (one second): independent
conditional publishers, eight concurrent callers sharing one disk facade,
exact completed-attempt counters and object-publication sync failures. Run
`zig build test -Dtest-filter='disk facade' -Dtest-filter='concurrent local publishers' -Dtest-filter='object publication sync failures' --summary all`
from `packages/zig/transit-storage` in the pinned development shell. The native
and object tests use temporary directories on the checkout's physical filesystem.

A matched ext4 reactive control replaces only the node binary with this commit;
the caller binaries, `717f55793` fixture and deadlines remain unchanged. It still
fails in 83.25 seconds at the same ten-second serving completion assertion.
The lock correction therefore does not establish a fix for that failed suite.
A separate diagnostic retains that failure flag but observes the same original
operation for up to 60 seconds. Its checked result completes after 17.917 seconds;
the diagnostic stops there and does not execute the remaining browser trace.
No replacement operation is submitted. This is serving application coordination
over a direct Table owner, not a measurement of isolated Table acceptance.

The [source-attributed bundle](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/lifecycle-private-object-io-2026-10-26/report.json)
preserves component logs, the negative control, node hashes, diagnostic patch and
complete telemetry. Private configurations and durable fixture state remain
outside Git. The committed reactive fixture and runtime deadlines are unchanged;
the broader physical browser failure remains recorded separately from the
data-plane lock-independence result.

## Complete Table archives and physical WAL trimming — 2026-10-26

The selected storage checks pass **5/5 tests**, including one-page-cache archival
of 33 rows across multiple WAL segments, lost publication replies, restart before
and after trimming, and a second archive pass over earlier physical records.
Original receipts, retained unflushed rows, offline history commitments and
admitted operations remain exact. Denial after staging leaves only unpublished
objects; missing archive bytes, a substituted frame LSN, regressed coverage and
an omitted mandatory archive field reject. Selected local native checks pass
**3/3 tests**, including control-reserve archival after ordinary quota fills,
refused trim beyond accepted coverage and revocation before trim. The focused
entry point is `nix develop --command just test::table-archives`, which passes.
The complete storage suite also passes **88/88 tests** (10 minutes, 47 MiB maximum
RSS in this run); that process measurement is not a matched performance control.

`just test::local-storage-faults` passes **63 SIGKILL schedules** in ReleaseSafe,
including **21** new Table cases. Thirteen stop during archive object/index
publication, before acceptance, during partial WAL acceptance or its durability
barriers, and after acceptance before the reply. Eight stop during trim metadata
publication, three individual prefix deletions or completion. A new process
checks original receipt positions, pinned rows and independently expected logical
operations; retries complete archive coverage before removing WAL files. The
parent independently checks persisted trim metadata and actual prefix-file absence.
The first run rejected the harness's below-minimum WAL segment setting before
Table initialization; the corrected run uses the admitted 256-byte roll target.
These schedules preserve the operating system/page cache and do not simulate
power loss or host disk loss.

The shared current-v1 cutover makes archive coordinates mandatory. Native/host
contract checks pass, with regenerated signed fixtures. The Station ABI suite
passes 22 tests and the focused reactive signature suite passes two after fixing
the two omissions found by clean core at `d599e0b8e`: Table ABI test constructors
lacked collation vectors, and the reactive fixture retained an earlier definition's
cursor signature. That clean run failed during `check-core` (1,380/1,381 executed
unit tests passed, plus an ABI compilation failure); it is not qualification of
this later revision. Documentation links, diagnostic mappings/inventory and the
verification catalog pass.

Archiving preserves unlimited logical history and retains immutable objects.
It does not establish logical retention floors, a faster replay checkpoint,
Table-object collection, automatic installed scheduling or full clean-CI results.


## Bounded live Table segment compaction — 2026-10-26

`just test::table-compaction` passes its selected storage, local native and
ReleaseSafe process-death checks. The storage checks merge live rows from four
partially deleted segments in bounded two-row calls, lose a publication reply,
reopen disk owners and finish the same exclusive segment boundary. A second
boundary merges the two outputs; old snapshots still contain removed rows and
current unflushed rows remain WAL-backed. Complete/no-op retries append nothing.
Identity/order roots, live counts and logical-change frontiers remain unchanged.

Private memory, encoded-row bytes, row count and index-work limits reject before
publication. Revocation after staging preserves the old root. The allocation
failure sweep separately passes every compactor/cold-reader allocation point,
checking unchanged accepted roots and cleanup. The shared `MemoryBudget` suite
passes 22 selected Fuze tests; its relational consumers pass 36 tests, including
16,840 input rows and 8,420 groups with bounded disk spill. The local native
control-reserve case compacts and archives after ordinary allocation admission
fills, then checks current authorization before trimming.

`just test::local-storage-faults` passes **78 SIGKILL schedules**, including **15**
new compaction cases. They stop during segment/index object durability, before
acceptance, during a partial acceptance frame and each acceptance durability
barrier, and after acceptance before reply. Fresh owners compare current values,
retained snapshots, original receipts and logical history with independent Python
expectations. Retrying the fixed boundary produces exactly one accepted physical
checkpoint and never selects its own output. The previous 63 schedules continue
to pass with explicit current-row values in their oracle.

These checks establish bounded physical relocation, not deletion of old segment
or index objects, logical expiry, automatic scheduling, host power-loss recovery
or a matched latency improvement. The clean core attempt at `1f6e1c969` stopped
at Zig formatting of the new definition enum tag; `9c2b44597` corrects that spelling.
Later complete clean qualification remains pending.


## Accepted Table recovery checkpoints — 2026-10-26

`just test::table-checkpoints` passes its selected storage checks (seven tests
including the test root and admitted-operation recovery), local native checks
(two tests) and ReleaseSafe process-death schedules. An additional focused old
archive failure check passes two tests including the test root. A disk fixture
accepts 65 point/bulk writes, keeps an unflushed snapshot and history lease,
archives and trims the prefix, loses a checkpoint reply, then accepts one later
write. Reopen replays exactly two Table frames: the checkpoint publication and
that later write. Every original value, the first receipt and the offline logical
history remain exact. A later checkpoint reopens without recursively loading its
superseded capsule.

Denied publication after capsule staging leaves the accepted root unchanged;
retrying covered progress still checks current authority. Missing selected
capsules, incorrect partition/object/frontier, a broken chain, a changed root and
an unrelated action carrying a checkpoint reference fail readiness. Required
stored fields, permanent retirement, pending conditional work and every injected
allocation failure are checked. The native backend publishes a checkpoint using
control reserve after ordinary admission fills; checkpointing does not expand
its separately enforced archive trim floor.

`just test::local-storage-faults` passes **92 SIGKILL schedules**, including **14**
new checkpoint cases. They stop at all six capsule object sync barriers, before
acceptance, during a torn acceptance write, at the four WAL acceptance sync
barriers, at acceptance metadata publication and after acceptance before reply.
Independent Python expectations check whether coverage was accepted, exact replay
counts, current values, pinned rows, original receipt/history and unchanged trim
floors. Repeating the original requested cut publishes at most one checkpoint;
subsequent archive/trim preserves all of that evidence. These experiments keep
the operating system/page cache alive and do not simulate power loss.

Checkpoint metadata is at most 16,424 encoded bytes, with paged dependencies.
The replay counts exclude LocalWal startup and separate historical/index I/O;
they are not matched latency or whole-process RSS results. Older archive data is
verified on access: removing an old required receipt fails the original retry
without creating new work or advancing a history cursor. Unlimited logical
history remains the policy; this work does not authorize object collection or
history expiry, and it does not add automatic scheduling.

The shared current-v1 definition is replaced for mandatory recovery references;
wire/host schemas and independent signed fixtures are regenerated. Native,
Station/client ABI, logical, direct Table and configuration contract checks pass.
The complete storage package suite passes **97/97** tests (seven minutes,
44 MiB maximum RSS). A follow-up missing-index-root test passes both full-chain
and checkpoint recovery cases. Diagnostic catalog/mapping, formatting and
documentation checks pass.

The preceding compaction commit `ea35aa43b` passes the clean core lane's
`check-core` stage in 1,169 seconds, plus transition properties and the delivery,
resource, scheduler and domain simulations. The lane then fails during independent
SQL package compilation: its configuration fixture lacked the collation vector
introduced earlier on this branch. `d2592cbd1` supplies that field; all 31 SQL
package tests and the complete independent package-build recipe pass. This failed
lane is not complete clean qualification of the checkpoint increment.

A subsequent clean core lane at `8aa9b2199f01c82f13a643732e8225627d7e024f`
passes `check-core` (2,016 seconds), transition/delivery/resource/scheduler/domain
simulations, independent package builds (249 seconds), Zig SDK and runtime/client
boundary checks. It then fails `test::station`: the requester ledger's
`example-station-ledger --once` process exceeds its 30-second wait in
`tests/station.py`. The lane is failed, not complete clean qualification; its
successful earlier stages do not prove the Station lifecycle finished.

## Bounded Table build allocations — 2026-10-26

`just test::table-build-memory` passes the selected allocator, Table mutation,
frozen-statement, ALTER and admitted-operation checks, followed by all **92**
local storage SIGKILL schedules. The shared allocator's separate run passes
**23/23** tests; **36/36** relational query regressions pass, including the
16,840-input/8,420-group disk-spill case. A further allocation-failure sweep
passes every injected parent failure while performing admitted Table work:
pending work and the accepted root remain unchanged until successful commit.

Point/bulk candidates, statement input decoding, per-group UPDATE/ALTER work and
flushes share their operation's private budget. Tests reject one-byte budgets,
reject just below a measured successful bulk peak, preserve roots/rows across
failed rewrite and restart, and use declarations and cached rows after temporary
workspaces are gone. Budget exhaustion records the existing admitted work-limit
outcome; an underlying allocator failure remains unresolved. The allocator
regression distinguishes a later parent failure from an earlier refused resize.

Diagnostic error and outcome proofs pass, including **3,409** executed outcome
projections across **24** declared surfaces. Inventory/mapping, formatting,
verification-catalog and documentation checks pass. These are explicit private
allocation bounds; persistent declarations, reader/index caches, WAL and provider
allocations retain their separate owners and bounds. This evidence does not
establish whole-process RSS ceilings, matched latency or complete clean CI.

## Retained metadata recovery reuse — 2026-10-26

The focused catalog metadata suite passes **4/4** tests. Equivalent retained
snapshot inspection plus current authority metadata uses **8 object-range reads**
through one recovered Table owner, compared with **14** for the separate calls
in the same one-page-cache component fixture. This is an operation-count
comparison over memory adapters, not a disk latency measurement. The retained
interpretation survives a committed rename, and the authority IDs agree with the
separate read. Historical points retain their exact commitment and declaration;
snapshot manifests intentionally omit control directories present in WAL roots.

Denying each guard, including the final check after output construction, releases
partial results and returns no successful metadata. Exhaustive allocation
failures cover owner recovery, snapshot decoding and selected history. Reads
leave the accepted root and object-put count unchanged. Corrupt commitments,
foreign leases and released pins reject. Historical dispatch retains its
original-grant check before opening a selected successor; the added signed
regression and broad service replay are still running at this commit. Earlier
full lifecycle runs timed out during repeated history replay, so this component
result alone does not close that failure. The five history phase markers make
the unfinished proof's location visible without changing its checks or deadline.


## Borrowed plain segment payload ownership — 2026-10-26

The focused codec/segment suite passes **48/48** tests. Plain UTF-8, nested text
and conflict alternatives point into immutable page bytes; recursive arrays and
conflict stamps survive temporary-arena resets. Every physical codec agrees with
the independent logical cells, and compressed fallbacks remain detached. A
handwritten TCP1 fixture rejects every truncated prefix, foreign definitions,
invalid ordinals, trailing bytes and corruption in an unselected suffix.
Exhaustive allocation failures release recursive metadata and both group owners.

A 64-row group of 2 KiB strings retains all payloads under a separate encoded
allowance while fitting a **16 KiB decoded budget**; owned full decoding rejects
that same decoded budget. Projected groups retain exact schema/page commitments
and footer counts. Views survive source destruction and reader closure; explicitly
cloned output survives releasing the buffered group. Compressed expansion still
fails when its decoded budget is insufficient.

The focused disk Table/compaction/filter suite passes **6/6** tests. Its 512-row
point/scan control records **3,898 bytes** of point metadata/owned payload and
**86,754 bytes** of buffered group metadata, with **530,562 encoded bytes** under
its separate allowance. Sixteen 16 KiB plain payloads fit an **8 KiB decoded
metadata budget**. Cache projection/group replacement and reopen preserve detached
rows, accepted roots and receipts. A one-byte decode budget leaves no partially
published cache. Allocation failures exposed an intermediate tagged-cache
construction bug; results are now constructed locally before assignment, and
both compaction and filtered-read allocation schedules pass after the fix.

The complete Table suite subsequently passes **59/59** tests. Documentation site,
verification catalog and link checks pass. The signed projection service rerun
and repository-wide check are running; those unfinished runs are not
qualification evidence. This increment changes no
stored definition and does not supply Arrow-compatible physical buffers or an
end-to-end query latency measurement.

## Aligned plain segment value buffers — 2026-10-26

Qualified plain int64, uint64, float64, Boolean, UTF-8, binary and JSON columns
use canonical aligned Arrow value buffers. The shared current-v1 definition is
`ee8cd16789fd88d229945c3dee87bbaadf11e948adadffd8f5dc0e5f3b9fb422`;
earlier definitions reject. Native schemas, binding resources, browser contracts
and independent signing/physical fixtures are regenerated together.

The focused codec/reader run passes **85/85** tests; the complete Fuze suite
passes **396/396** and query units pass **141/141**. Independently authored page
bytes verify validity, signed full-width words, offsets, non-value lanes and
padding. Pinned Arrow accessors read the original buffers, with pointer identity
checked after reader/source destruction. All five states, conflict stamps, exact
JSON, signed zero, variable bytes, empty buffers, allocation failures, malformed
offsets/UTF-8/tail bits, unaligned export, foreign definitions and every truncated
prefix are covered. Selected output survives overwriting input storage.

The full Table run initially passes **58/59**, then fails an old expectation
that complete-group metadata exceeds 16 KiB; the successful row also exposes a
test-only unreleased result on that unexpected-success path. The corrected
focused rerun passes **2/2**. It checks all 512 rows under the original 16 KiB
allowance, a separate one-byte failure with no partial cache, original receipts,
retained cuts, restart and detached output. The measured group uses **456 bytes**
of decoded metadata plus **528,240 encoded bytes**; the point selection uses
**4,584 decoded bytes**. These are distinct allocation owners, not whole-process
RSS or end-to-end latency measurements. The earlier failed suite remains
recorded; this is its focused correction, not a second complete Table-suite run.

The signed `projection` service proof passes filtering, sparse coverage,
segment/WAL reads, prepared comparisons, ordered failures and current/terminal
revocation under the new definition. Contract and independent-fixture checks,
diagnostic inventory/mappings/error boundaries, verification catalog, links and
the complete documentation site check pass. The earlier clean core lane and
ingestion matrix retain their original revisions and remain separate evidence.

The [storage contract](../../../contracts/TRANSIT_STORAGE_V1.md#qualified-plain-value-buffers)
defines exact layouts and bounded fallback. The local Arrow view is a borrowed
nullable value child; complete Transit state/error/conflict evidence stays with
the column. It supplies no C data release callback or external import profile.

## Direct candidate epochs across native storage fences — 2026-10-26

The complete local backend suite passes **25/25** tests. A focused **5/5** run
includes a real native storage fence between Table staging and append for both
point/WAL and bulk/segment ingestion. Publication rejects with
`StaleStorageEpoch`, leaves accepted roots and the WAL frontier unchanged, and
does not renew the old candidate on a later authorization check. Recovery and a
fresh request accept the original unaccepted operation exactly once. Original
receipt reads still work across the fence and continue to check current rights.
The same suite preserves policy revocation, prerequisite authorization and
unrelated native-progress behavior.

The signed Table `authorization` service proof passes explicit role grants,
future-only defaults, filtered metadata, SELECT-only write/DDL denial and retained
cut recovery after revocation/restoration. Documentation links pass. The first
diagnostic-inventory check detects only the quoted-to-unquoted definition enum
spelling produced by Zig formatting in `040959617`; its reviewed inventory is
refreshed, and inventory, mappings and inferred boundary checks pass. This fence
correction does not add Table-object collection or change
the stored definition.

## Table logical history floors — 2026-10-26

The shared current-v1 definition is
`ebc59054719c82fc7358f55b1f7044b499bf2ec361df39ed9c8323a68a1de3c0`.
Table roots require an explicit logical history floor and a paged index ordered
by live history-lease frontier. Earlier definitions and missing persisted fields
reject. Schemas, bindings, independent fixtures and signing resources are
regenerated together.

The complete Table-filtered storage suite passes **63/63**. A final focused
**5/5** run additionally checks admitted work across expiry/restart and empty
history intervals below the floor. Disk-backed cases cover required archive and
recovery coverage, live lease blocking and release, exact lease-frontier expiry,
publication-time denial, lost acknowledgement, monotonic retry after reopen,
original receipts, retained snapshot values and new work after expiry. A
65-lease case with a one-page cache bounds the oldest-lease lookup and rejects a
forged floor that crosses a live lease. Allocation-failure sweeps preserve the
accepted root during lease acquisition, release and floor publication.

The complete local backend suite passes **25/25**, including expiry through
reserved control capacity after ordinary quota exhaustion. The complete signed
direct Table service proof passes **1,942 typed calls**, including CRUD/DDL,
retained cuts, lifecycle/history replay, authorization, prepared queries,
collations, filtered projection and original outcomes across three restarts.
This service proof checks existing public operations under the new definition;
logical expiry is a component maintenance operation, not a new service endpoint.

Contract/fixture checks, diagnostic inventory/mappings/inferred boundaries and
documentation links pass. The [history-floor contract](../../../contracts/TRANSIT_STORAGE_V1.md#table-logical-history-floors)
separates explicit logical expiry from physical collection: the floor neither
deletes objects nor authorizes expiry under quota pressure. Full ingestion and
beyond-process-memory growth runs retain their earlier frozen revisions; neither
is claimed complete here. Clean CI qualification for this revision remains
outstanding.

## Compact Table outcomes independent of historical row payloads — 2026-10-26

The shared current-v1 definition is
`16c0cfe22317dcf6541123f20017e9cd3105ad41b8c8ddc724637901c26af9df`.
Receipt, operation and pending indexes now publish bounded immutable evidence
references. Earlier eight-byte frame pointers reject. Canonical evidence is
bound to the accepting Table transition; schemas, SDK/browser resources and
independent signing/physical fixtures are regenerated together.

The complete Table-filtered storage run passes **63/65**, with two failures. One
old checkpoint test expects a missing archive to break original-receipt lookup;
the corrected test independently removes archive and receipt evidence and checks
their distinct failures. The parent-allocation fault test reports nondeterministic
allocation counts: diagnostics observe 20 allocations/five in-place resizes in
its baseline and 19 allocations/six resizes in the later run. Its test allocator
now disables in-place resize/remap so every growth passes through the injected
allocation schedule. Runtime allocation behavior is unchanged. The corrected
focused run passes **5/5**, including both corrections and the new evidence cases;
this is not a second complete Table-suite run.

The disk case flushes rows, publishes archive/recovery coverage and explicitly
expires history, then removes old payload frames through the test storage
interface. Reopening preserves original outcomes/definitions, exact point and
DDL retries, cancellation, current denial and pending work that can still commit
once. Negative cases reject missing/corrupt evidence without WAL fallback, old
reference lengths, foreign definitions, every truncated prefix, invalid outcome
metadata and a forged acceptance that omits its receipt index entry. An earlier
version of the disk fixture stops at inserted-row identity validation; it is
corrected to use the owning intent's identity constructor before these passes.

The complete local backend suite passes **25/25**. The complete signed Table
service proof passes **1,942 typed calls** under the new definition, including
original receipts, current authority, three restarts, retained history, prepared
queries, collations and filtered projection. `just test::local-storage-faults`
passes **92 SIGKILL schedules** with original outcomes, snapshots, archives and
checkpoints. Contract/browser drift checks, diagnostic inventory/mappings/error
boundaries, verification catalog and documentation links pass. The site check
initially rejects a repository command embedded in public Internals; reproduction
commands move to this ledger, and the complete site check/build passes.

Reproduce with `nix develop`, then `just test::table-checkpoints` for the expanded
focused retention/recovery recipe. The corrected unit invocation is
`zig build test -Dtest-filter='Table build memory parent failures' -Dtest-filter='Table recovery checkpoint separates' -Dtest-filter='Table compact evidence' --summary all`
in `packages/zig/transit-storage`. This representation separates retention
dependencies; it does not implement physical Table collection. New immutable
evidence staging is not covered by the still-running earlier-revision ingestion
matrix. The frozen growth proof at `b85a0a076` has verified both Table fixtures,
including **191,717,253 retained bytes** for 8,192 rows under a **128 MiB** process
address-space limit; native-owner cases remain pending. Neither complete growth
qualification nor clean CI qualification for this revision is claimed.

## Bounded Table directory traversal — 2026-10-26

`TableStorageWalk` traverses one selected immutable directory with at most 33
page frames, a cursor smaller than 4 KiB, and at most 34 page loads per call.
The focused storage run passes **11/11**, covering the walker, archive ownership
and ordered-key cases. Reproduce in `packages/zig/transit-storage` after entering
`nix develop` with `zig build test -Dtest-filter='Table storage walk' -Dtest-filter='Table archive' -Dtest-filter='ordered full key' --summary all`.
The expanded `just test::table-checkpoints` recipe includes the walker cases.

The component cases walk 257 row locators with a one-page cache, round-trip
the owned cursor between steps, and inject a failed load before every step.
They reject corrupt page digests, invalid parent/child heights and malformed
typed leaves without advancing. A 4,096-byte ordered key emits 64 separately
queued child directories instead of accumulating nested stacks. The disk case
reopens accepted point/bulk rows, live and released pins, admitted work, compact
receipts and archives; every emitted object is read through its owning verifier,
and the accepted root remains unchanged. The first compile attempt uses a Zig
reserved word for the page-only role and fails; renaming it precedes these passes.

Diagnostic inventory, semantic mappings, inferred error boundaries, verification
catalog and 6,409 documentation links pass. This component does not select all
retained roots, persist a collection queue, inventory allocations or delete
objects. Test cursor JSON is not a stored maintenance format. Complete Table
collection and final committed-HEAD clean qualification remain outstanding.

## Stream retained graph and native physical collection — 2026-10-29

At source `f2b4fd82a4d22ba01725781ca9ded2441323b13d`, the disk scenario in
[direct collection](../../../tests/storage/local/direct_collection.zig) passes
`nix develop --option eval-cache false --command zig build test-local-data-collection -Doptimize=ReleaseSafe`
with exit zero. The executable SHA-256 is
`8d01a0f36ce40ac49d358dc9da95f3b4ae55e9ed521c2ee4fe97f55078301b60`.
The retained graph also passes the catalog's focused `log` package tests.

The Stream case uses the real local native disk adapter and native epoch/time
collection fences, with an explicit trusted component publication guard. It
archives and checkpoints a pinned append, physically trims the WAL, publishes
additional archive progress, collects abandoned read/checkpoint objects, then
reopens the backend and recovers the same read and append receipt. Releasing the
read preserves its basis while checkpoint replay still requires it. After a
new checkpoint, collection removes that basis and the superseded checkpoint;
fresh recovery still returns original outcomes and refuses the closed read.
Its three collection passes complete in 125, 1,311 and 1,416 bounded steps,
reclaiming 7, 538 and 669 allocations respectively. Existing Table collection
cases also pass (225 and 2,177 steps).

This executes native storage composition, not signed public payload APIs,
automatic Stream maintenance, Queue scheduling or complete R0–R6 qualification.
The source's payload owners still require service composition. Diagnostic
inventory and 8,275 documentation links pass; final committed-source CI remains
a separate gate.

## Rebase over private object I/O separation — 2026-10-26

The branch rebases 31 commits onto `443404722` with all author dates preserved
and matching committer dates. Resolution preserves direct-data namespace checks,
the upstream removal of the journal mutex from private direct-object reads and
publication, both proof-ledger histories and regenerated diagnostic inventory.
Native allocation/collection serialization remains its existing separate scope.

At rebased revision `db0214006`, `zig build test-local-native --summary all`
passes **26/26**, including the upstream paused-sync/control-progress regression
and this branch's native collection, quota, fencing and recovery cases. Focused
storage tests pass **6/6** for disk-facade concurrency, independent conditional
publishers, publication-sync failure and retained Table root enumeration.
Diagnostic inventory matches. Commands run inside the pinned Nix shell; the
storage selection uses `-Dtest-filter='disk facade'`,
`-Dtest-filter='concurrent local publishers'`,
`-Dtest-filter='object publication sync failures'` and
`-Dtest-filter='Table retained root enumeration'` in `packages/zig/transit-storage`.

The preceding full `just check` at `fcefc1e67` is **interrupted with exit 130**
to perform the requested rebase. Python harnesses, toolchain checks, formatting
and contracts complete; unit execution reports the 92 local storage and 15
native collection SIGKILL schedules before interruption. The overall unit step,
Board/site checks and full check do not complete. Its log remains
`/var/tmp/transit-m2-retained-roots-check.log`. Focused post-rebase passes do not
replace a completed full check or final committed-HEAD clean CI.

## Concurrent immutable confirmation counters — 2026-10-26

Post-rebase review finds that `confirmImmutableObject` still updates disk read
counters without the short counter mutex introduced for ordinary object reads.
It now takes that mutex only after verification and sync finish. The existing
eight-caller disk-facade proof also confirms each private and shared immutable
object, then checks exact completed put/read/byte counts after joining all
callers. Publication and acceptance semantics are unchanged.

The focused disk-facade, confirmation and publication-sync run passes **4/4**:
`zig build test -Dtest-filter='disk facade' -Dtest-filter='confirmation' -Dtest-filter='object publication sync failures' --summary all`
in `packages/zig/transit-storage` inside the pinned Nix shell. The log is
`/var/tmp/transit-m2-pr-confirmation-test.log`. Full workspace and clean core
checks started at `9ae8b801f` are interrupted with exit 130 during toolchain
qualification to include this correction; neither is a passed full check.

## Retained Table history and recovery root enumeration — 2026-10-26

`TableStorageRoots` follows a caller-retained accepted root/chain cut. It emits
the current root, one selected recovery capsule and one owned record per frame
from the logical floor through that fixed frontier. Historical data roots are
distinguished from control dependencies needed by replay. The canonical frame
decoder is shared with the existing Table recovery path; stored bytes and
acceptance semantics are unchanged.

The focused run passes **13/13** with
`zig build test -Dtest-filter='Table retained root enumeration' -Dtest-filter='Table recovery checkpoint' -Dtest-filter='Table history floor' --summary all`
in `packages/zig/transit-storage` after entering `nix develop`. The disk case
covers no checkpoint, unlimited history, a floor below the recovery baseline,
and a floor exactly at that baseline, followed by physical WAL trim and reopen.
It deletes a superseded capsule through the test store: its structural reference
is never recursively opened. A later append cannot extend an earlier selected
cut. Missing selected capsules, lost required history and a wrong terminal chain
fail without advancing the cursor. The final accepted root remains unchanged;
cursor size is asserted below 8 KiB. Existing checkpoint/floor tests run alongside
these cases. The first focused checkpoint/root run passes 8/8 before the final
additional boundary cases.

Diagnostic inventory/mappings/inferred boundaries, verification catalog and
6,409 documentation links pass. Current live pins, lease anchor frames and
unflushed-row dependencies remain separate edges to traverse. Only complete
enumeration can support a future collector's marks; this component supplies no
all-owner cut, persisted mark/work queue, physical inventory or deletion. Full
collection and final committed-HEAD clean qualification remain outstanding.
