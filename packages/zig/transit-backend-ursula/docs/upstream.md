# Upstream integration and dependency updates

[transit-backend-ursula](../README.md)

## Pinned dependencies

Ursula 0.5.1 and its matching `ursulactl` CLI are pinned in the dev shell
through [ursula-overlay](https://github.com/rupurt/ursula-overlay). `flake.lock`
records the overlay revision. [ursula-zig](https://github.com/rupurt/ursula-zig)
is the selected Zig client, pinned by revision and package hash in
[build.zig.zon](../build.zig.zon).

The local Nix provider includes the
[cold-flush planner correction](../../../../nix/ursula.nix). It sizes subsequent
chunks against the remaining batch budget, so a busy small journal cannot
repeatedly block a larger page stream from using that space. The upstream source,
Cargo lock and Rust toolchain stay pinned; the patch changes neither storage
formats nor admission limits. Its derivation runs the upstream stream tests and
a repeated mixed-stream flushing regression. See the
[toolchain guide](../../../../nix/README.md) for build and update ownership.

Container deployments use the [official Ursula image](https://github.com/tonbo-io/ursula/pkgs/container/ursula),
not a separately built Nix image. The matching `0.5.1` release and immutable
multi-platform manifest digest are pinned in
[`deploy/reference/versions.json`](../../../../deploy/reference/versions.json). Update this
pin deliberately alongside the development overlay and rerun disk recovery
checks. Supply an explicit disk-backed configuration and persistent volume;
the upstream image's bundled configuration uses an in-memory WAL. These official
images do not include the local Nix cold-flush correction; local latency results
do not qualify the image's behavior under that pressure schedule.

## Client integration surface

These operations are available through `ursula-zig`; API availability is
distinct from a verified Transit integration against the pinned server. Keep Ursula-specific behavior explicit in contract fixtures.

| Transit operation | Ursula API |
| --- | --- |
| Provision namespace and stream | `PUT /{bucket}`, then `PUT /{bucket}/{stream}` |
| Append command/event bytes | `POST /{bucket}/{stream}` |
| Read retained history | `GET /{bucket}/{stream}?offset=...` |
| Tail new data | GET with `live=long-poll` or `live=sse` |
| Inspect stream metadata | `HEAD /{bucket}/{stream}` |

The reviewed upstream API overview listed bucket stream enumeration as
unimplemented; Transit owns its stream catalog/naming scheme. This storage catalog is separate
from Station's registered-name-to-PID registry. See
[API overview](https://ursula.tonbo.io/docs/api/overview/).

Treat `Stream-Next-Offset` as an opaque continuation position and `Stream-Cursor`
as a separate cache token. Echo the cursor unchanged alongside the next offset
or record position; it is not a checkpoint or stream-incarnation identifier.
The pinned client exposes these as `ReadOptions.position` and `ReadOptions.cursor`.
Its former `Position.cursor` API treated the cursor as a position and could not
send both together; [ursula-zig PR #1](https://github.com/rupurt/ursula-zig/pull/1)
fixes that model. Transit's disk-backed proof wakes on an append, then checks that
offset-plus-cursor and record-plus-cursor long polls return only the next record.

Direct HTTP checks independent of the client, including the official 0.5.1 image,
also confirmed a server documentation mismatch: cursor-only catch-up requests
reread from the earliest retained data, while cursor-only live requests return `400` because
they lack a start position. Recreating the same stream path does not make an
old cursor detect a new incarnation. The guide's cursor-as-position and
cursor/epoch claims are tracked in [Ursula #317](https://github.com/tonbo-io/ursula/issues/317).
Transit uses explicit record positions and unreused physical identities. The
selected client restricts `max_records` to record-coordinate requests;
byte-offset reads use `max_bytes`.

`offset=-1` starts at the earliest retained data, not necessarily the original
beginning. Handle trimmed positions (`410 Gone`) through explicit restore policy.
See [offsets](https://ursula.tonbo.io/docs/concepts/offsets/) for the upstream
description, qualified by this executable finding.

The client leaves retries, live-read reconnects, deadlines, and redirects to its
caller. Transit must inspect HTTP status and response metadata before advancing
producer or consumer state. Follow redirects only to configured trusted
endpoints, preserving the method, body, and append identity. See the upstream
[usage and lifetime rules](https://github.com/rupurt/ursula-zig/blob/2d507829429d4199f411df02df9cc937bf624144/docs/usage.md).

Extending live streaming/routing requires tests for partial responses,
cancellation, bounded buffering, reconnects, and leader redirects. SSE support
in the upstream client is not a claim of a Transit subscription API. Use the library's SSE decoder and
copy borrowed continuation metadata before releasing its response. Checkpoint
only after applying the preceding data; a closed connection alone does not mean
the stream is complete. Choose the payload encoding and its record framing
before connecting producers to consumers; an HTTP chunk is not a domain event
boundary.

## Producer and consumer state

Ursula's append deduplication uses `Producer-Id`, `Producer-Epoch`, and
`Producer-Seq`, scoped per producer and stream. Sequences advance contiguously
within an epoch. Receipt history covers the current epoch; a newer epoch replaces
the previous epoch's receipts. See
[exactly-once writes](https://ursula.tonbo.io/docs/concepts/exactly-once-writes/).

Transit's producer recovery design must durably associate pending payloads with their
append identities and stable domain event IDs. Retrying an uncertain append in
a new epoch can defeat transport deduplication. Prove recovery/fencing behavior
before advancing epochs or taking over producer ownership.

Transit owns process sequence validation, ownership, consumer positions, recoverable
state, and output delivery. Kernel ownership generations and Ursula producer
epochs are distinct; the mapping must not let a stale worker regain authority
by choosing a new producer identity or epoch. Do not infer consumer scheduling
or multi-stream transactions from append deduplication.

The current authority uses conditional record-tail append, not Ursula producer
deduplication. Policy and process operations share the realm journal, so grant,
revocation, and commit ordering require no cross-stream transaction. A future
split must prove its coordination protocol; independently successful appends
or a trusted-writer convention do not establish atomic authority.

Mailboxes and exchange stream groups are Transit abstractions over Ursula. Group
membership, complete-record visibility, and safe retention need explicit
manifests and policies; do not assume a native group/transaction API. Follow
[STREAMS.md](../../../../docs/reference/streams.md) and [CONNECTORS.md](../../../../docs/reference/connectors.md).

## Updating the client dependency

[ursula-zig](https://github.com/rupurt/ursula-zig) is the selected application
library. The `transit-backend-ursula` package owns the `ursula_zig` dependency in
its `build.zig.zon`, pinned to an immutable revision URL and Zig package hash.
The upstream client exports the `ursula` module;
see its
[build integration](https://github.com/rupurt/ursula-zig/blob/2d507829429d4199f411df02df9cc937bf624144/docs/usage.md).
The adapter now pins that revision and its Zig package hash; `just build::debug apps` and
`just test::storage` compile and exercise the consuming backend. The Git URL avoids
a tarball-root handling failure observed in this pinned compiler's build fetch.

The reviewed client revision `2d507829429d4199f411df02df9cc937bf624144` declares
Zig `0.17.0-dev.2251+1175a3e99` as its minimum version. Transit now uses
`0.17.0-dev.2267+48abf1a34` for M9 Arrow integration; the Ursula server pin is
unchanged. Compatibility is checked through the consuming package tests.
`just ci` builds the consuming packages and runs disk-backed integration and
recovery checks against that server. See the client
[package metadata](https://github.com/rupurt/ursula-zig/blob/2d507829429d4199f411df02df9cc937bf624144/build.zig.zon)
and [toolchain pins](https://github.com/rupurt/ursula-zig/blob/2d507829429d4199f411df02df9cc937bf624144/flake.lock).

This revision includes [the cursor API fix](https://github.com/rupurt/ursula-zig/pull/1):
set the continuation offset or record position in `ReadOptions.position` and
echo the independent cache token in `ReadOptions.cursor`. `Position.cursor` was
removed. The storage proof exercises both position types with the cursor; the
journal adapter's existing record-position reads need no API migration.

Updating `ursula-overlay` changes the server tools; update the Zig source
dependency separately. Check client/compiler/server compatibility and rerun the
backend integration and recovery checks with `just ci`.

During this dependency update, the pinned Zig reused a stale build configuration
that still selected the old client despite the new manifest and fetched package.
Clearing the affected build root's ignored `.zig-cache/` forced resolution of
the new pin. If compilation still references an old package hash after an update,
clear that local cache and rerun `just ci`.
