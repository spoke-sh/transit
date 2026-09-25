# Retained read versions — proposed growing-profile extension

Status: M10 design for implementation. No current node capability, query or turn
supports this contract yet. [Transit v3](TRANSIT_V3.md) and
[Station growing](STATION_GROWING.md) describe the implemented surface.

## Purpose and boundary

A turn view expires and closes when its input commits. It cannot support a query
that captures bounded result batches across multiple inputs or a worker restart.
A retained read version will preserve an explicit source revision across those
turns. This is generic state access; the kernel does not execute queries, verify
application computation or interpret Arrow.

The retained version records one immutable catalog root plus source metadata,
not a copy of the resource. Its logical owner is a Transit PID, not a worker
activation. Current execution ownership, PID scope, resource read/inspection
grants, association and source lifetime remain necessary to read it. A reference
is never a bearer capability. Owner retirement, source expiry, revocation or
explicit release cannot be bypassed by retaining an old root.

## Proposed publication and identity

Use an additive `turn_with_versions` command instead of extending the canonical
encoding of existing `turn` requests. Existing v3 signatures, journal records and
retained receipt digests must continue to validate after the extension is added.
The new command wraps an ordinary turn with up to four retained view IDs and up
to four explicit version releases. It has the same execution authorization and
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

## Proposed reads and lifetime

Add separate version-metadata and version-entry query variants. Do not change
the canonical encoding of existing signed entry queries. Entry queries provide
the version ID and the caller's expected ownership generation, plus either a
point key or an exclusive key continuation. They return at most eight records,
the explicit version and source revision, with the same final authority-tail
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

## Implementation gates

- Preserve old signed command/query bytes and recovery of pre-extension v3 roots.
- Capture and release atomically with the ordinary turn decision; reject stale
  views, forged bases, duplicate identities and foreign-owner releases.
- Read the old version after source mutation and worker/node/provider restart;
  reject old generations, changed grants, expiry, release and missing pages.
- Keep retained-version discovery and storage resident work bounded. Expose
  capability/budgets explicitly; account for retained roots in quota and cleanup
  work. Retention defaults do not authorize eviction under pressure.
- Demonstrate bounded result capture across multiple committed continuations,
  interruption, grant changes and independent Arrow validation before advertising
  growing query/result support.
