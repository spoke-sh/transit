# Data workbench

Board presents catalog definitions, typed data and observed query results through
public Transit callers. Its built-in home selects Catalog when configured,
Workbook when only SQL is configured, or Operations when neither is configured.
Published interfaces keep their declared entry screen. Catalog and Workbook
also have fixed routes. Operations focuses on storage and maintenance evidence,
with links to the atlas, activity and separately configured relational recovery.
Interface bindings belong to Definition.

## Activities and contextual inspection

The horizontal activity bar opens **Data**, **Workbooks** and the declared
**Operations** screen. Published interfaces retain their application entry and
navigation. **Definition recovery** remains directly available. Missing catalog
or SQL configuration is explained inside its workspace; navigation grants no
additional access. The deployment-discovery route reports safe configuration
flags independently of upstream authorization and health. Unconfigured pages
issue no data reads and offer **Check availability** after configuring and
restarting Board. Catalog-only and SQL-only configurations are supported.
Without SQL configuration, dataset definitions and relationships remain readable
and **Preview rows** is disabled. Forwarding the HTTP listener through SSH does
not create either connection.

Dataset and workbook pages share one **Inspector**. **Dataset details** shows
the selected definition and metadata basis. Selecting a schema column shows its
logical type, physical codec and collation separately. Selecting a result column
opens **Profile**, **Definition** and **Evidence** dimensions; **Result evidence**
opens the result's canonical observation and verified terminal count. The panel
names the selected dataset or workbook cell. A different selection replaces its
contents instead of opening another panel. Result schemas do not supply source
codec or collation metadata.

**Dataset navigation** and **Cells** open optional local navigation. Dataset
branch/object/definition context and workbook connection scope stay above the
workspace. These are the actual configured or observed identities; Board does
not infer one branch or atomic snapshot shared by every workbook cell.

**Open detail in workspace** expands the selected inspection without closing its
result or discarding SQL drafts. **Return to workspace** restores the layout.
At widths of 1000 CSS pixels or less, inspection replaces the central content;
its result status, window bounds, observation kind and earlier-draft warning
remain visible. **Close inspector** or Escape restores the workspace and returns
keyboard focus to the selection control, or an available page control if it has
been removed. Selecting, changing dimensions and expanding details never run SQL.

The inspector reads the current authorized view, without retaining a separate
data copy. Closing or replacing a result, removing its cell, hiding the document
or a failed observation clears its inspection. Unavailable workbook connection
metadata also removes inspector content and displayed rows until access can be
checked again. Reconnection refreshes the original result identity before showing
rows; it never submits the SQL again.
Whole-source statistics, storage sharing/reclaimability, measured operator
metrics and branch-comparison workflows have no new presentation in this
workbench. Existing operational evidence remains in Operations.

## Operations and observation states

Operations pairs capacity/allocation bars and Table frontier diagrams with
data grids and the shared Inspector. Both views use the same returned facts;
selection retains a measure identity rather than another payload copy. Table
selection uses bounded catalog pages and an exact prepared binding. It needs
neither Explain nor a relational connection. Native realm-wide inspection and
catalog Table reads retain their independent identities and permissions.

Byte measures use powers of 1,024 (B, KiB, MiB, GiB, TiB, PiB and EiB),
approximately three significant digits and at most two decimal places. Rounded
labels carry ≈; a positive quantity below a shared scale's precision uses `< 0.01`.
Click or keyboard-activate a size to reveal exact decimal bytes and **Copy exact
bytes**. Copy uses the ungrouped integer and reports failure when clipboard access
is unavailable. Byte measures retain their original integers for ratios and
ordering. Counts, offsets, positions, identities and arbitrary SQL cells keep
their own units. Used/limit bars share units, cap only the drawing and explicitly
label above-limit values. They describe their reported allowance, not disk free
space; overlapping pools are not summed.

Maintenance pairs a compact state/settings view with its grid and Inspector.
It shows aggregate worker state/enablement, completed/failed steps, last failure,
resident memory, interval/timeout, flush row/size/age thresholds and work rows,
archive work frames, compaction work rows and collection record cadence.
Eligibility thresholds and configured work bounds are not progress observations.
Durations retain exact milliseconds in details. Disabled and unavailable are
separate; counters reset on owner restart, and a last failure can remain while
the worker is waiting or running. These node observations do not identify a
per-Table maintenance phase or queue.

Every diagram labels its scale and basis. Full-width Table positions stay decimal
strings; only drawing coordinates are rounded. Pending rows and data size separately identify complete
backlog versus a prefix/lower bound of at most 1,024 records. Null is unavailable, never zero.
These are independent current observations, not a global snapshot or time series.
No view infers shared/reclaimable bytes, elapsed age or permission to delete.

Catalog, dataset metadata, Workbook connection metadata, Operations, process and
resource inspection, record metadata and interface observations use one
deterministic observation reducer. Its phases are idle, loading, ready,
refreshing, failed, hidden and disposed. A generation identifies each in-flight
read. Navigation, scope replacement, hiding and disposal abort it and fence late
responses. Hiding or a failed metadata read removes its observations and inspectors;
refreshing retains the last qualified observation until replacement or failure.
Only one request chain per owner is active; manual refresh coalesces with it.
Per-tab transport scheduling admits two reads plus one explicit submission,
control or cleanup, with 75-ms read staggering and separate bounded queues
(60 reads and four controls). Queued scope changes cancel before dispatch; an
active request retains its permit until settlement. Reads have a 15-second deadline;
transient failures back off to at most 30 seconds. Capacity refusals retry sooner
with bounded backoff. Configuration, denial, expired observations and incompatible
responses require explicit action instead of automatic retries.

Process/resource inspection retains its last-observed page during transient
unavailability or capacity refusal, explicitly labeled stale at the original
cut/time. Denial, expiry, incompatibility, hiding and scope replacement clear it.
This evidence is never presented as a current read.

This reducer does not restart SQL. Statement submission, terminal verification,
original result identity, paging and cleanup remain owned by the shared
`StatementReader`. Its presentation owner rejects duplicate Run while busy,
clears rows on hiding/unavailable connection and observes the original identity
on return. An unconfirmed close is labeled; bounded server lifetime still applies.
Query, finite Live and definition publication retain their shared settlement
owners and use the same scheduled transports. Workbook drafts stay local to the page;
this change adds no durable workbook storage or automatic Run.

The separately configured relational UI is at `/recovery/relational`, including
its existing query controls and interrupted-query cleanup. Moving the view does
not alter or forget its service journal or start a replacement query. Interface
bindings appear in Definition; neither section is embedded in Operations.

## Configure data access

`transit server` connects Catalog and read-only SQL to its managed local account
by default. Catalog reads use that account's native binding; SQL uses the private
local Unix socket with peer authentication and the installation identity. No
connection file, password or additional Board grant is needed. The inspection
principal keeps its existing read-only scope. Board rejects mutating statements
even when the local account can write, and every read requires current permission.
Restart never repairs revoked grants or substitutes a different account.

Every viewer admitted by Board's private deployment boundary shares this local
data scope. Keys remain on the service host. Set `board.local_data: false` for
inspection-only defaults. Setting `sql.native.local: false` also disables automatic
data connections. Operations remains available while the local account initializes;
the supervisor activates data access once its binding is initialized. Subsequent
connection failures and permission denials remain visible in the data workspace.

To choose another scope, set `board.workbench_file` to a JSON file. This is a
complete explicit override: missing or failing connections never inherit the local
account. The server resolves the path relative to its configuration directory.
Standalone Board requires explicit connections and accepts
the same `workbench_file` or an inline `workbench` object, but not both. The file
is read at startup, is limited to 16 KiB, and has this shape:

```json
{
  "catalog": {
    "seed_file": "/private/board-data.seed",
    "connection": {
      "scope": { "realm": 42, "resource": 3, "catalog": "1" },
      "branch": "1",
      "audience": 5,
      "principal": 101,
      "role": null
    }
  },
  "sql": {
    "version": 1,
    "endpoint": "https://sql.internal:7443",
    "account": "board_reader",
    "database": "transit",
    "source": null,
    "authentication": "scram",
    "ca_file": "/private/sql-ca.pem",
    "password_file": "/private/board-sql.password",
    "request_timeout_ms": 2000
  }
}
```

Substitute provisioned identities and endpoints. Catalog reads use Board's
configured native upstream and require the corresponding current catalog/domain
grants. The catalog principal must differ from the inspection principal and use
the same realm. SQL uses the [public SQL client configuration](../../../packages/zig/transit-sql-client/README.md);
its service account owns authentication and source authorization. Absolute secret
paths avoid dependence on the service working directory. Either connection may be
omitted. An unavailable connection is visible in its workspace; Operations remains
available. Discovery does not provision schemas, Tables, grants or SQL accounts.

## Catalog and dataset exploration

Catalog reads eight authorized namespaces or Tables per page. Filtering applies
only to the current page. Continuations bind their selection and observed directory
position; changes require a fresh read. Definitions have stable scope, branch,
object, revision and digest identities. Dataset links retain that identity; a
changed definition cannot silently resolve to a replacement.

Dataset views expose declared logical types, codecs and collations, independently
observed row counts, metadata positions and registered relationship pages.
They do not infer relationships or a common snapshot. KV/Document projections
remain in Resources through their existing supported callers.

Preview is explicit. The catalog caller supplies quoted SQL and an exact expected
definition. The shared SQL client compares that definition with the executed
result's interpretation before disclosing rows. This is not an execution-time
definition pin. A mismatch refuses the preview; refresh the catalog selection.
The SQL connection must resolve the selected Table in its configured namespace.
A different namespace or source cannot substitute a same-named Table: the exact
definition comparison refuses that result.

## Retained catalog inspection

From Catalog or Operations, open **Inspect a retained catalog**, enter its saved snapshot selector and the
schema name recorded in that catalog, then choose **Inspect snapshot**. Board
resolves that schema inside the retained selection and displays eight Tables per
page. Selecting a Table shows its original schema, codecs, collations, constraints,
semantic descriptors and exact catalog/source digests.

**Physical definitions** reads one generation and its stable-column or ADD-time
mapping per page using metadata rights. **Row placement** requires SELECT and
shows at most eight original row identities with WAL or segment references.
Both modes pair a bounded diagram with an equivalent grid. Select a column or
original row in either view to highlight the same identity and inspect full
physical interpretation, digests and exact locations. Shared destinations group
only the returned page; segment IDs are not sizes or counts. ADD origins identify
the initial state and definition without decoding application values. Type,
codec and collation remain distinct in the logical schema.

Continuation controls replace the displayed page; partial traversal stays visible.
Changing mode resets its continuation and Inspector. Scope/selector/object/page
replacement, denial and expiry remove old disclosure before a new observation
can appear. The saved selector identifies the retained cut independently of
current Table storage. Renamed objects retain their historical name and stable
identity; current-name lookup is not a fallback.
Directory exhaustion does not establish payload verification or query completion.
Failed reads and document hiding clear displayed evidence. Visible pages recheck
current permissions every five seconds. Collapsing the retained catalog removes
its observations and stops its reads; reopening revalidates the supplied selector. Inspection neither acquires nor releases
retention and never runs SQL.

## Workbook and results

A workbook is temporary in-memory presentation: up to four narrative/SQL cells,
explicit Run or Ctrl/Command+Enter, and one attached result per cell. Leaving the
route discards the workbook and closes results. There is no browser persistence,
sharing or durable workbook identity. Editing never executes a statement; an
earlier result stays visibly attached to its submitted SQL until the next Run.

The read adapter prepares through the SQL service, checks typed non-mutating,
row-returning semantics, and executes that same prepared handle. SELECT, SHOW,
DESCRIBE and EXPLAIN use the shared result lifecycle. Commands, writes, unbound
parameters and captured execution are refused. Existing application and finite
Live interfaces keep their separate authorities.

Four result readers are shared by the Board deployment. Each has a five-minute
absolute lifetime and a window of at most 100 rows with a 2 MiB value-allocation
budget. Metadata retains one bounded source chunk to recheck all held authority
subjects. Requests are limited to 64 KiB; result replies to 4 MiB. Byte-budget
exhaustion fails closed. A display limit is not query completion. Empty results,
verified result counts and incomplete prefixes are distinct.

Values preserve exact integers/decimals, logical types and all five cell states.
Column profiles count only the received window. Integer/decimal min/max,
distinct counts and distribution bins use exact arithmetic; unsupported ordering
or statistics are unavailable. Preview coverage is unknown and is never called a
random sample or whole-dataset profile.

Every result disclosure checks current source rights, including repeated and
terminal windows. Visible views revalidate every five seconds and clear on failed
observation or document hiding. Reopening visibility observes the original result;
it does not rerun SQL. Failed submissions/advances can check that original reader,
but cannot splice another snapshot. Closing stops local consumption and requests
cleanup; aborting an HTTP wait does not itself prove remote cancellation. Native
leases independently bound abandoned resources. Each result reports its own
canonical observation and verified completion; neither is a retention promise.
