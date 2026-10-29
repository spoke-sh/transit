# Board OpenAPI reference

Board exposes private system inspection and separately enabled finite query
workspaces. Its [OpenAPI specification](../../../contracts/transit-board-v1.openapi.json)
is generated from the Board public types; the operation and schema reference
below is rendered from those exact bytes.

## Catalog and logical statement results

`POST /api/v1/catalog` exposes read-only public catalog operations: description,
bounded namespace/Table/resource discovery, an exact Table definition and
registered dependency pages. `POST /api/v1/sql-read` adapts the shared SQL client's
generated `ReadWorkspace` contract: describe, run, observe, next-window and close.
Both require same-origin JSON requests and explicit service-side configuration.
The browser receives no SQL account secrets or native signing key.

Run uses typed prepared-statement admission and refuses mutations, commands and
unbound parameters even if its configured account can write. Results preserve one
logical schema, exact cells, observation and terminal count across physical
batches. Up to four readers and 100 rows per display window are retained; metadata
windows may be smaller to preserve their disclosure scope. Requests are limited
to 64 KiB, value allocations to 2 MiB per window and SQL-read replies to 4 MiB.
Current authority is rechecked before every disclosure, including repeated and
empty terminal windows. Limits, failures or closed readers cannot establish
complete coverage. Reader IDs do not create per-viewer sessions.

See [data workbench configuration and lifecycle](../../../apps/transit-board/docs/workbench.md)
for source-definition checks, expiry and cleanup. Existing query, Live and
relational contracts below remain separately configured operations.

## Access boundary

Every reachable viewer shares the configured upstream inspection identity.
Board has no viewer access keys or sessions. Place it behind the private deployment
boundary; a reachable listener is not per-user authorization. Upstream Transit
still enforces the inspection principal's current read-only grant on each read.

An optional query workspace uses a different explicitly configured identity and
publishes query requests through its own public contract. The opt-in application
editor also has a separate operator identity. Neither grants mutations to the
inspection identity. See [Board configuration](../../../apps/transit-board/docs/configuration.md).

The query workspace's `inspect` request accepts `DESCRIBE`, `SHOW TABLES` and
`EXPLAIN SELECT` through the shared [SQL inspection owner](../../../contracts/SQL_INSPECTION_V1.md).
It returns current metadata within the configured source scope, separate from
compiled query bundles or submitted results. It creates no query or snapshot.
The worksheet's Run action retains its explicit SELECT submission interface.
An Atlas query entry identifies the worker's progress resource; a declared
worksheet binds its data source. Direct Table data and query progress can have
different resource IDs. SQL inspection, suggestions and result source evidence
refer to the data declaration, while query recovery retains its execution route.

Resource-entry inspection interprets a typed Table head only when its current
format, object key and resource identity agree. It reports the recorded head
revision, row count, pending operation, retirement state and immutable schema
publication reference. It does not infer column names or decode application rows
from that head. Use authorized catalog inspection for column definitions. Query
record inspection reports the current request and execution records, including
their result references and attributed failures. Every lens retains its source
PID, resource, key and observed revisions; current read revocation removes access
to that evidence as well as to ordinary entries.

The query API's `compile` request also accepts an explicit neutral `parameters`
array and delegates to the shared [parameter compiler](../../../contracts/SQL_PARAMETERS_V1.md).
It returns an ordinary owned bundle after current source and budget checks;
compilation does not submit it. Invalid parameter indices, counts and types
return a bad-request response. The separate `sql_capabilities` request reports
local parameter support and grammar bounds. The worksheet has no parameter-entry
form; existing SQL drafts continue to use ordinary compilation.

The query route accepts at most 64 KiB of JSON per request, including a complete
hexadecimal query bundle. Replies are bounded to 1 MiB. A result page contains
at most eight rows and 128 columns with complete logical descriptors, nullability
and optionality. The browser checks recursive shape and value limits before
presentation, displays exact numeric values and typed nested cells, and preserves
the immutable source cut separately from its contract and schema. JSON values
remain text with exact numeric lexemes; they do not become JavaScript numbers.

## Relational queries

The separately configured `POST /api/v1/relational` route exposes the shared
interactive Table query owner. Its typed request wraps capabilities, metadata-only
explanation, open, one-row page and close. A `describe` request reads configured
catalog routes, the same host's active query reference/current ordinal and
pending recovery under current source rights. Open saves complete source
bindings and accepted positions; a private service journal preserves original
pin requests before dispatch. `recover` explicitly closes the matching original
query's pins after interruption. Inspection advances no execution and reruns
no lost work.

The Operations screen's [relational worksheet](../../../apps/transit-board/docs/relational.md)
distinguishes draft, proposed plan, captured source vector and incomplete/complete
output. Run is explicit; editing creates no query. The route admits 16 KiB JSON
requests and returns at most one 128-column row, with a 256 KiB browser response
limit. It uses a separate configured principal and one active session shared by
this instance's viewers. A browser reload can inspect that session; a Board
restart loses its executor and exposes the original retention for explicit
cleanup. New work waits for that cleanup. Current rights apply to repeated pages
and terminal coverage.

## Query diagnostics

Error responses carry the finite `err` identifier and a nullable
[`diagnostic`](../../../contracts/DIAGNOSTICS_V1.md) envelope. Query compilation and
inspection preserve the original compiler subject, source span, parameter sites
and expected/actual types. Read, preparation and submission failures describe
that attempt separately from the saved query's outcome. Unknown submissions
retain the exact native sequence and recovery guidance; diagnostics never cause
automatic submission or replace frozen work.

HTTP presentation follows the shared semantic category after specific native
inspection dispositions. Invalid syntax/bindings and unsupported query profiles
return 400; conflicts and incompatible lifecycle operations return 409. Current
denial returns 403 and unavailability returns 503. Invalid remote result evidence
returns 502; an invalid locally supplied frame remains 400. Internal failures
return 500. An unknown submission always remains 503 with its exact recovery
identity. The diagnostic's stable code supplies the specific reason.

A native `TableDefinitionChanged` response reports
`inspection.observation_changed` and permits a fresh observation. It does not
establish an empty Table, complete a previous read or restart a saved query.
Results from the earlier and newer definitions remain separate.

The worksheet displays the semantic message, byte location, exact counters,
provided or unavailable facts and permitted recovery guidance. Saved query
failures and Live draft failures use the same display. Current denial clears
protected source/results and prior diagnostic detail while preserving exact
recovery intent. Detail is returned to the authorized caller; telemetry records
only the finite error identifier.

The browser query client retains owned detail on `QueryError.diagnostic` and
flags invalid optional detail with `diagnosticInvalid`. It checks the generated
shape, current definition, byte/encoding/number bounds, evidence consistency and
recovery targets. Invalid detail cannot replace the primary HTTP status/code or
change the retry policy. Error messages used by ordinary logging contain only
the finite identifier; caller-facing views explicitly render the detail. Other
inspection reads preserve their own semantic code for current denial, changed
cuts, reclaimed history, unavailable resources, replay gaps, coverage mismatch,
invalid capture, protocol mismatch and inspector capacity. A failed inspection
reports no complete observation and never changes the outcome of earlier work.
Read retries and fresh observations remain separate from signed-command recovery.
Errors before selecting an inspection route may have no diagnostic envelope.

## Read evidence, not assumptions

Reads are paged and carry their observation basis. A source association is not
a foreign-resource grant. A recorded result manifest is not proof that all
segments remain readable. Retained gaps, current revocation and unavailable
sources stay visible; Board does not decode arbitrary application values.

The specification covers its declared inspection/query routes. Optional private
reactive and application adapters have their own
[reactive client](../../../contracts/REACTIVE_CLIENT_V1.md) and
[application](../../../apps/transit-board/docs/application.md) contracts. They are
not silently added to this OpenAPI surface. Read [Board concepts](../guides/inspect-board.md)
for the distinction between implemented interfaces and reviewed UI proposals.


Current query execution and request lenses retain the source-owned `failure`
code, stage and any budget dimension/measurements. The optional query workspace
status exposes the same neutral object. Observing these fields still requires
current access through the relevant inspection or query identity; the lens does
not fetch source payloads to enrich a failure.

HTTP/RPC metadata and the allowlisted Exchange failure record expose the original
capture cause, operation/input, original phase and sealed prefix. These fields
come from the atomic first closure, survive worker replacement and remain distinct
from native effect settlement. A replacement with no admitted cause says that it
was not recorded. Board checks the resource/writer/exchange basis, displays the
original cause and directs inspection of effect settlement and connector policy.
It does not read captured bodies, destinations or credentials to enrich errors.

Inspection failures distinguish unavailable transport, incompatible definitions,
invalid resource responses and inconsistent retained exchange evidence. Known
query failures retain their shared semantic codes. Current native denial and
lifecycle evidence take priority. Every failed inspection remains an incomplete
read: it cannot authorize resubmission, cancellation or repeating external effects.
