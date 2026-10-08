# Unified source capture

`UnifiedCapture` implements the source-owned v1 state machine in ordinary growing
Station turns. Its
[contract](../../../../contracts/UNIFIED_QUERY_V1.md) owns versions and limits;
component tests alone do not qualify disk or process recovery.

Configure a revisioned `UnifiedRecords.Policy` with the permitted peer PID,
request resource, a declaration or catalog target, and explicit maximum input
pages, segments and result bytes. A catalog target records scope, owner and an
explicit principal whose current inspect/read rights are checked at every page.
New Table admissions bind their immutable metadata and complete logical row type. Reusing a revision with different policy
rejects. Document declarations permit another accepted revision only within the
same epoch, type, identity, change format and projection.

On a call, `start` verifies the current policy and complete immutable bundle,
validates the declared source and plan, then retains the source turn's committed
cut. It records the original peer/correlation, request reference, job, checkpoint
and self-continuation. Reserve namespaces `2^63 | source_input_position` in this
resource; occupied namespaces reject, and query jobs never adopt prior records.
Initialize the enclosing behavior separately before admitting its first query:
start uses four mutations and cannot share a turn with private initialization.
The bundle's Publication publisher must also be the authenticated requester PID;
access to the configured request resource cannot substitute another publisher.

`advance` reopens current request access and source policy, then reads a bounded
page from the retained source. Supply disposable bounded decode/adapter storage,
a 4 MiB Arrow workspace and a cancellation flag. A local cancellation flag aborts
unsent work; it does not close accepted work. The returned private decision is
not durable until the host confirms its exact signed commit.

Each segment begins a Publication with frozen metadata. Later turns recompute
that same page and stage at most two chunks plus the next self-input. The publish
turn atomically writes the Publication descriptor/budget, checkpoint and job:
four mutations. A conflicting recomputation fails; an older self-input is a
no-op. Empty adapter pages advance without inventing result rows. Source pins
are released with the final capture checkpoint, before manifest publication.

The final manifest includes the complete original route, request, source/plan
basis, progress and ordered segment coverage. It has its own immutable publication;
only its final publish turn marks the job complete and emits the original-call
reply. Published segment records alone do not establish a completed query.

`close` explicitly cancels, denies or fails unfinished work and releases its pin.
The caller must invoke it in a fresh proposal, before a failed source read poisons
the turn. Infrastructure/read failures must not silently become cancellation or
successful completion. Current policy denial is handled before source/request
reads. A completed result requires explicit retirement to remove its records.

Closure schedules bounded cleanup without relying on continued request access.
It abandons or retires each record and collects at most two chunks per turn,
including a partially staged segment or manifest. Descriptors, segment metadata,
job identity and correlation index remain as permanent history. No automatic
expiry, cardinality ceiling, retention opt-in or second authoritative store is
introduced. Resource quotas still govern retained publications and ledgers.

## Reading completed results

`UnifiedResult.open/page` takes the expected source/resource, requester,
original correlation and exact request reference. It verifies the current complete
job and source policy, canonical request, Document floor/retirement and manifest
publisher. The immutable reference does not cache these rights.

Every page reads one segment publication, verifies its raw Arrow digest and
nested typed schema/states, and advances an owned ordinal/row/byte/hash cursor.
Only a null continuation verifies whole-result coverage. Current source/request
access and source policy are rechecked after decoding, before return; denial
invalidates the entire candidate page. Previously returned bytes remain disclosed.
Callers must discard partial buffers on error. Arrow bytes borrow the supplied
output buffer; scalar strings and schema columns use the caller's result allocator.
The `LogicalInspect.Batch` owns its descriptor and recursive rows. Call `deinit`
on each successful page before reusing its output slot; error returns free partial
decoding and invalidate the candidate. No whole-result allocation or new source pin is needed.

## Catalog ownership

`CatalogQueryOwner` composes `TableBehavior` with the same durable query engine.
Initialize the catalog using its exact administrator command, then install a
`PolicyChange` for each requester process. These are separate bounded decisions;
initialization does not grant query delegation. One owner routes queries and DML
for all authorized Tables in its namespace. Current catalog read and mutation
rights remain independent.

A query policy maps a requester PID to an explicit catalog principal. Submitted
SQL and source declarations cannot choose that principal. Cancellation uses the
original requester's correlation index, and only native self inputs can advance
jobs. See the [owner contract](../../../../contracts/CATALOG_QUERY_OWNER_V1.md).
