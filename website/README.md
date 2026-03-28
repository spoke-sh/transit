# Transit Public Docs

This directory contains the public MDX documentation site for Transit.

## Local Workflow

Use the repo-supported `just` recipes from the repository root:

```bash
just docs-install
just docs-sync
just docs-dev
just docs-build
```

The dev server binds to `0.0.0.0` by default. Override the port when `3000` is already in use:

```bash
PORT=3010 just docs-dev
```

These commands use the repository's Nix-supported Node toolchain so the docs workflow stays reproducible in this workspace.

## Build Inputs

The site reads these optional environment variables at build time:

- `DOCS_SITE_URL`
- `DOCS_BASE_URL`

If they are not set, the site defaults to `https://transit.spoke.sh` and `/`.

## Deployment Inputs

The GitHub Actions docs workflow expects these repository variables for deployment:

- `TRANSIT_DOCS_DEPLOY_ENABLED`
- `TRANSIT_DOCS_SITE_URL`
- `TRANSIT_DOCS_BASE_URL`
- `TRANSIT_DOCS_BUCKET`
- `TRANSIT_DOCS_DISTRIBUTION_ID`
- `TRANSIT_DOCS_AWS_ROLE_ARN`
- `TRANSIT_DOCS_AWS_REGION` (optional; defaults to `us-east-1`)
