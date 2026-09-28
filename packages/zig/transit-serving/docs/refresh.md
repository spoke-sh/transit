# Durable finite refresh

M21 implementation in progress. `LiveService` composes `Service`, M20 sessions
and the v2 query requester in one Station owner/resource. Install its handler and
input guard together, initialize privately, and provision caller, worker and
resource grants before exposing ingress. Standalone `Service` rejects refreshes.
PID-scoped reads also require optional cross-resource associations installed
before activation; these confer no resource grant or lifetime ownership.
The initial profile is a published int64 Table, not a continuous SQL evaluator.

`follow` selects a completed, retained query and an open caller session. The
owner verifies its actual manifest/current policy and matches the captured
resource, Table contract and schema to the watch. It retains the submitted bundle
identity, never SQL draft text or a requested `AS OF` cut. Conditional previous
generation fences replacement; committed input position identifies the new view.

Each view has one latest dirty data revision and one covered capture revision.
Invalidation rereads the published marker; callers cannot supply watermarks.
Scheduling scans at most four live session slots in round-robin order. Only the
configured query principal participates: its two sessions share one finite-query
admission. Explicit manual work holds admission until completion without busy
query records or self-polling. Fairness is among eligible automatic views; an
unbounded stream of manual admissions has no automatic-service guarantee.

Each explicit follow generation permits one to eight refresh intents, with
1000 ms between its starts, measured by the authenticated M20 observer clock.
A start reserves a new namespace from the committed input's high-bit domain;
existing identities cannot be overwritten. `UnifiedUpload` copies one 256-byte
template chunk per turn, seals and submits. Selection, copying, admission,
completion and acknowledgment have separate turns within the four-write limit.
Namespaces are decimal JSON strings preserving all 64 bits.
An occupied automatic namespace fails only that view and advances selection;
it cannot stop ingress progress. Rejected query commands use the query client's
disposition records, including when rejection occurs during initialization.

Budget charges selection before copying, including failed copies, not successful
results. Two views may select sixteen intents for their explicit generations.
New follow generations deliberately grant new budgets. Accepted queries retain
their original lifetime policy; neither budget exhaustion nor display replacement
authorizes deletion. Closed view histories are durable point records, not resident
arrays. Copy cancellation uses bounded upload cleanup, retaining terminal status.

Selected work survives pause, socket closure and lease expiry. Those events stop
new selections without retracting committed intents. Before copy/admission the
owner rechecks service policy, native identity and both resource permissions.
Follow requires `resource_read_access` and records signatures over the native
identity query and source/requester `read_access` queries. Authority checks the
caller's current key, inspect/read grants, PID association scope and resource
lifetime on every use. Metadata-only permission is insufficient. These proofs cannot read
arbitrary entries or delegate execution. A conservative host wall-clock bound
prevents starts after expiry even when the observer stops. Infrastructure failure
leaves the proposal uncommitted; current denial closes scheduling distinctly.

Completion exposes a ready namespace. The consumer must verify the complete
result with bounded memory, then reread its visible page under current authority
before swapping rows/profiles. Acknowledgment rereads the actual result basis
and latest data marker. A mutation during capture remains dirty; query bookkeeping
does not change the marker. Replaced generations cannot acknowledge newer views.
Old accepted work resolves independently.

The opt-in private host adds `refresh_prepare` and `refresh_status`, preserving
frozen sends/committed dispositions. Only pause uses reserved control capacity.
Status remains readable after session closure under current caller/resource
authority without renewing the view or exposing rows.

Component tests use actual uploads/captures/manifests and reconstruct requester
state at each committed copy step. They cover fairness, capture-time mutation,
quiescence, manual admission, generation fencing, pause, denial, outage and expiry.
Native TLS/worker recovery uses `just test::reactive-refresh`. Browser rendering,
physical node/store recovery and placement freshness/cost measurements remain
separate M21 qualification gates.

Session open/attach/renew controls do not create query demand or unconditional
refresh wakeups. Query inputs and follow controls schedule separate refresh turns;
clock inputs can release recorded spacing after a scheduler exists. Thus an idle
metadata-only view does not pay for query wakeup/delivery cycles.
