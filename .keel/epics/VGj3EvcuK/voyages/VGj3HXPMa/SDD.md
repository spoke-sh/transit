# Define Hosted Consumer Endpoint Contract - Software Design Description

> Make the authoritative hosted endpoint, auth, acknowledgement, and error contract explicit for downstream consumers such as Spoke so new semantics land only in Transit-owned contract surfaces.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage defines the authoritative hosted consumer contract above Transit's
generic engine and below any downstream product semantics. The goal is to make
it impossible for consumers such as Spoke to invent a second endpoint, auth, or
acknowledgement contract locally.

## Context & Boundaries

In scope: hosted endpoint grammar, auth posture, acknowledgement vocabulary,
and error semantics for downstream consumers.

Out of scope: downstream repo implementation, consumer-owned schemas, and Infra
rollout manifests.

```
┌────────────────────────────────────────────────────────────┐
│                         This Voyage                        │
│                                                            │
│  hosted endpoint grammar -> auth posture -> ack/error      │
│  contract for downstream consumers                         │
└────────────────────────────────────────────────────────────┘
          ↑                                   ↑
   downstream repos                     Transit generic core
```

## Dependencies

<!-- External systems, libraries, services this design relies on -->

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| Mission `VGh598Oz0` | prior Transit mission | Supplies the generic hosted authority vocabulary this voyage must refine rather than replace. | current repo |
| Spoke mission `VGikpu8hf` | downstream consumer contract | Confirms that Spoke must consume the upstream contract and delete duplicate local runtime/client ownership. | current repo docs |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Contract owner | Transit owns the hosted consumer endpoint/auth/ack/error contract | Stops downstream repos from becoming parallel protocol authorities |
| Scope boundary | Keep schema and business policy outside Transit | Preserves the generic substrate role |
| Cutover rule | Downstream repos cut directly to the upstream contract and do not preserve a second protocol lineage | Keeps the cutover clean |

## Architecture

The voyage introduces one authored contract layer:

- `Hosted consumer endpoint contract`
  Purpose: define the authoritative endpoint grammar, auth posture, ack
  vocabulary, and error surface for downstream consumers.

## Components

- `Endpoint grammar`
  Purpose: state how downstream consumers identify the hosted authority
  surface.
- `Auth posture`
  Purpose: state how credentials or other access material are presented without
  making the contract Spoke-specific.
- `Acknowledgement and error surface`
  Purpose: define the literal durability and failure vocabulary consumers must
  preserve.

## Interfaces

- Downstream consumers should be able to answer:
  - which upstream Transit surface is the hosted authority
  - how auth material is attached or referenced
  - what acknowledgement fields are authoritative
  - which error fields are authoritative and must survive the cutover literally

## Data Flow

1. A downstream repo such as Spoke targets the hosted Transit authority.
2. The repo authenticates using the authored upstream posture.
3. Hosted operations return literal acknowledgement and error semantics from
   Transit-owned contract surfaces.
4. Downstream repos consume those semantics directly instead of inventing or
   preserving a second contract.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Downstream contract drift reappears in repo-local implementations | Review finds new endpoint or ack behavior authored only outside Transit | Treat as architectural drift | Update the upstream contract first, then consume it downstream |
| Hosted auth posture becomes consumer-specific | Contract review finds Spoke-specific semantics inside Transit docs or interfaces | Reject the design as overscoped | Reframe the contract around generic hosted consumers |
| Ack or error vocabulary is underspecified | Downstream cutover planning cannot state what must be preserved literally | Treat the contract as incomplete | Expand the upstream authored surface before asking consumers to cut over |
