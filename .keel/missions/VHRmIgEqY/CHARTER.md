# Improve Hosted Transit Robustness For Producer Consumer Workloads - Charter

Archetype: Strategic

## Goals

| ID | Description | Verification |
|----|-------------|--------------|
| MG-01 | Improve hosted Transit robustness for sustained producer/consumer workloads by making connection I/O timeouts configurable, serving accepted connections concurrently, and shipping proof coverage that shows the hosted request/response surface survives moderate load without routine 1s transport timeouts. | board: VHRmIhDsm |

## Constraints

- Preserve the shared-engine thesis: robustness work must stay in the existing hosted client/server transport boundary and continue to reuse the same append, replay, lineage, manifest, and durability semantics.
- Keep the request/response protocol intact. This mission does not change append semantics, tail semantics, or introduce a streaming producer protocol.
- Make timeout behavior explicit on both sides of the hosted boundary. Server and client timeouts must be configurable, with the current 1s default remaining explicit when callers do not override it.
- Remove strict serial connection serving in the listener path. Per-connection worker threads or an equivalent concurrent handoff are acceptable; a larger transport redesign is not required for this mission.
- Do not expand scope into connection pooling or reuse. That can be a separate optimization track after robustness is restored.
- Verification must include targeted automated coverage and a CLI/server proof path that exercises raised timeout configuration under mixed producer/consumer load.

## Halting Rules

- DO NOT halt while any MG-* goal has unfinished board work
- HALT when epic `VHRmIhDsm` is complete, mission verification is recorded, and `keel doctor` reports no blocking board-health errors
- YIELD to human when satisfying the mission would require changing the hosted protocol semantics, introducing connection pooling as a prerequisite, or expanding scope beyond configurable timeouts and concurrent connection serving
