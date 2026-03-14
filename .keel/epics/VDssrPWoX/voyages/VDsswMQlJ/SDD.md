# Implement Consensus Kernel - Software Design Description

> Deliver the core consensus traits and lease-based stream ownership mechanism.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage implements distributed coordination for stream ownership. It moves `transit` from a single-node engine to a distributed-capable engine where multiple nodes can share access to object-store-backed history, but only one node "owns" the writable head of any given stream.

## Architecture

1. **Lease Model:** A node must acquire a distributed lease for `stream_id` before it can append records or update the manifest.
2. **Object Store Coordinator:** We use the `object_store` itself as the coordination point. A lease is implemented as an immutable object with a short TTL (or simulated via heartbeats and conditional updates).
3. **Fencing:** Every manifest update includes the lease ID. If the lease has been stolen or expired, the object store's conditional write (ETag or Version match) will reject the manifest update.

## Components

- `ConsensusHandle`: Async trait for acquiring and heartbeating leases.
- `ObjectStoreConsensus`: Implementation using conditional writes on a `lease.json` object.
- `FencedManifest`: A manifest update wrapped in an ownership proof.

## Data Flow

1. **Acquire:** Node A calls `consensus.acquire(stream_id)`.
2. **Lock:** Node A writes `leases/{stream_id}.lock` with its metadata and a version number.
3. **Heartbeat:** Node A periodically updates the lock to keep it alive.
4. **Append:** `LocalEngine` checks `consensus.is_leader(stream_id)` before accepting records.
5. **Roll/Publish:** Node A writes the new manifest. If Node B has stolen the lease, Node A's manifest write (which requires the current lease version) will fail.

## Error Handling

<!-- What can go wrong, how we detect it, how we recover -->

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
