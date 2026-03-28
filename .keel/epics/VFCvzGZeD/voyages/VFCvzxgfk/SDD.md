# Repair Docs Header Layout - Software Design Description

> Keep the docs header single-line and full-width on desktop while handing off cleanly to the mobile navbar before layout overlap occurs.

**SRS:** [SRS.md](SRS.md)

## Overview

Repair the custom Docusaurus navbar shell in place. The header already uses a swizzled layout plus Transit-specific CSS; the regression comes from Infima allowing `.navbar__inner` to wrap once the additional right-side item is present. The repair will keep the shell single-line on desktop, reduce the chance of width pressure, and widen the handoff to the mobile navbar so the wrapped intermediate state never appears.

## Context & Boundaries

- In scope: Transit docs navbar layout, responsive CSS behavior, and the existing header item arrangement.
- Out of scope: content reorganization, footer changes, and non-navbar styling work.
- External dependency: Docusaurus/Infima navbar behavior, especially the default wrap and mobile breakpoint rules.

```
┌─────────────────────────────────────────┐
│              This Voyage                │
│                                         │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐ │
│  │         │  │         │  │         │ │
│  └─────────┘  └─────────┘  └─────────┘ │
└─────────────────────────────────────────┘
        ↑               ↑
   [External]      [External]
```

## Dependencies

<!-- External systems, libraries, services this design relies on -->

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| Docusaurus classic theme | frontend framework | Provides the swizzled navbar layout and item rendering model | repo-pinned website deps |
| Infima navbar CSS | CSS framework | Supplies the default wrap and mobile breakpoint behavior being overridden | transit website dependency tree |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Desktop wrapping | Force the custom navbar shell to stay single-line on desktop. | Prevents the overlapping two-row state that broke the page layout. |
| Responsive fallback | Override the default breakpoint so the mobile navbar appears before the Transit desktop nav can wrap. | Keeps navigation available without squeezing the desktop shell past its safe width. |
| Navigation content | Keep `Spoke` and `GitHub` intact. | The regression is layout-related, not a reason to remove the new link. |

## Architecture

The repair stays inside the docs theme layer:

- `website/src/css/custom.css` owns navbar shell sizing, width, and responsive overrides.
- `website/docusaurus.config.ts` remains the source of truth for the actual nav items.
- `website/src/theme/Navbar/Layout/index.tsx` continues to provide the custom surface-and-slice structure without structural changes unless the CSS fix proves insufficient.

## Components

- Navbar shell CSS: defines width, height reservation, wrapping behavior, and responsive handoff.
- Swizzled navbar layout: preserves the header surface and colored slice chrome.
- Docusaurus navbar content: renders the configured links and mobile toggle/sidebar.

## Interfaces

No API surface changes. The user-visible interface is the public docs header behavior across viewport widths.

## Data Flow

1. Docusaurus renders navbar items from `docusaurus.config.ts`.
2. The swizzled navbar layout wraps that content in the Transit surface/slice shell.
3. Transit CSS decides whether the desktop row remains active or hands off to the mobile navbar.

## Error Handling

Primary failure mode is another CSS regression that still allows wrapping or hides navigation unexpectedly. Detect with docs build plus manual review of the responsive header behavior and recover by keeping the change isolated to the navbar shell rules.

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Desktop header still wraps | Manual review | Tighten nowrap and breakpoint rules | Rebuild docs and re-check the affected viewport range |
| Mobile navbar appears without usable navigation | Manual review | Reconcile toggle/item visibility rules with Docusaurus defaults | Rebuild docs and verify sidebar navigation |
