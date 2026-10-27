# Larger immutable publications

`Publication` stores opaque application-versioned
records over existing KV without changing the 256-byte value, four-mutation or
single-resource turn limits. The [v1 layout](../../../../contracts/STATION_PUBLICATION_V1.md)
owns exact encoding, commitment, lifecycle and capacity accounting.

## Using a private turn

Create a namespace once with explicit deployment limits:

```zig
const publications = try station.Publication.create(turn, .application, 1, .{
    .record_bytes = 65536,
    .staging_bytes = 131072,
    .staging_records = 2,
});
```

Later handlers reconstruct `{ .resource = turn.view.resource, .domain = .application,
.namespace = 1 }`.
Limits cannot silently change on restart. Resource grants and the fenced writer
remain necessary. A namespace or record ID is not an authorization token.
Application schemas/replica identity are outside this opaque storage layer.

1. Prepare a `Spec` with nonzero application format, length and expected digest.
   `Digest.initial`/`next` compute the canonical chain one chunk at a time;
   `Digest.of` is convenient only when the caller already owns the finite body.
2. `begin(turn, id, spec)` reserves the full length and one staging slot. Use a
   stable nonzero ID, with an application-owned durable allocation policy.
3. `append(turn, id, ordinal, bytes)` stages one canonical chunk (256 bytes except
   the final chunk). Schedule later inputs/continuations explicitly. Accepted
   staging is recoverable work, not publication or a Document acceptance result.
4. `publish(turn, id)` verifies completeness and returns `changed` or `duplicate`.
   On `changed`, update an application head and emit the acceptance reply in
   this same turn. At most two mutations remain after publication. On duplicate,
   return the recorded outcome without creating another business event.

Every call builds a private proposal. Only the host's confirmed turn receipt
establishes commitment. Helpers restore their own writes on error; applications
must discard the whole proposal if subsequent composition fails. Configure the
existing host failure policy deliberately. Native handler fields and files are
not durable staging progress; `inspect` returns the recorded written count,
chain, lifecycle and publication PID/input.

For an already-owned finite body, `stage(turn, id, spec, bytes)` combines these
steps within the remaining native mutation slots. Descriptor and quota updates
to the same keys share private slots; the four-write limit is unchanged. A
`false` result preserves bounded progress for commitment and exact resumption.
A `true` result means publication in the private proposal, with no guarantee of
remaining slots for an application head or receipt. The caller must reserve or
roll back its composition accordingly. Capacity failure without progress and
other errors restore this helper's proposal. Reading still requires a committed
published source; staging does not create a readable cursor or an accepted Table
operation. General Table pages and catalog metadata use this finite-body helper.

## Reading and recovery

`open(source, id)` accepts either a growing turn or its `Retained` reader. It
returns an owned, exact-source cursor. Repeated `read(source, cursor)` returns
at most 256 owned bytes. A non-null `next` is a provisional prefix; null verifies
complete length and commitment. Do not expose a prefix as a complete document,
checkpoint or result. Missing/corrupt data is an error, not end-of-input.

No record-sized allocation occurs in these operations. Persist a continuation
only with its exact source and application job. Across handlers, retain a
committed source with `turn.retain()` and reopen its ID using `openVersion`;
current grants still apply. Current-turn reads reject private writes. Historical
reads exclude later publication, retirement or cleanup. Cursors are local owned
state and must not be accepted as untrusted remote bearer tokens.

A live host retains and retries the exact signed pending turn after an uncertain
response. After host loss, acquire fresh ownership before recomputing from the
recorded descriptor. Never discard an unresolved request and rerun its handler
under the old activation. Stale owners cannot publish or clean up. Resource
revocation, expiry, view expiry and retained-version release are explicit errors;
no helper opens a fresh source automatically.

`PublicationReference` supplies a canonical 72-byte `SPF1` identity for one
published record. Its `read(resource_reader, output)` helper materializes a finite
record into a caller-sized buffer, reopening current access and the exact published
spec for every bounded chunk group and after completion. Public readers with
`resource_read_batch` acquire one descriptor and at most seven 256-byte chunks
in one current authorized cut, retaining only that bounded group. Other readers
keep the original point-read path. Both verify the identical ordered commitment
and require a final fresh read; batching never turns a reference into a grant. An error invalidates all copied bytes.
Use it only with a declared application size/format limit; references do not grant
access or establish application acceptance. Use `Publication.open/read` when the
application needs bounded streaming at an explicitly captured or retained cut.

## Resumable finite uploads

`PublicationUpload.step` stages one or two finite records, one operation per turn,
using the same domain, namespace, immutable specs and caller-owned source bytes on every
resume. It returns `true` only when all records were already published before
that turn; the adapter may then admit the reference using the remaining budget.
It restores the private decision on failure, including failures after namespace
creation. Published records are individually visible; the adapter owns admission
of their combined reference.

Supply a separate nonempty `identity_key` and an opaque frozen `identity` that
binds every record spec and adapter policy field. The helper stores a 48-byte
`SPU1` marker binding the domain, namespace and SHA-256 of this identity; changing
either identity coordinate rejects before another staging step. Changed identity/content and an
occupied namespace without that marker fail explicitly. The helper validates
content digests and quota before staging, but does not interpret the adapter's
marker or grant access. HTTP and RPC callers use this shared upload mechanism;
formats, authorization and durable call identity remain with their adapters.

`PublicationUpload.marker(domain, namespace, identity)` returns that same bounded
marker for comparison with a current-authorized read. It rejects a zero domain,
zero namespace or empty identity. Compare the stored marker with this value when
resuming an already admitted call; the marker is not the raw adapter reference.
Marker construction grants no access and does not check publication completeness.

## Disposition and cleanup

Retention defaults to unlimited. There is no timer or automatic garbage collector.
`abandon` permanently closes unpublished work; `retire` closes published content.
Resolve or replace application heads/dependencies in that same turn. Both are
explicit application decisions; capacity refusal cannot trigger either implicitly.

`collect` removes at most two current chunks and commits its cursor. Repeat on
later inputs until it returns true. An abandoned record retains its reservation
until the last cleanup turn, including when no chunks were written. This prevents
repeated abandonment from bypassing the staging quota. Final cleanup uses all
four mutations for two chunks, descriptor and budget; allow a separate turn if
additional application state must change. Outputs use their separate budget.

Permanent descriptors reject delayed begin/append/publish attempts after cleanup.
They remain subject to the enclosing resource's lifetime and capacity. Current
KV deletion is not physical erasure: an older retained version may still own and
read its published body. The authority/backend own protected roots and eventual
physical cleanup. This API neither trims authority history nor claims a general
reference graph or provider-space reclamation guarantee.

## Qualification and integration limits

Run `just test::publication` for real signed service, disk recovery, exact retry,
current access, protected historical reads and cleanup. `just check::native` covers
strict codecs, independent digest fixtures, quota/identity refusal and rollback.
The [test guide](../../../../tests/README.md) records executed evidence and limits.

The native SDK publication actions use the application domain. Query uploads,
query results, Table mutations, accepted Documents, exchange captures and
application definitions use separate domains. Caller-staged HTTP, RPC and
Document request bodies use the application domain and caller-assigned
namespaces. The [layout contract](../../../../contracts/STATION_PUBLICATION_V1.md)
records the domain registry. Domains isolate budgets, descriptors, chunks and
cursors within a resource; current grants and writer fencing still apply.

The 64 KiB qualification is a useful operation
size, not a whole-resource limit; total published records grow on disk under
normal deployment quotas. Larger configured records require workload-specific
qualification. Format IDs label application bytes; they do not validate them.

## Public-envelope chunk assembly

`PublicationParts.append` reuses the v1 query upload's two-part assembly for any
publication owner. Each ordinary envelope carries at most 128 bytes. The owner
supplies the exact immutable reference and a scratch key unique to that record;
it must check current caller policy and active upload state first. One first half
is retained durably; the second half appends the canonical chunk and removes the
scratch value in at most three mutations. Exact repeated halves are checked
against retained bytes, including already completed chunks; changed halves,
wrong references and gaps fail. The helper restores private writes on error.
It does not admit a request or make staged bytes visible. Application composition
must not bypass a pending first half with a different full-chunk upload path.
