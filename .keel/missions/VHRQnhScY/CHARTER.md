# Ship Batch Append For Hosted Rust Producers - Charter

Archetype: Strategic

## Goals

| ID | Description | Verification |
|----|-------------|--------------|
| MG-01 | Ship single-stream batch append across the hosted protocol, `transit-server`, `transit-client`, and CLI so downstream Rust producers can amortize append overhead without collapsing multiple logical records into opaque payload envelopes. | board: VHRQnhLcW |

## Constraints

- Preserve the shared-engine thesis: hosted batching must reuse the existing stream, lineage, segment, and manifest semantics rather than introducing a second write path.
- Keep the scope to one stream per request. Multi-stream transactions, cross-stream atomicity, and streaming producer protocols are out of mission scope.
- Preserve per-record Transit semantics: batch append may reduce transport overhead, but replay, tail, checkpoints, and downstream materialization must still observe ordinary individual records with deterministic contiguous offsets.
- Make success and failure explicit at the batch boundary, including documented server/client limits for batch size and failure behavior when those limits are exceeded.
- Keep the Rust client and CLI as thin hosted surfaces over the remote contract; they must not invent private batching envelopes or repo-local protocol dialects.
- The verification bar is targeted tests plus CLI proof coverage for happy-path batching and limit/failure behavior.

## Halting Rules

- DO NOT halt while any MG-* goal has unfinished board work
- HALT when epic `VHRQnhLcW` is complete, mission verification is recorded, and `keel doctor` reports no blocking board-health errors
- YIELD to human when satisfying the mission would require changing the product boundary to include multi-stream atomicity, a streaming producer protocol, or altered read/tail/materialization semantics
