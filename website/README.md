# Transit Public Docs

This directory contains the public MDX documentation site for Transit.

## Local Workflow

Use the repo-supported `just` recipes from the repository root:

```bash
just docs-install
just docs-dev
just docs-build
```

The dev server binds to `0.0.0.0` by default. Override the port when `3000` is already in use:

```bash
PORT=3010 just docs-dev
```

These commands use the repository's Nix-supported Node toolchain so the docs workflow stays reproducible in this workspace.

For production publication, the repository-owned
[`publish-docs.yml`](../.github/workflows/publish-docs.yml) workflow is the
preferred lane. It publishes the stable Transit site plus the `main` preview
into the shared `spoke-previews` bucket through the infra-managed OIDC role.
The checked-in [`publish-docs.sh`](../scripts/publish-docs.sh) script is the
local repair and CI execution surface for that contract.

## Build Inputs

The site reads these optional environment variables at build time:

- `DOCS_SITE_URL`
- `DOCS_BASE_URL`

If they are not set, the site defaults to `https://www.spoke.sh` and
`/transit/`, which matches the shared production route.

## Deployment Inputs

The shared production docs lane is:

- stable docs at `https://www.spoke.sh/transit/docs`
- preview docs at `https://www.spoke.sh/previews/transit/<branch>/docs`

The publish workflow runs in the repository's `prod` GitHub environment. It
accepts the same publication inputs Keel uses:

- `AWS_ROLE_TO_ASSUME` (optional when the default `spoke-transit-docs-publisher` role ARN is correct)
- `DOCS_PREVIEW_BUCKET` (optional; defaults to `spoke-previews`)

The publish script also accepts:

- `DOCS_APP_NAME`
- `DOCS_SITE_URL`
- `DOCS_BRANCH`
- `DOCS_PUBLISH_STABLE`
- `DOCS_SKIP_SYNC`
