# 1. Publish the handbook

[Roadmap](README.md) · [Handbook build guide](../handbook/README.md)

Publish the static handbook at `https://transit.spoke.sh/`. The site project and
content live in `docs/handbook`; shared contracts and component guides keep their
repository owners. This is the next task after the documentation restructure.
The canonical URL and static build are prepared; no Cloudflare deployment or DNS
change is established by that preparation.

## Deployment design

Use Cloudflare Workers Static Assets to serve the Docusaurus output without a
Worker request handler or Transit backend. Cloudflare documents
[static site generation and 404 handling](https://developers.cloudflare.com/workers/static-assets/routing/static-site-generation/)
for this profile. Select `assets.directory: ./dist`,
`assets.html_handling: drop-trailing-slash` and
`assets.not_found_handling: 404-page` in a manifest beside the site package.
Existing routes remain `/guides/*`, `/reference/*`, `/internals` and `/sdks/*`.

The production [custom domain](https://developers.cloudflare.com/workers/configuration/routing/custom-domains/)
is `transit.spoke.sh`, with the worker as its origin. This requires an active
Cloudflare zone and a review of any existing record for that hostname. Keep
account identifiers and deployment credentials in deployment configuration and
GitHub secrets; they are not site content or browser environment variables.

## Implementation sequence

1. Inspect the selected Cloudflare account and `spoke.sh` zone. Establish whether
   `transit.spoke.sh` already serves anything and record the intended DNS change.
   Select the project name and production deployment identity.
2. Pin Wrangler through the existing Vite+ workspace tooling. Add the asset-only
   manifest with an explicit compatibility date, route policy and custom domain.
   Add focused tasks for preview, deployment and rollback without changing the
   Transit executable's CLI.
3. Build from a clean committed revision using the locked docs shell and workspace
   dependencies. Upload only `docs/handbook/dist`. Preserve the source revision
   and artifact identity with the deployment record; no runtime binaries,
   installation state or source checkout belongs in that artifact.
4. Add deployment CI for accepted `main` changes and an explicit manual trigger.
   Include handbook sources, component/SDK docs, contracts/generated descriptions,
   workspace locks and site tooling in change detection. Build/test pull requests
   without production credentials. If previews are added, keep their domains and
   indexing policy separate from production. Serialize production deployments so
   an older build cannot replace a newer one by finishing later.
5. Preview the exact asset bundle with Cloudflare's local serving behavior. Check
   direct deep links and refreshes, clean URLs, missing-page HTTP 404s, JSON content
   types, search, diagrams and exact schema bytes. Set cache policy so mutable
   HTML, search and schema URLs refresh together; fingerprinted JS/CSS can use
   immutable caching. Check a second deployment for stale assets.
6. Attach the custom domain, publish the verified bundle and inspect HTTPS from
   outside the account. Record the revision and deployment identifier. Exercise
   rollback to a previously verified deployment and restore the intended version.
   Promote operational commands into the handbook project guide.

## Completion evidence

Require successful public HTTPS and direct navigation to a guide, SDK page,
Internals page and generated API reference. Verify the canonical URL, sitemap,
robots policy, custom 404 response and all schema downloads. Confirm search
contains public guides/reference/Internals and excludes individual planning and
historical records. Inspect desktop/mobile navigation and keyboard access.

Keep preview/build evidence separate from actual Cloudflare routing, TLS and
rollback evidence. A local Docusaurus preview does not verify CDN behavior.
The current site describes the selected source revision; release-versioned
documentation and immutable release links remain separate distribution work.
