# Configuration service v1

The [reflected envelopes](configuration-v1.schema.json) and
[local settings registry](configuration-settings-v1.json) define configuration
inspection and reload. Their `definition` is the current native contract-set
identifier. Missing or foreign definitions are rejected. These operations do
not change native grants or the installation's immutable identity.

## Binding and authority

`POST /configuration/v1` accepts `Signed`: a configuration request and the
caller's native signed authorization check. A binding contains realm,
installation identifier and a native domain object. Domain privileges are
`inspect = 1`, `provenance = 2`, and `reload = 4`. The installation bootstrap
registers this domain and object once, owned by the initial local owner role.
Ordinary startup and reload do not repeat completed grants.

The request contains a nonzero 16-byte operation ID. Its context is SHA-256 of
`transit.configuration.request.v1\0` followed by the protocol JSON encoding of
`Request`. The native proof binds this context, current credential epoch,
principal, selected role and object ID as audience. The guard has exactly one
`all` requirement for the bound object and action's privileges. The host
forwards this original signed check to native authority; it holds no signing
credential. A configuration file cannot substitute a principal or grant.

Inspection requires `inspect`; including file/environment origins additionally
requires `provenance`. Reload requires `reload`. SQL adapters also inspect the
current generation before preparing a reload. History requires `inspect`; historical error coordinates additionally require
`provenance`. A reload caller receives sanitized coordinates for its own validation
outcome, with no source filename or rejected value.
Current authorization is checked before work, before a valid candidate is
published and before returning a result. Revocation can hide an already
accepted result; it does not undo that accepted operation.

## Actions and responses

- `settings`: an exact canonical dotted name or a cursor, and `origins`. Rows
  include active/default/configured values, type, unit, bounds, owner, scope,
  change policy, source, generation, session eligibility and pending restart.
  Sensitive descriptors produce null values before serialization. Source paths
  and coordinates are omitted unless provenance was authorized.
- `reload`: an expected generation. The owner reads its pinned configuration
  filename, validates the complete effective candidate, and records an outcome.
  Failed validation leaves active and configured values unchanged.
- `reloads`: an operation ID or a cursor, and `origins`. History includes principal, generation,
  ordinal, overall phase, component phases and sanitized validation diagnostics.

Pages contain at most eight rows. Cursors bind a generation or history revision;
changes reject continuation rather than combine inconsistent pages. Request and
response bodies are limited to 256 KiB. Unknown keys, changed cursors and reused
operation IDs with different contents are explicit rejections. Errors contain
known codes and known setting names, never rejected values or unknown keys.

An exact retry binds the same request digest, principal and selected role. It
returns the retained terminal outcome without reading the file again. A fresh
credential may authenticate recovery after rotation, subject to current grants.
A new operation against an obsolete generation records a rejected outcome.

## Application and storage

The local configuration owner shares the native gateway process. Its checkpoint
contains one immutable active snapshot, one configured snapshot, pinned startup
inputs, provenance, a generation and the native observation floor. Host policy
and defaults for newly opened query sessions are consumed from this snapshot.
Other owners' fields remain active at their previous values and are reported as
pending restart. Reload does not launch, restart or provision services.

Candidate validation and preparation precede checkpoint publication. File
replacement plus file/directory synchronization is the acceptance boundary.
The checkpoint includes the terminal operation until its individually addressed
operation and ordinal history records have been synchronized. Recovery completes
these indexes before accepting another operation. Resident history remains one
page; retained history is unlimited. No collection-wide startup scan is required.
A failed checkpoint/index write makes the current owner unavailable.

This placement has one live checkpoint owner, so it does not claim atomic
application across independent processes or deployments. Component outcomes
identify applied live defaults and pending restart. The response vocabulary
reserves `applying` and `partial` for hosts with separate appliers; the local
checkpoint owner returns `applied`, `pending_restart` or `rejected`.

Normal `server` startup validates a new candidate and applies restart settings
under the existing installation lock. Initialization-only settings and artifact
hashes remain identity checks. An automatic child restart retains the same boot
identifier and recovers the accepted checkpoint rather than restoring stale
startup values. Restore configuration checkpoint and history together; these
local records are not a replicated native log.
The installation completion field is required on disk. Initial startup publishes
it only after the first configuration checkpoint is durable. Completed
installations reject a missing or invalid checkpoint before starting children;
neither normal startup nor automatic recovery creates replacement state.

Loading and reloading are the validation operations. There is no separate check
endpoint or SQL function, persistent SQL configuration write, automatic watcher,
include expansion, remote fetch, or arbitrary SQL file selection.
