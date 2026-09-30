# Serving, reactive views and Board

This account explains how network and visual interfaces preserve the underlying
execution model. It consolidates serving, reactive and Board reasoning. Usage
belongs to the [serving](../reference/serving.md), [reactive](../reference/reactive.md),
[application](../reference/applications.md) and [Board](../guides/inspect-board.md) references.

## Model and trust boundary

A gateway adapts an inbound protocol to public Transit operations. A service has
durable identity and policy; a socket is a temporary attachment. A durable command
has an admission identity and an application outcome. A status read is a bounded
observation. These objects have different lifetimes and evidence requirements.

Caller authentication and current native/service/source authorization remain
separate from TLS, Host/Origin checks and the gateway's own credentials. A stronger
gateway credential cannot substitute for a caller's missing access. Board's
private deployment boundary admits viewers to a shared configured scope, while
its upstream identity still needs a read-only grant; it is not a per-viewer
authentication system.

## Admission and observation

A connection can fail after a command was admitted. The HTTP response therefore
cannot be the sole recovery identity. Preserve the original command and reconcile
its recorded outcome. Socket deadlines stop observation work but do not undo
accepted commands. Once a streaming response has begun, failure is interruption,
not a second success/error object appended as if the stream were complete.

Bounded concurrency, chunks and joined cancellation protect ownership when a
peer stalls. Protected disclosure must recheck current policy, including on later
pages or attachments. Transport liveness establishes neither durable application
progress nor a complete answer.

## Reactive consistency

The implemented reactive profile combines int64 Table notifications with exact
finite snapshot refresh. It does not supply every intermediate revision or
continuous SQL. The snapshot/watch handoff must bind compatible source evidence;
reading latest state and subscribing later leaves a change window.

A refresh generation fixes its submitted plan/schema/source. Each refresh obtains
its own finite query identity and verifies complete ordered results before
replacing displayed rows and summaries together. While it runs, a bounded pending
invalidation can record further dirty progress. A late response cannot replace a
newer generation, and insufficient retained coverage requires reset or interruption.

This makes freshness explicit rather than equating the latest arriving packet
with truth. On denial, protected displayed and candidate state are cleared.
Temporary unavailability cannot be rendered as a successful empty result.

## Declarations and controls

SQL declarations, visual editors and generated modules use the same typed model
and owning validation. Parsing or editing a definition is not publication,
administration or external dispatch. Conditional activation applies a reviewed
definition; data migration has its own owner, ledger and acceptance boundary.
Installing compatible code, publishing an interface and activating a data epoch
are independent operations.

An alternate UI configuration database would create a second semantic authority.
Sharing contracts avoids that divergence but requires interfaces to display
definitions, proposed changes and observed state distinctly.

## Evidence and limits

The [serving contract](../../contracts/SERVING_V1.md),
[reactive contract](../../contracts/REACTIVE_V1.md) and
[application definition contract](../../contracts/APPLICATION_V1.md) define the
boundary. [Serving](../../tests/README.md#m19-qualification),
[reactive API](../../tests/README.md#m20-qualification) and
[refresh evidence](../../tests/README.md#m21-qualification) supply commands,
fault schedules and qualified source/deployment combinations.

The evidence does not establish arbitrary live queries, speculative execution
while editing or public per-user Board admission. Historical proposals remain in
the [serving](../history/SERVING.md), [reactive API](../history/REACTIVE_API.md),
[reactive interface](../history/REACTIVE.md),
[declarative application](../history/REACTIVE_APPLICATIONS.md) and
[Board](../history/BOARD.md) records. UI/UX review outcomes belong in
[Design](../design/README.md), where acceptance remains distinct from implementation.
