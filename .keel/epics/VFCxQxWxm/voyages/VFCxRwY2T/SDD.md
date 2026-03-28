# Tune Hero Diagram Card - Software Design Description

> Raise the hero diagram contrast and align the four route links below it to the same usable width as the lineage panel without changing the broader docs shell.

**SRS:** [SRS.md](SRS.md)

## Overview

Refine the hero card in place. The implementation stays inside the homepage CSS module so the diagram panel can be brightened and the route-link list can be given the same full-width, box-sized treatment as the lineage panel above it.

## Context & Boundaries

- In scope: homepage hero-card presentation, especially the diagram panel and the route-link list below it.
- Out of scope: broader homepage redesign, docs shell changes, and route/content changes.
- External dependency: Docusaurus homepage rendering and the existing Transit docs theme variables.

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
| Docusaurus homepage rendering | frontend framework | Renders the Transit landing page and CSS module styles | repo-pinned website deps |
| Transit theme variables | design system | Supplies the current docs-shell color and surface tokens | `website/src/css/custom.css` |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Contrast approach | Brighten the panel foreground and simplify the panel background rather than changing the diagram content. | The readability issue is primarily a visual contrast problem. |
| Width alignment | Make both the diagram panel and route links explicitly full-width and box-sized within the hero frame. | This gives the lower items the same usable width treatment as the lineage box above them. |
| Scope control | Keep the change inside `index.module.css`. | The problem is local to the homepage hero card. |

## Architecture

The change stays in the homepage layer:

- `website/src/pages/index.tsx` continues to render the same hero structure.
- `website/src/pages/index.module.css` owns the contrast and width treatment for the diagram and route-link blocks.

## Components

- `sceneDiagram`: monospace lineage box that needs higher readability.
- `sceneSteps` and `sceneStepLink`: route-link list that needs the same usable width treatment as the diagram panel.
- `sceneFrame`: shared hero-card container that remains structurally unchanged.

## Interfaces

No API or content-surface changes. The user-visible interface is the rendered hero card.

## Data Flow

1. `index.tsx` renders the hero card with the diagram followed by the route links.
2. `index.module.css` applies the panel contrast and width rules to both blocks.
3. The built Docusaurus site ships the refined hero card through the existing docs build path.

## Error Handling

Primary risks are under-correcting the contrast or accidentally changing the hero-card structure. Detect with manual review plus `just docs-build`, and recover by keeping the adjustment isolated to the homepage CSS module.

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Diagram still reads too dark | Manual review | Raise foreground contrast and reduce background muddiness further | Rebuild docs and re-check the hero card |
| Route links still look narrower than the diagram box | Manual review | Add explicit width and box-sizing to the list items/links | Rebuild docs and verify the hero card again |
