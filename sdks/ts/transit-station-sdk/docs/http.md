# HTTP calls and capture

The experimental M15 API composes the shared Zig HTTP connector. Provision its
exact endpoint/method/target/header policy and independent capture resource using
the [worker admission guide](../../../../apps/transit-station-http-worker/docs/admission.md).
Request/capture reads require optional resource associations plus current grants.
Create those associations before assigning ownership.

```typescript
import { prepareHttp } from "@transit/station";

const request = await prepareHttp(
  resource,
  namespace,
  {
    method: "POST",
    target: [
      { kind: "literal", value: "/items/" },
      { kind: "variable", name: "id", value: itemId },
    ],
    headers: [
      {
        name: "Authorization",
        value: [
          { kind: "literal", value: "Bearer " },
          { kind: "secret", binding: "api", version: 7n },
        ],
      },
    ],
  },
  body,
  { endpointRevision: 7n, reconcileBeforeMs: deadline },
);
```

Preparation copies input before asynchronous work, validates it through Zig and
returns owned immutable commitments. Bytes returned by getters are copies.
Namespaces, endpoint/secret versions and exchange IDs preserve all 64 bits as
`bigint`. Body and metadata bounds are 65,536 and 8,192 bytes respectively.
Duplicate application headers retain order. Target variables use UTF-8 percent
encoding. Secret references resolve only in the authorized connector executor;
local preparation never reads credentials or sends an HTTP request.

Inside a handler, `await turn.stageHttp(request)` advances one bounded durable
publication step. If false, schedule another continuation turn with the same
recoverable source. If true, `await turn.callHttp(connector, request)` may run in
that turn; save its correlation in associated state. Fresh ownership resumes the
exact request. Changed identity, unpublished records and namespace reuse after
retirement reject. Host fields and promises do not replace durable source recovery
or continuation scheduling. All scoped operations must be awaited.

Implement the optional handler method
`handleHttpReply(turn, input: Reply<HttpReply>)` to receive typed HTTP outcomes.
This explicitly reserves HTR1/HTF1 reply payloads for shared native decoding;
ordinary messages still use the application codec. Authenticate each reply with
`turn.requireReply(input, { peer: connector, correlation: savedCorrelation })`.
Local `decodeHttpReply(realm, bytes)` also delegates to the shared codec.

`HttpOutcome` distinguishes observed, closed-unknown and not-dispatched. Only
observed includes an HTTP status and complete capture reference. `HttpRejected`
reports denied, invalid-request or busy. Neither HTTP status nor local stop proves
business success or external cancellation. A reference grants no access.

After committing the turn, close any active `run()` iterator and resolve pending
mutations before replay:

```typescript
const reader = await runner.openHttp(outcome);
try {
  for (;;) {
    const part = await reader.read();
    if (!part) break;
    consume(part.kind, part.data);
  }
  if (!reader.complete) throw new Error("Incomplete capture");
} finally {
  await reader.close();
}
```

Each part owns at most 256 bytes and may split HTTP heads, bodies or metadata.
Only the final complete part establishes verified full coverage. Access is checked
on every read; after a failure, close and reopen under current permissions. The
captured policy includes explicit omissions; `require-unredacted` rejects gaps.
Replay performs no external HTTP, DNS or credential lookup.

One reader and one outstanding operation are permitted per runner. Overlap
rejects as busy. `runner.stop()` requests local stop; `await runner.close()` joins
outstanding native work and disposes the reader. Ignoring a promise does not
cancel that work. Owned bytes remain valid after disposal. Closing local handles
does not release the durable caller capture hold.

Use `await turn.releaseHttp(connector, outcome.resource, outcome.exchange)` to
request durable disposal. Save its correlation in state, then authenticate the
`HttpReleased` reply in `handleHttpReply` with `turn.requireReply` and check the
resource/exchange. `decodeHttpReply` also returns this frozen value with
`kind: 'http-released'`; rejection remains `http-rejected`. The runner reserves
the HTK1 prefix for this callback alongside HTR1/HTF1.

Disposal needs no transcript read grant and duplicate requests remain safe after
restart or cleanup. The service checks the original holder and current policy;
local decoding grants no authority. It does not cancel remote work, retire capture
or perform cleanup. A finite worker uses a fresh `poll` activation to handle the
call.

Use `await turn.followupHttp(connector, parentOutcome, reason, request)` for an
explicit linked attempt. `HttpFollowupReason` is `retry`, `redirect`, `reconcile`
or `cancel`, with runtime validation too. The proposed request must already be
published in the current associated resource with the original deadline and
total attempt budget. Save the new correlation and authenticate its outcome or
rejection in `handleHttpReply`. The service checks the original caller, current
scope and parent's frozen policy before allocating a child. The helper does not
retry automatically or infer retry safety. The finite worker must select a fresh
child exchange and the matching parent/reason. Parent outcomes remain unchanged.

Outcome and rejection values own `diagnostic` after the codec/native buffer is
released. It retains the exact protocol status, exchange identity and inspection
guidance. A completed response does not establish business success or permit a
retry; rejected input does not settle earlier work. Original details absent from
the reply are explicitly unrecorded. See the
[shared SDK diagnostic contract](../../../../docs/reference/sdks.md#structured-failure-details).

## Original diagnostic evidence

Use `await runner.httpDiagnostic(outcome, kind)` after the runner has no pending
mutation. Select `"capture-failure"` or `"native-effect"`; the result is an owned `Diagnostic` or `undefined`.
Capture evidence is the original retained local failure; native effect evidence
reports the independently recorded effect outcome. Absence does not establish
success. Reads work after exchange retirement while the evidence remains readable.
They require current capture-resource access; native effect reads additionally
require inspection of the connector PID. Permission, stale-cut and integrity
failures remain read errors. These operations do not open a replay cursor,
resolve credentials, dispatch, resume or retry an effect. See the
[shared diagnostic semantics](../../../../docs/reference/sdks.md#structured-failure-details).
