# Generated work-item browser

M23 implementation in progress. The strict TypeScript/Vite+ application builds
from `../interface.sql` through `transit-app module`; `../generate.py` writes or
checks the committed proposal. The SQL file selects renderer artifacts and is
never a published-definition fallback. The live interface must come from the
current native publication reader and match the build's realm, application,
component version and available renderers.

The application imports `transit-application` for definitions, presentation and
publication generations, and `transit-query-client` for transport, exact finite
draft recovery and complete result verification. Its work-item state labels are
application code; Board contains no business decoder. The browser retains one
visible page, clears it on generation changes, rechecks the visible page's current
authority, and keeps accepted query recovery outside disposable screens.

Run snapshot explicitly opens a one-intent generation. Live drafts explicitly
opens two intents and coalesces edits; it is not a source watch. Save recovery
before a browser restart, restore it, then recover or cancel the original work.
Nothing is persisted automatically in cookies or browser storage. Same-origin
Web Locks do not coordinate callers on other origins or hosts.

`vp check`, `vp exec tsc --noEmit` and `vp build` run here after the locked root
install. `just test::work-items-browser` qualifies this actual frontend with separate
native data/publication/requester workers and disk-backed Ursula. It exercises
three verified pages, schema/publication migration, an original uncertain upload
across browser/gateway restart, cancellation, a new query and current denial.
Compose/reference placements remain outstanding. See the [composition guide](../docs/browser.md).
