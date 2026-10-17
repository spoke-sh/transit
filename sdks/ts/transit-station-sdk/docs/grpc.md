# Finite RPC calls and replay

The M16 APIs compose the [shared RPC contract](../../../../contracts/STATION_GRPC_V1.md).
`await grpcMethod(descriptorBytes, "/package.Service/Method")` resolves an explicitly
supplied local descriptor set through Zig. There is no reflection, connection or
secret discovery. Application protobuf codecs remain caller-owned.

```typescript
const method = await grpcMethod(descriptorBytes, "/test.Peer/Bidi");
const prepared = await prepareGrpc(
  resource,
  namespace,
  {
    method,
    metadata: [
      { name: "x-label", value: { kind: "literal", bytes: label } },
      { name: "authorization", value: { kind: "secret", binding: "api", version: 7n } },
    ],
  },
  [protobufMessage, new Uint8Array()],
  {
    endpointRevision: 7n,
    reconcileBeforeMs: deadline,
  },
);
// In a handler; arrange another durable input until staging completes.
if (await turn.stageGrpc(prepared)) {
  const correlation = await turn.callGrpc(connector, prepared);
  await turn.state.put(callKey, correlation);
}
```

Preparation copies inputs before awaiting the native host. Prepared accessors
return copies. Keep source inputs recoverable across host replacement; JS fields
are not durable state. Namespaces, secret versions, endpoint revisions, exchange
and correlation identities use `bigint`. The finite batch/half-close cannot change
in response to incoming messages. Per-call limits are 64 messages/direction,
16 KiB/message, 64 KiB outgoing and 256 KiB incoming framed bytes, plus 64 metadata
fields/8 KiB. These bounds do not limit total retained calls.

An optional `Handler.handleGrpcReply` receives authenticated-origin metadata and
`GrpcReply` values. Match the recorded peer/correlation with `turn.requireReply`.
`GrpcOutcome.status` is `0` for observed `OK`, and `undefined` for closed unknown;
unknown outcomes have no complete reference. Application protobuf decoding and
business success remain application concerns.

`await runner.openGrpc(outcome)` returns an `AsyncDisposable` reader. `read()`
returns owned 256-byte parts; only `complete=true` establishes verified coverage.
The runner admits one RPC reader independently of its HTTP reader. Each read
rechecks current access. A failed reader stays failed; a fresh reader requires
current authorization. Closing readers is local. Runner close joins active work;
local wait cancellation does not promise remote cancellation or rollback.

`turn.retryGrpc(connector, parent, prepared)` records an explicit new linked call.
Service policy checks original attempt/deadline budgets and remote idempotency.
`turn.releaseGrpc(connector, resource, exchange)` requests durable hold disposal;
authenticate the `grpc-released` reply. Neither operation is automatic.

`just bindings::node-sdk-test` runs an installed caller against the actual Zig
worker, including interrupted upload recovery, binary/Unicode protobuf, duplicate
metadata, prefix revocation, owned replay without secrets, joined close, retry
refusal and disposal after cleanup. [Proof details](../../../../tests/README.md)
keep transport, native-boundary and deployment evidence separate.

Outcome and rejection values own `diagnostic` after the codec/native buffer is
released. It retains the exact protocol status, exchange identity and inspection
guidance. A completed response does not establish business success or permit a
retry; rejected input does not settle earlier work. Original details absent from
the reply are explicitly unrecorded. See the
[shared SDK diagnostic contract](../../../../docs/reference/sdks.md#structured-failure-details).

## Original diagnostic evidence

Use `await runner.grpcDiagnostic(outcome, kind)` after the runner has no pending
mutation. Select `"capture-failure"` or `"native-effect"`; the result is an owned `Diagnostic` or `undefined`.
Capture evidence is the original retained local failure; native effect evidence
reports the independently recorded effect outcome. Absence does not establish
success. Reads work after exchange retirement while the evidence remains readable.
They require current capture-resource access; native effect reads additionally
require inspection of the connector PID. Permission, stale-cut and integrity
failures remain read errors. These operations do not open a replay cursor,
resolve credentials, dispatch, resume or retry an effect. See the
[shared diagnostic semantics](../../../../docs/reference/sdks.md#structured-failure-details).
