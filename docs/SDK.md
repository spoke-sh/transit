# Public SDK design

Status: M11 implementation design. The examples below describe the intended
Python, TypeScript and Rust interfaces; they are not runnable programs yet.
[M11](roadmap/M11.md) owns delivery and qualification. The existing
[M9 adapters](../bindings/README.md) remain the executable low-level interfaces.
The [caller model](CLIENT.md#idiomatic-language-sdks) owns shared guarantees.

## Boundaries and first implementation

Raw Transit and Station have separate public packages. Raw Transit owns typed
references, credentials, signed operations, receipts, paged reads and recovery.
Station adds typed messages, private turns, Tables and handler runners. Loading
either package performs no credential discovery, network I/O or worker startup.

Generated ABI and wire declarations remain internal to each adapter or available
through an explicitly named raw interface. Public host types are designed for
their language. Signing, response validation, sequencing and framework decisions
remain in Zig. A host codec only interprets application bytes; it cannot change
authenticated origins, durable identity or current authorization.

The first implemented shared capability is the raw growing-profile ABI. Its additive
operation kinds retain the existing v2 ABI and frozen requests, expose v3
command/query preparation and exact recovery, and report supported kinds before
dispatch. A local library capability is distinct from an authority's advertised
capabilities. A subsequent explicit growing Station adapter must supply bounded
reads and actions through `GrowingGenServer`; wrapping the legacy complete-state
snapshot cannot satisfy the public SDK growth requirement.

| Boundary | Decision |
| --- | --- |
| Profile | Explicit `growing_v3` or supported legacy profile; no automatic fallback or history conversion |
| Identity | Realm-qualified process/resource references; protocol IDs retain their public 53-bit bound, application int64/u64 and correlations preserve all bits |
| Bytes | Python `bytes`, TypeScript `Uint8Array`, Rust owned bytes; no common-path hex strings |
| Application codecs | Explicit stable application type/version, strict decoding and bounded output; shared fixtures precede language implementations |
| Native compatibility | Negotiate ABI plus required operation capabilities; reject missing support before preparing or dispatching work |
| Raw recovery | An owned operation exports/imports opaque exact native retry bytes; host code never parses or reserializes those bytes |
| Scheduling | One operation per handle, bounded admission and explicit native stack/worker budgets; overlap is an error, not an unbounded queue |
| Arrow | Original owned IPC bytes and source/completeness metadata first; optional adapters have separate ownership and compatibility checks |
| Packaging | Separate installable client/Station artifacts with explicit native dependency resolution; Linux x86_64 first, no public registry publication in M11 |

## Equivalent application

The example service maintains a typed counter in its associated resource. It
accepts `Add(u64)` and `Read`, and replies with `Total(u64)`. This is an integer
counter, not a monetary model. Overflow fails explicitly; no host may round or
wrap a value. Application contract `counter`, version 1, owns the message tags
and value codec. It must be checked through the same shared fixtures in each
language, including values beyond JavaScript's exact-number range.

The requester first receives a typed `Start` input and uses correlation 1 exactly
once during its process lifetime. Initialization and consuming `Start` commit
with that call's waiting record and output intent. A
later invocation runs under a fresh activation for that same durable process.
Its initialized descriptor and waiting record prevent a second initial call;
the recorded reply resumes through a later handler. A general application must
allocate a fresh durable correlation for each new call, not reuse this example's
single-call constant. Deadline policy is explicit at configuration time.

Python and Rust can run blocking handler bodies on bounded native workers;
TypeScript awaits its local port operations. A handler can use bounded
local/native reads through its turn; it cannot await another process while
holding an open private proposal. Outer runners keep runtime schedulers
responsive and expose commitment separately from handler return.

### Python

Proposed service and requester bodies:

```python
class Counter:
    def initialize(self, turn: Turn) -> None:
        turn.state.put(TOTAL, 0, codec=U64)

    def handle(self, turn: Turn, message: Add | Read) -> None:
        if isinstance(message, Add):
            value = U64.checked_add(turn.state.get(TOTAL, codec=U64), message.value)
            turn.state.put(TOTAL, value, codec=U64)
        else:
            turn.reply(Total(turn.state.get(TOTAL, codec=U64)), codec=TOTAL_MESSAGE)


class Requester:
    def initialize(self, turn: Turn) -> None:
        turn.call(counter_ref, Read(), correlation=1, codec=COUNTER_MESSAGE)

    def handle(self, turn: Turn, message: Start | Reply[Total]) -> None:
        if isinstance(message, Start):
            return
        turn.require_reply(message, peer=counter_ref, correlation=1)
        turn.state.put(OBSERVED, message.value.value, codec=U64)


async with Runner.open(config, handler=Counter(), codec=COUNTER_MESSAGE,
                       failure_policy=FailurePolicy.BLOCK_INPUT) as runner:
    async for outcome in runner.run(stop=stop_signal):
        if isinstance(outcome, Committed):
            record_committed_position(outcome.receipt.position)
```

The synchronous runner has an ordinary context manager and iterator. Async
operations use a bounded owned worker; cancellation abandons the local await
while close joins native work. A returned `Turn` is invalid outside its handler.
The requester codec accepts `Start` and `Total`; the runner exposes an
authenticated reply as `Reply[Total]`, preserving its origin and correlation.

### TypeScript

```typescript
class Counter implements Handler<CounterMessage> {
  async initialize(turn: Turn): Promise<void> {
    await turn.state.put(TOTAL, 0n, u64);
  }
  async handle(turn: Turn, message: CounterMessage): Promise<void> {
    switch (message.kind) {
      case "add": {
        const total = await turn.state.get(TOTAL, u64);
        await turn.state.put(TOTAL, u64.checkedAdd(total, message.value), u64);
        break;
      }
      case "read":
        await turn.reply({ kind: "total", value: await turn.state.get(TOTAL, u64) }, totalCodec);
    }
  }
}

class Requester implements Handler<Start | Reply<Total>> {
  async initialize(turn: Turn): Promise<void> {
    await turn.call(counterRef, { kind: "read" }, { correlation: 1n, codec: counterCodec });
  }
  async handle(turn: Turn, reply: Start | Reply<Total>): Promise<void> {
    if (reply.kind === "start") return;
    turn.requireReply(reply, { peer: counterRef, correlation: 1n });
    await turn.state.put(OBSERVED, reply.value.value, u64);
  }
}

const runner = await Runner.open(config, new Counter(), counterCodec, { failure: "block-input" });
try {
  for await (const outcome of runner.run({ signal: stopSignal })) {
    if (outcome.kind === "committed") recordCommittedPosition(outcome.receipt.position);
  }
} finally {
  await runner.close();
}
```

All full-width application values and correlations are `bigint`. Runtime codecs
reject malformed values even when TypeScript types were bypassed. Awaiting
`turn.call` stages the private intent through the local port; it does not await
admission or a remote reply. The runner awaits one handler before freezing its
proposal and invalidates the turn when that scope ends. Concurrent operations on
the same turn reject; no helper loads the complete resource or extends its view.

### Rust

```rust
impl Handler<CounterMessage> for Counter {
    fn initialize(&mut self, turn: &mut Turn<'_>) -> Result<()> {
        turn.state().put(TOTAL, &0_u64, &U64)
    }
    fn handle(&mut self, turn: &mut Turn<'_>, message: CounterMessage) -> Result<()> {
        match message {
            CounterMessage::Add(value) => {
                let total = turn.state().get(TOTAL, &U64)?;
                let updated = total.checked_add(value).ok_or(Error::ValueOverflow)?;
                turn.state().put(TOTAL, &updated, &U64)
            }
            CounterMessage::Read => {
                let total = turn.state().get(TOTAL, &U64)?;
                turn.reply(&Total(total), &TOTAL_CODEC)
            }
        }
    }
}

impl Handler<RequesterMessage> for Requester {
    fn initialize(&mut self, turn: &mut Turn<'_>) -> Result<()> {
        turn.call(self.counter, &CounterMessage::Read, Correlation::new(1), &COUNTER_CODEC)
    }
    fn handle(&mut self, turn: &mut Turn<'_>, message: RequesterMessage) -> Result<()> {
        let RequesterMessage::TotalReply(reply) = message else { return Ok(()); };
        turn.require_reply(&reply, self.counter, Correlation::new(1))?;
        turn.state().put(OBSERVED, &reply.value.0, &U64)
    }
}

let mut runner = Runner::open(config, Counter, COUNTER_CODEC, FailurePolicy::BlockInput)?;
while let Some(outcome) = runner.next(&stop)? {
    if let Outcome::Committed(receipt) = outcome {
        record_committed_position(receipt.position);
    }
}
```

The scoped borrow prevents turn escape. Runtime workers still enforce one
operation at a time and the generated native stack budget. The initial blocking
runner can execute on one owned worker; an optional executor integration must
retain that bound and join it during disposal.

## Unknown outcomes and recovery

Raw clients expose preparation separately from one dispatch. Equivalent usage
in all languages is: prepare a typed operation, persist its opaque export when
restart recovery is required, dispatch once, then handle a receipt, definite
rejection or uncertainty. Retrying imports the original bytes; it never allocates
a replacement sequence or reconstructs signed JSON from a public model.

| Observation | Required application behavior |
| --- | --- |
| Admission receipt | Input is accepted; this does not establish handler commitment or reply completion |
| Handler returned | Private proposal exists; the runner must still freeze and reconcile its result |
| Confirmed turn receipt | State, input progress and outputs committed under one authority decision |
| Unknown mutation outcome | Preserve the same operation and stop dispatching new handlers until reconciled |
| Lost retry material | Obtain fresh fenced ownership and inspect committed state before recomputing |
| Local task cancellation | Join owned native work; no inferred rejection, durable cancellation or acknowledgement |
| Decode/handler failure | Discard private work, then follow the configured explicit stop or block-input policy |
| Read failure | Poison/discard that proposal; do not turn incomplete state into a committed application-failure marker |
| Host loss after a call | Recover the recorded wait/reply under fresh ownership; do not recreate an in-memory future as durable state |

The runner needs an explicit pre-dispatch persistence hook for frozen mutations
when local exact-retry recovery is selected. It may not send first and only then
offer the caller a recoverable operation. An exception in that hook leaves the
proposal unsent. A persistence hook is application-owned storage, not a second
execution authority or an SDK background queue.

## Review and qualification work

The sketches require explicit async turn methods for Node's local port and a
native boundary that surfaces frozen work to a persistence hook before dispatch.
Qualify those decisions in executable examples,
then check the same service/requester and failure scenarios through Python,
TypeScript and Rust before adapting the other target languages.

Initial proof obligations are explicit profile rejection, full-width IDs,
canonical retry export/import, no fallback routes, rejected malformed ingress,
uncertainty after accepted-response loss and allocation failure, and current
revocation on retry. Later runner proofs add sequential dispatch, turn escape,
durable continuation, failed persistence hooks, cancellation and clean installs.
The [shared scenario catalog](../tests/verification/sdk.json) remains the common
failure vocabulary. Passing low-level proofs alone does not qualify these public
SDK examples, optional Arrow adapters or package installation.
