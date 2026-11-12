# Private transactional Station comparison

This reference preserves the native/private handler comparison beyond ordinary
CI retention. The [Station test owner](../../runtime/AGENTS.md) and
[performance owner](../../performance/AGENTS.md) retain it to assess the cost of
the private common-transaction composition before a public consumer cutover.
These files are evidence, never correctness-test inputs or performance budgets.
The [qualification account](../../../docs/history/qualification/performance.md#private-transactional-station-comparison--2026-11-12)
owns interpretation and limits; the [measurement guide](../../performance/load/station_turn.md)
owns the workloads.

| Observation | Source | Retained report |
| --- | --- | --- |
| Initial native control | `68b65d06c32b6e47e14e7fa66692e0ce61f48478` | [Complete](native-initial/report.json) |
| Native repeat before the first private attempt | Same native source | [Complete](native-repeat/report.json) |
| First private attempt | `feae88768aebb086b51841e77959380107ddf20a` | [Incomplete: restart oracle failed](transactional-initial-failed/report.json) |
| Native control before the corrected comparison | Same native source | [Complete](native-final/report.json) |
| Corrected private comparison | `4c19523ddf46da888c5f2d8bd6e80e6696193a4b` | [Complete](transactional-final/report.json) |
| Native control before the compact client comparison | Same native source | [Complete](native-context/report.json) |
| Private comparison with compact client context | `b24c048d24d4045c0876fe0306d08c73b7adb902` | [Complete](transactional-compact-client/report.json) |

Each arm has three warmups and twenty measured turns, one 128-byte state value
and one output intent per input, with an independent byte-pattern oracle. The
private arm also inserts a Table row, checks two private Table reads and appends
a journal entry. Its input is a typed Queue payload, and its timer covers
pending discovery through decision and cleanup. The native arm uses an integer
message and times accepted-input preparation through native commit confirmation,
including private recorder writes. These are different compositions of the
same state/output sequence, not isolated commit-mechanism costs.

Both use pinned ReleaseSafe builds, synchronous local disk storage, one resident
storage page and unlimited retention. The private arm preserves its 64 MiB runner
ceiling, five-minute Queue lease and 30-second client exchanges. Runs are
sequential after builds on a shared 48-logical-CPU host with retained OS caches.
External load is uncontrolled; machine/load observations remain in each report.
No absolute latency target, allocator-free steady state or physical power-loss
claim follows from these runs.

The first private attempt confirms all 23 turns but fails its restart oracle
because that oracle assumes physical Table scans use numeric primary-key order.
Its report remains `completed: false`; a successful sample summary inside that
report is not complete qualification. The corrected oracle checks the exact
independent value set and rejects duplicate or foreign rows. It verifies the
original installation twice across another SIGKILL restart without rerunning a
handler or changing the saved binding. The [recheck output](retained-oracle.stdout)
and [provenance](provenance.json) retain that separate source and binary identity.
A fresh corrected run then passes both restart checks with principal replacement
and zero recovery handler calls.

Raw reports, samples and phase outputs are copied byte-for-byte. Provenance
lists original paths, hashes and sizes, plus exact driver hashes for each private
source. The [failure excerpt](transactional-initial-failed/verification-failure.txt)
selects the first six lines of the original log without editing them; its full-log
hash and selection are recorded. Remaining routine node diagnostics stay in
ignored output. Installation state, credential files and recovery stores are
excluded. Verify the retained bytes with `sha256sum --check SHA256SUMS.txt`.
