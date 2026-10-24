# Working on the handbook

Follow the [shared documentation instructions](../AGENTS.md). This directory owns
public guides, reference, Internals and the Docusaurus site. Read the
[site guide](README.md) before changing catalogs, rendering, search or publication.

## Write for the reader's task

- `guides/` teaches runnable workflows. State prerequisites, use public operations
  and show the result or progress the reader can inspect.
- `reference/` defines current concepts, operations, types, configuration,
  compatibility and concrete limits. Keep supported, offline, grammar-only and
  proposed capabilities distinct.
- `internals/` explains models, mechanisms, invariants, alternatives and evidence.
  Consolidate related explanations around a technical subject.

Start with the [data model](reference/data-model.md). Explain data, computation
and policies before execution machinery. Usage pages must include the assumptions
and failure semantics needed to operate an interface; deeper reasoning can link
to Internals. Keep milestone IDs, roadmap links and delivery sequencing out of
usage pages, examples, routes and generated descriptions. The documentation
ownership index may name those repository sections.

Public command examples use `transit` from `PATH` and name the required installed
bundle. Keep repository setup and task commands in source tooling guides outside
the site catalog. Label speculative syntax as proposed text, not executable SQL.
Use the existing grammar checks when changing SQL or application examples;
parser acceptance alone does not establish execution support.

New and substantively revised architecture accounts must follow the
[scientific standard](internals/standard.md), using the
[account template](internals/template.md) where useful. Identify scope, source
basis, assumptions, claims, reasoning, evidence, reproduction, alternatives and
limits. Link the owning contracts, implementation and proof ledger; a site build
does not rerun or expand cited runtime evidence.

## Keep sources and navigation aligned

Every Markdown page under `guides/`, `reference/` and `internals/` belongs in the
catalog and search. Update [catalog.ts](catalog.ts),
[internals-catalog.ts](internals-catalog.ts) or [sdk-catalog.ts](sdk-catalog.ts) as
appropriate, along with the relevant index/sidebar. Preserve existing routes
when reorganizing navigation. Update the [interface map](reference/interfaces.md)
when an interface's documentation coverage changes.

Read component and SDK guides from their owning files; do not copy them into this
directory. Keep roadmap, design, history and agent instructions as repository
sources outside the catalog and search. Use ordinary relative Markdown links;
the site transform resolves included pages to routes and other owners to source.

Render generated API descriptions and copy schema downloads from their checked
owners. Regenerate them through the owning package tasks, never by editing site
output. Keep the site static, without credentials or live service requests.
Restart the development server after changing catalogs, schemas or search-index
inputs; ordinary Markdown edits hot reload.

## Validate the change

From the repository root, use the pinned docs shell and locked dependencies:

```sh
nix develop .#docs --command just transit-docs::install
nix develop .#docs --command python3 -B tests/docs.py
nix develop .#docs --command just transit-docs::check
```

The site check covers formatting/lint, strict types, content/link-transform tests
and a production build with broken links and anchors treated as errors. For
navigation, search, rendering or hosting changes, use the site guide's
[browser proof](README.md#validation-and-hosting), including root/prefixed routes
where affected. Local checks do not establish live hosting behavior. Follow the
[publication workflow](README.md#github-pages-publication) for hosting changes.
