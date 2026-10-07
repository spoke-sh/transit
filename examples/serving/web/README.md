# Counter live view

Strict TypeScript/Vite+ application example using `@rey/transit-reactive-client`.
It displays the int64 Table snapshot with the resource and revision from its
captured source cut and the application's separate data progress;
values remain decimal strings. The bounded first page explicitly reports when
more rows exist. This application owns counter presentation; Board has no
counter decoder.

The serving example embeds this real build. Set top-level `counter_view: true`
on a gateway configuration with `reactive: true` and an explicit viewer whose
`snapshot_values` is true. The exact configured private HTTPS origin serves the
page and reactive API. No browser signing keys, application server or external
assets are needed. Follow is explicit; Pause, hiding and page exit stop renewal.
Lease expiry handles an unavailable close. An unknown control retains its exact
signed bytes for recovery in the current page; a full reload does not persist them.

From the root, install locked dependencies with `just transit-board::install`.
From this directory use `vp check`, `vp exec tsc --noEmit` or `vp build`. Root
`zig build serving-example` embeds assets with the shared bounded build helper.
`just test::reactive-views` is the real Board/application Chromium proof. M21's
browser and placement qualification remains in progress until recorded in the
[proof ledger](../../../tests/README.md#m21-qualification).
