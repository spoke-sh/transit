# transit-docs

Docusaurus renders Transit's user documentation from the owning repository
Markdown files. Start with [the introduction](../../docs/guides/introduction.md).
The site is a static frontend; it does not connect to Transit or hold credentials.

From the repository root, inside `nix develop` (or the smaller `nix develop .#docs`):

```sh
just transit-docs::install
just transit-docs::dev
```

Open `http://localhost:3000`. `just transit-docs::build` writes `dist/` in this
package. `just transit-docs::serve` previews that production output. All commands
use locked workspace dependencies through Vite+; Docusaurus owns its site builder.
[Docusaurus 3.10.2](https://docusaurus.io/docs/installation) and Mermaid 11 are
pinned together with the supported ELK peer. This package intentionally omits
`type: module`: Docusaurus 3's generated webpack registry uses mixed module syntax.
Its TypeScript sources still use imports/exports. The strict tsconfig is local
because the upstream preset retains `baseUrl`, removed by our pinned TypeScript 7.
There is no dependency on Board's runtime or a running Transit installation.

## Sources and navigation

`catalog.ts` maps each owned Markdown file to a readable route and sidebar label.
All top-level foundational `docs/*.md` files must appear in the catalog. Task
guides and cross-interface references live in `docs/guides` and `docs/reference`;
component guides stay beside their implementation. See
[documentation ownership](../../docs/README.md#where-documentation-lives).

The docs plugin reads those files directly. A Markdown AST transform maps links
to included pages onto site routes and other repository links onto GitHub source.
Literal code examples are untouched. Original edit links point at the owning file.
Markdown uses CommonMark mode; Mermaid fences render as diagrams. No separate
copy of the foundations or generated wire schema is maintained here.

`lib/specs.ts` renders API operations/messages and recursive field/variant tables
from checked Board/serving OpenAPI and reactive AsyncAPI descriptions. Builds copy
the same bytes to `specs/` for downloads. Regenerate those descriptions with their
owners, not in this package; `just transit-board::contract` and
`just test::reactive-descriptions` detect upstream drift. Build/start clear Docusaurus compilation caches so changes to external schemas
and link transforms cannot leave old rendered contracts behind. The generated reference
is read-only, with no credential collection or live request console.

Search downloads a static text index on demand and filters locally; it has no
external service, API key or analytics. Restart the dev server after editing the
catalog, API descriptions or search-index content; ordinary Markdown pages hot
reload, but the index is built when configuration loads.

## Validation and hosting

`just transit-docs::check` runs Vite+ lint/format, strict TypeScript, reference/link
transform tests and a production build with broken links/anchors treated as
errors. `just check` includes it. The experience CI lane owns it on ordinary runs;
documentation-only PRs run it through the dedicated documentation job.

```sh
just transit-docs::browser-install
just transit-docs::browser
TRANSIT_DOCS_BASE_URL=/handbook/ just transit-docs::browser
```

The browser proof builds and serves real output, checking desktop/mobile navigation,
search, generated references, exact spec downloads, diagrams and accessibility.
It uses a private loopback port (4179 by default, `TRANSIT_DOCS_TEST_PORT` to change).
No Transit deployment is started or modified.

For a static host, set `TRANSIT_DOCS_URL` to its origin and optionally
`TRANSIT_DOCS_BASE_URL` to a path beginning and ending with `/`, then build. The
default is a local preview at `http://localhost:3000/`. Publish the resulting
`dist/` contents under that path; clean URLs need the host's `.html` resolution.
These tasks do not publish the site or assume a production domain. Versioned
release docs and immutable source links belong to [M27](../../docs/roadmap/M27.md).
