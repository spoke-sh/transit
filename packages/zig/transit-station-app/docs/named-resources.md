# Named KV and Document resources

`transit-catalog.DirectResourceClient` saves, previews, admits, executes, inspects
and cancels named native-resource declarations. `NamedResource` supplies their
kind-specific initialization and typed KV access on the actual native owner.
The [direct request contract](../../../../contracts/DIRECT_TABLE_V1.md#named-native-resources)
defines exact identities and wire semantics.

## Declare and inspect

Construct a `DirectResource.Binding` with the current shared definition, catalog
connection, unique operation and object IDs, and explicit CREATE settings. The
writer PID must already exist. KV settings select one of the scalar query types,
nullability, native byte keys and FVL1 values. Document settings select its ID,
type revision and publication limits. The deadline and history policies are
explicit nullable fields; absence of a finite policy means unlimited retention.

CREATE always allocates its own native resource. It accepts no supplied backing
resource ID and does not adopt existing populated state. Metadata records alone
cannot substitute for the native receipt and exact initialization marker.

Save the binding with `DirectResourceClient.save` before admission. `load` rejects
missing or foreign compatibility definitions. `preview` checks metadata admission
without accepting work. `operation(binding, .admit, steps)` reserves the shared
name and permanently claims its object ID. Names remain absent from lookup until
completion. `inspect` never allocates, initializes or starts application work.

## Allocate and initialize

Explicit execution registers metadata authority and records `prepared` with the
original caller's next native sequence. The typed client's next execution signs
that frozen allocation. One prepared allocation per caller may occupy a catalog;
reconcile or cancel it before preparing another. Independent native commands can
still consume the sequence. Preserve the original binding and inspect the native
receipt after uncertainty; never invent a new sequence for the same declaration.

Catalog CONNECT, namespace USAGE/CREATE and owner-role eligibility govern metadata
creation. Native ADMIN on the writer governs allocation. Accepted allocation does
not grant native data permissions. Give the caller and worker their explicitly
required native resource rights, establish the writer's association and ownership
through existing public operations, and preserve the original caller on its
accepted Station input. Native read queries also require their ordinary inspection
scope. Registration credentials grant none of these rights implicitly.

The `allocated` operation carries a complete `DirectResource.Definition`. Supply
its initial revision to `NamedResource{ .initial = definition }`. Run
`initialize(allocator, turn, original_principal)` on the declared writer, commit
that private turn, then inspect progress before the next step. KV finishes in one
turn. Document uses three turns: exact reservation, `Document.Service.create`,
then verification and completion. A lost reply resumes the same durable marker;
an existing populated resource is not adopted. A framework descriptor already
proposed by GenServer is compatible with the committed-state emptiness check;
private user writes are rejected.

If the declaration has explicit source dependencies, use
`definition.dependent(allocator)` to bind its exact allocated interpretation.
Save and accept a `DirectDependency.Binding` for each declared source before
publishing the name. The source is an exact published Table or named KV/Document
definition in the same catalog. Named resource sources support the SELECT read
requirement, checked against native INSPECT/READ; mutation masks reject. The
dependent's metadata ownership authorizes registration, independently of its
native data permissions. Inspect each original registration after an uncertain
reply. Registration does not initialize or publish the consumer.

Execute the original catalog binding again after initialization. Publication
checks the exact native allocation, current lifetime and initialization marker
under a single native fence. This checks accepted writer evidence; it does not
prove arbitrary application code computed honestly. Use `lookup` or bounded
`list` pages to resolve the completed definition. Empty filtered pages can still
have continuations. Catalog positions describe metadata, not a data snapshot.

## Use and recover

KV `put` and `remove` mutate through the writer's private turn. `get` and `inspect`
also accept a current public `ResourceReader.Reader`; its signed caller must be
the requested principal. They recheck current rights before returning values or
absence. `get` returns an owned FVL1 decoding arena that the caller must `deinit`.
User keys contain 1–31 bytes; the adapter owns a leading `01` byte. Encoded values
fit the native 256-byte value envelope. Missing keys and explicit NULL remain
distinct, and values must match the declared scalar type and nullability.

`document()` returns the existing `Document.Service` for the declared resource
and document. Use that service's staged changes and public `Document.Client`
reads; naming creates no parallel merge or publication engine.

Rename and logical DROP require the exact expected interpretation and current
metadata ownership. After rename, `definition.initial()` recovers the original
initialization identity for data access. A retained successful receipt continues
to describe its original publication after rename, native expiry or revocation.
It cannot authorize current data access.

Explicit incoming dependencies block DROP even when their metadata is hidden
from the caller. Rename preserves each edge's old exact definition, so the owner
must explicitly revise a stale consumer. Retiring a consumer retains its outgoing
registrations: save and accept separate removal bindings after retirement or
abandoned-publication recovery. Removal requires current consumer metadata
ownership but no source data grant. Repeating an old registration returns its
original receipt and cannot restore a removed edge. There is no implicit CASCADE
or dependency discovery from values and associations.

Cancellation retains any already accepted allocation and its resource ID. Cleanup
uses the ordinary authorized native retirement operation separately. Cancellation
does not undo native work or prevent another holder from submitting a previously
signed native request. A name can be reused with a new object ID; the original ID
and terminal receipt remain permanent. Current failures leave the last accepted
stage observable. Resolve that original stage before creating replacement work.

The [proof ledger](../../../../docs/history/qualification/README.md) records reproduction commands,
executed coverage and limits for the public caller/node fault schedule.
