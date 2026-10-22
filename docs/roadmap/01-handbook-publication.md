# 1. Publish the handbook

[Roadmap](README.md) · [Handbook build and publication guide](../handbook/README.md)

Publish the static handbook at `https://spoke-sh.github.io/transit/` through
GitHub Pages. The site project and content live in `docs/handbook`; shared
contracts and component guides keep their repository owners. Use the default
GitHub domain and the `/transit/` project path.

The [publication workflow](../../.github/workflows/handbook.yml) checks and
uploads the static artifact on pull requests, and deploys accepted `main`
revisions. Local build evidence does not establish a successful public deployment.
The handbook project guide owns setup, manual publication and rollback commands.

## Remaining acceptance work

1. Merge the workflow and observe the first successful `main` deployment. Confirm
   the Pages source is GitHub Actions and the `github-pages` environment permits
   only `main`. Record the source revision and deployment URL in the proof ledger.
2. Inspect public HTTPS and direct navigation/refreshes for a guide, SDK page,
   Internals page and generated API reference. Verify assets and links remain
   under `/transit/`, including canonical URLs, sitemap entries, search results
   and exact schema downloads. Confirm a nonexistent URL returns the site's
   custom 404 with HTTP 404, rather than a success response.
3. Inspect desktop/mobile navigation, diagrams and keyboard access on the live
   site. Search must contain public guides/reference/Internals and exclude
   individual planning and historical records. Keep these results distinct from
   the local production-browser proof.
4. Verify a subsequent accepted change appears publicly, and exercise recovery
   by reverting that change through `main`. Confirm the revision is republished
   and stale CDN assets do not mask the recovered content. Old workflow reruns
   must not replace newer `main` content.

GitHub owns the hosting cache policy; the repository uploads one static bundle
per deployment. Do not infer runtime or CDN guarantees from a successful local
build. Remove this milestone after recording the live publication and recovery
evidence. Release-versioned documentation and immutable release links remain
separate distribution work.
