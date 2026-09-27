# transit-board-web

Strict TypeScript, React, and TanStack Router file routes built with the pinned
Vite+ 0.3.3 toolchain, packaged as `@rey/transit-board-web`. The static output is
embedded by the [Board executable](../transit-board/README.md), which hosts the private inspection and optional Table query APIs on the
same origin. There is no production JavaScript server.

From the repository root:

```sh
just transit-board::install
just transit-board::check
just transit-board::demo
```

The [generated Board client](../../packages/ts/transit-board-client/README.md) supplies
wire models and CSP-compatible runtime validation. No signing seed or provider
access reaches the browser. Views open directly without a sign-in form or
Board session. Board sets no cookies and uses no local/session storage or offline
cache.
Known denial unmounts and clears data views; a retry rechecks the configured
Transit read grant. Startup failures also expose a retry action.

The overview, process tabs and journey use readable tables and sequence lanes.
Stable routes carry PID, tab, sort and lifecycle filters. Filtering applies to
the visible authorized page, not undisclosed totals. Polling preserves element
identity/focus, runs at five-second intervals and backs off to 30 seconds after
failures. Each view holds one page, aborts abandoned requests, pauses while hidden,
and never stitches a changed continuation. Historical pagination requires explicit
refresh; no unbounded graph or automatic scan is performed.

Opaque bytes render as escaped text or an explicit binary label. Timing labels
refer to the latest observation; no duration or ETA is inferred. State resources
and associations have generic views with explicit coverage, lifecycle and revision
evidence. Resource entries render as exact hex bytes after an explicit read.

## Visual design exploration

The growing profile implements a bounded relief atlas and Table workspace from
D5/D6's architecture and a focused D7 interaction, recorded in [D9](../../docs/design/board-atlas/D9.md).
Processes/Resources emphasis and overhead detail share stable selection. Resource
entry is explicit; Canvas and Browse retain one SQL draft and identified result.
Run compiles/submits once; switching views never runs it. Editing a completed
query preserves its result with a visible draft-changed label.

One verified result segment is resident at a time, with exact int64 strings,
nulls and binary labels. Five-second current-policy observations continue while
the resource interior is hidden by Neighborhood. Browser tab hiding clears
visible results; returning rechecks authority. Known denial/expiry clears the
source, draft, result and frozen pending request. A connection failure hides
protected rows and preserves uncertain submission identity for explicit retry.
No storage, history or retention pin survives leaving the page.

The atlas shows at most eight processes and eight authorized resources. Relief
marks pending work qualitatively; unavailable bytes, outbox counts and age stay
unknown. Keys include framework metadata. Only the configured query Table has
an entry affordance for queries; all resources offer **Inspect records**, subject
to the configured read grant. That view holds eight record identities with
recognized exchange metadata and exact source revisions. It omits captured
bodies and application values, uses explicit continuation, and clears on errors
or tab hiding. Five-second refreshes recheck current authority. Auto emphasis,
animated entry and D8 venues/growth remain open design proposals.

Recognized HTTP captures offer **Inspect HTTP metadata**. The selected view shows
frozen policy revisions, budgets, trust digest, timing, omitted field counts and
committed member references. Body values, raw routing fields and credentials are
excluded. Only the selected metadata records are verified; this view makes no
claim to have replayed the full body. It follows the same current-grant refresh
and clearing rules as the records view.

## Working in the frontend

| Source                                         | Owns                                                                              |
| ---------------------------------------------- | --------------------------------------------------------------------------------- |
| [routes/](src/routes/)                         | Overview, resource and PID/journey routes; stable URLs and route validation       |
| [state.tsx](src/state.tsx)                     | Shared process inspection state and polling lifecycle                             |
| [resources.tsx](src/resources.tsx)             | Resource/association/entry reads and generic state presentation                   |
| [components.tsx](src/components.tsx)           | Evidence, status and process views                                                |
| [atlas.tsx](src/atlas.tsx)                     | Growing catalog, emphasis, selection and explicit resource entry                  |
| [records.tsx](src/records.tsx)                 | Growing record identities and source-backed exchange metadata                     |
| [http-metadata.tsx](src/http-metadata.tsx)     | Selected HTTP policy, timing, omission and completion evidence                    |
| [query-workspace.tsx](src/query-workspace.tsx) | One draft/result, explicit submission, current-policy refresh and denial clearing |
| [model.test.ts](src/model.test.ts)             | Model/client boundary tests                                                       |

Import public types and transports from `@rey/transit-board-client`; do not copy
wire types into a route. Generated route trees and client validators are not
hand-maintained APIs. Make API changes in the Zig owner, run
`just transit-board::generate`, and use `just transit-board::check` before the
real embedded-browser proof. Keep business-value decoding in downstream UIs.

`just transit-board::browser` requires `just transit-board::browser-install` first. It starts the
actual embedded binary against a disposable realm; checks direct access, deep
links, lazy assets, keyboard focus across polling, causal/effect explanations,
denial clearing and connection retries;
and saves a local screenshot/failed traces under `.cache/`. Chromium needs its
host libraries; on supported CI Linux images Playwright can provision them with
`vp exec --filter @rey/transit-board-web playwright install --with-deps chromium`.

`just transit-board::query-browser` qualifies the growing atlas and workspace
against real hosts, including live revocation and lossless typed values.
`just transit-board::http-browser` checks actual HTTP capture metadata and live
read revocation against the disk/S3 worker fixture; it additionally requires Docker.
