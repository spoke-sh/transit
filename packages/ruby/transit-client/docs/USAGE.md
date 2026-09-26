# Ruby raw client

Use `Transit::ClientConfig` with explicit `profile: :growing_v3`, an HTTP endpoint
without URL credentials/query/fragment, and optionally `timeout_ms` (1–60000) or
`native_host`. `ProcessRef` and `ResourceRef` are distinct immutable values;
protocol counters must fit the generated public bound. `Credential` contains a
realm, principal and explicit seed-file reference; its inspection omits the path.
No credential is discovered from the environment.

```ruby
require 'transit/client'

Transit::Client.open(config) do |client|
  pending = client.prepare_send(peer, payload,
    credential: credential, sequence: next_sequence)
  outbox.persist(pending.identity, pending.export)
  case result = client.dispatch(pending)
  when Transit::Admitted
    outbox.confirm(pending.identity, result.receipt)
  when Transit::Rejected
    record_rejection(result.error)
  when Transit::Uncertain
    retain_for_recovery(pending.identity, result.recovery)
  end
end
```

The configuration, payload, sequencer and durable outbox above are application
inputs. A principal's sequencer covers all its handles. `prepare_send` copies the
bounded binary `String` before dispatch. Exported bytes are independent mutable
copies of opaque signed retry material; keep them private. `PendingSend#close`
only releases its local bytes. It does not cancel or reject an operation.

An `AdmissionReceipt` proves mailbox admission, not handler commitment or reply
completion. `recover_send(bytes)` reimports canonical native metadata and rejects
non-send operations before dispatch. `recover_mutation`/`dispatch_mutation` support
exact recovery of other growing mutations and return a distinct `MutationReceipt`.
Recovery does not need a signing seed. Current grants still apply, including
historical retries; a revoked retry cannot resolve an earlier unknown outcome.

Named errors retain `status`, `code` and `phase`. Authorization, stale ownership,
retirement, unavailable history and failed reads remain distinct. Rejected
mutations return `Rejected`; lost or malformed mutation responses return
`Uncertain` with owned recovery bytes. Validation errors before dispatch raise
without implying any accepted work.

## Scheduling and cleanup

One client owns one Ruby worker, one command slot and one native child. The worker
serializes the whole operation, including native metadata validation followed by
dispatch. Concurrent or reentrant work raises `Busy`; it is not queued without a
bound. The native process owns the ABI's stack and bounded transport workspace.
Ruby owns no native pointers. Requests/configuration/responses use generated
size and schema bounds, including exact integers and valid UTF-8.

The API is synchronous. Ruby's other threads continue while native I/O is in
flight. An interrupted or killed caller thread abandons only its wait: the owned
worker continues and stores a confirmed receipt. Retain the client in a surviving
owner and call `close`; the close joins outstanding work and returns
`Shutdown(last_admission:, last_mutation:)`. `evidence` also exposes the last
known receipts after close. Cleanup failure raises `CleanupError` with any captured
shutdown evidence. Closing from a callback cannot join its own worker.

Prefer `Client.open(config) { |client| ... }`, whose ensure clause joins on normal
return or exceptions. Explicit `open` without a block requires explicit `close`.
There is no finalizer that acknowledges or safely recovers work. Process death
requires persisted retry bytes or fresh-ownership reconciliation. Neither local
thread interruption nor closing the native port performs durable cancellation.

Native exchanges have an outer 65-second deadline in addition to the configured
transport timeout. Cleanup joins active work, then gives the child two seconds
to exit before terminating it. Stderr is discarded without buffering credentials
or payloads. Core imports neither Station nor an Arrow library.
