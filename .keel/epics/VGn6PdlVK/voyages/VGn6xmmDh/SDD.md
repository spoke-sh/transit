# Object Store Runtime Bootstrap - Software Design Description

> Resolve authored object-store providers from config and boot hosted Transit with honest runtime guarantees.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage makes hosted runtime bootstrap honor the authored storage section
instead of hard-coding `LocalFileSystem` plus `durability = local`. The design
adds one generic provider factory and one hosted bootstrap path that can accept
that object store for tiered operation.

## Context & Boundaries

- In scope: config-to-object-store resolution, hosted runtime bootstrap, and
  honest bootstrap-time validation.
- Out of scope: downstream consumer adoption and deployment-repo rollout.

```
Transit config/env -> object-store factory -> hosted server bootstrap
                                       \-> shared proof/runtime helpers
```

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `object_store` | Rust crate | Provider builders and generic object-store trait | workspace |
| `transit-core::config` | internal | Effective config and provider selection | existing |
| `transit-core::server` | internal | Hosted server binding | existing |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Provider construction | Centralize provider building in shared Transit code instead of ad hoc `LocalFileSystem` calls in CLI paths. | One factory prevents runtime and proof drift. |
| Failure posture | Reject incomplete or unsupported provider configs loudly. | Silent local fallback would create false tiered claims. |
| Bootstrap contract | Keep `transit server run` generic and driven by config rather than consumer-specific flags. | Transit owns substrate semantics, not downstream migration shims. |

## Architecture

The hosted runtime path becomes:
1. load effective Transit config
2. resolve storage provider via shared factory
3. build hosted runtime context from node/storage/server config
4. bind the server using that context

## Components

- `transit-core::object_store_support` or adjacent shared module
  Builds `Arc<dyn ObjectStore>` from effective config.
- `transit-cli::run_server`
  Replaces the current local-only durability guard with hosted runtime
  bootstrap that accepts object-store-backed configs.
- shared validation helpers
  Surface provider-specific config errors with concrete messages.

## Interfaces

- Existing config keys remain authoritative:
  - `[storage].provider`
  - `[storage].bucket`
  - `[storage].prefix`
  - `[storage].endpoint`
  - `[storage].region`
  - `[storage].durability`
- Runtime bootstrap must preserve the hosted endpoint contract already
  documented in `HOSTED_CONSUMERS.md`.

## Data Flow

Config load -> provider factory -> runtime bootstrap -> server bind -> startup
recovery.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Unsupported provider features | Factory build fails | return explicit bootstrap error | operator fixes config/build features |
| Missing required bucket/prefix/region data | Config validation fails | return explicit bootstrap error | operator supplies missing values |
| Attempted local fallback on tiered config | Guard in bootstrap path | fail closed | use supported config or complete runtime support |
