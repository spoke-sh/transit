# Reactive serving v1 (M20 in progress)

Set `role.gateway.reactive` to `true` and set
`role.gateway.options.request_timeout_ms` to `30000` for the finite streaming
profile. `clock_error_ms` defaults to 1000 (maximum 10000); the host clock must
actually satisfy that bound. A gateway conservatively stops disclosure at local
wall time plus this error reaching the lease deadline. Transport restart does not
renew a lease. Default M19 installations keep this capability disabled.

Provision the gateway reader with inspect scope covering ingress and source plus
explicit read/inspect grants on both resources. A watch publication identifies the
exact target, Table resource/schema and data-progress key. The administrator
publishes it through `Model.Command.reactive.publish`; the configured observer
records time; the caller opens a finite session and subscribes. Each is an ordinary
signed native command with a separately observable commit/disposition. Four live
sessions/service, two/caller and one subscription/session bound aggregate work.

`POST /reactive/v1/read` accepts a signed session, snapshot or event observation.
Snapshot row keys and values are decimal strings. Its first eight rows and `more`
flag are an initial page, with exact finite-query source basis and a signed watch
cursor. Use M18's finite query reader for larger results. An invalidation is
coalesced through its named data watermark; it is not a continuous query answer.

For fetch SSE, obtain a single-use challenge with a signed session read at
`POST /reactive/v1/challenge`. Sign an attachment control binding that nonce and
the expected attachment revision. `POST /reactive/v1/events` takes the `Bootstrap`
containing that native command and signed event read. Resume carries the same
cursor in the read and, when present, the lowercase-hex `Last-Event-ID` header.
Event data is one JSON `ServerMessage`; decode UTF-8 and lines incrementally.

For WebSocket, connect to `/reactive/v1/websocket` with subprotocol
`transit.reactive.v1` and exact configured HTTPS Origin. The server sends a random
challenge; send a typed `attach` message within two seconds. Browser credentials
belong in the signed message body, not URLs, subprotocols or invented handshake
headers. After the durable attachment is observed, `command`, `control` and `read`
messages use the same types as HTTP. An ingress receipt does not prove service
admission or application completion. Keep uncertain native bytes for exact HTTP
recovery. Attachment replacement never changes accepted operation identity.

The listener retains a separate HTTP control pool at
`POST /reactive/v1/control` for renew/unsubscribe/close and trusted observer
controls. New operations/open/attach cannot consume that pool. Current authority
is checked on every message and bounded disclosure, including a 500 ms idle poll.
Each output write has a one-second deadline. A connection has no event history
queue: it holds one coalesced observation. The default handler bounds are four data
requests and two control requests; per-caller data is two with one reserved control.
A WebSocket uses at most three independent 2 MiB workspaces during bootstrap and
its two joined directions; SSE uses one. Encoded messages are at most 8 KiB.

Denial, expiry, fence, reset-required, invalid-message and interruption are distinct
terminal reasons. Recover retained commands/results through authorized ordinary
HTTP. Reopening a closed session requires a new session identity. A signed cursor
never grants access, and a cursor for another subscription/session cannot be reused.
Hard native expiry does not depend on the observer. Missing observations cannot
silently free quota or extend a lease.

`POST /reactive/v1/discovery` takes a signed serving discovery read. It names the
accepted route/watch revisions and generated description SHA-256 digests only
after current source/service checks. Generic type descriptions are available at
`GET /reactive/v1/openapi.json` and `/reactive/v1/asyncapi.json`; they contain no
accepted resource identities. Board's separate OpenAPI 3.1 publication is unchanged.

Run `just test::reactive` for independent non-UI TLS peers, and
`just test::reactive-descriptions` for pinned offline validator/drift checks.
Executed native tests include cross-transport exact retry, empty snapshot, Table
progress/outcome notification, cursor resume, attachment fencing, fragmented
bootstrap with ping, declined compression, idle native/service revocation and
worker/gateway/node/store recovery. Browser, Compose/Substrate reactive paths,
capacity and remaining adversarial/lifetime schedules are still pending; M19's
physical serving results alone do not qualify reactive transports.
