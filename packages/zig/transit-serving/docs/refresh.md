# Durable finite refresh

`LiveService` composes `Service`, reactive sessions
and the v1 query requester in one Station owner/resource. Install its handler and
input guard together, initialize privately, and provision caller, worker and
resource grants before exposing ingress. Standalone `Service` rejects refreshes.
The private reader must authenticate proofs for the requester, query worker and
direct Table audience. A credential restricted to one PID cannot inspect the
other audiences, even with additional resource grants. Configure an independent
inspection identity with the required native inspection and Table read privileges;
these checks remain separate from the original caller's privileges.
PID-scoped reads also require optional cross-resource associations installed
before activation; these confer no resource grant or lifetime ownership.
The source is a published catalog Table with two INT64 columns and a primary
key on the first. The scheduler checks caller database/schema/Table read privileges as
well as native and service authority. Its read-only direct observation uses the logical `changed_lsn` watermark.
Admission alone and no-op writes leave it unchanged; rows and their changed
watermark publish together. The accepted partition position remains separate.

`follow` selects a completed, retained query and an open caller session. The
owner verifies its actual manifest/current policy and matches the captured
resource, Table contract and schema to the watch. It retains the submitted bundle
identity. The caller also supplies one to eight distinct prepared query
namespaces. Each holds the same source, plan, budgets and route, with its own
caller-signed current-capture grant. Follow authenticates these against its
original accepted caller, role and credential epoch; it cannot renew signatures
or reuse the completed template’s pin. Conditional previous
generation fences replacement; committed input position identifies the new view.

Each view has one latest dirty logical-change position and one covered accepted
capture position in the same source partition. Invalidation rereads the direct
observation; callers cannot supply watermarks.
Scheduling scans at most four live session slots in round-robin order. Only the
configured query principal participates: its two sessions share one finite-query
admission. Explicit manual work holds admission until completion without busy
query records or self-polling. Fairness is among eligible automatic views; an
unbounded stream of manual admissions has no automatic-service guarantee.

Each explicit follow generation permits one to eight refresh intents, with
1000 ms between its starts, measured by the authenticated observer clock.
A start selects the next prepared identity. It first reclaims the requester’s
one active slot, then submits those exact immutable bytes in a separate turn.
The first direct acquisition freezes one current cut; an uncertain retry
recovers that cut. Selection, activation, admission, completion and acknowledgment
have separate turns within the four-write limit.
Namespaces are decimal JSON strings preserving all 64 bits.
An occupied automatic namespace fails only that view and advances selection;
it cannot stop ingress progress. Rejected query commands use the query client's
disposition records, including when rejection occurs during initialization.

Budget charges selection before activation, including failed selections, rather
than counting only successful results. Two views may select sixteen intents for their explicit generations.
New follow generations deliberately grant new budgets. Accepted queries retain
their original lifetime policy; neither budget exhaustion nor display replacement
authorizes deletion. Closed view histories are durable point records, not resident
arrays. Prepared-query cancellation uses bounded upload cleanup and retains terminal status.

Selected work survives pause, socket closure and lease expiry. Those events stop
new selections without retracting committed intents. Before activation/admission the
owner rechecks service policy and the original subject’s current source privileges.
Follow retains its original native admission reference. Native authority owns the
immutable principal, selected role and credential epoch for that input. Each
continuation authenticates it and checks database CONNECT, schema USAGE and Table
SELECT, then carries the same subject and requirements into the native publication
guard. The private reader checks source/requester lifecycle and acquires bytes;
it does not grant source privileges to the caller. Rotation or revocation stops
new selection and continuation. Restoring permission never rewrites a retained
stop record or substitutes a new identity for accepted work.

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

The [proof ledger](../../../../docs/history/qualification/README.md) distinguishes executed direct
observation, prepared-request and capture-recovery checks from Follow composition
and browser replacement. Historical actor-backed refresh results do not establish
the direct Table execution path.

Session open/attach/renew controls do not create query demand or unconditional
refresh wakeups. Query inputs and follow controls schedule separate refresh turns;
clock inputs can release recorded spacing after a scheduler exists. Thus an idle
metadata-only view does not pay for query wakeup/delivery cycles.

Each view retains its first scheduling stop as a finite reason, original committed
input and bounded witness. The record fits 255 bytes including the complete direct source
identity and maximum witness. Closing or expiring a session records its stop in the same turn,
before removing the active slot; it does not cancel selected work. Cancelled or
retired query uploads stop progress before separate bounded cleanup. Only actual
permission denial receives the denied phase; resource unavailability and query
execution errors remain distinct. A later query rejection has its own diagnostic
and does not replace an earlier pause or closure witness.

`refresh_status` returns the view, requester resource/revision, policy revision,
optional scheduler diagnostic and separate optional query diagnostic. Scheduler
outcome is `not_applicable`: it is not a claim about query completion. The query
diagnostic projects its retained status and original failure. Full-width query
namespaces remain decimal strings in witnesses and diagnostic facts. Lease stop
witnesses record the comparison clock, the maximum of the committed observer
sample and conservative host bound; recorded expiry and an observed deadline
remain distinct. Missing retained query evidence is explicit, never reconstructed
from a later source read.
Current caller database/schema/Table read privileges protect this status even when its
source has been renamed or dropped. The service reader's own identity cannot
substitute for those rights.

Reader diagnostics name the original failed check: the admitted subject, current
source privileges, source/requester writer or lifecycle, or template
phase and manifest presence. They include the observed policy or resource revision
when that check supplied one. A denied read identifies its operation and principal;
nested result reads retain the actual failing resource, which may differ from the
watched source. The original native cause survives the broader scheduling stop
classification. Restoring permission or replacing a template does not change this
evidence. Memory, transport and integrity failures leave the proposal unresolved.

The private caller discovers the selected namespace, then reads refresh head,
view and selected query status together in one bounded native cut (five keys
including configuration and policy). A changed namespace restarts this read,
with at most three attempts. It
then rechecks the fresh original-caller proof, source privileges and service policy
before disclosure. Receipt observation reads the caller-authorized process once
and performs one protected disposition read with its own before/after checks.
It does not rediscover the service twice per poll. These reductions preserve
authorization boundaries; they do not extend a lease or promise a latency bound.
