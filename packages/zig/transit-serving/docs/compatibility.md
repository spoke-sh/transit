# Serving compatibility

The [M19 proof ledger](../../../../tests/README.md#m19-qualification) owns commands,
measurements and fault schedules. All executed rows use pinned tools on Linux
x86_64. A row does not qualify every combination of the columns below.

| Consumer | Native | Compose | Substrate/reference | Authentication and lifetime |
| --- | --- | --- | --- | --- |
| Non-trading Table service | Signed HTTP/TLS, two gateways, lost receipts, cancellation/timeout, hard expiry, retained growth | Two TLS gateways and physical worker/node/store recovery | Fresh worker keys and exact generations, gateway egress probes, physical recovery | Explicit native caller keys, current service policy/resource reads, separate gateway reader; unlimited retained receipts/outcomes |
| Board inspection | Shared listener, flooding, revocation, trimming, outage, diagnostics | Existing persistent launcher/update/recovery proof | Existing isolated launcher/update/recovery proof | Private shared viewer boundary; read-only Transit identity; exact Host/Origin |
| Board Table query | Two instances, conflicting and identical prepared requests, durable active quota, bounded Arrow/JSON readers, shell/generated client/Chromium | Existing M18 Table host proof; no new multi-instance Board query placement claim | Existing M18 Table host proof; no new multi-instance Board query placement claim | Separate optional query identity and current source/result checks |
| SSE / WebSocket | Unavailable pending M20 | Unavailable | Unavailable | Separate sessions, watches and attachment proofs required |
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
