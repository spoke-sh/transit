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
Top-level sections follow the homepage's interface entry points: CLI, SQL, SDKs,
HTTP APIs/OpenAPI, reactive APIs/AsyncAPI, Flight SQL/ADBC and the native protocol.
Usage guides and wire contracts sit with their interface; shared concepts,
application state and operation have their own sections. Existing page routes
stay stable when their navigation location changes.

The [SQL reference](../../docs/reference/sql.md) indexes every statement in the
checked query/extension grammar, its historical-read fragment and the separate
application declaration language. Statement pages live in `docs/reference/sql/`
and distinguish executable queries, offline definitions and grammar-only syntax.

Every page in `docs/guides/` and `docs/reference/` must appear in the catalog.
These are the shared current documentation for users, developers and agents;
component guides stay beside their implementation. Engineering history and
planning live in `docs/internal/` and are excluded from the catalog and search.
Public guides/reference cannot depend on internal links. Every cataloged page,
including component guides and generated API content/downloads, plus every wire
contract in `contracts/`, is checked for milestone labels and roadmap references. Write these pages as a
snapshot of supported capabilities, retaining real wire/profile versions and
stating unsupported cases without delivery promises. Public workload priorities
and performance improvement plans distinguish selected direction from implemented
behavior and link their measured evidence. See
[documentation ownership](../../docs/README.md#where-documentation-lives).

Use direct interface language in the homepage and documentation. Describe
operations, compatibility, configuration and errors without maturity labels or
blanket readiness disclaimers. State specific limits where readers need them.

The docs plugin reads those files directly. A Markdown AST transform maps links
to included pages onto site routes and other repository links onto GitHub source.
Literal code examples are untouched. Original edit links point at the owning file.
Markdown uses CommonMark mode; Mermaid fences render as diagrams. No separate
copy of the foundations or generated wire schema is maintained here.

The [workload gallery](../../docs/guides/workload-examples.md) uses excerpts from
complete executable examples. A `source-excerpt` HTML comment before a code fence
names its repository-relative owner; content tests require the block to match
contiguous source lines, allowing only common indentation. Keep imports, setup
and run commands linked to the complete example. This guards documentation drift;
it does not replace the language checks or the example's real-authority proof.

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
It follows the top-level interface sections into executable SELECT, grammar-only
DDL and application declarations, and finds a statement through search.
It also follows the workload gallery into performance evidence and planned
session semantics, checking highlighted language blocks and search discovery.
It uses a private loopback port (4179 by default, `TRANSIT_DOCS_TEST_PORT` to change).
No Transit deployment is started or modified.

`just test::sql-grammar` also parses the public SQL examples and checks that they
cover every statement rule and the historical-read fragment. This verifies syntax,
not execution of administrative forms. `just test::application-grammar` validates
the complete published application program through the independent grammar and
real offline compiler, including its canonical model round-trip.

For a static host, set `TRANSIT_DOCS_URL` to its origin and optionally
`TRANSIT_DOCS_BASE_URL` to a path beginning and ending with `/`, then build. The
default is a local preview at `http://localhost:3000/`. Publish the resulting
`dist/` contents under that path; clean URLs need the host's `.html` resolution.
These tasks do not publish the site or assume a production domain. The preview
documents the checked-out source capabilities; published versioned
release documentation and immutable release links are not provided by this package.
