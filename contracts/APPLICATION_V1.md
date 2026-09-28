# Declarative application v1

M23 implementation contract. The model, parser and conditional publication owner are implemented;
publication, browser and placement qualification remain open until recorded in
the [milestone](../docs/roadmap/M23.md). This contract grants no execution rights.

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
Inspection names a qualified public projection and holds one bounded page.
Query bindings name an exact resource, source/schema contract, query profile and
immutable SQL. Compilation uses the owning Fuze compiler with an authorized
source. Follow requires the qualified Table watch and M21 admission owner.
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

Interface bodies use M14 immutable publication. A Station owner records one
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
