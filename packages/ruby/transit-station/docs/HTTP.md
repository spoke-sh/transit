# HTTP calls and replay

The experimental M15 API uses shared Zig HTTP validation and lifecycle. Provision
the exact endpoint/method/target/header policy and independent capture resource
using the [worker guide](../../../../apps/transit-station-http-worker/docs/admission.md).
Foreign resource reads need optional associations plus current grants. Add
associations before assigning ownership; associations themselves grant no access.

```ruby
request = Transit::Station.prepare_http(resource, namespace,
  Transit::Station::HttpRequest.new(method: :post, target: [
    Transit::Station::HttpLiteral.new(value: '/items/'),
    Transit::Station::HttpVariable.new(name: 'id', value: item_id)
  ], headers: [Transit::Station::HttpHeader.new(name: 'Authorization', value: [
    Transit::Station::HttpLiteral.new(value: 'Bearer '),
    Transit::Station::HttpSecretRef.new(binding: 'api', version: 7)
  ])]), body: body, endpoint_revision: 7, reconcile_before_ms: deadline)
```

Request values own frozen copies of their strings and arrays. Namespaces,
endpoint/secret versions and exchange IDs preserve unsigned 64-bit `Integer`
values. Body and metadata bounds are 65,536 and 8,192 bytes. Header order and
duplicates are preserved; target variables use UTF-8 percent encoding. Secret
references resolve only in the authorized executor. Preparation uses a local
native worker without reading credentials or sending HTTP requests.

Inside a callback, `turn.stage_http(request)` advances one bounded publication
step. False requires another continuation turn with the same recoverable source.
True permits `turn.call_http(connector, request)` in that turn; save the returned
correlation in associated state. A fresh owner can resume the exact upload.
Changed identity, unpublished calls and namespace reuse after retirement reject.
Application objects/threads are not durable source recovery or scheduling.

Wrap the application's codec with `HttpReplyCodec.new(codec, realm: realm)`.
The explicit union reserves HTR1/HTF1 payload prefixes for shared decoding into
`HttpOutcome`/`HttpRejected`. Verify each input against its durable wait using
`turn.require_reply(input, peer: connector, correlation: saved_correlation)`.
HTTP outcomes are receive-only through this codec. `Station.decode_http_reply`
also validates saved outcome bytes through Zig; decoding confers no authority.

Only `:observed` has HTTP status and a complete capture reference. `:closed_unknown`
preserves effect/attempt identity, and `:not_dispatched` has no attempt. None of
these promises business success or remote cancellation.

After committing and resolving pending mutations, call `runner.open_http(outcome)`.
`reader.read` returns one `HttpPart` with frozen owned binary data of at most 256
bytes, or nil at verified end. Parts may split HTTP heads, bodies and metadata;
only the final `complete` flag establishes full coverage. Read access is checked
each time. After failure, close and reopen under current grants. Default
`:captured` preserves explicit omissions; `policy: :require_unredacted` rejects
gaps. Replay performs no external HTTP, DNS or credential lookup.

One active reader and one outstanding operation are permitted per runner. Close
readers explicitly when done. If a controller thread is interrupted during a
read, always close the owning runner to join pending work and dispose the native
slot; interrupting its wait does not cancel native I/O. The block form of
`Runner.open` owns that cleanup. Returned strings remain owned after runner close.
Local reader/runner disposal does not release the durable caller capture hold.
Public followup/release conveniences and the remaining language matrix remain
M15 work.
