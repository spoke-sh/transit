# Growing profile (M10 development)

[transit-node](../README.md) accepts an explicit `"profile": "growing_v3"`
configuration. Omitting `profile`, or choosing `"v2"`, keeps the existing protocol.
This is a partially qualified development profile. Launchers, Board, Station,
provider controllers and foreign bindings still use v2; they do not silently
negotiate or convert to v3.

## Configuration

Use a fresh bucket/journal location for v3. The expected `genesis` is the
[growing genesis](../../../packages/zig/transit-core/docs/growing.md), including
`version: 3`, `realm`, `root_key`, optional `max_clock_error_ms`, required-resource
and dependency-graph operation budgets, and `allow_history_trim` (false by default).
It is a trusted bootstrap input, not a root signing credential. Startup validates
the durable genesis fingerprint. An old history is an error, not an empty realm.

| Field | Development behavior |
| --- | --- |
| `profile` | Required literal `growing_v3` for this mode |
| `genesis` | Exact expected v3 genesis |
| `ursula_url`, `bucket`, `journal` | Private provider location |
| `listen`, `port` | IPv4 address and port; default loopback:8080 |
| `resident_pages` | Decoded page cache slots, default 16, configurable 0–1024; not retained cardinality |
| `request_timeout_ms` | Whole-request deadline, default 2000 ms, range 1–60000 |
| `accept_trace_parent` | Internal diagnostic context acceptance, default false |

`--initialize` and `--bootstrap` explicitly create the authority and packed page
journals. Ordinary startup requires existing history. Both use the same
[clock and diagnostic boundary](operations.md#time-and-deadlines) as v2. Finite
views require a configured trusted clock bound even for unlimited-lifetime state.
The cache budget omits transport buffers, parsing and provider memory; consult
the [storage measurements](../../../packages/zig/transit-backend-ursula/docs/growing.md).

## Public surface and limits

The listener provides `GET /health`, `POST /v3/command` and `POST /v3/query`.
The [contract](../../../contracts/TRANSIT_V3.md) owns signed types and semantics.
Public queries require current inspection rights plus resource/PID scope where
applicable. Values remain opaque application bytes. Computation runs in the
caller; the node validates identity, ordering, state dependencies and publication.
Requests use the common bounded, cancelable HTTP loop and diagnostics.

Capabilities advertise the implemented operation budgets. Runtime bindings,
Station support and automatic history reclamation remain false. `--maintain`
and public `checkpoint` commands reject explicitly: growing background
maintenance is not composed yet. The core/backend checkpoint proof is separate.
Clock-based operations still fence known-expired work immediately; terminal
metadata and pending-work disposition can lag until explicit protocol operations.

No quota/control-reserve, large-result, migration, production throughput or
clustered-provider guarantee is implied. The public profile must retain these
limits until its remaining M10 gates are implemented and qualified. The node
remains sequential within a realm; additional replicas still share its one
conditional publication journal.

`just test::growing-service` uses an independent Zig calling program, disk Ursula
and the real node on one CPU. It writes 64 rows with bounded point/batch access,
rejects malformed replies, preserves a signed uncertain turn across caller/node/
provider restart, and checks current revocation on both reads and old receipts.
The [client guide](../../../packages/zig/transit-client/docs/growing.md) explains
the explicit development API. Existing v2 service proofs remain required after
changes to the shared listener or client transport.
