# HTTP requests and owned replay

The experimental M15 API uses the shared Zig HTTP connector. Provision an exact
endpoint/method/target/header policy and independent capture resource using the
[worker guide](../../../../apps/transit-station-http-worker/docs/admission.md).
Both optional associations and current resource grants are required for foreign
request/capture reads; associate before assigning PID ownership.

`prepare_http(resource, namespace, &request, body, options, native_directory)`
returns a `PreparedHttpRequest` with owned metadata/body bytes. `HttpRequest`
contains an explicit `HttpMethod`, ordered target pieces and ordered headers.
`HttpPiece::Literal`, `Variable` and `Secret` preserve provenance; target variables
are UTF-8 percent encoded. Secrets carry only binding names/versions and resolve
in the executor. Preparation runs shared Zig validation on an owned worker, with
no credential lookup or HTTP send. Namespace and version fields preserve `u64`.
Body and metadata bounds are 65,536 and 8,192 bytes.

Inside a handler, `turn.stage_http(&request)?` performs at most one bounded
publication step. False requires another continuation turn with exactly the same
recoverable source. True permits `turn.call_http(connector, &request)?` in that
turn; persist its correlation in associated state. The shared uploader resumes
under a fresh owner, rejects identity changes, and prevents namespace reuse after
retirement. Rust fields or a blocked stack do not make the source durable or
schedule continuation inputs.

Wrap the application codec in `HttpReplyCodec::new(codec, realm, directory)?`
and handle `HttpMessage<T>`. Its explicit union reserves HTR1/HTF1/HTK1 payload prefixes
for shared decoding into `HttpReply::Outcome`, `Rejected` or `Released`. Before using a reply,
verify it with `turn.require_reply(&reply, connector, saved_correlation)?`.
Outcome records are receive-only through this codec. `decode_http_reply` provides
local shared validation of saved outcome bytes; decoding confers no authority.

Only `HttpPhase::Observed` includes status and a complete capture reference.
Closed unknown preserves effect/attempt identity; not dispatched has no attempt.
Neither HTTP status nor local stop proves business success or remote cancellation.

Once the turn commits and pending mutations are resolved:

```rust
let mut reader = runner.open_http(&outcome, HttpReplayPolicy::Captured)?;
while let Some(part) = reader.read()? {
    consume(part.kind, &part.data);
}
assert!(reader.complete());
reader.close()?;
drop(reader);
```

`HttpReader<'_, M>` borrows the runner mutably. Rust rejects overlapping runner
operations while the reader is live. Its parts own at most 256 bytes, which can
split HTTP heads, bodies and metadata records. Only final verified completion
establishes full coverage; earlier parts are provisional. Every read checks current
access. After failure, close/drop and reopen under current permissions.
`RequireUnredacted` rejects omitted fields as gaps. Replay never invokes HTTP,
DNS or credential resolution.

Reads and disposal use the runner's blocking worker. Move the runner into an
owned blocking task when integrating with an async executor, request local stop
through its `StopToken`, and join that task. Dropping a host wait cannot cancel
native I/O or a remote operation. Dropping the reader attempts local disposal;
explicit `close()` reports errors. Runner destruction joins remaining work and
disposes its native reader. Returned bytes remain owned. Local disposal does not
release a durable capture hold.

Inside a handler, use `turn.release_http(connector, outcome.resource, outcome.exchange)?`
to request disposal of that durable hold and save the returned correlation in
state. Authenticate `HttpReply::Released` with `turn.require_reply`, then check
its resource/exchange. Duplicate calls remain safe after worker restart and
capture cleanup. A transcript read grant is unnecessary; the service checks the
recorded holder and current admission policy. Release performs no remote
cancellation, retirement or automatic cleanup. The finite worker needs a fresh
`poll` activation to handle it. Public followup helpers remain M15 work.
