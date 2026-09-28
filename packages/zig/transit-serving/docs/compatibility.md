# Serving compatibility

The [M19 proof ledger](../../../../tests/README.md#m19-qualification) owns commands,
measurements and fault schedules. All executed rows use pinned tools on Linux
x86_64. A row does not qualify every combination of the columns below.

| Consumer | Native | Compose | Substrate/reference | Authentication and lifetime |
| --- | --- | --- | --- | --- |
| Non-trading Table service | Signed HTTP/TLS, two gateways, lost receipts, cancellation/timeout, hard expiry, retained growth | Two TLS gateways and physical worker/node/store recovery | Fresh worker keys and exact generations, gateway egress probes, physical recovery | Explicit native caller keys, current service policy/resource reads, separate gateway reader; unlimited retained receipts/outcomes |
| Board inspection | Shared listener, flooding, revocation, trimming, outage, diagnostics | Existing persistent launcher/update/recovery proof | Existing isolated launcher/update/recovery proof | Private shared viewer boundary; read-only Transit identity; exact Host/Origin |
| Board Table query | Two instances, conflicting and identical prepared requests, durable active quota, bounded Arrow/JSON readers, shell/generated client/Chromium | Existing M18 Table host proof; no new multi-instance Board query placement claim | Existing M18 Table host proof; no new multi-instance Board query placement claim | Separate optional query identity and current source/result checks |
| int64 Table SSE / WebSocket | Independent Python/OpenSSL and Chromium over TLS; cross-transport retry, scoped resume, current checks | TLS peers, attachment fences and physical stack recovery within the lease | TLS peers, fresh ownership, physical recovery exceeding the lease and explicit new session | Provisioned native signing keys; scoped cursor; finite session and current native/service/source reads |
| Board inspection, KV/Document reactive watches | Unavailable | Unavailable | Unavailable | Each needs its own qualified public watch adapter |
| Reactive language SDK wrappers | Unavailable | Unavailable | Unavailable | M18's ten SDKs retain finite-query coverage only |
| Inbound gRPC / Flight | Unavailable | Unavailable | Unavailable | Protocol-specific admission/framing/client qualification required |

The HTTP listener bounds sockets and tasks, while each consumer owns request
allocation and result budgets. The application example has four data handlers and
two reserved health handlers, 2 MiB per data request and two in-flight handlers per
caller per gateway. Durable active-operation quotas are enforced by the shared
Station owner across all gateways. A gateway config admits up to 32 provisioned
caller keys; this is an explicit listener configuration limit, not a total
cardinality bound on stored service policies or retained operations.

Command payloads/results are bounded to 64 opaque bytes in serving v1. The Table
counter's codec uses checked i64 arithmetic. Query/Arrow pages retain their own
M18 bounds and current-source rules. Service declarations, policies and terminal
records live in growing resources accessed through bounded public reads.

The private nginx terminator is trusted with plaintext data; signed bodies and
current native authority establish caller identity. Physical examples put the
terminator on the operator host, with a private bridge or authenticated Kubernetes
port-forward backend. This is not a public Internet or arbitrary-proxy profile.
Board keeps its existing private deployment admission, read-only inspection
identity and separate optional query identity.

Application worker placement is explicit/operator-controlled. A Substrate Actor
publishes a fresh key; the operator checks physical attribution, reissues resource
grants and records ownership at the exact next generation. No growing runtime
controller, autonomous timer daemon or finite receipt reclamation is claimed.
Session/transport loss never grants expiry, retargets an operation or makes an
external connector retry safe. M20 and M22 consume these boundaries separately.

M20's [proof ledger](../../../../tests/README.md#m20-qualification) separates
native/browser, Compose and reference evidence. The browser fixture pins its own
certificate public key and grants local-network permission only to its loopback
origin. It uses real WebCrypto, browser WebSocket and fetch-streaming SSE; it does
not add Board authentication or qualify an SDK. Chromium is the only executed
browser row.

Reactive hosts bound encoded messages to 8 KiB and 32 fragments. The JSON decoder
has a 2 MiB workspace; a WebSocket owns at most three such workspaces across
bootstrap and its joined directions. Snapshots hold eight int64 rows, with decimal
strings preserving the full application range. There is no per-socket result
history. Four live sessions/service, two/caller and one subscription/session are
shared durable limits across gateways. Per-gateway handler limits remain separate.
The first profile uses a maximum 30-second lease and a finite 30-second connection;
reconnect does not renew either. The host must qualify its configured clock error.

SSE challenges are local to one gateway, single-use and valid for two seconds;
the challenge/stream exchange needs affinity. Committed attachments and signed
cursors recover across gateways. Both gateways in the proof share the configured
cursor-signing reader key; rotating that key invalidates old cursor signatures
and requires an authorized resnapshot, not re-execution of commands.
