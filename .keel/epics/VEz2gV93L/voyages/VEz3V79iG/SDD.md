# Integrity End-To-End Proof - Software Design Description

> Exercise segment checksums, manifest roots, lineage checkpoints, and tamper detection end-to-end through `just screen` in both embedded and server modes.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage adds an `integrity-proof` CLI mission command to `transit-cli` that exercises the full integrity trust chain: segment checksums (fnv1a64), content digests (sha256), manifest roots, lineage checkpoints, and tamper detection. The proof joins the existing `just screen` flow as a peer of `local-engine-proof`, `tiered-engine-proof`, and `networked-server-proof`.

## Context & Boundaries

The integrity primitives already exist in `transit-core`. This voyage wires them into a proof surface — it does not invent new cryptographic layers.

```
┌──────────────────────────────────────────────────────────────┐
│                    just screen                                │
│                                                              │
│  local-engine  tiered-engine  networked-server  integrity    │
│  proof         proof          proof             proof (NEW)  │
└──────────────────────────────────────────────────────────────┘
        ↑               ↑               ↑              ↑
   transit-core    object_store    server::tests    engine.rs
   engine.rs       integration     framed proto     verify_*()
```

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `transit-core::engine` | crate | `verify_local_lineage()`, `checkpoint()`, `verify_checkpoint()` | current |
| `transit-core::storage` | crate | `SegmentChecksum`, `ContentDigest`, `SegmentManifest`, `LineageCheckpoint` | current |
| `transit-core::engine::validate_segment_checksum` | fn | fnv1a64 segment validation | current |
| `transit-core::engine::validate_segment_digest` | fn | sha256 segment validation | current |
| `transit-core::engine::compute_manifest_root` | fn | Manifest root computation | current |
| `transit-cli` | crate | Existing mission proof command pattern | current |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Proof shape | Single `integrity-proof` mission command with multiple phases | Follows the existing `local-engine-proof` pattern; one command, structured JSON output |
| Tamper method | Byte corruption of a sealed `.segment` file on disk | Simplest credible tamper scenario; exercises `verify_local_lineage()` without external tooling |
| Server parity | Run `verify_local_lineage` on the server's underlying engine after remote operations | Proves shared-engine integrity without needing a remote verification RPC |
| Screen integration | New `just screen` step between networked-server-proof and object-store probe | Natural position after the server proof establishes the data; integrity verifies it |

## Architecture

The proof command follows the existing mission proof pattern in `transit-cli`:

1. **Setup** — Create a temporary data root and open a local engine.
2. **Append & Roll** — Append enough records to trigger segment roll, producing sealed segments with checksums and digests.
3. **Verify Segments** — Call `verify_local_lineage()` and confirm all segments pass.
4. **Publish & Restore** — Publish to object storage, restore from remote manifest, verify manifest roots match.
5. **Branch & Checkpoint** — Create a branch, append to it, produce a `LineageCheckpoint`, verify it.
6. **Tamper & Detect** — Corrupt a sealed segment file, call `verify_local_lineage()`, confirm it reports the corruption.
7. **Server Parity** — Start a server on the same engine, perform remote operations, verify integrity on the underlying engine.

## Components

### IntegrityProofResult

A struct mirroring `LocalEngineProofResult` and `TieredEngineProofResult`:

- `data_root: String`
- `segment_verification: VerifyLineageOutcome` — pass/fail per segment
- `manifest_root_before_publish: String`
- `manifest_root_after_restore: String`
- `manifest_roots_match: bool`
- `checkpoint: LineageCheckpoint`
- `checkpoint_verified: bool`
- `tamper_detected: bool`
- `server_parity_verified: bool`

### Screen Integration

Add a `Prove integrity` step to the `just screen` recipe:
```bash
announce "Prove integrity"
just transit integrity-proof --root "$screen_root/integrity"
```

## Interfaces

The proof command follows the existing CLI interface pattern:

- `transit integrity-proof --root <path> [--json]`
- Human-readable terminal output by default with pass/fail indicators.
- `--json` produces `IntegrityProofResult` for machine consumption.

## Data Flow

1. Engine opens at `<root>` → appends records → segments roll with checksums and digests.
2. `verify_local_lineage()` reads sealed segments, recomputes checksums/digests, compares to manifest.
3. Publication pushes segments to object store → restore pulls them back → manifest root compared.
4. Branch created → checkpoint produced → `verify_checkpoint()` confirms binding.
5. Segment file bytes corrupted on disk → `verify_local_lineage()` returns verification failure.
6. Server wraps same engine → remote append → `verify_local_lineage()` on underlying engine confirms parity.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Segment checksum mismatch (expected in tamper scenario) | `verify_local_lineage()` returns `verified: false` for the corrupted segment | Report the corruption in proof output as a successful tamper-detection result | N/A — corruption is intentional in the proof |
| Manifest root mismatch after restore | Compare `manifest_root` fields from publication and restore outcomes | Fail the proof with a clear error | Investigate storage or publication bug |
| Checkpoint verification failure | `verify_checkpoint()` returns error | Fail the proof with checkpoint details | Investigate manifest or checkpoint binding bug |
| Server fails to start | Connection error during server parity phase | Fail the proof with server error | Investigate server lifecycle |
