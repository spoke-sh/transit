# Add Spoke Header Nav Link - Software Design Description

> Add a right-side Spoke link immediately to the left of GitHub in the public docs header while preserving the existing docs build workflow.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage makes a narrow docs-configuration change in `website/docusaurus.config.ts`. The navbar already has a right-side `GitHub` item, so the implementation simply inserts a `Spoke` item before it using the same `https://www.spoke.sh` target found in the upstream Keel site.

## Context & Boundaries

The requested change is about header navigation only. That keeps the implementation small:

- in scope: right-side navbar items in `themeConfig.navbar.items`
- out of scope: site layout, styling, footer links, or documentation content

```
┌────────────────────────────────────────────┐
│ Transit docs navbar                        │
│                                            │
│ left items ...      Spoke   GitHub         │
└────────────────────────────────────────────┘
```

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `website/docusaurus.config.ts` | local config | Owns the Transit docs navbar items. | current repo |
| Upstream Keel `docusaurus.config.ts` | local repo reference | Provides the established Spoke link target and placement pattern. | current local checkout |
| Docusaurus docs build | repo workflow | Verifies the site still builds after the navbar change. | current repo |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Spoke target | Use `https://www.spoke.sh` | Matches the upstream Keel docs header exactly. |
| Placement | Insert `Spoke` on the right side immediately before `GitHub` | Matches the user request and upstream pattern. |
| Scope | Limit the patch to config only | No styling change is needed for a standard navbar item. |

## Architecture

The implementation stays in one file:

- `website/docusaurus.config.ts`
  Update `themeConfig.navbar.items` to add the `Spoke` link before `GitHub`.

## Components

### Header Nav Item

Purpose:
Expose a direct route from the Transit docs header to the broader Spoke site.

Behavior:
Renders as a standard right-side navbar link beside `GitHub`.

## Interfaces

Primary verification interface:

- `just docs-build`

## Data Flow

1. Docusaurus reads `themeConfig.navbar.items`.
2. The new `Spoke` item is rendered on the right side of the header before `GitHub`.
3. The docs build emits the updated header without affecting routes or content.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| `Spoke` appears in the wrong position | Manual review | Reorder the navbar item array | Rebuild after correcting item order |
| The target URL drifts from upstream | Local config review | Align the URL with upstream Keel config | Patch and rebuild |
| The docs build regresses | `just docs-build` fails | Stop closure and fix config | Rebuild until green |
