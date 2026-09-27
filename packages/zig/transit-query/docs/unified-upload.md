# Unified requester uploads

`UnifiedUpload` and `UnifiedBehavior.Requester/Source` implement the finite v2
request lifecycle. The [contract](../../../../contracts/UNIFIED_QUERY_V2.md)
owns wire versions. Component schedules pass; signed daemon/deployment and SDK
qualification remain in progress.

Initialize a requester separately with `UnifiedRequest.Command.initialize` from
its configured query principal. The behavior durably binds that principal and
source PID. Restart configuration must match that binding. Source initialization
similarly binds its accepted peer and initializer principal; source policy and
application data must already be provisioned through their owning operations.

The requester accepts these authenticated casts:

| Command | Effect |
| --- | --- |
| `begin` | Reserve one finite bundle and the sole active slot; never adopt an occupied namespace |
| `part` | Stage one 128-byte half of a canonical Publication chunk; verify repeated parts exactly |
| `seal` | Verify the complete Publication commitment and mark the bundle ready |
| `submit` | Create one durable call carrying the immutable reference; duplicates keep its original correlation |
| `cancel` | Explicitly close an active local wait/upload and schedule bounded collection |
| `retire` | Explicitly withdraw a terminal request publication, ending later result availability |
| `collect` | Advance closed-publication cleanup; no implicit expiry |

The largest part payload is 145 bytes, before the existing 13-byte Station header.
Begin is 72 bytes; namespace-only operations are 12 bytes. Neither the 243-byte
payload nor the four-mutation budget changes. An upload may contain a 4 KiB
predicate while each handler sees one small command. Partial pairs are durable
requester state, not native worker fields. A changed part, identity or digest
cannot overwrite earlier accepted staging.

One active upload/query bounds admission independently of retained history.
Abandonment keeps the active slot until Publication cleanup releases its staging
reservation. Accepted/complete request records remain immutable evidence until
explicit cancellation or retirement. A namespace cannot be reused after cleanup.
A transport receipt acknowledges input admission, not successful upload or query
acceptance. Invalid authenticated commands receive a durable error-name record at
`UnifiedRecords.key('e', input_position, 0)`; infrastructure/read failures do not
become successful acknowledgments. Never log bundle bodies or decoded values.

The source receives the reference through an authenticated call, checks its
publisher, policy and full bundle, and enters the
[capture state machine](unified-capture.md). Domain rejection/denial uses the
original reply route. Current request-resource denial closes an accepted query
without reading its body; own-source read failure cannot fabricate a closure.
Cancellation is an ordered request: source completion may already have won, and
previously returned bytes cannot be retracted.

Station still freezes exact pending signed commits, and a new OS worker still
requires fresh fenced ownership. The shared client must keep each prepared
signed upload command across uncertainty. It may choose its successor only after
the preceding input has been observed as committed. No local timeout grants
permission to invent a replacement call.
