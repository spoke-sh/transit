# Rust SDK API design

Status: the independent [raw client](../../packages/rust/transit-client/README.md)
and [Station SDK](../../packages/rust/transit-station-sdk/README.md) implement the
contracts below. The [compiled examples](../../examples/station-sdk/rust/README.md)
own the executable counter/query applications and shared fixture codecs. Read the
[shared design](../SDK.md) for authority, lifecycle and recovery rules and the
[test guide](../../tests/README.md) for qualification. The
[existing Rust adapter](../../packages/rust/transit-station/README.md) retains its
M9 surface. Bootstrap configuration and durable recovery storage are application
inputs.

## Crates and ownership

`transit-client` exposes `transit_client` with typed raw operations, references,
receipts and errors. The separate `transit-station-sdk` crate depends on it
and exposes handler traits, scoped turns, Tables and runners. The M9
`transit-station` crate retains its low-level `Client`/`GenServer` entry points
and generated FFI without changing existing consumers. Generated FFI
stays private/raw; new public types must not mirror JSON action unions. Keep
Arrow integration behind an optional dependency/feature.

`ProcessRef` and `ResourceRef` are distinct structs holding validated realm/ID
newtypes. Protocol counters use checked `u64` newtypes with the generated public
bound; application values use `u64`/`i64`, and `Correlation` preserves a nonzero
u64. Byte payloads and exports use owned `Vec<u8>` or `Box<[u8]>`. Preparation
copies borrowed input before returning; buffers cannot borrow a transient FFI
response. Secret and payload types do not expose contents through default `Debug`.

Selected public declarations (abbreviated):

```rust
pub trait Codec<T>: Send + Sync + 'static {
    fn type_id(&self) -> &str;
    fn version(&self) -> u32;
    fn max_encoded_bytes(&self) -> usize;
    fn encode(&self, value: &T) -> Result<Vec<u8>>;
    fn decode(&self, bytes: &[u8]) -> Result<T>;
}

pub trait Handler<M>: Send + 'static {
    fn initialize(&mut self, turn: &mut Turn<'_>) -> Result<()>;
    fn handle(&mut self, turn: &mut Turn<'_>, input: Incoming<M>) -> Result<()>;
}

impl State<'_> {
    pub fn find<T>(&mut self, key: &Key<T>) -> Result<Option<Found<T>>>;
    pub fn require<T>(&mut self, key: &Key<T>) -> Result<T>;
    pub fn put<T>(&mut self, key: &Key<T>, value: &T) -> Result<()>;
    pub fn delete<T>(&mut self, key: &Key<T>) -> Result<()>;
    pub fn page(&mut self, cursor: Option<&Cursor>) -> Result<Page<KvEntry>>;
}

impl Turn<'_> {
    pub fn state(&mut self) -> State<'_>;
    pub fn cast<M>(&mut self, peer: ProcessRef, value: &M, codec: &impl Codec<M>) -> Result<()>;
    pub fn call<M>(&mut self, peer: ProcessRef, value: &M, codec: &impl Codec<M>,
                   wait: WaitPolicy) -> Result<Correlation>;
    pub fn reply<M>(&mut self, value: &M, codec: &impl Codec<M>) -> Result<()>;
    pub fn require_reply<M>(&self, reply: &Reply<M>, peer: ProcessRef,
                            correlation: Correlation) -> Result<()>;
    pub fn cancel_call(&mut self, correlation: Correlation) -> Result<bool>;
}
```

The `impl` blocks show signatures, not compilable method definitions. `Key<T>`
owns immutable key bytes and a codec; `Found<T>` preserves present nullable values
inside `Option`. `Incoming<T>` is an enum with `Cast`, `Call` and `Reply` variants
carrying native-authenticated metadata and a decoded message. `Reply<T>` contains
its value and correlation; user payloads cannot supply that provenance.

Turn and helper lifetimes borrow the active proposal, with no owned/clone escape.
They are neither `Send` nor `Sync`; mutation uses exclusive borrows. Runtime scope
checks still protect the FFI boundary. Native read poisoning persists after a
handler catches `Err`; borrow checking does not substitute for that invariant.

## Equivalent service and requester

The application module defines `CounterMessage::{Add(u64), Read}`,
`RequesterMessage::{Start, Total(u64)}`, reply value `Total(u64)`, typed
`Key<u64>` values `TOTAL`, `REQUEST`, `OBSERVED`, and codecs for `counter`, version 1.

```rust
impl Handler<CounterMessage> for Counter {
    fn initialize(&mut self, turn: &mut Turn<'_>) -> Result<()> {
        turn.state().put(&TOTAL, &0_u64)
    }

    fn handle(&mut self, turn: &mut Turn<'_>, input: Incoming<CounterMessage>) -> Result<()> {
        match input {
            Incoming::Cast { value: CounterMessage::Add(value), .. } => {
                let total = turn.state().require(&TOTAL)?;
                let updated = total.checked_add(value).ok_or(Error::new(ErrorKind::Handler, "counter-overflow"))?;
                turn.state().put(&TOTAL, &updated)
            }
            Incoming::Call { value: CounterMessage::Read, .. } => {
                let total = turn.state().require(&TOTAL)?;
                turn.reply(&Total(total), &TotalCodec)
            }
            _ => Err(Error::new(ErrorKind::Handler, "unexpected-message")),
        }
    }
}

struct Requester { counter: ProcessRef }

impl Handler<RequesterMessage> for Requester {
    fn initialize(&mut self, _turn: &mut Turn<'_>) -> Result<()> { Ok(()) }

    fn handle(&mut self, turn: &mut Turn<'_>, input: Incoming<RequesterMessage>) -> Result<()> {
        match input {
            Incoming::Cast { value: RequesterMessage::Start, .. } => {
                if turn.state().find(&REQUEST)?.is_some() {
                    return Err(Error::new(ErrorKind::Handler, "already-started"));
                }
                let correlation = turn.call(self.counter, &CounterMessage::Read,
                                             &CounterCodec, WaitPolicy::Untimed)?;
                turn.state().put(&REQUEST, &correlation.get())
            }
            Incoming::Reply(reply) => {
                let RequesterMessage::Total(total) = &reply.value else {
                    return Err(Error::new(ErrorKind::Handler, "unexpected-message"));
                };
                let expected = Correlation::new(turn.state().require(&REQUEST)?)?;
                turn.require_reply(&reply, self.counter, expected)?;
                turn.state().put(&OBSERVED, total)
            }
            _ => Err(Error::new(ErrorKind::Handler, "unexpected-message")),
        }
    }
}
```

`call` returns Station's input-derived correlation after staging its wait/output;
there is no remote future. Persisting that correlation happens in the same turn.
A fresh requester host with fresh ownership and the same configured peer handles
the reply from durable state. The example selects unlimited lifetimes; finite
waits require the explicit deadline/observer policy validated by native Station.

## Runner and worker boundary

```rust
let mut runner = Runner::open(
    service_config, Counter, CounterCodec,
    RunnerOptions {
        failure: FailurePolicy::BlockInput,
        recovery: Recovery::PersistBeforeDispatch(Box::new(store)),
    },
)?;
let stop = runner.stop_token(); // Clone into a separate controller if needed.
while let Some(event) = runner.next()? {
    match event {
        RunnerEvent::Committed { input, receipt } => observe_commit(input, receipt),
        RunnerEvent::Blocked { input, receipt } => report_blocked(input, receipt),
        RunnerEvent::NeedsRecovery { mutation, .. } => { report_pending(mutation); break; }
        RunnerEvent::Idle => wait_for_more_work(),
        RunnerEvent::Progress => {},
    }
}
let shutdown = runner.close()?;
save_shutdown_evidence(shutdown)?;
```

The requester uses `Requester { counter }`, `RequesterCodec` and its own
activation with the same runner API. `next(&mut self)` returns
`Result<Option<RunnerEvent>>`; `None` means locally stopped, not an
empty mailbox with no future work. A recovery event pauses dispatch; `reconcile`
makes one explicit attempt before native state can allow a new run. No retry
loop inside a convenience method silently drives new handler decisions.

`Runner::open` moves the handler and message codec to one owned worker; they must
be `Send + 'static`. The worker executes handlers and native calls on a stack at
least the generated 8 MiB requirement. The synchronous controlling API waits
for owned outcomes through bounded admission, without relying on a caller or
executor thread's default stack. Native I/O workers keep their own separate
bound. `Client` uses the same owned-worker strategy. Both public handles are
`Send` and not `Sync`, with mutable access required for operations.

The initial public API is blocking; applications must not call it on an async
executor thread. A later optional executor adapter must preserve one worker,
bounded command admission, cancellation ownership and join semantics. Tokio or
another executor is not a mandatory dependency of the core crates.

Convert handler errors and caught panics into the selected stop/block policy
outside the ABI; unwinding cannot cross FFI. Abort during native work or a process
abort follows host-loss recovery. `close(self)` requests stop, joins work and
returns structured shutdown/pending evidence. `Drop` releases/joins owned work
without implicitly committing; applications needing error/evidence handling use
explicit close. A handler that never returns can prevent a graceful join. Native
deadlines cannot promise to terminate arbitrary Rust code.

## Raw send and restart recovery

`Client::prepare_send(peer, &[u8], &Credential, Sequence)` returns an owned
`PendingSend`. `export()` returns owned opaque bytes; `recover_send(&[u8])`
validates the native operation's kind before constructing that type. It needs no
signing seed. `dispatch(&mut self, &PendingSend)` makes one exchange:

```rust
pub enum DispatchError {
    Preflight(Error),
    Rejected(Error),
    Uncertain { cause: Error, recovery: Box<[u8]> },
}

let mut client = Client::open(client_config)?;
let pending = client.prepare_send(requester, &encoded_start, &credential, sequence)?;
outbox.save(pending.identity(), &pending.export())?;
match client.dispatch(&pending) {
    Ok(receipt) => outbox.confirm(pending.identity(), &receipt)?,
    Err(error) => report_attempt(error), // Saved material remains for recovery.
}
client.close()?;

// Fresh host; loading an operation does not need credentials or authorize it.
let mut recovered_client = Client::open(recovery_config)?;
let pending = recovered_client.recover_send(&outbox.load(operation_id)?)?;
let receipt = recovered_client.dispatch(&pending)?;
outbox.confirm(pending.identity(), &receipt)?;
recovered_client.close()?;
```

The success type is `AdmissionReceipt`, distinct from a runner turn receipt and
reply consumption. `encoded_start` comes from Station's shared cast encoder;
the raw crate does not depend on Station. The application's sequencer assigns
`sequence` across all handles using that principal. Retry bytes stay opaque and
must be durably saved before dispatch; do not expose them in `Debug`/logs.

Rejections preserve native status, exact authority code and attempt phase;
ownership, retirement, authorization and history failures remain distinct.
An earlier uncertainty is not resolved by a revoked later retry. Failed reads
are not unknown mutations. Preparation/ownership/allocation errors before any
send differ from allocation failure after possible acceptance. Dropping a pending
handle releases memory but does not change the durable outcome.

`RecoveryStore: Send + 'static` has synchronous `before_dispatch(&FrozenMutation)`
and `confirmed(&OperationIdentity, MutationReceipt)` methods returning `Result<()>`. They execute serially on the worker outside native locks.
Owned export bytes are available for persistence; borrowed callback arguments
cannot escape. Failure before dispatch leaves the request unsent. Failure after
confirmation returns the receipt plus pending evidence and stops without rerunning
the handler. The SDK does not provide a hidden durable queue or filesystem store.

## Data, packaging and acceptance

`turn.table(&schema)` returns a borrowing `Table<'_, C>` with point operations
and owned bounded `Page<Row<C>>` results. Retained IDs and exported cursors are owned;
source handles borrow the turn. `handle_result` receives `ResultComplete`; the handler opens
`turn.result(complete.correlation)` and releases that borrow before mutating
state. This keeps the reader and mutable turn from aliasing. A query-enabled `ResultReader<'_>` exposes owned
complete-manifest metadata and bounded `IpcSegment { ipc: Box<[u8]>, ... }` values.
Segment bytes survive reader/turn disposal; further reads require a live authorized
source. Optional Arrow adapters must document buffer retention and cannot treat
one segment as the whole result or concatenate independent IPC streams.

Build/install crates with an explicit version-matched native artifact dependency
for Linux x86_64. Build/runtime discovery must work from installed artifacts,
with a documented native-directory override and actionable ABI/capability errors.
Do not require sibling-source imports or manual loader paths in the consumer.
Feature `arrow` qualifies owned record batches from Arrow Rust 59 components;
the core dependency graph excludes Arrow. Keep those dependencies locked; registry
publication and non-Linux support are outside the M11 installation baseline.

Acceptance includes compilation of both example roles, compile-fail checks for
turn escape/sharing, shared codec/failure scenarios, panic and close/join behavior,
worker stack/admission bounds, and clean consumer builds outside the repository.
Borrow checking does not qualify native buffer lifetime or durable recovery;
those need executable failure evidence too.
