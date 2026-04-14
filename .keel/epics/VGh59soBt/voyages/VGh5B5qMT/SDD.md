# Remote Authority Contract And Consumer Wiring - Software Design Description

> Define how external control planes publish consumer-owned records to hosted Transit and consume acknowledgements, replay, and thin client surfaces without local embedded authority.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage defines the first hosted-authority contract for consumer-owned workloads. The objective is not to teach Transit downstream domain policy; it is to make a running transit-server the authoritative append/replay surface for external control planes and prove that consumers can interact with it through thin remote contracts only.

## Context & Boundaries

Transit already has a network server, a thin Rust client, and shared lineage semantics. What is missing is a clearly authored authority path for downstream services that currently treat embedded local storage as the source of truth.

```
┌──────────────────────────────────────────────────────────────┐
│                 External Control Plane Consumer             │
│      domain writer, replay reader, projection user          │
└───────────────────────────────┬──────────────────────────────┘
                                │ thin remote contract
┌───────────────────────────────┴──────────────────────────────┐
│                         transit-server                       │
│              authoritative append/replay acknowledgements    │
└───────────────────────────────┬──────────────────────────────┘
                                │ shared engine semantics
┌───────────────────────────────┴──────────────────────────────┐
│                     transit-core lineage model               │
│          manifests, checkpoints, branches, replay rules      │
└──────────────────────────────────────────────────────────────┘
```

### In Scope

- hosted authority contract for external workload producers and readers
- thin remote proof surfaces and acknowledgement guidance
- migration guidance for Hub-like consumers

### Out of Scope

- object-store authority and warm-cache recovery semantics
- provider-specific domain logic
- downstream UI and browser flows

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `transit-server` | binary/service | Hosted authority endpoint for append and replay | current |
| `crates/transit-client` and shared remote client transport | existing code | Thin remote contracts for downstream consumers and proofs | current |
| Repo proof path | operator surface | Evidence that the hosted authority path works end to end | current |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Authority boundary | Hosted transit-server owns append and replay for consumer-owned records; consumers stop opening embedded local authority stores | Removes redeploy-sensitive local authority from downstream services |
| Client model | Thin remote client and acknowledgement surfaces only | Preserves the one-engine thesis and avoids a second semantic path |
| Workload vocabulary | Keep the remote contract generic while allowing downstream examples to exercise it | Keeps the voyage directly useful without making Transit own consumer schema |
| Migration guidance | Explicitly document local embedded authority as an anti-pattern for hosted control planes | Prevents partial adoption that leaves the real failure mode intact |

## Architecture

The voyage introduces or clarifies three layers:

1. Server authority contract
   A running transit-server is the only append/replay authority for hosted downstream workloads.
2. Thin consumer contract
   Consumers use remote client configuration, acknowledgement surfaces, and replay calls only.
3. Proof and migration surface
   Repo-native proofs and docs show how a downstream service should interact with hosted authority and what it must not do anymore.

## Components

### Hosted Authority Contract

- Purpose: Name the authoritative server endpoint, access token, and durability posture expected by external consumers.
- Behavior: Downstream services connect to transit-server, publish records, and replay acknowledged history there.

### Remote Proof Fixture

- Purpose: Exercise append, replay, and acknowledgement handling for representative consumer-owned records through the hosted path.
- Behavior: Starts or connects to a server, publishes reference records, replays them, and surfaces acknowledgement semantics.

### Migration Guidance

- Purpose: Explain how Hub-like consumers stop opening local embedded authority stores.
- Behavior: Documents the cutover boundary and points consumers toward the hosted contract and proof path.

## Interfaces

Interfaces shaped by this voyage:

- server endpoint + token configuration for external consumers
- append and replay acknowledgements surfaced through the existing remote contract
- reference workload message families used in proofs and examples
- documentation contract describing the no-local-authority rule for hosted control planes

## Data Flow

1. External consumer configures a hosted Transit endpoint and token.
2. Consumer publishes consumer-owned records through the remote contract.
3. transit-server acknowledges the write with explicit durability posture.
4. Consumer replays authoritative history from the server.
5. Proof and docs confirm that no local embedded authority store participated in the workflow.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Consumer falls back to local embedded authority | Proof or code review finds local engine open path in hosted workflow | Reject the implementation | Keep remote-only contract explicit and documented |
| Server acknowledgement semantics hidden by the client | Tests or proof output omit status/error posture | Treat as design failure | Surface raw acknowledgement and error envelopes |
| Reference workload leaks consumer policy into Transit core | Review finds provider-specific rules in core modules | Reject the design | Move policy back to the consumer and keep only generic reference fixtures and contract language |
