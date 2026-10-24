# Generated browser composition

The application composes the shared compiler, conditional publication owner,
finite query workspace and TypeScript draft scheduler. Business interpretation
of `status` (`0`/`1`) and `state` (`10`/`20`) lives in this example's frontend.
Neither Board nor the kernel knows what an Open or Done work item means.

`interface.sql` is an artifact proposal. `transit-app module` validates the whole
program and generates `web/src/proposal.generated.ts`; `generate.py --check`
checks that output during builds. Provisioning replaces the placeholder resource
and full source-contract digest before publishing. The running application reads
only the currently authorized publication and checks that its renderer artifacts
exist in the build. An absent, denied or incompatible publication hides the
application; the generated proposal is never a fallback or a grant.

Application compilation and query failures carry the same owned diagnostics as
Board, including original SQL locations, failed column names and exact signed
submission identities. The gateway validates a saved token before forwarding it;
malformed local input remains unsent. The browser displays diagnostic text without
dispatching suggested actions. Existing recovery keeps the original pending work
across gateway replacement and interface/data generation changes.

## Roles and configuration

`zig build example-work-items work-items-gateway` installs the worker and the
private gateway with its built frontend. Each executable takes one JSON path.
The ordinary worker configuration is described in the [README](../README.md).
Two optional, mutually exclusive roles compose existing native handlers:

- `query_peer` is the requester PID. The data owner accepts administrator-issued
  query policy only for that peer and its retained direct catalog binding.
  The administrator's current Table rights gate policy publication; the named
  query caller's current rights separately govern query capture. Query capture
  initialization is a separate turn from data initialization, preserving the
  four-mutation boundary. The worker needs current read access and an association
  to the requester's resource, in addition to its own resource grant.
- `publication` configures the shared application publication owner with
  `application`, `realm`, `administrator`, `namespace` (decimal string), and
  `name_digest`. Use a separate PID/resource/activation. `application` and `realm`
  must match the worker's base application configuration; its domain Table role
  is inactive. The ordinary application operator policy remains required.

The gateway configuration contains:

| Field | Meaning |
| --- | --- |
| `url`, `port`, `listen` | Native authority URL and HTTP listener; loopback by default |
| `public_origin` | Exact external scheme/host/port; forwarded headers are rejected |
| `development_allow_insecure_http` | Explicit opt-in for local HTTP |
| `inspection` | Distinct read-only `principal` and `seed_file`, scoped to the publication resource |
| `application` | Shared operator host `scope` and fixed `operators` allowlist; no operator private key |
| `data` | The data worker's application configuration |
| `query` | Scoped requester `connection`, `seed_file`, and finite `limits` |

Inspector and query identities must differ. Operators sign shared native
application commands themselves. The gateway does not contain an administrator
key. Its private deployment admits the browser; native resource grants, query
policy, catalog inspect/read and publication policy are checked independently.
The gateway resolves the active Table from its published catalog metadata; it
never constructs a physical source commitment from a Table name alone.
The application reads its direct service binding from native state. The gateway
uses the query caller's key for direct metadata reads, and the capture worker
authenticates with its login identity to use that caller's retained read grant.
The Table role selected for application mutations supplies no query authority.
Finite query capture retains explicit Table cuts; the migration's conditional
current reads have a separate lifetime.

`GET /api/v1/interface` reads the current publication.
`POST /api/v1/application` exposes the shared signed operator host.
`POST /api/v1/query` exposes the shared finite query workspace. Query compilation,
new admission and page reads must match both the published binding and active
data contract. Exact pending submission, observation and cancellation remain
available independently of the current interface, so migration cannot erase
accepted work's recovery path.

The gateway has four data request slots and two control slots, a five-second
HTTP deadline and a 3.5-second upstream deadline. Request bodies are bounded to
64 KiB for queries or 512 KiB for operator publication; JSON output is bounded
to 1 MiB. Query signing is serialized; pre-dispatch contention returns 429.
Credentials and payloads are excluded from telemetry. Native placement is not
an OS sandbox.

## Interaction and recovery

Run admits one finite snapshot. Live admits at most two native query intents per
explicit generation and coalesces edits; it is not a data watch. Pause closes
scheduling without cancelling accepted work. Navigation and hidden pages pause
scheduling, while recovery controls remain outside the published screens.

A saved recovery file contains the original compiled bundle and frozen native
proposal, never a private key or result pages. Restore does not submit until
Recover is selected. Cancellation settles the original proposal before closing
and collecting its upload. New Run is unavailable until accepted work settles.

One result page resides in the browser. The shared reader verifies complete
ordered coverage and rereads the visible page against current authority. The
UI preserves full-width IDs and labels its source revision and visible page.
An interface change clears the old page; policy denial clears protected state.

For the selected schema evolution, explicitly prepare the empty target, then
copy and verify it while
writes are paused, activate its epoch, update source query policy, publish the
compatible interface, then explicitly release writes. These are separate owner
commits, not a cross-resource transaction. See [migration](migration.md).

The proof composition sets the requester and courier to a 100 ms base poll
interval with an idle ceiling of one second. Idle polling backs off without
changing query identity, admission budgets or native request capacity.
