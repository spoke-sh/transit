# Implement Verifiable Lineage Primitives - Software Design Description

> Deliver the core integrity primitives and verification tools for transit.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage implements the core cryptographic integrity primitives for `transit`. It introduces SHA-256 content digests for segments and manifests, and `LineageCheckpoint` structures for verifiable stream heads.

## Architecture

The integrity model is layered on top of the existing storage kernel:
1. **Segment Layer:** Each segment carries a SHA-256 digest of its content.
2. **Manifest Layer:** The manifest carries a `manifest_root`, which is a digest of the manifest's own content (including segment descriptors).
3. **Checkpoint Layer:** A `LineageCheckpoint` binds a stream's head offset to the current `manifest_root`.

## Components

- `ContentDigest`: Shared structure for cryptographic digests.
- `SegmentDescriptor`: Updated to carry `content_digest`.
- `SegmentManifest`: Updated to carry `manifest_root`.
- `LineageCheckpoint`: New structure for stable, verifiable stream heads.
- `LocalEngine`: Updated with `checkpoint()` and `verify_local_lineage()` methods.
- `transit-cli`: Updated with `verify-lineage`, `checkpoint`, and `verify-checkpoint` commands.

## Data Flow

1. **Append:** Standard append path (stays fast).
2. **Segment Roll:** Compute SHA-256 digest of the finalized segment.
3. **Manifest Update:** Compute `manifest_root` of the new manifest state.
4. **Checkpoint:** Bind current head and `manifest_root` into a verifiable artifact.
5. **Verify:** Recompute and compare digests from storage against the manifest/checkpoint claims.

## Error Handling

<!-- What can go wrong, how we detect it, how we recover -->

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
