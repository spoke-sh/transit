# Caller and SDK semantics

Application handlers run in callers outside the authority. The public client
owns canonical encoding, signatures, response validation and exact recovery;
Station adds private turns and behavior semantics. Language packages own native
types, codecs, dispatch and scheduling. Use the [SDK index](sdks.md) for install
commands and target-language APIs.

## Language-neutral boundary

The shared implementation is Zig. Host APIs use its generated ABI or bounded
native port rather than reimplementing protocol transitions. Generated wire types
are not the public language API. Raw Transit and Station are independently usable
packages; importing either does not discover credentials, connect or start work.

Select the profile and credentials explicitly, check native ABI/operation support,
then read the running authority's capabilities under current permission. A
local library feature does not imply the server supports it. Realm-qualified
process/resource references keep identity separate from grants.

Protocol counters use their validated safe-integer ranges; application u64 and
correlations retain full 64-bit values. Follow each neutral contract's decimal
string/byte representation at JSON boundaries. Do not coerce wide values into
JavaScript numbers or silently narrow them in another language.

## Private turns and owned values

The runner presents the next input with authority-derived origin. A handler reads
scoped views and returns a private proposal. State changes, consumed input and
outputs become durable only at accepted commit. Exceptions and abandoned drafts
must not leak a partial proposal into a later turn.

Borrowed turns, views and Arrow buffers are valid only within their declared
scope. Copy or retain through the owning API before storing values elsewhere;
close/release owned native resources. Handler fields, host futures and in-memory
queues are volatile. Persist durable call identity, workflow progress and result
evidence in the application's state resource.

One active operation per handle and one handler per runner bound overlap in the
public SDK profile. Unsupported concurrent use rejects rather than creating an
unbounded background queue. Separate handles sharing a principal still need a
coordinated principal sequence allocator.

## Frozen mutations and retry

Prepare a mutation with an explicit sequence and persist its exact recovery
material before relying on recovery after process loss. The saved operation binds
the identity, original content and signature. A transport error means unknown
until reconciled; reconstructing a similar payload with a new sequence is new
work. Do not mutate a pending draft or replace its original reply route.

A durable receipt can survive caller loss. Current permission controls whether
it can be read. Cancelling an async await does not establish cancellation of the
native operation or its accepted work. Close must join active native ownership
according to the binding contract; freeing buffers while native I/O still uses
them is invalid.

## Calls, pages and results

Station calls have durable correlation and recorded reply destinations. A timeout
is distinct from a committed reply or a closed call; late evidence follows the
call's protocol. Registry rebinding cannot redirect a pending reply. Pure payload
codecs cannot forge authenticated origins or broaden the runner's authority.

Use bounded KV/Table/Document pages rather than loading an entire retained
collection. Query frames are provisional until their declared completeness and
digest checks pass. Arrow ownership is explicit; an owned IPC object or C release
callback must outlive consumers. See [queries](queries.md) and [Arrow](arrow.md).

The local application supervisor hosts separately compiled Zig workers. The SDK
packages expose client and framework APIs independently of that supervisor. Native Node
SDKs are distinct from browser query/reactive/application clients and their
credential scopes. See [installation](applications.md) for that boundary.

Exact native/ABI ownership lives in the [client binding guide](../../packages/zig/transit-client/docs/bindings.md)
and [Station binding guide](../../packages/zig/transit-station-bindings/README.md).

## Local transport denial

A local socket or firewall denial has cause `AuthorityTransportDenied`; it is
separate from a validated authority `AccessDenied` response. Reads are unavailable.
A command attempt remains uncertain unless its original outcome is established
separately; retain and reconcile the exact signed work. The native ABI preserves
these read/command distinctions, and query, mutation, catalog, application, Board
and serving diagnostics identify the local connection policy as the failed boundary.
