# HTTP calls and replay

The experimental M15 API uses the shared Zig HTTP connector. Provision a connector
PID with an exact endpoint/method/target/header policy and independent capture
resource, as described in the [worker admission guide](../../../../apps/transit-station-http-worker/docs/admission.md).
Request and capture access require both optional resource associations and current
resource grants. Prepare those associations before assigning PID ownership.

```python
from transit_station import (
    HttpRequest, HttpMethod, HttpHeader, Literal, Variable, SecretRef, prepare_http,
)

request = prepare_http(
    caller_resource, namespace,
    HttpRequest(HttpMethod.POST, (Literal('/items/'), Variable('id', item_id)), (
        HttpHeader('Authorization', (Literal('Bearer '), SecretRef('api', 7))),
    )),
    body,
    endpoint_revision=7, reconcile_before_ms=deadline_ms,
)
```

`prepare_http` performs local validation and computes immutable commitments through
Zig. It performs no HTTP send or credential lookup. It owns its metadata/body bytes;
the finite profile accepts at most 65,536 body bytes and 8,192 metadata bytes.
Header order and duplicate application fields are preserved. Ordinary target
variables use UTF-8 percent encoding. Credential values belong in the executor's
private binding files; the request stores only `SecretRef` names and versions.

Inside a handler, call `turn.stage_http(request)` once per continuation turn. False
means another bounded publication step is needed. True means both records were
published before this turn, allowing `turn.call_http(connector, request)` in the
same turn. Save the returned correlation in associated state. The application
must schedule continuation inputs and keep the exact source recoverable until
publication completes. A host object or coroutine is not durable upload state.
Fresh owners can reconstruct the same request; changes to its identity reject.
Each namespace belongs permanently to one request and cannot be recycled after
retirement. Calling with unpublished or changed records rejects before output.

Use `HttpReplyCodec(application_codec, realm)` as an explicit union codec for
ordinary application messages plus `HttpOutcome`/`HttpRejected`/`HttpReleased`.
It reserves the `HTR1`, `HTF1` and `HTK1` payload prefixes for shared HTTP replies. Before using an outcome,
call `turn.require_reply(incoming, peer=connector, correlation=saved_correlation)`
to verify the current authenticated input against the durable wait. Decoding an
outcome or possessing a reference confers no authority.

Observed outcomes carry HTTP status and a complete capture reference. Closed
unknown outcomes preserve effect/attempt identity and have no complete reference;
not-dispatched outcomes have no attempt. Neither status nor local cancellation
proves business success, remote failure or external cancellation. HTTP reply
records are receive-only through this codec. `decode_http_reply` supports explicit
local decoding of saved outcome bytes using the same Zig validation.

After the turn commits and the runner has no pending mutation or active run
iterator, use its bounded replay reader:

```python
with runner.open_http(outcome) as reader:
    while (part := reader.read()) is not None:
        consume(part.kind, part.data)  # owned bytes, at most 256 per part
    assert reader.complete
```

Parts may split HTTP heads, bodies and metadata records. Only the final part's
`complete` flag establishes verified full coverage; earlier bytes are provisional.
Each read checks current access. A failed reader stays failed even if access is
restored: close and reopen under current permissions. The default captured policy
preserves explicit omissions; `HttpReplayPolicy.REQUIRE_UNREDACTED` rejects gaps.
Replay performs no external HTTP, DNS or credential lookup.

`AsyncRunner.open_http`, `AsyncHttpReader.read` and `aclose` use the same owned
worker. One reader and one outstanding operation are allowed per runner.
Concurrent operations reject as busy. Cancelling an await does not undo native
work; always `await runner.aclose()` to join it and dispose the native reader,
including when cancellation races with opening a reader. Reader bytes remain
owned after disposal. Closing the reader releases local state only; it does not
release the caller's durable capture hold.

To dispose that durable hold, call
`turn.release_http(connector, outcome.resource, outcome.exchange)` in a handler
and save its returned correlation in state. Check the subsequent `HttpReleased`
with `turn.require_reply` against that connector and correlation, then check its
resource/exchange. A rejection remains `HttpRejected`. Duplicate requests remain
safe after worker restart and capture cleanup. This operation needs no transcript
read grant; the service checks the recorded holder and current admission policy.
It performs no remote cancellation, retirement or automatic physical cleanup.
The finite worker needs a fresh `poll` activation to handle the call. Public
followup helpers remain M15 work.
