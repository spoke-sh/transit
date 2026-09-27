# transit-station-grpc-worker

The finite M16 Zig worker composes the [RPC adapter](../../packages/zig/transit-station-grpc/README.md)
with the shared [Exchange worker/service helpers](../../packages/zig/transit-exchange/README.md).
`just test::grpc-worker` qualifies all four shapes, partial-capture worker loss,
node/store restart, explicit retry, current-policy reads and bounded cleanup over
disk Ursula. Installed callers pass in every M11 language. The Zig
[caller example](../../examples/station-grpc/README.md) also qualifies local,
Compose and isolated Kubernetes/Substrate recovery;
[proof details](../../tests/README.md#m16-connector-work-in-progress) separate these limits.

Build with `zig build transit-station-grpc-worker`. Supply one JSON configuration
file with authority URL, realm/principal/seed file, PID/fresh generation, activation
marker directory, state association, exchange ID, endpoint revision and finite
endpoint configuration. The endpoint pins a numeric IPv4 destination, TLS host,
explicit CA file and network/byte/message limits. Credentials bind immutable
binding/version/metadata names to local files; at most 16 files, 4 KiB each.
Resolve them only after dispatch and zero their memory on completion. No secret
values or local secret paths enter capture, stdout or diagnostic events.

`prepare` reads a canonical Request JSON file and a GRB1 batch file, validates
frozen policy, publishes the independent exchange copy and commits one intent.
`accept` obtains those inputs from an authenticated caller's sealed publications
under current read grants, exact method/schema/metadata scope and a fixed reply
route. `execute` validates the captured request against current configuration,
then dispatches only a pending effect. An already authorized predecessor is
closed unknown without resending. Complete capture can resume observation and
settlement. An explicit retry has a new exchange/effect and identical frozen
request/policy/key, consuming the original EXB2 budget and deadline.

The physical connection belongs to one invocation. Each OS invocation requires
fresh ownership; a private exclusive activation marker prevents re-entering a
used generation. This is explicit operator placement, without automatic growing
runtime bindings or supervision. Public admission uses a separately configured
caller PID/resource/scope. Associations confer no grant or implicit lifetime hold.
Capture resources must have neither an owner nor a deadline.

`poll` advances pending mailbox admission; `release` explicitly disposes the
recorded caller hold, retires availability and performs up to `cleanup_steps`
(default 64, maximum 128) bounded reclamation steps. Unsettled effects, descendant
holds and other consumers prevent retirement. No retention timer is implicit.
A fresh invocation resumes unfinished cleanup with the same exchange identity.

Per-call capture admits at most 256 segments / 384 KiB, with 8 KiB segments and
4 KiB body parts. This accounts for a 64 KiB outgoing batch, 256 KiB incoming
framed bytes, indexed message headers and policy/metadata. It does not limit the
number of retained calls. The deployment must provision ordinary capture capacity;
the kernel control reserve does not fund arbitrary framework writes.

Structured bounded stderr events are `service.*`, `grpc.worker.operation` and
`grpc.transport.completed`. Stdout is one JSON summary separating capture phase
from kernel outcome. Status is captured RPC evidence, not business success;
closure never promises cancellation or rollback at the peer. All message/body
replay uses the public current-availability reader with dialing and credentials
absent. Board metadata qualification is in progress.
