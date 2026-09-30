# Ruby Station SDK

`require 'transit/station'` exposes `Transit::Station`; loading starts no worker
and discovers no credentials. The gem depends on independent `transit-client`
and version-matched `transit-native-station`. Install built gems through RubyGems;
no repository source or manual native loader path is required. `native_host` is
an explicit trusted Station executable override. ABI/capability mismatches reject
without falling back to incompatible definitions.

## Handler and runner

Subclass `Transit::Station::Handler` and implement `on_message(turn, input)`.
`on_start(turn)` initializes associated state in the same private proposal as
the first input. Ruby's ordinary `initialize` remains the object constructor.
Application fields disappear with the host; associated state is durable.

Use a codec implementing `type_id`, `version`, `max_encoded_bytes`, `encode` and
`decode`. It must reject malformed/trailing/unsupported bytes and validate host
values. Codecs preserve application integers up to u64/i64 bounds. Decode runs
before initialization or message dispatch; wrong-role messages never reach a
handler. The [example codecs](../../../../examples/station-sdk/ruby/README.md)
implement the same formats as Python, TypeScript and Rust.

`ServiceConfig` contains an explicit growing `ClientConfig`, `Activation`,
association (default `data`) and `query_results` opt-in. An activation requires a
`ProcessRef`, ownership generation and `Credential`. Provision current ownership,
process/resource grants and the association before opening the runner.

```ruby
Transit::Station::Runner.open(config, handler: handler, codec: codec,
    failure: :stop, recovery: store) do |runner|
  runner.each do |event|
    case event
    when Transit::Station::Committed
      observe_commit(event.input, event.receipt)
    when Transit::Station::NeedsRecovery
      save_observation(event) # Exact mutation and any known receipt remain available.
    when Transit::Station::Idle
      sleep 0.02
    end
  end
end
```

The configuration, handler, codec, store and observers are application inputs;
the installed examples are runnable implementations. Returning from a callback
does not prove commitment. `next` performs bounded preparation and at most one
mutation dispatch, returning `Committed`, `Blocked`, `NeedsRecovery`, `Idle` or
`Progress`. `nil` means local stop. `each` yields those observations and ends
after a recovery event; `reconcile` explicitly retries/observes pending work.
Repeated `next` on a paused runner preserves the same event and never reruns the
handler. Control and verified complete-result inputs invoke `on_control` and
`on_result` separately from application decoding.

Failure policy `:stop` discards private changes and leaves the input pending.
`:block_input` records an explicit failure marker without consuming it. Callback
exceptions, including exceptions outside `StandardError`, use that policy; none
cross into the native process. Process death follows host-loss recovery. Native
read failures poison the proposal even when the handler catches the error.
The guard covers application decoding and typed page/result conversion as well
as native I/O. Codec reentry returns `Busy`; a caught decoder failure still
aborts the proposal and cannot record a block marker.

## Scoped data and messages

`turn.state` supports `find`, `require`, `put`, `delete` and `page` through `Key`
objects pairing binary names and codecs. `Found(nil)` is distinct from an absent
key. Tables use `TableSchema(id:, value_type:)` with `:int64`, `:boolean`, `:utf8`
or `:binary`, i64 keys and nullable values. `get`, `insert`, `update`, `upsert`,
`delete` and `page` enforce the captured native schema and operation bounds.

Pages own their entries and opaque cursors; at most eight entries are admitted
by the current profile. Cursors remain bound to source revisions. `retain`
returns an owned `ReadVersion`, `open_version` provides read-only scoped source
helpers, and `release` stages release. IDs never confer access or resource
lifetime ownership. `turn.budgets` reports remaining mutations, outputs, views
and retained-read operations; initialization consumes a mutation slot.

All turn/resource operations check callback scope, thread and fiber, with one
operation admitted at a time. Keeping a helper in a handler field does not extend
its scope. Owned pages, read-version IDs and manifest/IPC data may outlive it.

`cast` stages a typed message. `call(peer, value, codec:, wait:)` stages a wait
and output and returns the native input-derived correlation. Save that value in
associated state in the same turn. `WaitPolicy.untimed` omits both deadline and
observer; a timed wait supplies both explicitly. A fresh owner resumes through a
recorded reply using `require_reply(input, peer:, correlation:)`. `cancel_call`
stages advisory durable cancellation. Local stop or thread interruption has no
such durable meaning.

## Queries and original IPC

Enable query results on both roles. Service policy is explicit through
`allow_query`; `start_query` takes a `TableSchema` and typed `QueryPlan` with
projection, aggregate, optional limit and predicate. These helpers delegate
capture, planning, execution, credit and acknowledgement to shared Zig.

`on_result(turn, complete)` receives verified completion. Open
`turn.result(complete.correlation)` and read its full manifest and bounded
individual segments. Each read checks current access. Metadata includes source
and destination, correlation, resource/revision/schema basis, plan and chain
digests, policy revision, rows, segments and bytes. Every segment is an independent
IPC stream. `IpcSegment#ipc` returns an owned binary `String` copy and survives
runner disposal. A segment alone does not prove whole-result completeness.
The clean proof independently decodes all streams with PyArrow after closing
Ruby handles; no Ruby Arrow adapter is currently selected.

## Recovery and cleanup

A recovery store implements `before_dispatch(mutation)` and
`confirmed(identity, receipt)`. Returning normally from the first promises that
opaque `mutation.export` bytes were durably saved; raise when persistence fails.
The runner gates every permit, view-open and turn mutation, including framework
query work. A confirmation-hook failure retains the known receipt without
redispatch or handler replay. Store hooks run serially on the owned Ruby worker;
they cannot reenter/join their own runner. `:fence_on_restart` explicitly selects
fresh ownership when no persistence store is supplied.

Use the independent client's `recover_mutation` and `dispatch_mutation` after host
loss to reconcile saved bytes exactly, without the signing seed. A revoked retry
does not convert an earlier uncertainty into rejection. Fresh ownership is
required before a replacement runner makes new decisions.

One Ruby worker and one native child own each runner, with one admitted command.
The synchronous API releases Ruby scheduling during port I/O; it is not a Fiber
scheduler adapter. `stop_token.stop` signals local stop. Killing a waiting caller
thread cannot kill owned native work. `close` stops, joins and returns
`Shutdown(pending:, last_event:)`; cleanup errors retain available evidence.
Block-based `open` protects acquisition until its ensure clause owns the runner,
then permits interruption of user code. Internal admission/acquisition/cleanup
use Ruby's all-interrupt mask, including thread termination; see
[Ruby's thread documentation](https://docs.ruby-lang.org/en/3.4/Thread.html#method-c-handle_interrupt).
Opening without a block still requires caller ownership and close.
Arbitrary application callbacks can prevent graceful join; no timeout can force
honest computation or acknowledge private work.
