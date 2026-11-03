# Inspect with Board

Board displays evidence obtained through Transit's public read APIs. Open the
`board_url` printed by the [local server](quickstart.md), use the
[development launcher](../../../launchers/README.md), or configure the
[standalone service](../../../apps/transit-board/docs/configuration.md).
Use it to follow process history, state resources, ownership and retained work.

The default local server serves Board at both `http://127.0.0.1:19107` and
`http://localhost:19107`. A configured Board port applies to both addresses.
Use one address consistently: requests with an `Origin` header must match their
own scheme, hostname and port. Other hostnames and forwarded headers reject.

## Explore data

The local server connects Catalog and read-only SQL to its managed local account
automatically. Everyone who can reach Board shares that data scope; every read
still requires current permission. Set `board.local_data: false` for inspection-only
defaults, or use an explicit connection file to choose another scope.

The built-in home opens Catalog when its connection is configured, Workbook
when only SQL is configured, and Operations when neither is configured.
Published interfaces keep their declared entry. With a configured catalog,
select a namespace and Table, inspect its schema, then choose **Preview rows**. Catalog
filtering covers the current page. Dataset previews and column profiles are
bounded windows with explicit coverage and source evidence.

Use the horizontal **Data**, **Workbooks** and **Operations** activities to move
between exploration and operational evidence. Dataset details, schema columns,
received-window profiles and result evidence share one contextual **Inspector**.
It can expand into the workspace; Close inspector or Escape returns to the
selected control. Inspection never submits SQL.

Use **Workbooks** for temporary notes and SQL cells. **Run** explicitly submits a
read; editing only changes its draft. SHOW, DESCRIBE, EXPLAIN and SELECT share the
same typed result surface. Each result has its own observation basis and terminal
count. Leaving the workbook discards its cells. The
[workbench guide](../../../apps/transit-board/docs/workbench.md) explains connection
setup and limits. An unconfigured workspace explains which service connection
is missing and offers **Check availability** after setup/restart. It does not
continually retry a disabled read. SSH forwarding changes how you reach Board;
it does not provision a catalog/SQL identity or bypass Host/Origin checks.

Operations pairs current capacity/allocation diagrams with data grids.
Byte quantities use binary units such as KiB, MiB and GiB; ≈ marks rounding.
Select a quantity for exact decimal bytes and **Copy exact bytes**.
Select a measure in either view to inspect its meaning and observation basis.
Choose one Table in **Table storage** for partition-local accepted, archive,
recovery and history positions alongside bounded backlog facts. Unknown values
are distinct from zero; these observations establish neither query snapshots
nor elapsed age, throughput or deletion eligibility. Storage inspection runs no
SQL and starts no maintenance. **Processes and resources**, **Activity** and,
when configured, **Relational queries and recovery** lead to the existing
inspection and original-query recovery tools. Maintenance reports the aggregate
node worker state, its counters and configured thresholds/work bounds separately
from Table progress. Counters reset when their owner restarts; a retained last
failure does not mean the current worker is failed. Interface bindings are
inspected in **Definition**, outside Operations.

With a catalog connection, choose **Inspect a computation** in Operations,
select its schema and enter its name. **Inspect** resolves its exact definition.
The source → computation → output diagram and matching grid select the same
Inspector. Table links open current dataset metadata with a separate observation
basis; the computation Inspector shows declared SQL and exact completion evidence.

**Last completed result** reports a committed revision and its row count, including
zero. **Current computation** reports control state, epoch, pending work and the
owner's blocked reason. Active control does not imply a completed or fresh result;
no pending work does not prove that output reflects current source data.
Choose a positive **Retained revision** to inspect an older result. Refreshing
current progress preserves that selection; **Latest completed** follows the latest
observed completion again. A missing revision remains missing. Selection creates
no retention pin and never reads output rows. Denial or definition change clears
both observations and their Inspector; a same-name replacement requires another
explicit Inspect. Manifest and schema sizes use B/KiB/MiB/GiB with exact values
available for inspection and copying.

With a catalog connection, **Inspect a retained catalog** is available in both
Catalog and Operations. Supply a saved selector and historical schema, then
choose an object. **Physical definitions** maps logical columns to one physical
generation or ADD-time origin per page. **Row placement** requires SELECT and
links at most eight original row identities to WAL or segment locations. Both
have a diagram, equivalent grid and the shared Inspector. Page and mode changes
replace evidence; collapsing inspection stops its reads. These views acquire no
retention, read no payloads and never infer segment sizes. See the
[retained inspection guide](../../../apps/transit-board/docs/workbench.md#retained-catalog-inspection)
for scope and failure behavior.

## Start from an identity and an observed cut

Use **Process directory** or **Resource directory** to return to the atlas from
an open workspace. Selecting the directory already shown in the URL also returns
to its object list, where you can select and enter another resource.

1. Find the process/resource and confirm its realm and logical identity.
2. Inspect lifecycle, ownership generation and committed progress.
3. Follow input, turn, output or attempt references to their source evidence.
4. Check retained boundaries and current permissions before calling a view complete.
5. For application success, inspect its domain outcome using the application's
   decoder; generic Board metadata cannot prove a business operation succeeded.

A page is an authorized observation, not a lock on the system. Independent panels
can have different source cuts. Show freshness and gaps; a cached result cannot
extend history retention or survive known permission denial. Framework lenses
interpret allowlisted Station/connector metadata and do not decode arbitrary
private application values.

Resource participation pages carry their own association observation cut. Worker
progress can invalidate a continuation between pages. Board clears that page and
reports the changed observation; use **Refresh participation** to start from a
fresh cut. This action reads current associations and does not resume or replace
a query. Pages from the two cuts cannot be combined.

## Private viewer boundary

Everyone who can reach the deployment can inspect its configured shared scope.
There is no per-viewer sign-in, access key or session in this profile. Keep it
on a private network. Board's upstream identity still needs read-only grants;
it has no direct storage/provider access.

Optional query and application workspaces use separately configured identities
and capabilities. Enabling them does not turn ordinary inspection into an
administrative credential. See [Board OpenAPI](../reference/board-api.md) for the
actual inspection endpoints and [security](../reference/security.md) for scope.

## Queries and definitions

**Run query** explicitly submits a finite query. For a Table source, **Enable Live
draft** authorizes a finite budget within which complete valid edits can start
queries. Editing does not open or reset that budget. Preserve query namespace,
request and result identity through unknown replies; complete-result verification
precedes presenting a complete answer. **Follow changes** separately refreshes an
eligible submitted query under its own budget. The [Live Table guide](../../../apps/transit-board/docs/reactive.md)
describes scheduling, pause and recovery. Continuous SQL and speculative partial
draft execution are unsupported.

A finite query upload can contain several signed steps. If any step loses its
reply, **Retry exact submission** recovers that step's saved request. A later step
can require the same explicit action again. Status polling alone does not confirm
an uncertain submission or authorize a replacement query.
An explicit retry waits for an ongoing workspace check; navigation or a known
denial cancels the waiting action while retaining the saved request.

The optional application editor uses the shared compiler and neutral definition.
Review the whole valid proposal and publish conditionally with the operator's
current authority. A visual edit or accepted upload is not an activated interface
or completed data migration. See [application semantics](../reference/applications.md)
and the [Board application guide](../../../apps/transit-board/docs/application.md).

Board's UI is a projection of these contracts. Drawings, labels and rendered
forms cannot create additional operations, hidden grants or unsupported SQL.
