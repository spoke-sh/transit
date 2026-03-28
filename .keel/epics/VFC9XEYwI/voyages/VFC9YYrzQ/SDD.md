# Tune Public Docs Link Decoration - Software Design Description

> Replace the light blue docs link underline with a less distracting treatment while preserving clear link affordance and the existing docs build workflow.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage applies a narrow shared-CSS refinement to docs-body links. The goal is to remove the bright light blue underline treatment and replace it with a calmer decoration that still reads clearly as a link, using the existing Transit theme language rather than inventing a new accent system.

## Context & Boundaries

The complaint is about the underline decoration, not link text color or the broader docs shell. That keeps the patch tight:

- in scope: docs-body `text-decoration-color` and related hover decoration styling
- out of scope: navbar links, homepage layout, or larger palette adjustments

```
┌────────────────────────────────────────────┐
│ Public docs shell                          │
│                                            │
│  docs body links  <── shared decoration    │
│                                            │
└────────────────────────────────────────────┘
```

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `website/src/css/custom.css` | local CSS | Owns shared docs-body link styling. | current repo |
| Docusaurus docs build | repo workflow | Verifies the site still builds after the CSS refinement. | current repo |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Fix location | Adjust shared docs-body link decoration in `custom.css`. | The issue is theme-level and appears across docs content. |
| Default tone | Move the underline toward a neutral ink treatment instead of the current light blue accent. | The user explicitly dislikes the bright blue underline. |
| Hover tone | Retain a clearer accent on hover without restoring the same bright base treatment. | Keeps affordance obvious while calming the resting state. |

## Architecture

The implementation should stay in one place:

- `website/src/css/custom.css`
  Updates the `theme-doc-markdown a` and `theme-doc-markdown a:hover` rules.

## Components

### Docs Link Decoration

Purpose:
Provide a readable, intentional underline treatment for links inside docs content.

Behavior:
Uses a calmer resting-state underline with a stronger hover-state cue.

## Interfaces

Primary verification interface:

- `just docs-build`

## Data Flow

1. Docusaurus renders docs-body links using the shared theme styles.
2. Updated CSS changes the underline color behavior in resting and hover states.
3. The docs build emits the refined styling without route or structure changes.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Underline becomes too subtle to read as a link | Manual review | Increase underline contrast or hover differentiation | Iterate in shared CSS before submission |
| The new underline feels disconnected from the Transit palette | Manual review | Shift the decoration toward a better-aligned neutral/accent mix | Rebalance the colors |
| The docs build regresses | `just docs-build` fails | Stop closure and fix the styling change | Rebuild until green |
