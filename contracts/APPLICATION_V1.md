# Declarative application v1

This contract defines application interfaces, their canonical representation and
conditional publication. Publishing a definition grants no execution rights.

## Definition

One finite program declares one interface, up to two themes, sixteen screens,
sixteen bindings and sixteen actions. A program is at most 64 KiB of UTF-8;
identifiers are at most 64 bytes, paths 128, labels 128 and embedded SQL 4096.
These are per-definition deployment bounds, not total retained-history limits.
Each immutable revision carries its realm, full-width revision, component contract
version, entry screen and named theme. IDs/counters wider than native safe counters
use canonical decimal JSON strings. Components are static, allowlisted versioned
artifacts; the program cannot load code or interpolate credentials.

Bindings distinguish inspection, finite query and explicit service command.
Inspection names a supported public projection and holds one bounded page.
Query bindings name an exact resource, source kind (Table/KV/Document), source/schema contract, query profile and
immutable SQL. Compilation uses the owning Fuze compiler with an authorized
source. Follow requires the Table watch and refresh admission owner;
a KV or Document source explicitly rejects Follow even with a unified query profile.
A command names a service, destination, binding revision and codec; a renderer
cannot substitute any of them. Neither bindings nor associations grant access.

All references must resolve inside the complete definition, with unique names
and paths. Screens must use compatible renderer/binding kinds; actions must
select a valid local navigation, read-session control or explicit service command.
Validation rejects unknown options, unsupported versions, duplicate declarations,
dangling references and unsupported combinations before any mutation. A preview
and SQL/Form/Canvas round-trip are pure: they never submit a command or query.
Canonical SQL preserves semantic values, not comments or source formatting.

## Publication and migration

Interface bodies use immutable publication in the application-definition domain
(7). A Station owner records one
conditional active revision plus the exact immutable body/digest. It validates
body and compatibility before visibility. Conflicting base revisions fail;
repeating the same accepted identity/digest recovers its disposition. A changed
body is a different proposal. There is no multi-resource atomic publication.
Each source read and operation rechecks current authority independently of the
interface revision. An old compatible browser may keep its pinned generation;
new binding/schema generations fence late results and preserve pending recovery.

The implemented owner uses canonical SQL bytes, application format `0x41505031`,
and separately provisioned immutable configuration `(application, namespace,
realm, administrator, SHA-256(interface name))`. Each operator needs a current
application publication policy as well as native admission/read grants.
Configuration and policy changes do not come from interface SQL. Every staging,
activation, duplicate and abandonment checks current policy and authenticated
external origin. Metadata accessors require an already authorized public reader;
they are not an independent public ingress.

One proposal freezes `(operation, record, expected revision, expected body digest,
next revision, publication spec)` under its application/operator identity. The
next revision is exactly base + 1 without overflow. Record identity is independent
of revision so competing drafts can stage distinct immutable bodies. A receipt
remembers whether it owns that record; a rejected proposal cannot abandon a
different operator's upload by naming its record. Duplicate terminal proposals
recover their original disposition under current rights.

Staging reserves at most two bodies and 128 KiB per configured namespace. One step
appends one 256-byte chunk. Final activation uses exactly four existing mutations:
publication descriptor, released staging budget, active head and attributed receipt.
Uncommitted partial decisions are discarded. A changed base produces a durable
conflict; it does not delete a staged body or release its quota implicitly.
Explicit abandonment and bounded collection close unused uploads, retaining
terminal identities. A revoked operator needs explicitly restored rights to
finish that cleanup. Published revisions and receipts have no total-count array
and no implicit expiry.

### Fixed publication records

Keys are `00 41`, application:u64be, tag:u8, principal:u64be, operation:u64be.
Configuration (`c`), active head (`h`) and policy (`p`) use zero operation;
configuration/head also use zero principal. Receipts (`o`) use the exact operator
and operation. Values start `AP1` plus their record tag. Fields follow public type
declaration order; integers are little-endian, booleans are one byte 0/1, enums
one byte, arrays their exact elements and structs their fields without padding.
Full-width IDs/revisions are eight-byte integers here and decimal strings in JSON.
Unknown headers, enum tags, noncanonical booleans and trailing bytes reject.
`Proposal` uses tag `r`; `Receipt` adds phase (staging=1, applied=2, conflict=3,
abandoned=4), native input position and the record-ownership boolean. `Head` names
revision, record, spec, operator, operation and activation input. The owning public
types generate the structural schema; independent Python fixtures pin the layouts.

Owner tests qualify deterministic composition. The focused native proof also
qualifies signed operator admission, exact lost replies, stale-worker fencing and
node/disk-store restart. Signed HTTP operator ingress, browser generation switching,
application migrations and deployment placements remain separate gates below.

The selected data evolution is a versioned work-item encoding on the application's
existing int64 Table. The application records a write pause, converts one bounded
page at a time with a durable cursor, verifies complete coverage and explicitly
switches its codec/interface generation before resuming writes. The coordinator
keeps exact plan/step identities and digests; no generic schema conversion or
inverse is implied. Interrupted work resumes from committed state under fresh
ownership and current rights. Partial conversion is never an active new schema.
Old data and step receipts retain the application's normal unlimited lifetime.

## First admission and UI profile

Board inspection remains private and read-only. Administrative composition is an
explicit opt-in, separately provisioned operator principal; signed admission must
bind that identity to the reviewed base, target and digest. Separate credentials
and current-grant checks apply per request. No identity comes from a UI selector.
Bootstrap/recovery access stays outside mutable interface definitions. Ordinary
viewers cannot obtain an operator capability by editing a program.

The selected presentation is the monochrome Workspace/Operations shell, explicit
Atlas emphasis and resource entry, bounded flat alternatives, and comfortable /
compact token variants. Unknown age, bytes and global counts remain unavailable.
Local filtering precedes summaries and counts describe their bounded page only.
Live draft work is opt-in and finite: compile complete read queries, retain draft /
query / source identities, coalesce one latest candidate and enforce the existing
single-requester slot and explicit per-session starts. Administrative drafts never
enter that scheduler; speculative results cannot be presented as exact matches.

## Qualification

Shared fixtures must compare SQL/model/form round-trip, full-width identities,
unsupported syntax, unknown fields and complete-program failure. Owner tests must
exercise conditional publication, lost replies, restart, current denial, competing
plans, bounded backfill and compatibility. Real Board and generated work-item
clients must qualify accessibility, typed envelopes, publication and migration
through native, Compose and reference placements. These gates are independent;
parser success alone is not an executable administrative capability.

## Native upload commands

`Request.Command` uses `AP1i` and a one-byte variant: initialize=0, policy=1,
begin=2, part=3, publish=4, abandon=5, collect=6. Fields use the fixed record
encoding above. `part` carries operation:u64, ordinal:u32, second:bool and a
one-byte length followed by 1–128 bytes. The JSON value is lowercase hex; all
other identities retain their declared native-counter/decimal-string encoding.
Every encoded command fits an ordinary Station cast frame. The independent AP1
fixtures include all variants. No kernel opcode or frame bound changes.

`beginUpload` explicitly admits bounded byte staging for one frozen proposal.
Normal clients compile the whole program first; a direct malicious caller may
stage invalid bytes, but staging is not administrative publication. `appendUpload`
uses Station's shared two-part assembly, current operator policy and the exact
base. It cannot replace a pending half through the full-body helper. `finishUpload`
materializes at most 64 KiB from the captured turn, verifies the commitment,
validates/canonicalizes the whole program and then uses the same atomic activation.
Invalid programs never activate. Each finish performs at most 256 chunk reads
plus bounded metadata reads; deployment deadlines still govern progress.

`Behavior` provides the real Station handler and pre-frame guard. Malformed or
unauthorized inputs produce retained, payload-free dispositions keyed by the
actual operator and native input position. Unavailable reads and allocation
failures remain unresolved infrastructure failures; they cannot be reported as
successful publication or terminal caller rejection. Bootstrap config must be
initialized through the separately provisioned administrator before opening
ordinary operator admission. There are no browser keys, query identities or
administrative privileges implicit in a definition.

## Optional host transport

The reflected `HostRequest`/`HostResponse` values compose the same compiler,
publication owner and native authentication. The host allowlists at most sixteen
operators for this deployment; native authority independently verifies each
signature and current grant. `Native` prepares ordinary v1 digests and rechecks
scope and payload before forwarding. There is no host-held operator key or
substitution of the inspection/query principal. A trusted browser origin imports
a local PKCS#8 Ed25519 key; this profile does not imply human account federation.

Compilation and formatting return the same complete model, canonical SQL and
Station publication digest (its domain-separated chunk commitment, not an
unqualified hash of the SQL bytes). Upload continuation is pure and selects at
most one command from a frozen proposal plus observed progress. Observations
cannot grant rights; the durable owner checks every admitted step again.

The HTTP envelope is at most 512 KiB, accommodating JSON escaping of the smaller
64 KiB program. A signed mutation stays frozen through an unknown reply. Native
admission and application completion are distinct. Explicit pending and reviewed
plan exports contain no signing key and support recovery across browser reload.
Conflicts keep the original base; an explicit new review is required to change it.

Published reads use current public resource access for every bounded chunk group
and recheck the active head before exposing a complete body/model. The built-in
artifact is explicitly identified before first publication or when no publication
scope is configured. A denied or failed published read cannot expose cached data
or silently switch to that artifact. Interface-generation fencing in renderers is
an additional obligation; a successful materialization does not prove it.

### Declared route and query binding acquisition

Paths under `/api`, `/assets`, `/health`, `/openapi`, `/processes` and `/recovery`
are reserved (including their exact roots). The independent Board recovery route
is `/recovery/definition`. Inspection renderers require a compatible projection;
`atlas` includes the bounded catalog/identity projection used by its detail views.

A query binding's `schema` is the full `SourceDefinition.fingerprint()` (`UQS1`)
commitment, including resource, Table identity or declared decoder/projection
versions. It is not just a column schema hash. Acquisition checks that commitment
and the configured source name/kind. Result display separately checks the retained
manifest basis. Published interface changes cannot relabel an old result as a new
source. Exact pending commands outlive disposable routes and retain their original
native identity even when the replacement binding is incompatible.
