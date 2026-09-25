# Retained read versions — growing-profile extension

Status: implemented in the explicit v3 core/node and Zig client, with focused
qualification below. Station/Fuze resumable result capture remains M10 work.
This does not change default v2 callers, launchers or foreign bindings.
[Transit v3](TRANSIT_V3.md) owns the enclosing profile.

## Purpose and boundary

A turn view expires and closes when its input commits. It cannot support a query
that captures bounded result batches across multiple inputs or a worker restart.
A retained read version preserves an explicit source revision across those
turns. This is generic state access; the kernel does not execute queries, verify
application computation or interpret Arrow.

The retained version records one immutable catalog root plus source metadata,
not a copy of the resource. Its logical owner is a Transit PID, not a worker
activation. Current execution ownership, PID scope, resource read/inspection
grants, association and source lifetime remain necessary to read it. A reference
is never a bearer capability. Owner retirement, source expiry, revocation or
explicit release cannot be bypassed by retaining an old root.

## Publication and identity

The additive `turn_with_versions` command preserves the canonical
encoding of existing `turn` requests. Existing v3 signatures, journal records and
retained receipt digests remain valid.
The new command wraps an ordinary turn with up to four retained-view IDs, four
retained read dependencies and four explicit version releases. It has the same execution authorization and
one publication decision as an ordinary turn.

A retained version's ID is `{pid, input, index}`: the committing process, its
consumed input position and the retention slot (0–3). A caller can therefore
include that identity in its private state/job manifest before commitment. The
published metadata also records the source resource/revision and creation
position. Each retained view must be a validated member of that turn's view set.
It captures committed source state, excluding the turn's private mutations.

Versions, application mutations, input progress, outputs and retry receipt
publish together. A failed turn cannot retain or release versions. Rejected
proposals may leave staged pages, but cannot create a visible retained version.
Exact retry recovers the original publication; the same consumed input cannot
create another set of version identities. Releasing a version keeps terminal
metadata so stale references never reopen it.

Later turns declare every retained version used for computation in `reads`.
The kernel revalidates current owner/generation, association, grants, source
lifetime and unreleased status before preparing the publication. A concurrent
change fences a prepared proposal at the authority tail. Reads and releases may
include the same version, allowing a final result turn to consume its basis and
release it atomically. Applications remain responsible for declaring dependencies;
the kernel cannot prove that arbitrary handler computation is honest. Historical
retry of such a turn rechecks source read/inspection rights before releasing its
receipt, without requiring its already released version to reopen.

## Reads and lifetime

`read_version`, `read_versions` and `version_entries` are separate query variants;
existing signed entry queries retain their canonical encoding. Entry queries provide
the version ID and the caller's expected ownership generation, plus either a
point key or an exclusive key continuation. They return at most eight records,
the explicit version, checked generation and source revision, with the same final authority-tail
fence as existing reads. Clients validate the exact requested basis.

Retained metadata and values must survive root checkpoint/trim and process
activation replacement. An old activation cannot read merely because a new
activation reused the principal. A new activation may resume the named version
only with current rights and an eligible owning PID. Source updates do not move
its basis. Missing pages are unavailable evidence, never empty state.

Retaining a version neither creates an implicit required association nor extends
hard expiry. Its read eligibility is bounded by owner and source lifetimes and
explicit release. Unlimited lifetime is possible only while those contracts
permit it. Current association changes may revoke access; reattachment cannot
revive an expired owner or source. Physical deletion remains separate: release
is not proof that bytes have been erased. Future page cleanup must account for
live retained-version roots as well as active views and recovery roots.

Metadata queries require current inspection rights and PID scope; they can report
terminal versions without promising access to values. Discovery scans at most
eight version records per page under one authority cut, filtering resources the
caller cannot inspect. Empty pages may advance; only null means completion.
Entry reads additionally require current execution permission, owner/generation,
association, resource read rights and eligible owner/source lifetimes. A release
requires an ordinary authorized owner turn but no source read grant: an owner can
release a reference after losing source access. It cannot release another PID's
version. Unknown versions, released reads and malformed references reject explicitly.

The `retained_read_versions` capability advertises this extension, with
`version_change_budget: 4` for each reads/retain/release array per turn. This bounds
atomic work, not total retained versions. Catalog namespace additions leave
existing key bytes unchanged. A root currently covers the shared catalog; this
can retain unrelated physical pages and is not a space-optimal resource snapshot.
Selective reachability, quotas and physical cleanup remain unqualified. Cleanup
must not recursively treat obsolete versions found inside an old source root as
new authority to retain other roots.

## Station and Fuze use

A query-start turn can retain its source and write a durable query manifest with
that reference. Later self-continuations read bounded source pages, produce
bounded Arrow batches and commit result fragments with their progress. A crash
resumes recorded progress under fresh ownership. It cannot silently recapture
current rows, omit accepted fragments or publish a partial result as complete.

Query policy, per-peer disclosure, encoder/plan compatibility, byte/batch counts,
digests and complete-result evidence belong to Station/Fuze. Whole-query limits
and aggregates must span page boundaries correctly; applying a finite plan to
each page independently is insufficient. Global sorting, external materialization
and broad operator support need explicit qualification. This primitive alone
does not remove the existing finite Arrow result limit.

## Evidence and remaining gates

`just test::unit` checks old command/query digest fixtures, atomic private staging,
invalid release rollback, lost accepted replies, replacement ownership, bounded
filtered discovery, stale cuts, final disclosure races, missing captured pages,
explicit release and finite source expiry. Root-only recovery ignores an invalidated
test journal prefix after checkpoint; that injected test is not physical trim proof.
`just test::growing-service` additionally captures a 60-row version while committing
four new rows, loses the accepted reply, and recovers both current and retained
state through disk Ursula/node restart with one resident cache page. A replacement
activation reads the retained version while its predecessor is fenced.

`just test::growing` additionally checks live retained versions across actual
root checkpoint publication, authority-prefix trim and provider restart with one
resident page. Immutable page storage is preserved; this is not page-GC proof.

Quota/control reserve still needs qualification. Station/Fuze must demonstrate bounded result
capture across committed continuations, interruption, grant changes and independent
Arrow validation before advertising growing query/result support.
