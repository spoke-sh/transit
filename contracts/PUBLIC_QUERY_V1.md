# Public Table query profile v1

Status: implemented M13 public profile. The owning [query package](../packages/zig/transit-query/README.md)
shares this profile between Board and `transit`. This is an application protocol
above [growing Transit](TRANSIT_V3.md) and [Station query delivery](STATION_QUERY_V2.md),
not a new kernel command or authority to execute arbitrary values.

## Configuration and authority

One connection registers a realm, query principal, source PID/resource/Table,
SQL name, and requester PID/resource. Multiple installations may register other
connections; this first frontend exposes one configured Table. No discovery of
undeclared Tables, KV/Document adapter, write, export or provider access exists.
The requester durably records its query principal and source PID. Its external
commands require that authority-derived principal; payloads cannot choose it.

The query principal needs Transit `inspect` and `send`, with separate resource
`inspect|read` on the source and requester resources. The source's revisioned
Station peer/Table policy must allow this requester. The host identities own
execution and publication; the query client never owns a process or executes a
handler. Existing Board inspection credentials do not become query credentials.
The public client checks the durable requester binding, Table descriptor, current
resource grants and peer policy. Results also require the manifest's exact policy
revision; restoring a different policy does not revive old results.

Revoking ingress credentials cannot undo already admitted work. Revoke the
source's peer policy or worker/resource authority to stop further execution;
revoke query-resource reads to stop disclosure. Associations and result IDs are
not capabilities. Every metadata/status/page operation makes current signed
reads; no cache authorizes access. Rechecks after page decoding narrow the
observation window but cannot retract bytes disclosed before a later revocation.

## Submission and admission

The pure M12 compiler binds one SQL statement to the authorized Table name and
schema. `prepare` freezes an ordinary signed v3 `send` to the requester. Its
Station cast payload is `PQR1`, the 32-byte schema fingerprint, then canonical
Fuze `FZP1` plan bytes. The 243-byte Station payload leaves **207 plan bytes**.
Larger encoded predicates fail with `QueryRequestTooLarge` before submission;
the native compiler/plan's larger bounds remain unchanged. The schema fence is
never removed to fit a request. Source capture revalidates the fingerprint and
binds the plan to the actual retained source revision.

A successful signed submission receipt identifies the requester input, which
becomes the durable call correlation. It means **submitted**, not query-admitted.
Retries preserve the complete signed request, principal and sequence. Unknown
outcomes retain that request; disconnecting, timing out, or switching views must
not create a fresh submission. Independent clients sharing a principal can
conflict on its mutation sequence; this profile reports that conflict rather
than silently choosing another sequence. Initialization uses `PQI1` in a
separate authorized input before queries, so initialization and admission do not
exceed the four-mutation budget.

The requester atomically records one active query and its wait/call. At most one
query per configured principal is admitted; additional transport submissions
receive durable `busy` outcomes and are not queued for later execution. The
transport inbox is a separate durable backlog under the deployment's admission
quota. A client should stop submitting while active. Retained query identities
and results have no fixed total-cardinality array and no automatic deletion.

The source uses Station's existing four-mutation start, retained read version,
staged segments, two-segment credit window and verified completion/ack protocol.
Publication does not overwrite Table rows. Job/capture metadata shares the source
resource's existing transaction boundary; it does not imply a separate mutable
result resource or a cross-resource transaction.

## Status, cancellation and disclosure

`unobserved`, `submitted`, `busy`, `rejected`, `admitted`, `capturing`, `delivering`, `complete`,
`cancelled`, `denied`, `expired` and `failed` are distinct public states. Transport
errors and unavailable observations are errors, never successful completion.
An absent status record returns `unobserved`: an arbitrary correlation proves no
submission. Frontends can label their own confirmed receipt `submitted` while
waiting for behavior evidence. Only the receiver's verified manifest plus closed wait establishes `complete`.
Partial progress counts do not authorize row disclosure in this first profile.

An explicit cancellation is another frozen signed cast: `PQC1` plus little-endian
u64 correlation. The requester closes the wait and sends the existing Station
cancel frame; local submission and committed cancellation remain distinct.
Cancellation cannot retract already disclosed results or promise remote rollback.
Quitting the CLI, aborting a fetch or closing Board is only a local disconnect.

A page is one independently verified IPC segment of at most 8192 bytes and 32
rows, with one or two typed columns. It carries the complete manifest, ordinal,
next ordinal, exact source/schema basis and total coverage. The shared Zig client
checks the retained wait, transfer, manifest, fragment digest and Arrow schema;
frontends never interpret opaque application KV values. JSON uses decimal
strings for int64, hex for binary and distinct null/boolean/UTF-8 variants.
A page ending before the result's final ordinal is not a partial successful query:
all pages refer to the same already verified complete manifest.

## Recovery and retention

Query capture and delivery resume from committed Station records after worker
loss. An uncertain host mutation is retried exactly while that activation lives.
Restarted workers require fresh recorded ownership; the runnable host also
refuses reuse of its local activation marker. That marker is a refusal guard,
not execution authority or a durability substitute. SIGKILL recovery does not
claim power-loss qualification of local marker files.

Unlimited retention remains the default. Browser/session state creates no
retention pin, offline result store or saved-query capability. Denial clears
protected frontend state. Previously printed terminal output remains previously
disclosed data; no terminal erasure or clipboard recall is promised.

## Board transport

The optional `POST /api/v1/query` exposes `describe`, `prepare`, `submit`,
`status`, `page`, `prepare_cancel` and `cancel` from the Zig model. It requires
an exact same-origin Origin and JSON content type, with a 16384-byte body limit.
Prepare returns source metadata, a compiler explanation and an opaque `frozen`
token. The token contains canonical prepared-request JSON; the browser retains
that string unchanged so full-width SQL integers never pass through JavaScript
numbers. Cancellation uses the same opaque envelope. Tokens carry signed requests,
not signing seeds, and remain subject to current authority and configured identity.
The server validates the contained operation, destination, source, schema and plan;
it does not forward arbitrary Transit commands.

Generated response schemas require fixed arrays even when their bytes are valid
UTF-8; Board's typed serializer preserves that shape. Integer cells are decimal
strings. No browser storage or result history is written. One Board installation
shares its configured query principal across reachable viewers; the one-active
limit is enforced by that principal's dedicated requester. Operators must not
provision additional requesters for the same principal and assume a global limit.
