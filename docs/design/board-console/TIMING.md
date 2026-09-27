# Time in the result surface

Status: **Proposed D4 design, not implemented or measured**. The figures use
synthetic timings. [D4](D4.md) owns the review and [LIVE](LIVE.md) owns scheduling,
candidate identity and streaming semantics. Existing APIs do not already supply
all the timing, progress or prediction evidence described here.

## One compact line, four useful questions

Replace the result toolbar's Earlier draft and Complete badges with:

`Run 18 ms · Ready 42 ms · As of ~0.8 s ago · Next ~35–55 ms`

The line describes the displayed result plus an explicitly estimated next answer.
Rows/Chart remain at the left, with one information icon after the timing line.
No new status row, card or footer is needed. The grey surface covers speculative
and retained answers that do not match the current draft; the information icon's
accessible description and Query info identify which statement they answer.
Query correctness still depends on verified result identity, not elapsed time.

| Visible measure | Question answered | Exact boundary and limits |
| --- | --- | --- |
| **Run** | How long did execution take? | Owning engine's measured execution-start to execution-finish interval for this result. State included phases; this is elapsed time, not summed CPU time or browser round-trip time |
| **Ready** | How quickly did I get something usable? | Browser monotonic time from this exact draft/candidate becoming eligible to presenting its first verified usable result page. Includes local scheduling/admission wait, execution, capture/delivery/verification and rendering; freezing the start prevents hiding waits |
| **As of** | How old is the data basis? | Age of the source read cut represented by the result, including a stated clock uncertainty. It is not time since the browser painted rows, last user edit, last source mutation or last HTTP response |
| **Next** | How quickly could a new answer be ready? | An estimated Ready-duration range if the currently eligible plan/candidate were evaluated under current conditions. It is conditional, not a countdown to the next source event, an admission promise or a deadline |

Show a compact unit on every value. Predictions use `~` and a range, with an
accessible estimate label. Hover/focus or activating the information icon reveals
phase boundaries, absolute read-basis time, clock uncertainty, result identity
and the prediction's target/basis. The existing Query info popover combines
these with exact executed SQL. Keep values aligned so changing digits do not
move controls or keyboard targets. On narrow layouts use one compact timing
control with the full breakdown on activation, rather than crowding the grid.

Grey does not mean slow, disabled or failed. An old exact snapshot can stay
white while its As of age grows; a very recent retained answer can be grey
because the SQL changed. Data age and draft relationship are independent. Query
info and accessible state describe the latter without restoring the removed
badges. Denied, failed, gap, unavailable-policy and paused conditions still need
their explicit actionable messages; a duration cannot replace them.

## Attribute observations to the right result

Bind measured durations to frozen SQL/candidate and draft generation, query and
result identity, source basis, mode and current authorization. A late completion
cannot attach its fast time to a newer draft or result. Keep the original Run
and Ready values when reusing a candidate. A fast reuse/paint can be shown
separately in Query info; do not reset the engine timing or read-basis age.

Use a monotonic clock for each elapsed interval in its owner. Separate server
execution, local queueing, network/delivery and browser rendering. Correlate
phase observations explicitly; do not subtract timestamps from unsynchronized
machines or add overlapping parallel spans into a fictitious total. An engine
duration is unavailable if its owner did not publish one. Ready can be known
independently; neither field substitutes for the other. A first result page is
not a whole-result download. Record total verified completion or last-page time
separately where the result protocol supports it.

Start Ready when an actual qualified candidate first becomes eligible, including
any scheduling hold for that candidate. Changing semantics starts a new candidate
interval; reusing one keeps its original interval and origin. Do not start an
execution timer for unresolved text that has no eligible candidate. Before a
result is usable, show a running wait/elapsed observation in the timing control;
do not display a predicted duration as if the work already ran. Retry/recovery
attempts keep their durable identity and disclosed timing scope.

As of needs a qualified timestamp for the immutable read cut, with its clock
domain and uncertainty, or a qualified source-reported age plus bounded transit
and local elapsed time. A revision counter alone is not a timestamp. Across
clock domains calculate an age interval, round to supported precision and
disclose uncertainty; never clamp a negative raw clock subtraction to “fresh”.
If this basis is unavailable, show **As of —** and explain why. Query info may
still show “received 0.8 s ago”, but must not rename that observation data age.
For multiple sources, show conservative coverage only when every required source
has comparable evidence, and expose per-source bounds; otherwise mark mixed or
unknown freshness rather than borrowing the newest source's time.

The displayed age advances locally from its recorded basis without running
another query. Use a bounded refresh cadence and coarse precision as age grows;
do not announce every tick to a screen reader. On resume from a hidden tab,
recheck authorization and progress before presenting a current view. Source data
may still be the latest even when a snapshot is old; “As of” makes no claim that
a newer value exists. It also says nothing about upstream business-event delay.

## Streaming uses update time and frontier lag

In Stream mode use the same space for:

`Update 6 ms · Ready 14 ms · Lag ~120 ms · Next ~35–55 ms`

Update is the measured incremental evaluation for the latest published frontier;
Ready measures that update from its qualified observation at the worksheet
boundary until the corresponding verified relation is painted. Keep initial
snapshot timings separately in Query info. Rows, profiles and these timings all
refer to the same committed frontier, including any coalesced frontier range.

Lag is time since the displayed frontier's source progress/coverage timestamp,
not time since the last changed row. Idle sources need heartbeat/progress
evidence to demonstrate coverage without inventing changes. Lost progress makes
lag grow or become unknown; a recent network response cannot reset it. Distinguish
source coverage lag from transport delivery latency and any future event-time
watermark lag. M13's finite result stream provides none of these continuous-query
guarantees by itself.

Next still predicts readiness of a new eligible query generation, including its
initial snapshot/rebind cost. It is not the expected arrival time of another
source event and is not calculated by simply copying the 6 ms update duration.
Query info names that target explicitly. For a plan edit that cannot yet resolve,
show **Next —**, with “No eligible statement yet” in its explanation. Paused,
budget-blocked or unavailable admission does not manufacture a completion ETA.

## Predict duration, and say what the prediction is for

Keep performance prediction separate from the scheduler's probability that a
candidate will be useful. One forecasts time; the other decides whether work is
worth attempting. Neither changes authorization, executable semantics, result
verification or retention. Opening timing details makes no new query.

Begin with a bounded empirical baseline using comparable authorized executions:
plan/operator shape, known input bounds, cache state, execution profile, mode,
observed load and queue/admission conditions. Source growth, changed selectivity,
a cold cache or a stream rebind can invalidate that comparison. Keep the model
and feature schema versioned and bind each forecast to candidate/plan, scope,
observation time and an expiry. No raw SQL, literals or row values enter telemetry.
Any cross-user aggregation needs its own privacy and disclosure contract.

Publish a calibrated prediction interval rather than a single precise-looking
number. This study illustrates a nominal 80% interval; its numbers are invented,
not a measured coverage claim. Qualification must report empirical coverage,
interval width and underprediction by workload, including cold/loaded cases.
A future learned cost model must beat the empirical baseline on held-out traces.
Report sample sufficiency and out-of-distribution behavior in diagnostics. With
insufficient evidence, show **Next —**; do not extrapolate from one lucky run.

Recompute a forecast when relevant plan/load evidence changes, within a bounded
UI and prediction budget. Expire stale forecasts. Once an execution is admitted,
an optional remaining-time estimate needs a separate elapsed-conditioned model;
do not subtract elapsed time from an unconditional duration percentile. The
toolbar's Next duration is not that remaining-time estimate. Unknown admission
delay must widen or suppress a Ready prediction rather than being omitted.

## Synthetic study and checks still required

[The timing fixture](d4-timing-fixture.json) uses one synthetic clock to make
arithmetic reviewable. The snapshot's disjoint illustrative phases are 6 ms
waiting, 7 ms transit/admission, 18 ms running, 6 ms capture/delivery/verification
and 5 ms painting: 42 ms to ready. Its source read cut is 800 ms old at the
illustrated viewing instant. The speculative and retained views share their
original 12 ms Run / 31 ms Ready and source basis; only viewing time and draft
context change. The stream illustrates a 6 ms update, 14 ms Ready and a 120 ms
coverage lag. No running system produced these observations or predictions.

Implementation must verify missing phases, overlapping spans, clock skew,
source-age bounds, delayed rendering, reused/late candidates, empty results,
partial pages, offline/paused streams and progress without changed rows. Test
prediction expiry and invalidation for plan changes, new data scale, load and
cache transitions, plus calibration on held-out workloads. Check accessible
descriptions without per-tick announcements and no query on timing inspection.
The public observation/prediction contract and execution tests belong to a new
qualified implementation scope under the [roadmap sequence](../../roadmap/README.md#maintaining-the-sequence).
