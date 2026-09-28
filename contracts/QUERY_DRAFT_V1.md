# Finite query draft budget v1

Status: M23 native owner and Table host implemented and qualified; browser
scheduling and draft-specific process-loss qualification remain in progress. This extends the v2 requester, without changing explicit Run or M21
Follow semantics. It supplies no watch or continuous query support.

An explicit open conditionally advances the requester's draft generation. It
freezes a source-contract fingerprint, page/segment/result-byte limits and one to
eight evaluation intents. One current generation is shared by the requester's
configured native principal across hosts. Open retries recover the original
record, including its consumed budget and closed state. Another generation
requires an explicit open after closing or exhausting the previous generation.
No reload, edit, polling loop or reconnect may open/reset a generation implicitly.

The browser keeps one newest draft and one accepted query. It coalesces edits,
compiles complete drafts through Zig, and starts only after the previous query
has settled. Partial SQL never becomes execution by dropping a clause. The first
profile executes exact valid drafts; speculative alternatives are not selected.
Pause/hide stops scheduling; native close prevents subsequent new starts while
already admitted queries retain independent recovery and cancellation.

The existing immutable bundle upload is reused. At draft submission, the owner
reads and verifies its complete bounded publication, validates the bundle, checks
the frozen source contract and budgets, and atomically records an intent together
with the existing query call and correlation. The four native mutations remain:
wait, upload status, correlation index, generation record. Allocation/parse/read
failure or capacity failure restores the original turn decision. The requester
still admits one active upload/query; deployment/source limits also apply.

A generation record contains at most eight query namespaces. This is an explicit
bounded operation group, not a limit on durable generation or query history.
Records, closed generations and query identities are permanent by default; reads
use point lookups. Reapplying an exact recorded namespace returns its original
correlation, even after closure, and cannot dispatch again. A previously manual
query cannot be relabeled as a budgeted execution. New submissions need the
current open generation, remaining budget, matching complete bundle and current
native authority. The counter measures admitted intents, never rows or completed
results. There is no refund for cancellation or later failure.

Wire tags in ordinary Station casts: `UQD1` opens with expected generation u64,
limit u8, contract 32 bytes and three u64 budget fields (pages, segments, bytes);
`UQH1` closes a generation u64; `UQE1` submits generation u64 and namespace u64.
All integers are little endian; identifiers use lossless decimal strings at JSON
boundaries. Opening expected UINT64_MAX fails; generations begin at one. No
credential or SQL text is stored in the budget record.

Requester keys use the existing unified-record key encoding: `D/0/0` is the
current generation head, `D/generation/0` is a `UQD1` record. Its layout is tag,
generation u64, original open payload (expected u64, limit u8, contract[32], three
budget u64s), starts u8, enabled u8, eight namespace u64s. Used namespaces are
nonzero and unique; the remainder are zero. Native grants and requester
configuration are checked independently of these records.
