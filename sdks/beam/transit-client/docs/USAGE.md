# Erlang client usage

Build with `nix develop .#bindings -c just bindings::beam-build`. Extract
`transit_client-0.0.1.tar.gz` and `transit_native_client-0.0.1.tar.gz` into a normal
OTP library directory and set `ERL_LIBS` to that directory. For example:

```sh
mkdir -p /tmp/transit-libs
tar -xzf .cache/bindings/beam/transit_client-0.0.1.tar.gz -C /tmp/transit-libs
tar -xzf .cache/bindings/beam/transit_native_client-0.0.1.tar.gz -C /tmp/transit-libs
ERL_LIBS=/tmp/transit-libs erl
```

Compile consumers with `-include_lib("transit_client/include/transit_client.hrl")`
and ordinary `erlc`. Artifacts include standard `.app` manifests, compiled
modules, public headers and generated schemas. Direct dependency versions are
recorded in `rebar.config`; native discovery checks the exact 0.0.1 application
version. No manual executable/library paths are needed. This installation proof
uses standard OTP application resolution, not Rebar/Hex registry resolution.
Artifacts target OTP 28/Linux x86_64 and ARM64 and require the pinned Nix runtime closure.

## Operations and uncertainty

Construct explicit `config(Url, native_v1)`, `process(Realm, DurablePid)` and
`credential(Realm, Principal, SeedFile)` values. These return `{ok, Record}` or
`{error, #transit_error{}}`; constructors enforce the protocol counter bounds.
The principal can be zero. URLs, profile and timeout are explicit. The optional
`native_host` configuration override is still checked for compatible framing and
versions. Loading the application starts no port or credential work.

`open/1` returns an opaque local client handle. `capabilities/2` reads current
authority capabilities with the explicit credential. `prepare_send/5` takes the
client, typed process reference, binary payload, credential and exact sequence.
It freezes the signed operation through Zig and returns `{ok, Pending}` without
sending it. `info/1` exposes its typed identity/peer/principal/sequence;
`export/1` returns its immutable exact binary. Synchronize that material privately
before dispatch if host-loss retry is required. Signed requests can contain
application data: do not log them or whole pending values.

`dispatch/2` returns `{admitted, #transit_admission{}}`,
`{rejected, #transit_error{}}` or `{uncertain, ExactBytes, #transit_error{}}`.
Admission does not mean that a Station handler ran or a peer replied.
`recover_send/2` validates exported bytes through native metadata and rejects
non-send/unsupported profiles. It needs no seed file; `dispatch/2` rechecks current
authorization. `recover_mutation/2` and `dispatch_mutation/2` provide the corresponding
explicit recovery path for other growing commands, returning a
`{confirmed, #transit_receipt{}}`. Never parse/re-encode, re-sign or change the
sequence of an uncertain operation to make retry convenient.

`evidence/1` returns the last admission/mutation receipt. Native protocol statuses
and bounded error codes remain available without credential paths or arbitrary
callback exception details. Revoked access, rejection, uncertainty, stale
ownership, retirement and unavailable history remain distinct. Protocol counters
are bounded exact Erlang integers; payload/application integers are governed by
the application codec. Binaries are immutable and remain valid independently of
native memory or client cleanup.

## Scheduling, cancellation and cleanup

One coordinator and one worker own one native port. An atomic ETS admission slot
rejects overlap before queuing a request. A caller dying between reservation and
publication leaves a reclaimable ticket; once admitted, the reservation belongs
to the live worker. Killing a waiting process therefore cannot release the slot
or cancel its native work. Native I/O suspends only that worker's receive, not a
BEAM scheduler. Requests/responses have the generated 528 KiB line bound and
65-second deadline; JSON validation bounds nesting, rejects duplicate fields and
uses binary keys without creating atoms. No signing, transitions or authority
validation are reimplemented in BEAM.

`close/1` stops admission, joins admitted work and returns
`{ok, #transit_shutdown{}}` after the native shutdown acknowledgement and successful
child exit. Cleanup failure returns `{error, Error, Evidence}`. Keep that returned
evidence; the closed coordinator terminates and subsequent operations return
`closed`. Observe the close call rather than abandoning its result. A caller
abandoning an earlier dispatch can still join through close. Graceful owner death
also drains the owned job. Abrupt VM/process kill can lose local evidence; only
saved exact retry material or fresh-ownership reconciliation handles that loss.
Neither close nor garbage collection rejects, commits or durably cancels work.

For local supervision, use `child_spec(Config)`, obtain the child PID through the
supervisor, then call `handle(Pid)`. The child is transient and has a 70-second
shutdown budget; the coordinator joins from `terminate/2` as well as explicit
close. Its worker remains responsible for native cleanup during parent shutdown.
The internal join is bounded at 68 seconds; forcing shutdown can leave an unknown
remote outcome. Application callbacks added by Station need their own execution
bounds. Supervision restarts a local bridge, never a durable Transit process or
an execution grant. A local BEAM PID and `#transit_process{}` are different types.
Do not route arbitrary unbounded application messages through the bridge; its
public operation queue has one slot, not an application mailbox/backlog service.

M9's `transit_station` remains the low-level Station JSON adapter. This independent
raw client imports neither it nor Fuze. Public Station runners are a separate M11
package; raw-client qualification does not imply public handler qualification.
