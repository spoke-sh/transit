# transit-station-http

The first HTTP connector, under implementation in [M15](../../../docs/roadmap/M15.md).
This package owns HTTP-specific request construction, framing and capture kinds;
[transit-exchange](../transit-exchange/README.md) owns durable capture and coverage.
The pure API does not dispatch effects. `Transport.execute` performs one finite
HTTP/1.1 exchange when called by a trusted, freshly authorized executor; it never
retries or follows a redirect. Durable worker/deployment qualification remains open.

`Request` builds HTTP/1.1 heads from typed literal/variable/secret pieces. Target
variables are percent-encoded; header fields reject control-byte injection.
Transport-owned routing/framing headers cannot be overridden. Duplicate ordinary
headers retain order. Capture renders versioned credential references; only an
explicit executor resolver produces secret-bearing wire bytes. Keep its buffers
private and discard them after the authorized attempt.

`validateResponse` rejects ambiguous content lengths/transfer coding and unsupported
compression before capture. `beginSegment` adapts HTTP record kinds to the shared
Publication commitment. A status line, successfully parsed head or sealed body
segment is not a complete response or kernel-accepted outcome.

Head buffers, header counts and template-piece counts are bounded per operation;
exchange history is paged durable state. Capture/replay retains exact non-secret
bytes at the declared application HTTP boundary, with explicit omissions for
secret-bearing fields. It is not a TLS packet capture.

Run `nix develop --command bash -c 'cd packages/zig/transit-station-http && zig build test'`.
Run `just test::http-transport` for independent HTTP/TLS peers. The first transport
profile dials a provisioned IPv4 address and authenticates the configured TLS
hostname. It does not consult ambient DNS or proxies. Response header capture is
allowlisted, always omits credential fields, and reports omissions; unsupported
compression and unframed TLS bodies fail explicitly. Request/response byte and
deadline budgets are explicit endpoint configuration. A callback seals each
bounded capture segment before its buffer is reused. Capture failure or timeout
does not prove the remote operation failed.

TLS uses [transit-tls](../transit-tls/README.md), which adds bounded whole-chain
certificate verification to the pinned compiler's client. The independent peer
suite accepts valid TLS 1.2/1.3 chains and rejects non-CA signers, missing signing
usage, exceeded path length, wrong server purpose and excluded DNS names before
HTTP request bytes. The socket is dedicated to one exchange; neither TLS nor HTTP
can reconnect or retry it. This does not add certificate revocation lookups.

The final capture includes timing, omission counts and protocol coverage with
status/body counts. `Replay.open`/`read` composes current-grant reads, shared digest
verification and bounded HTTP record validation. Prefixes remain provisional until
the final `complete` part. `require_unredacted` reports `HttpReplayGap` when required
secret-bearing fields were omitted; neither replay mode can invoke transport or
credentials. See the [HTTP wire contract and fixtures](../../../contracts/STATION_HTTP_V1.md).

`Policy.followup` is the pure versioned request-change validator. It permits exact
idempotent retries, captured same-authority redirects and declared status/cancel
actions. It rejects destination, credential, policy and method/body changes outside
that explicit decision. The worker still owns current dispatch authority and the
shared exchange layer owns lineage/budgets; this helper performs no I/O.
The [connector design](../../../docs/reference/connectors.md) and
[exchange contract](../../../contracts/STATION_EXCHANGE_V1.md) own authority,
lifetime, unknown-outcome and replay requirements.

`RequestRecord.prepare` returns canonical metadata and a typed commitment to the
caller-published metadata/body records. `Service.admit` stores a fixed authenticated
caller/correlation route and finite exchange; `Service.publish` emits a durable
outcome after kernel settlement. Both compose with growing turns under the four
mutation budget. `Service.validateRequest` enforces exact method/serialized-target
and allowed header names; endpoint, credential and current resource grants remain
separate worker checks. `Outcome.reference` refuses unknown/not-dispatched results.
`Outcome.diagnostic(realm)` and `Rejection.diagnostic()` project the shared owned
diagnostic. HTTP status is retained separately from capture completion; a
completed 4xx/5xx response does not authorize retry or prove remote rollback.
The [worker admission guide](../../../apps/transit-station-http-worker/docs/admission.md)
describes the finite service profile and recovery limits.

`Service.Release`/`Released` are the explicit caller disposal call and correlated
acknowledgement. `Service.release` authenticates the original caller and current
policy, then releases the terminal hold atomically with its reply. It never
dispatches, retires capture or discards another consumer's dependency. Duplicate
disposal remains valid after retirement; local replay close is separate.

`RequestRecord.stage` reserves a namespace, freezes the full request identity and
advances one bounded publication step per turn. Repeat with identical recoverable
metadata/body until it returns true, then call in that turn. It rejects changed
identity after restart and cannot resurrect retired records. The caller supplies
continuation scheduling and keeps source bytes recoverable until publication.

`Service.admitFollowup` authenticates an HTU1 call from the original caller and
checks its published terminal parent before invoking a trusted validator for the
new request bytes. The callback must validate the frozen endpoint policy without
dispatching. Read errors roll back the turn; rejections allocate nothing. A valid
child records its new correlation in EXL2 context atomically with lineage and
root-budget consumption. Terminal publication uses the existing HTR1 reply.

`Inspection.read` projects metadata from a caller-supplied current authorized
source. It reads the request-template member (at most 8 KiB) and, for a complete
capture, the final timing/omission/completion members (at most 256 bytes each).
It verifies those publication digests and terminal coverage links, without reading
private head/body members or replaying the whole transcript. Returned policy
fields omit hosts, addresses, targets, headers, ordinary bindings and credential
references. Partial captures have no terminal metadata; retired captures reject.
The caller must maintain one resource revision and current access on every read.
Board uses the public read adapter and does not acquire a retained owner view.

Incomplete terminal capture includes the original Exchange failure witness:
reason/cause, capture operation and input, original phase and sealed prefix.
It requires current read authority and does not disclose routing, bodies or
credentials. This evidence is separate from native effect settlement. A worker
replays an admitted failure input after replacement; a cause lost before admission
is explicitly unrecorded. The worker JSON returns separate nullable capture and
effect diagnostics without claiming remote rollback or authorizing a fresh send.

The transport preserves available socket, TLS and HTTP body-framing causes.
Its owned chunk parser checks hexadecimal sizes, CRLF and extension syntax with
fixed 8 KiB line/trailer storage. Size overflow, malformed framing, truncated
chunks, line/trailer bounds and response-body capacity remain distinct errors.
`CertificateHostMismatch` differs from an untrusted or invalid certificate path;
TLS truncation and invalid/truncated HTTP chunks differ from a generic read
failure. Request-body input failures are distinct from missing/truncated response
heads. Capture callback failures keep their own cause. These details do not
change timeout, certificate verification, partial-capture or no-retry semantics.

Admission rejection diagnostics retain the original delivered input commitment,
failing field and check, expected/supplied values, and original validation cause.
Strings are bounded with explicit truncation; credential values and foreign-caller
state remain withheld. See the [shared admission layout](../../../contracts/CONNECTOR_ADMISSION_V1.md)
and [connector semantics](../../../docs/reference/connectors.md).
