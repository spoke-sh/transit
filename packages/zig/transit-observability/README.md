# transit-observability

Transit event vocabulary and optional instrumentation helpers, exported as
`transit_observability`. Its dependencies are the public
[protocol](../transit-protocol/README.md) and neutral
[telemetry](../telemetry/README.md) packages. It imports no core, Board, provider,
or exporter implementation. Executables own the runtime/sinks; libraries borrow
them. See [Observability](../../../docs/reference/observability.md) for shared semantics.

`begin(runtime, kind, operation, parent)` returns an `Observation` with a short
span and structured event. Set known fields, call `fail(err)` for a failure, and
`finish()` after joined completion. A null runtime does no I/O. Operation/error
strings must be compile-time vocabulary, never URLs, provider stderr or payloads.
`fail` classifies the attempt's error; it does not infer a durable rejection or
external cancellation. The owning code sets `protocol_outcome` separately.

| Event | Owner / meaning |
| --- | --- |
| `transit.http.request` | Node HTTP boundary; transport status/write outcome and separately known read/receipt/rejection |
| `transit.client.request` | One client attempt, including timeout or a validated response; successful reads/receipts are debug-level |
| `transit.storage.operation`, `transit.recovery` | Backend operation or authority recovery, supplied by the adapter/host |
| `transit.delivery.step` | One scoped courier step; progress, idle, denial or uncertainty |
| `transit.maintenance.step` | One bounded maintenance scan and its disposition |
| `transit.runtime.step`, `transit.provider.operation` | Runtime reconciliation and provider invocation, separate from execution authority |
| `transit.caller.turn`, `transit.caller.activation` | Caller-local computation/proposal progress and activation lifecycle |

The latter coverage is implemented with each owning component, not implied just
by these shared names. A receipt can be a retry of earlier acceptance. The v2
response does not distinguish fresh and historical receipts; no fresh-commit
metric is inferred from it. Operation names (`send`, `turn`, `deliver`, `dispatch`,
`observe`, `close_effect`, etc.) preserve which protocol boundary was called.
Replay/recovery uses its own event, never a fabricated sequence of fresh turns.

Only append verified realm/PID/sequence/position to server events after the
authorization boundary. Client events include identities from successfully
answered operations. These fields are protected diagnostics, never metric labels.
Transport context travels in unsigned `traceparent` headers and does not change
command canonicalization, signatures, retry identity, or returned receipts.

Use `just test::packages` and `just test::observability`; the latter follows a real
Board request across client and node, checks distinct related spans, duplicate
receipts, revoked reads, rejected remote context and excluded credentials/state.
