# Live Explore: predictive execution and changing results

[D4 review](D4.md#live-execution-snapshot-and-stream) · [Console notes](CONSOLE.md)

Supporting design for the in-place **D4 live refinement**, not a new review or
implemented protocol. The reviewer selected Figure 1 and asked for execution
while typing, potentially every keystroke, with probabilistic scheduling and a
streaming/snapshot distinction. This replaces D4's initial Run-only policy.

## Two independent dimensions

Live is a visible worksheet session that automatically schedules eligible reads.
Paused stops new scheduling and requests the qualified stop of existing work;
it does not claim immediate cancellation, rollback or retention of the displayed
data. Local text assistance continues. Opening an eligible worksheet can start
its provisioned live session without a per-query confirmation. Scope, grants,
cost limits and lifecycle still need a public contract. Do not add a modal
approval for each edit.

Snapshot produces an immutable answer for one complete candidate and captured
source basis. Editing schedules another answer. A source update alone does not
mutate an accepted snapshot; explicit Refresh selects a new basis. A separate
periodic-refresh mode could be designed later, but polling snapshots must not
be labelled continuous streaming.

Stream evaluates one query generation over an initial snapshot and subsequent
committed changes. Source progress changes its current relation even with no
typing. An edit proposes a different query generation and a new snapshot/tail
handoff unless a qualified incremental rebind proves reuse. A finite Arrow
delivery stream does not supply any of these continuous-query semantics.

The mode is part of the query specification and identity shared with typed APIs
and future textual surfaces. D4 does not invent runnable SUBSCRIBE, AS OF or
window syntax. Selecting Stream must require an advertised source/operator
profile and a new qualified request; current M13 exposes neither.

## Scheduling is the probabilistic problem

Every edit advances a document version. Analyze the statement and a bounded set
of grammar-consistent candidates. Exact valid text is the primary candidate;
an incomplete source name, literal or predicate can also support predictions.
Each executed prediction must itself be a complete, compiled, authorized query.
Probabilistic recovery may not turn a malformed prefix into an allegedly exact
query, insert text without acceptance or guess a credential/hidden object.

Estimate **the probability that a candidate will still be useful when its result
arrives**, given edit cadence, syntax position, candidate ambiguity, expected
execution time and known plan/source cost. Compare actions: run now, briefly
wait/coalesce, reuse a qualified computation, cancel/supersede, or abstain from
speculation. A useful experimental objective is:

```text
expected value = P(useful at arrival) × normalized latency benefit
                 − weighted compute, capture/storage, I/O and visual-churn costs
```

The terms need measured, comparable units or explicit normalization. Weights are
deployment policy, not kernel truth. Begin with an interpretable heuristic baseline
and replay synthetic edit traces; compare any learned predictor against immediate
execution and fixed debounce. No model, training pipeline, confidence threshold
or latency saving is established by this proposal. Probability scores describe
intent/usefulness, never accuracy of returned row values or permission to read.

There is no mandatory idle interval. Low-cost valid edits may execute on every
keypress. A rapid sequence `id >= 1`, `id >= 10`, `id >= 104` consists of three
valid queries whose cost/usefulness differs. Removing a restrictive predicate
can increase cost sharply; budget evaluation must use the candidate plan, not
merely text length. A stable valid draft receives exact work ahead of speculative
candidates when admission becomes available. Low confidence must not indefinitely
prevent an ordinary query from running. Paused or budget-blocked state is visible.

Comments, whitespace and equivalent text may reuse an answer only after shared
semantic comparison and source/schema/authority validation. Do not implement
ad-hoc textual plan equivalence or new optimizer rewrites in the browser.
Prediction is optional per edit: “Waiting for a predicate” is more useful than a
misleading answer. Correctness and resource bounds are deterministic constraints
around the probabilistic policy.

## What the result means

| Label | Required evidence |
| --- | --- |
| Complete (current draft) | Exact current compiled semantics, mode and basis available in Query info |
| Preview (speculative) | Complete candidate SQL, candidate ID, parent draft and exact result basis in Query info; the compact indicator explains that this is not the answer to unresolved text |
| Earlier draft | Executed text/generation and original basis, clearly distinct from current text |
| Updating | A newer eligible generation is being evaluated; the older view retains its label |
| Following | Continuous generation with a committed frontier and explicit initial-snapshot/delta coverage |
| Paused / gap / unavailable | Last permitted basis and reason; never a fabricated fresh or empty answer |

Figure 1's `FROM sam` can speculate on `FROM samples` if that disclosed candidate
is useful. Its result covers all six fixture rows; no LIMIT is silently appended.
If the user accepts the completion, the candidate may become current only when
the semantics, mode, source/schema basis and current authority match. Promotion
does not retimestamp a snapshot to “now”; preserve its original basis in Query info.
The result toolbar carries only the short state; counts live in Profile.
Source/candidate IDs and executed SQL are details on demand. The Profile panel summarizes the same
identified answer as the rows. Closing it changes layout, not execution, and
never removes the toolbar's Preview/Earlier draft/Following distinction.

Each evaluation requires session/epoch, document version, exact/candidate
fingerprint, mode, source/schema and policy context, and its own admitted query
identity. A continuous answer additionally carries subscription generation and
committed source frontier. This is required contract information, not an API
schema added by D4. Predicted query confidence, sampled-data confidence and
stream completeness are separate concepts.

A late response may be valid for its original evaluation while being unusable
as the current worksheet answer. Route it to its own outcome record; never let
it replace a newer generation. Do not merge rows or profiles from different
drafts or source revisions. Stable row keys, a bounded render cadence and an
immediately available Pause control reduce visual churn; text feedback remains
responsive even if result painting is coalesced. Coalescing rendered states must
not silently drop changes needed to maintain the underlying relation.

## Admission, budgets and recovery

Only allowlisted read-only source/operator plans may run automatically. SQL SELECT
can still trigger effects through an unqualified source or function, so the plan's
capability contract supplies the decision. No inferred live scope permits DDL,
DML, grants, sinks, credentials, remote probes or uncaptured connector fetches.
Query execution itself records durable work/capture; “read-only” does not mean
free, ephemeral or authorized by Board's inspection identity.

The [current query profile](../../../contracts/PUBLIC_QUERY_V1.md) admits one
active query per configured principal, shared across viewers. Transport requests
beyond it can create durable busy outcomes/backlog; flooding that path per key
is not the scheduler. An initial adapter must gate before submitting and retain
one latest **unsubmitted** request while active work finishes or is explicitly
cancelled. The new session service needs fair arbitration across visible viewers
and worksheets; additional requesters must not bypass shared admission.

Proposed starting bounds for experimentation:

- One admitted evaluation/subscription per existing principal, one latest pending
  draft, at most three locally considered candidates and one executed candidate
  at a time. Larger concurrency needs a new qualified profile.
- Deployments must specify maximum admitted starts per interval, compute/scan/I/O
  budgets, retained capture bytes, result-page delivery and active-session limits.
  Compare configurations in benchmarks before choosing defaults. Initial unknown
  cost uses a conservative cap; exhausted quotas pause scheduling, not retention.
- Prioritize exact stable drafts over speculation. No-op edits need not resubmit.
  A newer unsubmitted draft can replace an older pending draft; **accepted** work
  must still reach an observable outcome and retain required recovery evidence.
- Suspend live scheduling/following when the worksheet is hidden or the scope
  changes. Stop renewal of a future session lease and request explicit cancellation
  or unsubscribe; disconnect is not proof that admitted work stopped. Define
  server-side budget/lease expiry so abandoned browser sessions cannot run forever.

Leases bound execution authorization/admission, not data lifetime. Unlimited
retention remains the default; automatic query transcripts/results cannot simply
be discarded because another key was pressed. A deployment can explicitly opt
into an appropriate live-session retention policy under existing lifetime rules.
Account for retained outputs and control evidence in the cost model. If the
current per-query durability cost is too high, design and qualify a session-level
capture protocol; do not bypass recorded intents with an undocumented read path.

Cancellation or replacement may lose its acknowledgement. Retain the original
frozen operation and reconcile it; do not create a new sequence or retarget a
retry to the new draft. Current M13 cannot admit a replacement merely because
the browser no longer displays the old query. Resume from accepted identities,
recheck scope, and preserve outcomes across client loss. Denial/expiry still
clears protected state; a probability estimate cannot override that decision.

## Continuous source and operator semantics

Start with a snapshot and tail joined at a defined source position, with no
omitted or double-applied update at the boundary. Define initial completeness,
insert/update/delete or retraction messages, ordering/deduplication, atomic
transaction barriers and progress even when no rows change. The UI advances the
displayed frontier only after a whole committed cut is applied. Multiple sources
need their own consistency model; one timestamp cannot invent a shared snapshot.

Document an explicit gap/resnapshot transition when a resume point is reclaimed.
Do not continue a stale stream with an apparently current label or silently switch
to periodic SELECT. Changing SQL creates a new generation; a replacement handshake
must identify the old/new frontiers and whether there is a gap. Until the new
generation has a complete initial cut, an old result stays labelled Earlier draft.
The initial one-active adapter may have to stop the old query before starting the
new one; seamless overlapping subscriptions are not an existing capability.

COUNT, SUM, extrema and LIMIT need update/delete semantics, bounded operator state
and recovery proofs. Figure 5 treats LIMIT 3 as the current first three matching
rows in the profile's primary-key order, not “stop after three change events.”
Deleting a selected row requires filling its place; a value update must retract
the old contribution. This is proposed continuous semantics, not proved behavior
from the finite engine. Event-time windows and watermarks require an additional
contract and are not implied by following committed Table changes.

A stream summary describes the current relation **through a named frontier**,
with exact totals only where the operator supplies them. A loaded page remains
a loaded page. Row count is not total events observed; null/range profiles must
reflect replacements/deletions. Min/max can require a rescan or retained index
when a contributing row disappears; no unbounded browser map is allowed. Publish
bounded backend state/profiles where needed, and show unknown or partial coverage
until the frontier's summary is consistent. Preserve int64 values exactly.
Cardinality, histograms, nulls and min/max in the right panel must account for
retractions as well as inserts. Advance rows and their profiles at one published
frontier, or show profiles as Updating/unavailable; an old profile cannot be
labelled as describing newer rows. A closed panel does not retain a second stream
or accumulate an unbounded history of profile states.

Holding the visible view pauses live work and preserves its displayed basis only
while access and retention allow it. It does not pin storage. Exporting/freezing
a retained snapshot from a stream needs its own capture operation; D4 supplies
no implicit historical read or SQL AS OF support.

[Fuze](../../FUZE.md#durable-materialization-and-future-scope) and
[Tables](../../TABLES.md#materialization-from-durable-streams) already identify
these missing primitives. Materialize's [SUBSCRIBE documentation](https://materialize.com/docs/sql/subscribe/)
provides a concrete design reference for an initial snapshot followed by positive/
negative row changes and explicit progress. This is a reference for the distinction, not
a selected dependency or a claim that Transit implements SUBSCRIBE.

## Evidence to require

The [live fixture](d4-live-fixture.json) records synthetic edit/result races,
candidate promotion, paused behavior and snapshot-to-stream data changes. It is
an expected-outcome study, not an executable scheduler or stream proof.

Future tests must cover per-key valid edits, invalid predicates, ambiguous source
names, composition/paste/undo, expensive broadening, resource exhaustion, two
viewers sharing a principal, unknown submissions, revocation, stale responses,
pause/hide and resumption. Compare recomputation with incremental answers after
inserts/updates/deletes and at snapshot/tail and query-replacement boundaries.
Include duplicates, reordered delivery, gaps, worker loss and retained results.

Measure input-to-first-useful-preview and input-to-exact-answer separately from
the existing 50 ms warm-completion target. Compare immediate, fixed-debounce and
predictive policies on declared hardware, costs and workload traces. Report p95/
p99 latency, stable-draft delay, useful speculation rate, wasted execution,
cancellation/recovery cost, retained bytes, starvation and view churn. Calibration
and out-of-distribution behavior matter if probabilities are used. There is no
claimed execution-latency target or proven predictor in this review.
