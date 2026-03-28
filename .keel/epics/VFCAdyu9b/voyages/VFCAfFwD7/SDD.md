# Neutralize Markdown Hover Underline - Software Design Description

> Remove the blue hover underline treatment from markdown docs links while keeping hover affordance explicit and the docs build workflow intact.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage applies a narrow shared-CSS override to markdown link hover/focus styling. The purpose is to stop hovered docs links from picking up a blue accent while keeping the interaction state obvious and consistent with the current Transit theme.

## Context & Boundaries

The remaining issue is specifically hover state in markdown docs content. That keeps the patch small:

- in scope: `theme-doc-markdown a:hover` and related focus/decoration behavior
- out of scope: navbar links, homepage buttons, or broader palette work

```
┌────────────────────────────────────────────┐
│ Shared docs markdown theme                 │
│                                            │
│  resting link rules                        │
│  hovered markdown link rules  <── patch    │
│                                            │
└────────────────────────────────────────────┘
```

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `website/src/css/custom.css` | local CSS | Owns the shared markdown link rules. | current repo |
| Docusaurus docs build | repo workflow | Verifies the site still builds after the hover override. | current repo |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Fix location | Override markdown hover link styles in `custom.css`. | The issue appears in shared docs content. |
| Hover tone | Use a non-blue Transit-aligned accent and explicit decoration color on hover/focus. | This directly addresses the clarified complaint. |
| Scope control | Leave resting-state link styling alone unless needed for consistency. | The user clarified the problem is hover-specific. |

## Architecture

The implementation stays in the shared docs theme layer:

- `website/src/css/custom.css`
  Updates markdown hover/focus link color and decoration rules.

## Components

### Markdown Hover Link Treatment

Purpose:
Make hovered docs links feel interactive without the leftover blue accent.

Behavior:
Hovered/focused markdown links use an explicitly non-blue color/decorative treatment.

## Interfaces

Primary verification interface:

- `just docs-build`

## Data Flow

1. Docusaurus renders markdown docs links.
2. Shared CSS applies the default docs link style.
3. On hover/focus, the override applies a non-blue accent and matching decoration.
4. The docs build emits the refined behavior without route changes.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Hover links still read blue | Manual review | Strengthen the explicit hover override or inspect selector precedence | Iterate in shared CSS before submission |
| Hover affordance becomes too weak | Manual review | Increase contrast or decoration clarity while staying off blue | Rebalance hover styles |
| The docs build regresses | `just docs-build` fails | Stop closure and fix the CSS change | Rebuild until green |
