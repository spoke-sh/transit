# Re-skin Transit Public Docs - Software Design Description

> Match the Keel docs visual system while swapping in a subway-network palette and differentiated Transit navigation chrome.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage ports the public Transit site onto the same visual shell used by the upstream Keel documentation and then re-colors that shell for a subway-inspired Transit identity. The implementation is intentionally narrow: shared theme chrome, navbar treatment, and the homepage surface change together so the site feels cohesive, while docs content and routing remain stable.

## Context & Boundaries

Transit already ships a public Docusaurus site, so this is not a greenfield docs launch. The work is a shell migration from Transit’s current lighter theme to the fuller Keel docs aesthetic. The boundary is explicit:

- in scope: shared docs CSS, navbar layout, homepage presentation, and palette shifts
- out of scope: major content rewrites, Keel-specific homepage component porting, or deploy-pipeline redesign

```
┌────────────────────────────────────────────────────────────┐
│                 Transit Docs Theme Refresh                 │
│                                                            │
│  shared shell CSS   swizzled navbar   homepage reskin      │
│   custom.css        src/theme/...     index.tsx + CSS      │
└──────────────────────────────┬─────────────────────────────┘
                               │
                  upstream Keel website aesthetic
```

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| Docusaurus theme override system | framework runtime | Allows Transit to swizzle `Navbar/Layout` so the shell structure matches Keel’s navbar slice treatment. | 3.x |
| Upstream `keel/website` theme files | local repo reference | Source aesthetic and structural patterns for the port. | current local checkout |
| Transit public docs site | existing repo app | Provides current routes, content, and deploy/build path that must remain intact. | current repo |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Theme source | Reuse the upstream Keel docs shell as the baseline. | The operator asked for the same theme rather than a new approximation. |
| Transit differentiation | Shift the palette toward subway-style route colors and make the navbar/header the clearest brand delta. | Keeps the shell familiar while ensuring Transit does not read like a simple Keel clone. |
| Homepage scope | Rework the homepage with Keel-like structural motifs but preserve Transit-specific copy and routes. | Gives the public front door the same visual quality without importing Keel-only content components. |

## Architecture

The voyage touches three layers:

- `website/src/theme/Navbar/Layout/`
  Swizzled navbar layout that provides the shell structure Keel’s CSS expects.
- `website/src/css/custom.css`
  Shared visual tokens and Docusaurus-surface styling for navbar, sidebar, body copy, code, footer, and cards.
- `website/src/pages/index.tsx` plus `website/src/pages/index.module.css`
  Transit homepage markup and styling aligned to the upstream aesthetic.

## Components

### Navbar Layout Override

Purpose:
Expose the same structural wrappers (`navbar__surface`, `navbar__slice`, and slice segments) used by Keel’s shell.

Behavior:
Preserve Docusaurus navbar behavior while extending its DOM shape for Transit’s shared shell styling.

### Shared Docs Theme

Purpose:
Define the visual tokens, spacing system, surface treatments, and doc-body styling for the entire site.

Behavior:
Applies one consistent shell across docs pages, navigation, and footer, with Transit-specific palette values.

### Homepage Surface

Purpose:
Give the public landing page the same aesthetic standard as the rest of the docs shell.

Behavior:
Uses Keel-like hero/section/CTA structure while keeping Transit’s product narrative and docs links.

## Interfaces

Primary local interfaces:

- `just docs-build`
- `npm --prefix website run start`

## Data Flow

1. Docusaurus loads the swizzled `Navbar/Layout`, producing the extra shell wrappers needed for the themed header.
2. Shared CSS applies Transit palette tokens and the full shell treatment across docs routes.
3. The homepage consumes its local module CSS to mirror the same aesthetic in hero, cards, and CTA sections.
4. The existing docs build path emits the refreshed static site without changing routes or the deployment pipeline.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Navbar shell classes do not line up with the swizzled layout | Visual breakage or missing header slice in local docs run/build | Adjust the theme override or CSS selectors | Rebuild after matching the DOM shape to the CSS contract |
| Palette changes reduce contrast or readability | Manual review on nav, buttons, and doc surfaces | Tweak token values before story submission | Re-run docs build and re-check visually |
| Homepage styling diverges too far from the shared shell | Manual review shows the landing page feels inconsistent with docs pages | Simplify or realign homepage module styles | Iterate until the page reads as one system |
| Docs build regresses after theme port | `just docs-build` fails | Stop story closure and fix the broken theme assets | Rebuild until the existing workflow passes |
