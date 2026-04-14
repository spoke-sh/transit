# Published Cutover Surface - Software Design Description

> Publish the runtime and client surface downstream repos need for a hard cutover without private adapters.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage ensures the upstream runtime and client surface are the only
contract downstream repos need. The work is mostly contract publication:
runtime docs, client guidance, examples, and direct-cutover language that
matches the real hosted server behavior.

## Context & Boundaries

- In scope: upstream docs, examples, client-surface clarity, direct-cutover
  guidance.
- Out of scope: downstream code changes.

```
runtime/proof truth -> upstream docs/client surface -> downstream direct cutover
```

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `HOSTED_CONSUMERS.md` | doc | Canonical hosted contract | existing |
| `transit-client` | crate | Canonical Rust client surface | existing |
| object-store runtime and proof voyages | internal | Supply the truth the published docs must match | voyages `VGn6xmmDh`, `VGn6z2GXx` |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Publication surface | Keep runtime contract, client guidance, and direct-cutover language upstream in Transit. | Downstream repos should cite Transit, not reinterpret it. |
| Cutover stance | Require deletion of duplicate adapters once the upstream path exists. | The user explicitly wants no transitional debt. |
| Language boundary | Keep docs generic and consumer-neutral. | Transit remains substrate, not product-specific integration lore. |

## Architecture

The voyage aligns three layers:
1. runtime/proof truth
2. upstream client surface
3. published downstream cutover guidance

## Components

- `HOSTED_CONSUMERS.md`
  Canonical endpoint/auth/acknowledgement contract.
- `transit-client`
  Canonical Rust import surface and proof examples.
- `DIRECT_CUTOVER.md` and related docs
  Explicit guidance for removing downstream duplicate adapters.

## Interfaces

- `<host>:<port>` hosted endpoint grammar
- `RemoteAcknowledged<T>` / `RemoteErrorResponse`
- `transit-client::TransitClient`

## Data Flow

Runtime and proof updates land first, then docs/examples are updated to match,
then downstream repos consume that published surface.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Docs drift from runtime | review/tests catch mismatch | block publication update | reconcile docs with runtime/proofs |
| Client examples preserve old assumptions | example/test review fails | update examples before sealing | re-run cutover proof paths |
