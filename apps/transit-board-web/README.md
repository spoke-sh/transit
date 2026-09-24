# transit-board-web

Strict TypeScript, React, and TanStack Router file routes built with the pinned
Vite+ 0.3.3 toolchain, packaged as `@rey/transit-board-web`. The static output is
embedded by the [Board executable](../transit-board/README.md), which hosts the private inspection API on the
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

## Working in the frontend

| Source | Owns |
| --- | --- |
| [routes/](src/routes/) | Overview, resource and PID/journey routes; stable URLs and route validation |
| [state.tsx](src/state.tsx) | Shared process inspection state and polling lifecycle |
| [resources.tsx](src/resources.tsx) | Resource/association/entry reads and generic state presentation |
| [components.tsx](src/components.tsx) | Evidence, status and process views |
| [model.test.ts](src/model.test.ts) | Model/client boundary tests |

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
