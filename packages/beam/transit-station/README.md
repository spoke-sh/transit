# Station for Erlang and Elixir

`transit_station` owns a [native Zig port](../../../apps/transit-station-host/README.md).
`Transit.Station` exposes the same interface to Elixir. Both use OTP 28's built-in
JSON codec; there are no Hex dependencies or native scheduler extensions.
The pinned baselines are OTP 28 and Elixir 1.18 from `nix develop .#bindings`.

`open/2` takes an explicit executable and host-config path, starts one owned port,
and negotiates the generated ABI version. `next/1`, `apply/2`, `finish/2`,
`pending/1`, `call/2`, `prepare/4` and `arrow_cell/4` reuse the shared framework
and raw client. Results are `{ok, Value}` / `{:ok, value}` or
`{error, {Status, Detail}}` / `{:error, {status, detail}}`. JSON maps use binary
keys, avoiding atom creation from untrusted data. Original Arrow IPC remains a
binary. Decimal-string correlations and int64 cells preserve their full width.

The BEAM GenServer here owns transport; it is distinct from the durable Station
GenServer/PID. Waiting suspends the calling BEAM process, not a scheduler. Each
port admits one operation; overlap returns status 9. Native lines have a 528 KiB
bound and a 65-second deadline. The pipe is written without scheduler suspension.
Applications own their BEAM process/mailbox admission bounds; this wrapper is not
an unbounded host-side work queue.

The port monitors both its owner and its current caller. Owner death, caller
death, explicit close, malformed output and timeout close the handle. Losing a
possible submission returns status 6 (uncertain); process death can also prevent
that result from reaching its caller. Closing the pipe cannot cancel an already
submitted command. Native I/O remains bounded and may finish after the caller
exits. Use `try ... after close` or Elixir `try/after`. For cancellable awaits,
run the call in a monitored process/task; terminating that process also closes
the port. A subsequent activation must reconcile/fence, or retry exact exported
pending material, before recomputing. No BEAM exit implicitly commits or records
a handler failure.

`just bindings::test` compiles Erlang with warnings as errors and Elixir against
that module, then runs both [Erlang](../../../examples/station-bindings/erlang/station_example.erl)
and [Elixir](../../../examples/station-bindings/elixir/main.exs) in real
cross-language service/requester exchanges. It also tests scheduler progress,
owner/caller death, overlapping calls and malformed/oversized/lost ports.
`just bindings::check` checks generated constants and the shared schema resource.
Linux x86_64 is qualified; Hex publication and foreign Substrate workers remain
outside this milestone.
