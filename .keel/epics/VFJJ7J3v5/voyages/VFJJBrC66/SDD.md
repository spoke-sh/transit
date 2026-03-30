# Sync Controlled Failover Contracts And Guides - Software Design Description

> Align the foundational documents and public MDX docs with the shipped controlled failover proof so first-time users and operators see one consistent contract for promotion readiness, explicit lease handoff, former-primary fencing, and the bounded non-claims around durability, quorum, and multi-primary behavior.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage is a documentation-alignment slice. It does not change runtime behavior. It updates the root contracts where Transit defines durability, consistency, and deployment semantics; adds a first-class public explanation of the controlled failover slice; threads that explanation into the existing first-run and concept pages; and then resyncs the generated reference docs so the public reference set mirrors the foundational documents.

## Context & Boundaries

In scope: root docs that define the canonical controlled failover contract, public MDX pages that onboard first-time users, and the reference-doc sync output.

Out of scope: any new engine semantics, protocol changes, server implementation changes, or broader docs-site redesign.

```
┌─────────────────────────────────────────────────────────────┐
│            Controlled Failover Documentation Sync          │
│                                                             │
│  root contracts -> public MDX guides -> synced reference   │
│   durability/consistency   first-run/onramp   website/docs │
└─────────────────────────────────────────────────────────────┘
           ↑                              ↑
    shipped proof surface          docs build + sync
```

## Dependencies

<!-- External systems, libraries, services this design relies on -->

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `crates/transit-cli/src/main.rs` | repo proof surface | Supplies the shipped `controlled-failover-proof` contract and wording to mirror in docs | current repo |
| `README.md` / `GUIDE.md` / `ARCHITECTURE.md` | foundational docs | Canonical source material for the public reference set | current repo |
| `website/scripts/sync-foundational-docs.mjs` | repo tool | Regenerates website reference docs from root documents | current repo |
| Docusaurus docs under `website/docs/` | public guides | User-facing concept and first-run pages that need the updated contract | current repo |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Canonical wording source | Root documents plus the shipped CLI proof output | Keeps the repo contracts and the user-facing docs anchored to the same behavior |
| Public docs shape | Add one dedicated controlled-failover concept page and thread it into adjacent guides | A dedicated page prevents the contract from being buried in scattered one-line mentions |
| Reference sync | Regenerate synced reference docs instead of hand-editing generated files | Preserves the existing docs publishing workflow |

## Architecture

The voyage has three documentation layers:

- `foundational contracts`
  Root documents such as `ARCHITECTURE.md` define the canonical durability and consistency boundaries.
- `public MDX guides`
  Concept and first-run pages translate that contract into first-time-user language and proof-oriented guidance.
- `synced reference docs`
  The generated reference set republishes the foundational docs into the public docs site.

## Components

- `root contract updates`
  Adjust foundational docs so the controlled failover slice is part of the durable repo contract.
- `controlled failover concept page`
  Gives users one direct page that explains readiness, handoff, fencing, and non-claims.
- `guide link updates`
  Thread the new concept and proof command into durability, deployment, and first-run guides.
- `reference sync output`
  Refreshes the generated public reference docs after the root-doc edits land.

## Interfaces

Touched interfaces are documentation interfaces only:

- root Markdown contracts in the repo root
- MDX concept and onboarding pages under `website/docs/`
- the `just docs-sync` and `just docs-build` workflows

## Data Flow

1. Update the root contracts so the foundational wording reflects the shipped controlled failover slice.
2. Update the MDX guides so public docs explain the same contract and proof commands.
3. Run the foundational-doc sync to regenerate website reference docs from the updated root contracts.
4. Build the docs site to ensure the public artifact remains publishable.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Root docs and MDX guides drift on failover wording | Manual review or docs diff shows inconsistent non-claims | Treat as contract drift | Rewrite until the same controlled failover contract appears in both surfaces |
| Generated reference docs stay stale after root-doc edits | `website/docs/reference/contracts/*` does not reflect root-doc changes | Run the supported sync workflow | Rebuild the synced reference output before closing the story |
| MDX links or structure break during edits | `just docs-build` fails | Treat as a publishability failure | Repair links/frontmatter and rebuild |
