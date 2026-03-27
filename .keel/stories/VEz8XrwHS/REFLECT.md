---
created_at: 2026-03-26T23:53:00
---

# Reflection - Add Tail Session Support To Rust Client

## Knowledge

- [VL5mQ8pTs](../../knowledge/VL5mQ8pTs.md) Rust Tail Grant Credit Is A Poll Alias

## Observations

- The existing `RemoteClient` already carried the full tail-session behavior, so the Rust client story was mostly about exposing it without adding another abstraction layer.
- Using `TransitClient` itself for the tests kept the evidence on the public client surface instead of re-testing `RemoteClient` directly.
- The main semantic choice was naming: `grant_credit()` reads like a distinct capability, but it intentionally delegates to `poll()` so the wrapper stays protocol-faithful.
