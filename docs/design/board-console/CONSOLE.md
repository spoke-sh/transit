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
| Source metadata | [Query Model.Source](../../../packages/zig/transit-query/src/Model.zig) describes one configured Table, schema, revisions and current observation | Authorized bounded catalog search, stable object identities, owner-produced metric/schema summaries and source binding beyond that one Table |
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
Resource-search metrics and schema previews arrive with that bounded page or
from the same versioned cache; they never block names or trigger per-row fan-out.

Proposed prototype budgets, **unmeasured and subject to qualification**:

| Measure | Initial target / resident bound |
| --- | --- |
| Warm keypress to visible candidates | p95 ≤ 50 ms, p99 ≤ 100 ms; includes scheduling and rendering |
| Editor main-thread work per edit | p95 ≤ 4 ms; no edit-induced task over 50 ms |
| Completion popup | At most 20 visible candidates, with bounded continuation |
| Resource-search list | At most five visible rows; bounded continuation through the same catalog page; previews cap at four fields or two nested levels |
| Language worker queue | One active job plus one replacement request |
| Open drafts | At most eight; 64 KiB UTF-8 per worksheet as a proposed editor budget |
| Session history | At most 50 completed records and 256 KiB, whichever is reached first; active/uncertain operation identity is held separately and cannot be evicted with history |
| Active executable statement | Existing 4096-byte SQL bound; M13's separate 207-byte encoded-plan limit still applies |
| Resident catalog slice | At most 2 MiB and 2,000 entries, whichever is reached first; LRU by scope/version |
| Catalog response / concurrency | At most 100 entries and 64 KiB; one in flight, prefix requests coalesced after 100 ms idle |
| Profiles and visible data | One bounded result page; at most four visible column profiles, up to 32 histogram bins each; exact distinct sets stay within an explicit per-column entry/byte budget; no retained row history |

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

## Resource search: one field, informative rows

The **Find resources** field replaces the Catalog button/tree. It stays beside
Explore's title and opens a wide, dismissible list below it, over the worksheet.
The SQL editor keeps its width and split position. On a narrow screen the list
uses the available content width and stacks each row's metrics under its name;
hide no resource kind or measurement qualifier to preserve a desktop grid.

Focus with no text shows bounded recently inspected resources in the current
authorized scope; without recents, show the first bounded name page. Typing filters
warm names immediately while a fresh page is fetched. Begin with prefix matching
on resource names, exact matches first, then kind (Table, Document, KV) and stable
name/identity order within each kind.
Ranking is independent of metrics arriving. Broader token/fuzzy or schema-field
search needs an explicit index and ranking contract; do not imply it by filtering
only a loaded page. Kind filters, when used, are discrete controls, not a new SQL
or magic search-language grammar. Clearing text returns to the initial list.

Rows align four groups: name/kind/capability, cardinality, size and schema.
Keep kind text beside its icon; communicate selection with an outline and marker.
Schema diagrams have equivalent text. Keyboard navigation and assistive technology
receive each row's name, kind, capability and metric qualifiers as one option.
Use a labelled combobox with listbox options; Details/Insert name are separate
focusable actions for the selected row, not interactive controls nested in an
option. Arrow keys change selection, Enter opens Details and Escape closes the
list and returns to SQL. Tab reaches the explicit actions. Pointer selection
follows the same behavior. Preserve the selected identity when a page refreshes;
if it disappears, clear selection rather than moving it onto another resource.
The search field's accessible label is Find resources; the hint names the kinds
it can discover. Detail views return to the same search text and selected identity.

| Row content | Meaning and evidence |
| --- | --- |
| Name, type and capability | Stable resource identity with a display name; Table, Document or KV text/icon; Queryable or Inspect only for the current profile and grant |
| Cardinality | Table logical rows; KV keys in the named keyspace; a Document has no implied row count. Structural field/node counts, when available, are labelled separately. Physical resource entry counts may include framework records and cannot substitute for logical rows |
| Size | Named measure and unit: logical value bytes, encoded current-state bytes or retained bytes. Keep these different; provider allocation/compression is not derivable from a logical byte count |
| Table schema | Bounded field cells with names, declared types, primary-key and nullability labels; additional fields appear as `+N fields`, expanded in Details |
| Document shape | A small branching map/list diagram only from a recognized declared or registered shape with its version. Optional/unknown parts stay explicit; an absent descriptor is Shape unavailable, never a sampled schema |
| KV shape | Key encoding → value encoding or declared type; opaque bytes stay bytes. A decoder/schema requires the qualified owning adapter |
| Observation | Each metric carries resource/scope, basis revision, coverage, exact/estimated/unavailable state and producer. Estimates disclose method/error information when available; stale observations retain their old basis and stale label |

Keep the row compact: value plus unit on the first line, basis/qualification on
the second. Details exposes complete identity, scope, provenance and freshness,
including different metric/schema revisions. A schema diagram is structure, not
a value distribution; row profiles and histograms still belong to identified query
results. Never add a decorative sparkline without a bounded historical metric and
an explicit axis/window. Unknown size is `Unavailable`, distinct from exact zero.

The [synthetic search fixture](d4-catalog-fixture.json) supplies Figure 4's rows.
Its Table cardinality describes all six source rows at r42, not the worksheet's
three-row result. The 96 B figure counts only twelve eight-byte values; it is not
disk use. Document/KV observations illustrate future metadata contracts. Neither
today's atlas entry count nor a limited result can populate these fields honestly.
Metadata owners must maintain or publish bounded authorized summaries through
public surfaces, with their own cost/freshness contract. No per-keypress COUNT,
sample reads, raw storage inspection or background profile scans are implied.

Search text is discovery text, never a worksheet edit or executable statement.
Moving selection/opening Details leaves SQL and its Live result unchanged;
already admitted worksheet work can continue. **Insert name** is enabled only
for a queryable resource and a captured source-name position/selection. Recheck
editor version/range, current source identity, schema and capability before one
undoable, correctly quoted replacement. If context changed, ask the user to place
the SQL caret again rather than replacing unrelated text. Inserted SQL is eligible
for Live; an inspection-only Document/KV cannot become a runnable FROM candidate.
The compact SQL caret popup shares the resolver and metadata but stays small;
it need not show every search-list metric.

No matches, Loading, More available, offline metadata and authorization failure
are distinct. Show only authorized match coverage: a bounded page is not a total
count, and no hidden count leaks through an empty result. Names can arrive before
metrics with Pending placeholders. Late metric responses must match search/scope
generation and row identity/basis; they cannot repopulate a cleared or revoked row.
Keep authorized but aged observations visibly stale; expired authorization hides
them under the disclosure rules below.

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

## Result layout and column profiles

Make returned rows the main result view. The compact toolbar contains Rows/Chart,
counts, a short result state, Details and the Profile toggle. Remove the prominent
speculative title and source/candidate metadata line, plus the duplicate SQL
block and separate Summary tab. Exact statement, source/schema revisions,
candidate/draft identity, verified completion and observation evidence are
available in **Details**. A small **Preview** indicator has a focus/click description
that it answers a predicted completion; Earlier draft and Following remain
distinct. Detailed provenance is not repeated in the grid or profile headings.

The right **Profile** panel starts at the result split, leaving the SQL editor
full width. It opens by default for the first available result on a wide display.
Each visible column has its name/type, distinct-value cardinality, null count,
min/max and a compact distribution. Numeric columns use labelled histograms;
later categorical types can use bounded top-value bars and an Other bucket.
Row count belongs to the result; **Distinct** means non-null column cardinality,
with nulls shown separately. A dataset with six rows need not have six distinct
values. Never substitute source-resource cardinality for either metric.

**×** closes the panel and expands the rows to full width; **Profile** reopens it.
Keep this choice for the worksheet session so each live result does not reopen
a panel the user closed. Preserve column selection, row scroll and editor focus;
closing returns focus to the Profile toggle if focus was inside the panel.
On narrow screens open the same panel over the result region on demand, with a
labelled close control and keyboard focus management, without shrinking SQL.
No persistent browser storage is introduced for layout preferences.

Selecting a column in the grid can reveal its profile; selecting it in the panel
shows more distribution detail in that same panel. Wide results use a bounded
visible column window, with a selected column kept reachable. Every plot has
equivalent text, units, bucket boundaries and exact/estimated coverage. Charts
show counts, not unlabeled decorative sparklines. Selecting a bin or copying a
min/max value does not secretly filter or rerun SQL; only an explicit editor edit
enters the Live scheduler.

Panel open/close, column selection and local profiling only read the already
authorized loaded result. They do not rerun the SQL, prepare another query or
fetch every page. A closed panel can stop local profile work; reopening reuses
or recomputes bounded statistics for the same result/frontier under current
authorization. A result change invalidates old profiles. If computation lags,
show Updating rather than pairing old statistics with new rows.

Figure 1's six-row result and Figure 3's three-row result fit completely in one
loaded page, so the panel says **All 6 returned rows** or **All 3 returned rows**.
For a partial page, keep **Loaded page: N of M returned rows** visible even when
Details is closed; per-column coverage overrides it if different. A stream panel
instead names the current frontier, and every displayed statistic describes that
same relation. [The study fixture](d4-fixture.json) records the illustrated
histogram bins, cardinality and panel actions; it does not implement profiling.

## Summary semantics

Each finite snapshot view is bound to the frozen executed text, correlation/result ID,
source identity/revision and verified manifest. Column labels and types come
from the result schema, which may differ from source columns after an aggregate.
Before verified completion, show status/progress, not apparently final rows or
profiles. Speculative snapshots additionally bind their candidate and parent
draft, disclosed in Details; they can be verified answers to that candidate
without answering current text. Stream views instead require the committed-frontier contract in the live
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
| Distinct cardinality | Non-null distinct values in the named coverage, exact only within the declared set budget; estimates carry their method/precision |
| Distribution | Fixed bounded bins/top values over the same coverage; labels define intervals, counts and null treatment |
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
false, missing and unavailable. Null counts/ranges need bounded accumulators.
For loaded-page histograms, a bounded pass finds min/max and a second pass over
that same resident page fills fixed bins; no source scan is needed. Compute bin
edges without int64 overflow or lossy Number conversions. The figures use three
inclusive integer ranges per column; counts sum to its non-null count, and labels
state the ranges. Uniform values use one bin, not division by a zero range.
Empty/all-null columns have zero distinct values and no non-null distribution;
their min/max are unavailable. Never draw an apparently measured zero range.

Exact distinct counting uses a bounded set, not an ever-growing result cache.
At its byte/entry budget, return Unavailable or use a separately qualified sketch
with visible estimate/error semantics; never silently truncate the set. Choose
and measure those budgets before implementation acceptance. Whole-result and
stream profiles need their own bounded execution/state contract; insertion-only
sketches cannot qualify an update/delete stream. Defer sum/mean until their
overflow, precision and empty-input rules are specified. Document/KV profiles wait for
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
For resource search, additionally cover delayed metrics without list reordering,
empty versus unavailable measurements, exact versus estimated cardinality,
framework-entry versus logical-row counts, truncated schema previews, bounded
continuations, narrow layouts and stale captured SQL insertion positions. Search
input and Details must leave the worksheet draft/generation unchanged; only the
explicit Insert name action enters live scheduling. The search fixture records
these expectations, not an implemented interaction test.

Compare summaries with independent typed computations on empty/all-null, large
int64, multi-page and retried-page fixtures. Prove that page profiles cannot be
labelled whole-result profiles and that changed drafts retain the earlier result
identity. Measure the response budgets above while those operations are active.
Include repeated values distinct from row counts, bin-edge values, uniform data,
exact-set exhaustion, stale profile completion, streamed deletes of a min/max,
panel close/reopen without queries, and focus/scroll preservation. Plot counts
must agree with their text alternatives and the identified coverage.
These are planned proofs; D4 only supplies static examples and design checks.
