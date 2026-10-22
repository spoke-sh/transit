set shell := ["bash", "-euo", "pipefail", "-c"]
set working-directory := ".."

[default]
_default:
    @just --list transit-docs

# Install every locked frontend workspace dependency with Vite+.
install:
    vp install --frozen-lockfile

# Serve documentation locally with Docusaurus hot reload.
dev:
    cd docs/handbook && vp run start

# Build static HTML, references and exact specification downloads.
build:
    cd docs/handbook && vp run build

# Preview the existing production build on loopback.
serve:
    cd docs/handbook && vp run serve

# Validate source, strict types, reference generation and production links.
check:
    cd docs/handbook && vp check
    cd docs/handbook && vp exec tsc --noEmit
    cd docs/handbook && vp test run
    just transit-docs::build

# Install the locked Chromium used by the real documentation proof.
browser-install:
    vp exec --filter @transit/docs playwright install chromium

# Exercise production routes, responsive navigation, search and spec downloads.
browser: build
    cd docs/handbook && vp exec playwright test
