# Board web

Strict TypeScript, React, and TanStack Router file routes built with the pinned
Vite+ 0.3.3 toolchain. The static output is embedded by the
[Board executable](../board/README.md), which hosts the authenticated API on the
same origin. There is no production JavaScript server.

From the repository root:

```sh
just board::install
just board::check
just board::demo
```

The [generated Board client](../../packages/ts/board-client/README.md) supplies
wire models and CSP-compatible runtime validation. No signing seed or provider
access reaches the browser. Access keys are transient form data; the only stored
authentication is the HttpOnly session cookie. No local/session storage or offline
cache is used. Logout/known denial unmounts and clears data views.

The overview, process tabs and journey use readable tables and sequence lanes.
Stable routes carry PID, tab, sort and lifecycle filters. Filtering applies to
the visible authorized page, not undisclosed totals. Polling preserves element
identity/focus, runs at five-second intervals and backs off to 30 seconds after
failures. Each view holds one page, aborts abandoned requests, pauses while hidden,
and never stitches a changed continuation. Historical pagination requires explicit
refresh; no unbounded graph or automatic scan is performed.

Opaque bytes render as escaped text or an explicit binary label. Timing labels
refer to the latest observation; no duration or ETA is inferred. Optional lenses
show mapping provenance and source revision alongside unchanged kernel facts.

`just board::browser` requires `just board::browser-install` first. It starts the
actual embedded binary against a disposable realm; checks login, deep links,
lazy assets, keyboard focus across polling, causal/effect explanations and logout;
and saves a local screenshot/failed traces under `.cache/`. Chromium needs its
host libraries; on supported CI Linux images Playwright can provision them with
`vp exec --filter @rey/board-web playwright install --with-deps chromium`.
