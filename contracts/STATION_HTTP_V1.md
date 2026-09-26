# Station HTTP capture v1

Status: experimental M15 implementation profile. Finite public service admission
is implemented; all-language bindings remain unfinished. This protocol-specific layer uses the
[exchange contract](STATION_EXCHANGE_V1.md); it adds no kernel authority.

## Requests and scope

The public Zig `Request` owns the request JSON shape. Method is one of GET, HEAD,
POST, PUT, PATCH, DELETE or OPTIONS. Target is an ordered list of pieces, beginning
with a slash literal. Pieces are `literal:string`, `variable:{name,value}` or
`secret:{binding,version}`. Secrets are forbidden in targets. Ordinary target
variables use UTF-8 byte percent-encoding; literals preserve their escaped bytes.
The fully rendered target cannot begin `//`, contain whitespace, a fragment or a
backslash. Header values preserve literal/ordinary bytes after control validation.
Bindings have nonempty ASCII alphanumeric/dot/underscore/hyphen names, at most
128 bytes; secret versions are nonzero. No interpolation invokes a network lookup.

Headers are ordered `{name,value:[pieces]}` entries; duplicate application fields
retain order. Host, Content-Length, Transfer-Encoding, Connection, Proxy-Authorization,
Proxy-Connection, Upgrade, Expect, Accept-Encoding, Trailer and TE are transport-owned.
Bodies are uninterpreted bytes with an exact declared length. Each request head is
at most 8,192 bytes, has at most 64 application headers and 128 pieces per field.
Capture renders `{{secrets.name@version}}`; only the authorized executor resolves
that binding into a private, subsequently cleared wire buffer. Literal credentials
are not a supported substitute for typed secret references.

The finite worker freezes endpoint revision, scheme, authority, pinned IPv4 address,
port, timeout/byte bounds, ordered response-header allowlist and an explicit CA
bundle digest before dispatch. HTTPS requires that bundle (at most 1 MiB); it is a
trusted immutable deployment input, as are versioned credential files. It must not
change during an activation. TLS authenticates the named authority, not the numeric
address. No ambient proxy, DNS choice, redirect or transparent retry changes scope.
The worker clamps its live timeout to the remaining original reconciliation budget.
An already-authorized send may still be in flight after policy changes or closure.

## Finite public admission and outcomes

`RequestRecord.prepare` validates the request and computes two Publication specs.
The caller publishes metadata as record 1 and the body as record 2 in its own
namespace, both in format 1, before sending a Station `call` carrying `HTQ1`.
Empty bodies still have a published empty record. Metadata is at most 8,192 bytes;
the finite request body is at most 65,536 bytes. The reference is a commitment,
not permission to read either resource. Each chunk read rechecks current grants,
publication availability and the exact immutable spec before advancing its digest.
PID-scoped readers additionally require a recorded association to foreign request
or capture resources. These associations are optional dependencies; they grant
no access and do not make the connector's execution lifetime depend on the caller.

The initial service admits one exchange per provisioned worker PID. Its configured
policy fixes one authenticated caller PID, caller-written request resource,
endpoint revision, latest reconciliation deadline, maximum attempts, exact HTTP
method and rendered target, and a case-insensitive header-name allowlist. Admission
checks the authenticated process origin; external inputs cannot impersonate calls.
The worker copies and validates request data before freezing its effect and
rechecks current method/target/header scope before dispatch. Endpoint and credential
scope remain separate checks. There is no wildcard path matching or implicit
metadata/admin endpoint exception.

Strict binary layouts use little-endian fields without padding:

| Magic | Fields following the magic | Total bytes |
| --- | --- | --- |
| HTQ1 | resource:u64, namespace:u64, metadata_bytes:u32, metadata_digest:32 bytes, body_bytes:u32, body_digest:32 bytes, endpoint_revision:u64, reconcile_before_ms:u64, max_attempts:u32 | 112 |
| HTA1 | caller:u64, input:u64, correlation:u64, phase:u8, request:112 bytes | 141 |
| HTR1 | phase:u8, resource:u64, exchange:u64, effect:u64, attempt:u64, status:u16, chain:32 bytes | 71 |
| HTF1 | reason:u8 | 5 |

`HTA1` is private service state at exchange key `r/0`; phases are admitted=1 and
published=2. Admission creates the exchange and route in three mutations, leaving
one for framework initialization. Exact repeated calls retain the original input
and route; conflicting calls reply busy. Rejections are denied=1,
invalid_request=2 and busy=3. They create no exchange or external effect.

`HTR1` is a Station reply to the recorded caller/correlation. Phases are observed=1,
closed_unknown=2 and not_dispatched=3. Only observed carries HTTP status and an
EXR1-equivalent complete capture reference. Unknown has the original effect/attempt
but no complete reference; not_dispatched has no attempt. Neither invents a remote
failure or cancellation. The service atomically publishes its reply and marks
the route published only after terminal kernel settlement, or after preparation
was explicitly abandoned before intent. It does not release the caller replay hold.

Capture uses an independent resource with no owner or deadline. Its writer and
effect owner are the connector PID, distinct from the caller. Fresh ownership of
that PID can reconcile after caller termination; replies still target the old PID
and never a replacement found through a name. This does not make a terminated
connector PID restartable. Request publication must remain readable until copied;
the frozen capture thereafter owns its own bytes. If validation or copying fails,
the admitted route remains durable. A fresh authorized activation may resume, or
the controller may explicitly abandon it in `release` mode and publish
not_dispatched. There is no automatic deletion or implicit expiry on failure.

Public followup submission, multi-exchange queue scheduling and caller release
conveniences are not part of this initial admission surface. Explicit controller
followups retain the policies below; the remaining M15 SDK/lifecycle obligations
must be qualified before claiming a completed public connector.

## Explicit followup policies

`Policy.Prepared` owns the frozen metadata shape. It contains the typed request,
endpoint/capture/trust scope and optional versioned retry, redirect, reconciliation
and cancellation policies. The trusted worker checks current grants and requires
the parent's terminal kernel disposition before making another effect. Policy
references record decisions; they confer no dispatch authority.

Retry requires a closed unknown parent, identical request metadata/body and one
literal nonempty idempotency key under the declared endpoint contract. Redirect
requires an observed complete redirect and one captured Location. The finite
profile supports only an exact origin-form target at the same authority, preserving
credentials/method/body; methods besides GET/HEAD require 307/308. Missing, omitted,
duplicate, cross-authority or changed destinations reject before a new effect.

Status/cancellation actions freeze the exact literal target and method at root
preparation. A status query uses GET/HEAD; cancellation uses POST/DELETE. Both have
empty bodies and preserve credential/header scope. They require a closed unknown
parent; each is an independently authorized and captured effect. They neither
rewrite the original unknown outcome nor prove remote cancellation succeeded.
Every followup shares the original lineage, total attempt budget and deadline.

## Captured records

All records are immutable exchange members in protocol format 1. Kinds are:

| Kind | Value | Meaning |
| --- | --- | --- |
| request_template | 1 | Versioned finite-worker metadata, immutable ordinary bindings and secret references |
| request_head | 2 | Rendered HTTP/1.1 head with credential references |
| request_body | 3 | Ordered raw request body segments; empty body has one empty record |
| response_head | 4 | Up to four informational heads, then one final head |
| response_body | 5 | Ordered body bytes after HTTP transfer framing; empty is explicit |
| response_trailers | 6 | Optional ordered trailer lines |
| timing | 7 | One `HTT1` timing record |
| omission | 8 | One `HTO1` omission record |
| completion | 9 | One final `HTC1` protocol coverage record |

A record may cross publication chunks; heads/trailers may span capture segments.
No chunk boundary invents an HTTP message boundary. The transport captures at most
4,096 bytes per callback and waits for durable sealing before reusing that buffer.
HTTP transfer coding is removed from body bytes; this is application-boundary
capture, not TCP/TLS packet or chunk-extension capture. Compression other than
identity, protocol switching, ambiguous framing and unframed TLS bodies reject.

Header names and approved lines retain their bytes/order. Non-allowlisted values
become `{{omitted}}`; Set-Cookie, Authorization, Proxy-Authorization,
WWW-Authenticate and Proxy-Authenticate are always omitted. Omission counts include
informational heads, the final head and trailers. Redaction cannot promise exact
secret-bearing wire bytes. The request template and ordinary application body
remain subject to the resource's transcript permissions.

Binary records use the shared strict little-endian codec without native padding:

| Magic | Fields following the four-byte magic | Total bytes |
| --- | --- | --- |
| HTT1 | started_ms:u64, elapsed_ns:u64 | 20 |
| HTO1 | response_headers:u32, request_secrets:u32 | 12 |
| HTC1 | status:u16, request_bytes:u64, response_bytes:u64, heads:u8, framing:u8 | 24 |

Timing uses wall-clock start and monotonic elapsed duration through response
capture, excluding the final three metadata seals. It carries no URL or payload.
Framing values are none=1, length=2, chunked=3, close=4. The status is 200–599;
heads is 1–5. `none` has zero response bytes. HTTP status is not business success.
The exchange terminal code must match HTC1. Unknown capture has no complete replay
claim, even if a status line, body prefix or some terminal metadata was sealed.

## Replay and fixtures

`Replay` composes current-policy exchange reads with a bounded HTTP validator.
It checks required kinds/order, complete heads, request/body counts, final status,
timing/omission/completion records and shared digest/coverage. Only its final
`complete` part establishes replay completion. `require_unredacted` rejects captures
with omitted response fields or request secret references as `HttpReplayGap`.
Missing records and prequalification captures lacking terminal records also return
gaps. A failed reader must be reopened under current permissions. This API accepts
no network, DNS or credential resolver and cannot refetch missing data.

The [HTTP fixtures](../packages/zig/transit-station-http/src/fixtures.json) fix
Unicode escaping, duplicate header order, credential-reference rendering and
terminal encodings. The [exchange fixtures](../packages/zig/transit-exchange/src/fixtures.json)
fix full-width application identities, empty/binary publication bytes and ordered
coverage chains. Expected bytes were independently constructed with Python's
`struct` and `hashlib`; Zig tests consume those bytes, recompute commitments and
reject malformed versions/lengths. Future host APIs must consume these same
fixtures and shared Zig behavior rather than implementing another HTTP lifecycle.
The [admission fixtures](../packages/zig/transit-station-http/src/admission-fixtures.json)
independently fix caller metadata, binary body commitments, full-width namespaces,
routes, outcomes and rejection encodings.
