# Strengthen Embedded Branch Metadata Replay Views And Artifact Helpers - Decision Log

<!-- Append entries below. Each entry is an H2 with ISO timestamp. -->
<!-- Use `keel mission digest` to compress older entries when this file grows large. -->

## 2026-03-29T10:53:00-07:00

- Opened this mission from upstream product guidance after concluding that Transit already has the core lineage, replay, checkpoint, and artifact primitives needed for the work.
- Scoped the mission to helper surfaces and ergonomics for embedded callers rather than new conversation semantics, keeping paddles responsible for the first application-specific conversational layer.
