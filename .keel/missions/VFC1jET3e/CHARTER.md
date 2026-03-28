# Refresh Transit Docs Theme With Subway Palette - Charter

Archetype: Strategic

## Goals

| ID | Description | Verification |
|----|-------------|--------------|
| MG-01 | Reuse the Keel docs visual system for Transit’s public site while shifting the shell to a subway-inspired palette and a distinct Transit navigation header so the product reads as intentional on first contact. | board: VFC1jEl3d |

## Constraints

- Reuse the upstream Keel docs shell structure instead of inventing a second visual system for Docusaurus.
- Keep Transit visually distinct through palette and copy choices; use a subway-network direction inspired by systems like the NYC Subway and London Underground.
- Preserve the existing docs routes, information architecture, and deploy/build workflow; this mission is a presentation refresh, not a content rewrite.
- Make the top navigation/header visibly different from Keel’s default blue treatment.

## Halting Rules

- DO NOT halt while `MG-01` has unfinished board work or while the docs shell still materially diverges from the upstream Keel theme.
- HALT when `MG-01` is satisfied, the docs build passes, and `keel doctor` reports no blocking board-health errors.
- YIELD to human when palette or branding tradeoffs need product direction beyond the subway-theme brief.
