# Tune Transit Network Shape Contrast - Software Design Description

> Increase the readability of the Transit Network Shape panel without changing the docs route structure or broader theme language.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage applies a focused homepage refinement to the `sceneDiagram` block inside Transit’s hero panel. The design intent is simple: strengthen contrast and glyph clarity enough that the network diagram can be read instantly, while keeping the panel inside the same subway-theme visual family introduced in the previous docs refresh.

## Context & Boundaries

The readability problem is localized to the hero diagram panel rather than the whole docs shell. That keeps the implementation small:

- in scope: diagram text color, weight, spacing, background contrast, and minor supporting panel treatment
- out of scope: sitewide palette changes, navbar/footer work, or hero copy/layout rewrites

```
┌─────────────────────────────────────────────┐
│ Transit homepage hero                       │
│                                             │
│  hero copy      scene frame                 │
│                 └─ scene diagram contrast   │
└─────────────────────────────────────────────┘
```

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `website/src/pages/index.module.css` | local CSS module | Owns the hero panel and diagram presentation. | current repo |
| `website/src/pages/index.tsx` | React page | Supplies the Transit Network Shape diagram markup. | current repo |
| Docusaurus docs build | repo workflow | Verifies the homepage still builds after the CSS refinement. | current repo |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Fix location | Tweak the hero diagram presentation in place instead of changing broader shell tokens. | The user feedback points to one panel, not the whole site. |
| Contrast method | Increase text opacity/weight, simplify the dark background, and add subtle framing rather than changing the diagram content itself. | This improves readability while preserving the current metaphor and copy. |
| Verification | Use manual review plus `just docs-build`. | The issue is perceptual, but the site still needs workflow verification. |

## Architecture

The change is expected to stay inside the homepage layer:

- `website/src/pages/index.module.css`
  Primary location for contrast, border, shadow, and typography adjustments.
- `website/src/pages/index.tsx`
  Only touched if a small markup refinement is needed to support the CSS.

## Components

### Scene Diagram

Purpose:
Show the branch/mainline mental model in a compact monospace panel.

Behavior:
Uses stronger contrast and clearer glyph rendering so readers can parse the network shape quickly.

### Scene Frame

Purpose:
Provide the raised shell around the diagram and first-stop links.

Behavior:
May receive minor support styling so the adjusted diagram still feels balanced inside the hero.

## Interfaces

Primary verification interface:

- `just docs-build`

## Data Flow

1. The homepage renders the existing Transit Network Shape diagram.
2. Updated CSS increases the legibility of the diagram text and panel surface.
3. The docs build emits the adjusted homepage without route or structure changes.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Contrast still feels weak after the first pass | Manual review | Increase foreground clarity or simplify the panel background further | Iterate in the CSS before submission |
| The panel becomes visually harsher than the rest of the hero | Manual review | Soften borders/shadows while keeping strong text contrast | Rebalance supporting styles |
| The docs build regresses | `just docs-build` fails | Stop closure and fix the homepage changes | Rebuild until green |
