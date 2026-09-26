# Python SDK API design

Status: proposed M11 API, not an implemented package interface. Read the
[shared design](../SDK.md) for authority, lifecycle and recovery rules. The
[current Python adapter](../../packages/python/transit-station/README.md) remains
the executable M9 surface. Examples here are design excerpts: `counter_contract`
denotes the application models, codecs and typed keys still to be implemented
from shared fixtures; configuration and durable storage come from the application.

## Packages and types

`transit-client` exports `transit_client`: raw clients, explicit credentials,
references, operations and errors. `transit-station` exports `transit_station`:
handlers, runners, message framing, Tables and durable calls, depending on the
client package. Keep the existing `GenServer` and low-level `Client` imports
compatible; also expose them under `transit_station.raw`. Generated declarations
stay private. Optional Arrow integration is a separate install extra.

Use frozen dataclasses for references, receipts and input metadata. Constructors
validate runtime values, including calls from untyped Python. Protocol counters
use validated `int`; u64 application values and correlations use full-width `int`,
rejecting booleans, negatives and overflow. Owned payloads/exports/IPC use `bytes`;
copy mutable buffer inputs before native work can outlive them. Diagnostics must
not render payloads, credentials or retry exports by default.

Selected public signatures, with support types defined by the shared design:

```python
class Codec[T](Protocol):
    type_id: str
    version: int
    max_encoded_bytes: int
    def encode(self, value: T) -> bytes: ...
    def decode(self, data: bytes) -> T: ...

class State:
    def find[T](self, key: Key[T]) -> Found[T] | None: ...
    def require[T](self, key: Key[T]) -> T: ...
    def put[T](self, key: Key[T], value: T) -> None: ...
    def delete[T](self, key: Key[T]) -> None: ...
    def page(self, cursor: StateCursor | None = None) -> Page[KVEntry]: ...

class Handler[M](Protocol):
    def initialize(self, turn: Turn) -> None: ...
    def handle(self, turn: Turn, incoming: Incoming[M]) -> None: ...

class Turn:
    state: State
    def cast[M](self, peer: ProcessRef, value: M, *, codec: Codec[M]) -> None: ...
    def call[M](self, peer: ProcessRef, value: M, *, codec: Codec[M],
                wait: WaitPolicy) -> int: ...
    def reply[M](self, value: M, *, codec: Codec[M]) -> None: ...
    def require_reply[M](self, reply: Reply[M], *, peer: ProcessRef,
                         correlation: int) -> None: ...
    def cancel_call(self, correlation: int) -> bool: ...
```

`Incoming[M]` is `Cast[M] | Call[M] | Reply[M]`, with immutable native-validated
position/origin metadata and a decoded `value`. Replies also expose correlation.
`Key[T]` contains immutable key bytes and its codec. `find` distinguishes missing
from `Found(value=None)`; `require` raises `MissingValue`. `Turn` and every helper
check an active scope token and reject overlap or use after return. Catching a
native read error cannot remove the proposal's poisoned state.

## Equivalent service and requester

`TOTAL`, `REQUEST` and `OBSERVED` below are `Key[int]`; `U64.checked_add` validates
both operands and reports overflow. Message codecs implement `counter`, version 1.

```python
class Counter:
    def initialize(self, turn: Turn) -> None:
        turn.state.put(TOTAL, 0)

    def handle(self, turn: Turn, incoming: Incoming[Add | Read]) -> None:
        if isinstance(incoming, Cast) and isinstance(incoming.value, Add):
            total = U64.checked_add(turn.state.require(TOTAL), incoming.value.value)
            turn.state.put(TOTAL, total)
        elif isinstance(incoming, Call) and isinstance(incoming.value, Read):
            turn.reply(Total(turn.state.require(TOTAL)), codec=total_codec)
        else:
            raise HandlerError("UnexpectedMessage")


class Requester:
    def __init__(self, counter: ProcessRef) -> None:
        self.counter = counter  # Configuration, never a pending future.

    def initialize(self, turn: Turn) -> None:
        pass

    def handle(self, turn: Turn, incoming: Incoming[Start | Total]) -> None:
        if isinstance(incoming, Cast) and isinstance(incoming.value, Start):
            if turn.state.find(REQUEST) is not None:
                raise HandlerError("AlreadyStarted")
            correlation = turn.call(self.counter, Read(), codec=counter_codec,
                                    wait=WaitPolicy.untimed())
            turn.state.put(REQUEST, correlation)
        elif isinstance(incoming, Reply) and isinstance(incoming.value, Total):
            turn.require_reply(incoming, peer=self.counter,
                               correlation=turn.state.require(REQUEST))
            turn.state.put(OBSERVED, incoming.value.value)
        else:
            raise HandlerError("UnexpectedMessage")
```

The first requester turn commits its descriptor, wait, correlation and outgoing
call together. The reply turn commits wait closure and `OBSERVED` together.
Run it again in a fresh host with a fresh activation and the same configured
peer: no Python object needs to survive. This example selects unlimited lifetimes;
finite callers must supply a deadline and timer observer through `WaitPolicy`.

## Runners and async ownership

`Runner.open(config, handler=..., codec=..., failure_policy=..., recovery=...)`
returns a synchronous context manager. Its `run(stop=StopToken)` iterator yields
`Committed`, `Blocked` or `NeedsRecovery`. `AsyncRunner.open` is an asynchronous
context manager exposing the same events through an async iterator:

```python
async with AsyncRunner.open(
    service_config,
    handler=Counter(), codec=counter_codec,
    failure_policy=FailurePolicy.BLOCK_INPUT,
    recovery=Recovery.persist_before_dispatch(store),
) as runner:
    async for event in runner.run(stop=stop):
        if isinstance(event, Committed):
            observe_commit(event.input_position, event.receipt.position)
        elif isinstance(event, Blocked):
            report_blocked(event.input_position, event.receipt)
        elif isinstance(event, NeedsRecovery):
            report_pending_identity(event.identity)  # Do not log retry bytes.
```

Run `Requester(counter_ref)` with `requester_codec` and its own activation using
the same runner interface. No manual poll/finish or application JSON actions are
part of either role. `reconcile()` performs one explicit attempt for pending
native work and preserves its phase; it never reinvokes the completed handler.

Both runner forms own one bounded worker executing synchronous handler bodies
and native calls, using at least the generated 8 MiB native stack requirement.
The async API bridges completions to the event loop without a process-wide
unbounded executor queue. Native handles retain their separately bounded I/O
workers. Overlapping operations fail with `Busy`; separate runners require
explicit application capacity and shared-principal coordination.

The first handler protocol is synchronous even under `AsyncRunner`; a coroutine
handler is rejected instead of being silently left unawaited. Native reads occur
on that worker. Do not capture the event-loop-bound runner in a handler or start
background tasks using its turn. A future async-handler adapter needs a separate
bounded scheduling proof. Codec/handler CPU work and the selected Python runtime
also need responsiveness measurements; a worker is not an arbitrary-code latency
guarantee.

Cancelling the outer await requests local stop, retains any frozen mutation and
joins owned work during `aclose`/context exit. Synchronous close must not run on
the event loop. Unsent private work is discarded when stop is observed; sent work
is never inferred rejected. Noncooperative handler code can delay shutdown.
Exceptions/unwinding and finalizers never call successful `finish` implicitly.

## Raw send and restart recovery

`Client`/`AsyncClient` provide `prepare_send(peer, data, credential=..., sequence=...)`,
`recover_send(bytes)`, `dispatch(pending)` and explicit close/context management.
Sync calls run on their bounded owned worker; async counterparts await the same
ownership model. `PendingSend.export()` returns independent opaque bytes and the
operation itself is closeable. Credentials include explicit realm/principal;
the sequence is supplied by the application's sequencer, not guessed by a helper.

```python
with Client.open(client_config) as client:
    with client.prepare_send(requester_ref, encoded_start,
                             credential=credential, sequence=sequence) as pending:
        outbox.save(pending.identity, pending.export())  # Durable before dispatch.
        receipt = client.dispatch(pending)
        outbox.confirm(pending.identity, receipt)  # Record before deleting pending.

# In a new host, after an unknown result or a crash:
with Client.open(client_config) as client:
    with client.recover_send(outbox.load(operation_id)) as pending:
        receipt = client.dispatch(pending)  # Same signed request; no seed needed.
        outbox.confirm(pending.identity, receipt)
```

`encoded_start` comes from Station's shared `encode_cast(Start(), requester_codec)`;
raw Transit itself has no Station dependency. `outbox` is application-owned
durable pending-operation storage, not a second authoritative mailbox. If dispatch
raises, the saved entry remains. `UncertainOperation` carries owned recovery
material and attempt phase. `AuthorityRejected` retains the exact authority code;
subclasses/categories expose denial, stale ownership and retirement without
erasing that code. A revoked recovery attempt leaves the earlier uncertainty
unresolved. `ReadFailed`, `IncompatibleNative`, `UnsupportedCapability`, `Busy`,
`Closed`, `TurnExpired`, `CodecError` and `MissingValue` remain distinct failures.

The runner store protocol has synchronous `before_dispatch(FrozenMutation)` and
`confirmed(OperationIdentity, MutationReceipt)` callbacks executed on its worker.
Both may fail. Hook failure never permits dispatch; confirmation failure surfaces
the known receipt and saved operation without rerunning the handler. Applications
implement durable storage and loading; the SDK performs no hidden filesystem work.

## Data, packaging and acceptance

`turn.table(schema)` returns a scoped `Table[Row]` with point operations and
`page(cursor) -> Page[Row]`. `turn.retain()`, `open_version(id)` and `release(id)`
use native retained sources; only IDs/exported cursors survive the scope. A
query-enabled turn's result reader exposes owned complete-manifest metadata and
`segment(ordinal) -> IpcSegment`, whose `ipc: bytes` survives disposal. Source and
reader handles do not. Optional PyArrow decoding consumes those owned bytes;
it cannot replace complete-result or current-access checks.

Build wheels with type information and a version-matched native artifact dependency
for Linux x86_64. Resolve installed artifacts by package metadata; an explicit
native-directory override is supported. Reject missing symbols, ABI/capability
mismatches and unsupported platforms with actionable errors before dispatch.
No `PYTHONPATH` or manually assembled loader path in the clean-consumer example.
Registry publication is outside M11; artifact construction/install proof is not.

Before calling this implemented: type-check the examples, run shared codec and
failure scenarios, prove context cleanup and loop responsiveness during native
I/O/handler work, reject escaped turns and concurrent calls, and install/run both
roles from wheels outside this checkout. Existing adapter tests do not establish
those public SDK claims.
