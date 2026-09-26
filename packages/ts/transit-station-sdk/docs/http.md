# HTTP calls and capture

The experimental M15 API composes the shared Zig HTTP connector. Provision its
exact endpoint/method/target/header policy and independent capture resource using
the [worker admission guide](../../../../apps/transit-station-http-worker/docs/admission.md).
Request/capture reads require optional resource associations plus current grants.
Create those associations before assigning ownership.

```typescript
import { prepareHttp } from '@transit/station';

const request = await prepareHttp(resource, namespace, {
  method: 'POST',
  target: [{ kind: 'literal', value: '/items/' },
           { kind: 'variable', name: 'id', value: itemId }],
  headers: [{ name: 'Authorization', value: [
    { kind: 'literal', value: 'Bearer ' },
    { kind: 'secret', binding: 'api', version: 7n },
  ] }],
}, body, { endpointRevision: 7n, reconcileBeforeMs: deadline });
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
  if (!reader.complete) throw new Error('Incomplete capture');
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
does not release the durable caller capture hold. Public followup/release helpers
and the remaining SDK matrix are still M15 work.
