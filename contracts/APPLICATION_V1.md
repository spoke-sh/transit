# Declarative application v1

M23 implementation contract. The model, parser and fixtures are being implemented;
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
