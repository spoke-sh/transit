# HTTP calls and replay

`Transit.Station.Sdk.Http` wraps the
[Erlang HTTP API](../../transit-station-sdk/docs/http.md) with structs and tagged
results. It preserves the same shared Zig semantics, capacity, current grants
and ownership boundaries. No HTTP protocol or retry semantics live in Elixir.

```elixir
alias Transit.Station.Sdk.Http

request = %Http.Request{
  method: :post,
  target: [Http.literal("/items/"), Http.variable("id", "λ /")],
  headers: [{"Authorization", [Http.literal("Bearer "), Http.secret("api", 7)]}]
}

{:ok, prepared} = Http.prepare(resource, namespace, request, body,
  endpoint_revision: revision, reconcile_before_ms: deadline)
```

Prepared structs contain immutable binaries. Integer identities retain their full
unsigned 64-bit range where the contract permits; resource/deadline counters use
the narrower native bound. Methods, pieces, headers and options are validated
at the shared boundary. Secret pieces contain references, not credential values.

In a handler, `Http.stage(turn, prepared)` contributes one bounded upload step.
On false, commit and arrange another application input. On true,
`Http.call(turn, connector, prepared)` may share the turn with persisting its
correlation. Reconstruct identical bytes after fresh ownership to resume staging.
Keep the original body available until publication; namespaces cannot be reused.
Observe committed runner events and guard against duplicate calls with state.

Application codecs own message dispatch. With a byte-oriented codec, authenticate
an incoming reply using `Turn.require_reply/4` before
`Http.decode_reply(realm, bytes)`. This returns `%Http.Outcome{}` or
`%Http.Rejected{}` and preserves unknown/not-dispatched distinctions. A cast with
outcome-shaped bytes is not a reply. Only observed outcomes have complete capture
references; HTTP status does not establish business success.

```elixir
{:ok, reader} = Http.open(runner, outcome)
{:ok, {part, next_reader}} = Http.Reader.read(reader)
{:ok, :ok} = Http.Reader.close(next_reader)
```

Continue with the new reader returned from every read. Parts are `%Http.Part{}`
with at most 256 owned bytes; `:done` marks end of stream. `complete?/1` on the
new token reports validated completion. Prefixes are provisional. An older token
fails, so a killed waiting task cannot silently skip its undisclosed part.
Current grants are rechecked on every read; a failed stream must be closed and
reopened. `:require_unredacted` rejects gaps. Replay uses no HTTP, DNS or secrets.

Run waits in monitored processes/tasks when cancellation is needed. Losing a
waiter does not cancel owned native work: stop and close the runner to join it.
Closing invalidates readers while returned binaries remain valid. Local reader
disposal does not release durable holds or authorize cleanup. The installed
consumer in `just bindings::beam-sdk-test` exercises this lifecycle through the
public Elixir API and shared independent TLS schedule.
