# Transit handbook

Docusaurus renders Transit's user and Internals documentation from the owning repository
Markdown files. Start with [the introduction](guides/introduction.md).
The site is a static frontend; it does not connect to Transit or hold credentials.
This directory owns the site project plus `guides/`, `reference/` and `internals/`.
The top-level [documentation index](../README.md) describes the repository's
other documentation owners. Roadmap, design and history stay outside this project.

From the repository root, inside `nix develop` (or the smaller `nix develop .#docs`):

```sh
just transit-docs::install
just transit-docs::dev
```

Open `http://localhost:3000/transit/`. `just transit-docs::build` writes `dist/` in this
package. `just transit-docs::serve` previews that production output. All commands
use locked workspace dependencies through Vite+; Docusaurus owns its site builder.
[Docusaurus 3.10.2](https://docusaurus.io/docs/installation) and Mermaid 11 are
pinned together with the supported ELK peer. This package intentionally omits
`type: module`: Docusaurus 3's generated webpack registry uses mixed module syntax.
Its TypeScript sources still use imports/exports. The strict tsconfig is local
because the upstream preset retains `baseUrl`, removed by our pinned TypeScript 7.
There is no dependency on Board's runtime or a running Transit installation.

## Sources and navigation

`catalog.ts`, `sdk-catalog.ts` and `internals-catalog.ts` map each owned Markdown file to a readable route and sidebar label.
The first reading path introduces data representations, computation lifetimes,
policies and the evidence that a declaration has been fulfilled. The quickstart
creates and evolves a dataset before introducing custom workers. Data model,
Queries and derived data, and Policies and lifecycle precede the interface
references: CLI, SQL, SDKs, HTTP APIs/OpenAPI, reactive APIs/AsyncAPI,
Flight SQL/ADBC and the native protocol. Usage guides and wire contracts sit with
their interface; execution mechanisms and custom applications have their own
sections. Existing page routes
stay stable when their navigation location changes. Internals has a navbar entry
beside Data model, CLI, SQL and SDKs and its own compact sidebar for nine scientific
accounts, the overview, standard and template. SDKs has its own sidebar with foundations and installation guides for each language,
read directly from `sdks/<language>/README.md`. Detailed API links retain their
component owners. All sections share the same site and search index.

The [SQL reference](reference/sql.md) indexes every statement in the
checked query/extension grammar, its historical-read fragment and the separate
application declaration language. Statement pages live in `docs/handbook/reference/sql/`
and distinguish executable queries, offline definitions, grammar-only syntax and
absent operations. Types, functions/operators and streaming/effect boundaries
have dedicated pages. Unsupported command entries remain searchable alongside
implemented statements and explain the available application API alternatives.
The [grammar surface inventory](reference/sql/grammar-surface.md)
also publishes planned language targets with explicit checked/proposed/undecided
syntax labels. Illustrative proposed forms use text blocks; `sql` examples remain
inputs to the existing grammar check. Publishing a target adds no parser support.

Every page in `docs/handbook/guides/`, `docs/handbook/reference/` and `docs/handbook/internals/` must appear
in the catalog. Usage guides and references explain current capabilities;
Internals consolidates mechanisms and rationale under the
[scientific standard](internals/standard.md). Roadmap (`docs/roadmap/`),
UI/UX design (`docs/design/`) and historical source accounts (`docs/history/`)
remain separate repository owners, linked without publishing their individual
records in the catalog or search. Component guides stay beside their
implementation. Search labels results as Internals or guides/reference so their
purpose remains visible before opening a page.

Usage/reference pages, included component guides, generated API content/downloads
and every wire contract in `contracts/` are checked for milestone labels and
roadmap references. The contributor ownership index may describe those separate
source sections. Internals can cite scoped proof records as evidence; it contains
no delivery plans or design-review series.
Optional links to technical reasoning are allowed; operating an interface must
not require reconstructing its semantics from an engineering record. See
[documentation ownership](../README.md#where-documentation-lives).

Published command examples use `transit` on `PATH` and state the required
installed bundle. Repository environment setup and task-runner commands stay
in repository tooling guides outside the catalog and search. The public launcher
overview retains its route and links to the repository runbook. Content checks
reject repository tool commands and path-qualified CLI invocations in published
code, including included component guides and generated reference content.

Use direct interface language in the homepage and documentation. Describe
operations, compatibility, configuration and errors without maturity labels or
blanket readiness disclaimers. State specific limits where readers need them.

The docs plugin reads those files directly. A Markdown AST transform maps links
to included pages onto site routes and other repository links onto GitHub source.
Literal code examples are untouched. Original edit links point at the owning file.
Markdown uses CommonMark mode; Mermaid fences render as diagrams. No separate
copy of the foundations or generated wire schema is maintained here.

The [interface and architecture map](reference/interfaces.md) is the coverage
index: CLI/configuration, native SQL sessions, PostgreSQL/MySQL, language SDKs,
signed native HTTP, Table mediation, Serving, reactive APIs, Board, Arrow/Flight
and outbound connectors each lead to usage, contracts and technical accounts.
Runtime coverage includes authority, delivery, state, Station, query execution,
storage/concurrency/cleanup, deployment and observability. When an interface
changes, update its public owner and this map, then the relevant Internals account
if the mechanism or its evidence changes. Keep historical measurements tied to
their source revisions; documentation checks are not new runtime qualification.

The [workload gallery](guides/workload-examples.md) uses excerpts from
complete executable examples. A `source-excerpt` HTML comment before a code fence
names its repository-relative owner; content tests require the block to match
contiguous source lines, allowing only common indentation. Keep imports, setup
and run commands linked to the complete example. This guards documentation drift;
it does not replace the language checks or the example's real-authority proof.

`lib/specs.ts` renders API operations/messages and recursive field/variant tables
from checked Board/serving OpenAPI and reactive AsyncAPI descriptions. Builds copy
the same bytes to `specs/` for downloads. `lib/downloads.ts` also publishes native
message schemas and the setting registry, indexed by
[Contracts and schema downloads](reference/contracts.md). These files are copied
exactly, without treating native messages as OpenAPI. Regenerate descriptions with their
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
errors. `just check all` includes it. The experience CI lane owns it on ordinary runs;
documentation-only PRs run it through the dedicated documentation job. This
includes site code and assets under `docs/handbook`; shared dependency, contract
and runtime changes still select the full CI path. Markdown links across the
repository are checked separately by `python3 -B tests/runner/docs.py`.

```sh
just transit-docs::browser-install
just transit-docs::browser
TRANSIT_DOCS_BASE_URL=/handbook/ just transit-docs::browser
```

The browser proof builds and serves real output, checking desktop/mobile navigation,
search, generated references, exact spec downloads, diagrams and accessibility.
It follows the homepage into the data model and dataset tutorial, and finds the
shared data/computation/policy model through search.
It follows the top-level interface sections into executable SELECT, grammar-only
DDL and application declarations, and finds a statement through search.
It opens Internals from desktop/mobile navigation, finds its scientific standard
through labeled search results, follows the template and technical accounts,
renders their diagrams, and verifies Roadmap/Design links target source indexes.
It also follows the workload gallery into performance evidence and shared
session semantics, checking highlighted language blocks and search discovery.
Publication checks cover direct new-reference routes, canonical URLs, sitemap,
robots, search entries, the 404 artifact and exact schema downloads.
It uses a private loopback port (4179 by default, `TRANSIT_DOCS_TEST_PORT` to change).
No Transit deployment is started or modified.

`just test::sql-grammar` also parses the public SQL examples and checks that they
cover every statement rule and the historical-read fragment. This verifies syntax,
not execution of administrative forms. `just test::application-grammar` validates
the complete published application program through the independent grammar and
real offline compiler, including its canonical model round-trip.

## Static publication contract

The canonical origin defaults to `https://spoke-sh.github.io`, with base path `/transit/`
and no trailing slash on page routes. Local development still listens at
`http://localhost:3000/transit/`; canonical URLs do not select the listening interface.
Override `TRANSIT_DOCS_URL` and optionally `TRANSIT_DOCS_BASE_URL` for a different
publication target. A base path must begin and end with `/`.

From the repository root:

```sh
nix develop .#docs --command just transit-docs::install
nix develop .#docs --command just transit-docs::check
```

The publication artifact is **`docs/handbook/dist/`**, not the repository root.
It contains static HTML, fingerprinted assets, `404.html`, `sitemap.xml`,
`robots.txt`, the local `search-index.json` and exact `specs/` downloads. It needs
no running Node or Transit service. Source Markdown, roadmap, design and history
are not copied into this artifact; selected source links lead back to GitHub.

The `trailingSlash: false` setting emits `.html` files for clean page routes,
as supported by [Docusaurus on GitHub Pages](https://docusaurus.io/docs/deployment#deploying-to-github-pages).
Assets, internal links, search results, canonical URLs and schema downloads carry
the `/transit/` prefix. GitHub controls CDN caching and serves `404.html` for
missing pages. This build has no catch-all SPA success response.

## GitHub Pages publication

[Publish handbook](../../.github/workflows/handbook.yml) builds pull requests and
every push to `main`, including changes to component guides and contract owners
outside this directory. It installs the locked dependencies in the Nix docs shell,
checks repository links, runs `transit-docs::check`, then uploads only `dist/` as
the `github-pages` artifact. Artifacts are retained for 14 days. Local build and
preview commands do not publish anything.

Only `main` can deploy, using the `github-pages` environment. The deployment job
has `pages: write` and `id-token: write`; build jobs have read-only repository
access. No personal token, deployment secret, custom domain or DNS record is
needed. The workflow uses GitHub's
[artifact deployment actions](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages),
without a publishing branch or a Jekyll build. Deployments are serialized; a
superseded revision or an old workflow rerun is skipped after checking current
`main`. A failed build leaves the last successful deployment in place.

The repository's **Settings → Pages → Build and deployment → Source** must be
**GitHub Actions**. Keep the `github-pages` environment restricted to the `main`
branch. Accepted `main` revisions publish
[the handbook](https://spoke-sh.github.io/transit/). The deployment records the
commit and site URL; the final step checks the public homepage, an interface
reference, search index and SQL session schema over HTTPS.

To republish current `main`, use **Actions → Publish handbook → Run workflow**
with branch `main`, or `gh workflow run handbook.yml --ref main`. To roll back a
content or site regression, revert the offending change through a PR and merge
it into `main`; that new revision goes through the same checks and deployment.
Rerunning a superseded commit does not roll the site back.

The [publication evidence](../history/qualification/interfaces.md#published-handbook-observations-2026-10-21)
records successful deployments and direct public-content checks. Live browser
coverage, controlled revert/republication and superseded-run recovery checks
remain unqualified. Local Docusaurus preview does not verify GitHub's CDN routing
or cache behavior.
The site describes the checked-out source capabilities; release-versioned
documentation and immutable release links are not provided by this package.
