# Explore console: language assistance and result summaries

[D4 review](D4.md) · [Review index](README.md)

Supporting design for **board-console D4**, not another review or a wire
specification. All editor services, generated browser artifacts, completion,
catalog search, worksheet history and profile UI described here are proposed.
The live D4 refinement supersedes the original no-execution-while-typing policy.
[Live scheduling and stream semantics](LIVE.md) owns execution speculation,
session budgets and Snapshot/Stream behavior; this file owns editor assistance.

## What exists and what must be built

| Foundation | Current evidence | Required addition |
| --- | --- | --- |
| SQL syntax | [TransitExtensions.g4](../../../contracts/sql/TransitExtensions.g4), with a generated Python/ANTLR verification parser | A pinned editor artifact generator and incomplete-input/caret analysis |
| Executable semantics | [Sql.zig](../../../packages/zig/transit-fuze/src/Sql.zig) strictly parses complete SELECT statements and compiles against supplied source metadata | A versioned capability/semantic descriptor; useful diagnostic spans and completion contexts |
| Source metadata | [Query Model.Source](../../../packages/zig/transit-query/src/Model.zig) describes one configured Table, schema, revisions and current observation | Authorized bounded catalog search, stable object identities and source binding beyond that one Table |
| Browser execution | [QueryWorkspace](../../../apps/transit-board-web/src/query-workspace.tsx) prepares/freezes/submits, observes status and reads verified pages | A multiline shell, active-statement ranges, worksheet drafts, completion and session history |
| Result data | Query model supplies columns, lossless cells, pages, manifests and phases | Typed profile computation with explicit coverage; no inference from page count alone |

The current grammar generation is a verification step, not shipped editor code.
The production Zig parser returns an error for an unfinished string or statement;
it exposes no public incremental tree, token ranges or expected-token API.
The CLI is currently one statement per line, not an existing multiline editor.
Neither existing catalog inspection nor a Table `describe` response establishes
general SQL namespace resolution. These are concrete engineering gaps behind D4.

## Generate syntax support, share semantic rules

Use the checked grammar as the source for lexical classes, productions and
expected-token transitions. Build a versioned editor bundle ahead of time;
do not generate a parser in the browser. Prototype a generated worker adapter
that accepts incomplete input and returns token spans, candidate contexts and
diagnostics. Generator/library selection should follow bundle, recovery and
latency measurements; D4 selects no editor dependency or new runtime package.

Syntax alone cannot choose a Table, resolve a column or decide that a statement
can execute. Join the generated contexts with a shared, versioned description
of executable operations/types/bounds and authorized catalog metadata. Keep
type/operation support with its Zig semantic owner; do not hand-maintain a second
list of SQL semantics in React. Grammar-only DDL remains discoverable as language
documentation, marked unavailable for execution. A server capability version
must agree with the editor's grammar/profile before semantic suggestions are used.

The server's complete parse/compile and current authorization remain required
for every actual evaluation. A partial editor tree is not executable truth.
Speculation must produce a separate, complete candidate, compile it normally
and disclose its identity; it cannot silently drop an invalid suffix. Pure
editor diagnostics never call `prepare`. The live scheduler may prepare/submit
admitted candidates, recognizing that this freezes a signed operation, consumes
shared admission and captures durable work. Per-keystroke scheduling needs the
separate lifecycle and resource contract in the live notes.

## Completion request and response shape

Before implementation, define a neutral editor-service contract and shared
fixtures. It should carry a document ID/version, exact edit and caret offsets,
active statement range, grammar/profile version, scope generation and catalog
snapshot identity. Responses need token spans, diagnostic severity/support
reason, and candidates with label, kind, type, replacement range and insert text.
This list describes required information, not a new public API schema.

Specify browser UTF-16 positions versus SQL UTF-8 byte offsets explicitly,
including surrogate pairs, line endings and IME composition. A candidate replaces
the full intended token, including text after the caret, as one undoable edit.
It must preserve quoted-name case and escape embedded quotes exactly once.
Ignore a response for an old document, caret, capability, realm or policy context.

At the caret, combine both prefix and suffix where needed. `SELECT va| FROM
samples` can use the later FROM binding; at `FROM sam|` the context is a source
name. Only syntactically relevant candidate kinds enter ranking. Then filter by
source kind, resolved scope, compatible type and executable profile. Prefer an
exact prefix match and stable catalog order; do not reorder a highlighted entry
under the user's keypress. Tab/Enter accepts, arrows select, Escape dismisses,
and Ctrl+Space explicitly requests assistance. Accepting a completion is a text
edit and may schedule execution in Live. Ctrl/Cmd+Enter prioritizes an exact
evaluation now; ordinary completion remains usable in Paused without queries.

| Context (`\|` marks the caret) | Proposed assistance |
| --- | --- |
| `SEL\|` | `SELECT`; current executable profile does not offer runnable CREATE |
| `SELECT id FROM sam\|` | Visible, queryable source names matching `sam` |
| `SELECT va\| FROM samples` | `value` and its type from the resolved source |
| `WHERE samples.\|` | That source's permitted field names; no invented namespace |
| `WHERE id \|` | Supported comparisons and `IS NULL`, with semantic type filtering |
| `LIMIT \|` | Integer shape and current 0–32 explicit-limit bound; no implied limit when omitted |
| `SELECT SUM(\|) FROM samples` | Numeric columns, plus the actual aggregate restrictions |
| Inside a comment or string | Lexical highlighting; no object-name completion or data-value fetch |
| Unknown source or stale catalog | Syntax assistance plus a precise unresolved/unavailable state |

Unterminated quotes/comments are normal while typing. Preserve lexical state
across edits; completion must not suggest keywords inside their contents. In a
quoted identifier, use identifier assistance rather than string-literal behavior.
Respect nesting and document-work budgets; an edit near the beginning may require
a wider rescan. Reuse checkpoints where safe and schedule a bounded worker pass
when incremental recovery is uncertain. Never sacrifice correctness by treating
an arbitrary suffix as a new top-level statement.

Highlight lexical classes immediately; resolved identifiers and diagnostics may
arrive later. Do not mark unresolved metadata as a syntax error or normal
incomplete input as an execution failure. In the monochrome study, weight and
underline illustrate token distinctions; final syntax colors require a styling
review and must not be the sole indication of an error.

## Responsive without an unbounded catalog

Typing and caret movement stay on the editor thread. Syntax/context work runs in
a worker with one active job and one coalesced latest request. Cancel obsolete
jobs and discard stale results. Result decoding/profiling has a separate bounded
work budget and must not delay typing. Local assistance does not need a remote
round trip per key or an LLM. Separately, the live scheduler may send a qualified
candidate for each useful edit, including every keystroke within budget. Prefer
versioned edits/plan reuse where qualified; never confuse an editor worker job
with an admitted query or hide their different I/O and storage costs.

Seed the current Table's metadata through its authorized describe path. A future
catalog endpoint supplies bounded, prefix-filtered pages; one in-flight request
is superseded when the prefix/scope changes. Show warm candidates immediately,
then merge fresh catalog matches without stealing the current selection. On a
cold miss show that discovery is pending; network latency cannot honestly be
promised as instant. Never download the whole catalog or sample rows for hints.

Proposed prototype budgets, **unmeasured and subject to qualification**:

| Measure | Initial target / resident bound |
| --- | --- |
| Warm keypress to visible candidates | p95 ≤ 50 ms, p99 ≤ 100 ms; includes scheduling and rendering |
| Editor main-thread work per edit | p95 ≤ 4 ms; no edit-induced task over 50 ms |
| Completion popup | At most 20 visible candidates, with bounded continuation |
| Language worker queue | One active job plus one replacement request |
| Open drafts | At most eight; 64 KiB UTF-8 per worksheet as a proposed editor budget |
| Session history | At most 50 completed records and 256 KiB, whichever is reached first; active/uncertain operation identity is held separately and cannot be evicted with history |
| Active executable statement | Existing 4096-byte SQL bound; M13's separate 207-byte encoded-plan limit still applies |
| Resident catalog slice | At most 2 MiB and 2,000 entries, whichever is reached first; LRU by scope/version |
| Catalog response / concurrency | At most 100 entries and 64 KiB; one in flight, prefix requests coalesced after 100 ms idle |
| Profiles and visible data | One bounded result page plus fixed accumulators per supported column; no retained row history |

These numbers constrain editor work, not total catalog or result cardinality.
Larger worksheets remain editable only within their declared buffer budget;
selecting a statement does not relax compiler bounds. Larger catalogs are searched
through bounded pages. No browser limit may silently truncate executable SQL or
accepted results. Specify overall worker memory and bundle/startup budgets after
the candidate generator/editor is measured, before calling the implementation
qualified.

Measure warm edits, cold load, edits at the start/middle/end, invalid input, long
comments, paste/undo and composition against fixed hardware/browser versions.
Use 4 KiB executable statements and proposed 64 KiB worksheet stress cases,
eight open drafts and catalogs up to a million synthetic entries behind bounded
search. Repeat with delayed/offline metadata and result pages arriving. Report
latency percentiles, long tasks, resident/peak memory, cold startup and bytes
fetched. The catalog cardinality is a future test workload, not scale evidence.

## Catalog and history disclosure

Catalog metadata is protected data. Its cache key includes realm, principal or
configured identity, policy observation, catalog revision and capability profile.
Only disclosed entries may appear in candidates, hover text or match counts.
The server authorizes every metadata request; knowing a name supplies no grant.
Schema/source revisions are carried through resolution and checked at evaluation.
An expired observation suppresses affected semantic suggestions until refreshed;
known revocation clears them immediately. A late response cannot resurrect them.

Keep caches in memory under the current Board rules. Clear protected metadata,
drafts, session history and profiles on scope change/denial, and hide protected
data during unavailable-policy states or tab hiding as the current workspace
requires. Public grammar keywords can remain available offline. Do not send SQL,
literals, catalog names or candidate text to telemetry, URL state or persistence.
Future durable worksheets/history need explicit storage, retention, deletion,
access and secret-handling contracts. No automatic localStorage history is implied.

## Summary semantics

Each finite snapshot view is bound to the frozen executed text, correlation/result ID,
source identity/revision and verified manifest. Column labels and types come
from the result schema, which may differ from source columns after an aggregate.
Before verified completion, show status/progress, not apparently final rows or
profiles. Speculative snapshots additionally name their candidate and parent
draft; they can be verified answers to that candidate without answering current
text. Stream views instead require the committed-frontier contract in the live
notes, and cannot reuse snapshot Complete as a status for an endless query.
A submission receipt does not establish query admission or completion;
observe those phases separately.

| Summary field | Evidence / coverage |
| --- | --- |
| Outcome | Query status; submitted, capturing/delivering, complete, cancelled, denied, expired and failed remain distinct |
| Returned row count | Verified manifest; distinct from rows fetched/rendered and source cardinality |
| Columns / types | Verified result schema, including nullability and aggregate output names |
| Source / limit | Exact read basis and executed statement; a limited result is not a full Table profile |
| Null count, min/max | Typed computation over the named loaded page, or a qualified whole-result profile |
| Timing | Only measured phases with their clock/boundary; browser elapsed time is not engine execution time |

The D4 three-row example fits one complete loaded page, so its null counts and
ranges cover all returned rows. For a larger complete result, auto-profile only
the visible loaded page and label **Loaded page: N of M returned rows**. Loading
another page replaces that page profile. It does not silently scan other pages
or run `COUNT`, `MIN`, `MAX` queries against the source.

Whole-result profiling is a separate explicit result-read operation: it would
stream the same verified result under current read authorization, bound CPU/I/O
and memory, track processed ordinals exactly once, and expose partial coverage
until finished. Cancellation stops that profiling operation; it does not undo
the source query. A published profile would need a result-bound contract and
retention/access rules. Do not implement a browser accumulator that silently
grows with results or double-counts retried pages.

Keep int64 values exact as decimal strings/BigInt and preserve null versus empty,
false, missing and unavailable. Null counts/ranges need bounded accumulators;
histograms and distinct/top-value statistics require explicit bucket/cardinality
budgets and sampling/approximation labels. Defer sum/mean until their overflow,
precision and empty-input rules are specified. Empty results have zero rows and
an unavailable range, not a fabricated zero range. Document/KV profiles wait for
versioned typed adapters; the UI never infers application decoding from bytes.

Rows, charts and cell inspection share the same result and coverage. A chart can
render a loaded page without extra I/O; an entire-result chart must explicitly
obtain a qualified result-derived summary. Changing chart controls or a displayed
filter does not independently dispatch a fresh query. An explicit SQL edit enters
the worksheet's live scheduling policy; Paused leaves it unevaluated. Stream
views advance with committed source progress even while their SQL stays unchanged.

## Qualification to require before implementation acceptance

Use shared fixtures for complete-statement agreement with the reference grammar
and Zig compiler, plus caret/partial-input fixtures for editor recovery. Cover
quoted names, Unicode offset mapping, nested comments, strings, mid-token edits,
derived-table scope, unsupported constructs, type/limit filtering and version
mismatch. Valid syntax is not a sufficient positive case: include compilation
failures that the editor must explain instead of presenting as executable.

Exercise catalog revocation, delayed responses, a changed schema, realm changes,
offline policy state and hidden-object prefixes. Verify that Paused editing and
metadata-only browsing prepare/submit no queries. In Live, verify only admitted,
qualified exact/candidate reads occur within scope and budget, with no external
effects or automatic administrative writes. A completion popup itself is not
execution authority. Verify candidate identity, supersession and stale-result
fencing using the live scenarios.
Test keyboard/screen-reader completion, IME composition, undo and focus stability.

Compare summaries with independent typed computations on empty/all-null, large
int64, multi-page and retried-page fixtures. Prove that page profiles cannot be
labelled whole-result profiles and that changed drafts retain the earlier result
identity. Measure the response budgets above while those operations are active.
These are planned proofs; D4 only supplies static examples and design checks.
