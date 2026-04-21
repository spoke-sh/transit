# Configurable Hosted Timeouts And Concurrent Connection Handling - Product Requirements

## Problem Statement

Hosted Transit still hits transport timeouts under sustained producer/consumer load because connection I/O timeouts are hardcoded at 1s and accepted connections are served serially.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Make the existing hosted Transit request/response surface operationally robust for separate producer/consumer workloads without changing append or tail semantics. | Targeted tests and CLI/server proof coverage show configurable timeouts plus concurrent connection handling eliminate routine 1s transport failures under moderate sustained load. | Voyage `VHRmIjGvL` planned |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Downstream Rust Producer | Engineer running a separate `transit-server` process and appending many records through the Rust SDK. | A configurable client/server transport boundary that survives sustained batch append traffic without forcing heavy retry logic just to outrun 1s timeouts. |
| Downstream Rust Consumer | Engineer polling or tailing the same hosted stream while producers are actively appending. | Hosted reads and polls that are not head-of-line blocked behind a producer connection in the listener loop. |
| Transit Maintainer | Engineer evolving the hosted runtime and CLI proof surface. | A bounded transport/runtime fix that improves robustness while keeping the protocol and shared-engine semantics intact. |

## Scope

### In Scope

- [SCOPE-01] Configurable server-side connection I/O timeout on the hosted runtime surface, with an explicit default that remains 1s unless overridden.
- [SCOPE-02] Configurable client-side I/O timeout on `RemoteClient` and `TransitClient`.
- [SCOPE-03] Concurrent handling of accepted hosted connections so a producer and consumer are no longer served strictly serially.
- [SCOPE-04] Targeted tests and CLI/server proof coverage for moderate sustained producer/consumer traffic with raised timeouts and unchanged protocol semantics.
- [SCOPE-05] Operator-facing guidance for the new timeout knobs and their non-semantic nature.

### Out of Scope

- [SCOPE-06] Connection pooling, connection reuse, or any broader transport optimization beyond the immediate robustness fix.
- [SCOPE-07] Changes to append, read, tail, lineage, checkpoint, or materialization semantics.
- [SCOPE-08] Multi-node topology redesign, streaming producer sessions, or any protocol change beyond runtime configuration and concurrency behavior.
- [SCOPE-09] Application-level retry/backoff policy above the hosted boundary.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Add configurable server-side connection I/O timeout on `ServerConfig`, keeping the explicit 1s default when unset. | GOAL-01 | must | Hosted servers need a supported way to raise per-connection socket timeouts above the hardcoded 1s floor under sustained workloads. |
| FR-02 | Add configurable client-side I/O timeout on `RemoteClient` and `TransitClient`, keeping the explicit 1s default when unset. | GOAL-01 | must | Downstream Rust clients need a matching knob so the hosted boundary can be tuned coherently on both sides. |
| FR-03 | Serve accepted hosted connections concurrently instead of handling them strictly inline in the listener loop. | GOAL-01 | must | Mixed producer/consumer workloads currently suffer head-of-line blocking when one accepted connection monopolizes the listener thread. |
| FR-04 | Publish CLI/server proof coverage that exercises raised timeout configuration and mixed producer/consumer activity on the existing hosted protocol surface. | GOAL-01 | must | This is an operational robustness change; the proof path needs to demonstrate the tuned hosted runtime rather than rely on code inspection alone. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Preserve the current hosted request/response, append, and tail semantics exactly; timeout and concurrency work must not alter acknowledged history or wire meaning. | GOAL-01 | must | The request is about runtime robustness, not protocol semantics. |
| NFR-02 | Moderate sustained producer/consumer workloads should no longer hit routine 1s transport timeouts once the new configuration knobs are raised above the work duration. | GOAL-01 | must | The feature is only useful if it materially improves the failure mode observed in practice. |
| NFR-03 | Keep scope bounded to transport/runtime robustness rather than drift into connection pooling or a second hosted client dialect. | GOAL-01 | must | The immediate problem can be solved without introducing a larger architectural branch. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

| Area | Method | Evidence |
|------|--------|----------|
| Server and client timeout configuration | Targeted unit/integration tests across `transit-core` and `transit-client` | Story-level evidence under voyage `VHRmIjGvL` |
| Concurrent connection handling | Targeted hosted transport tests under mixed producer/consumer activity | Story-level evidence under voyage `VHRmIjGvL` |
| Operator-facing proof path | CLI/server proof or targeted CLI tests that exercise raised timeout configuration | Story-level evidence under voyage `VHRmIjGvL` |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| Raising timeouts and serving accepted connections concurrently is sufficient to eliminate the current routine transport failures without redesigning the protocol. | The epic could under-solve the observed workload or force a broader transport follow-up immediately. | Validate through mixed producer/consumer proof coverage and targeted load-oriented tests. |
| The current one-connection-per-request model can remain in place for this improvement cycle. | The epic could accidentally broaden into connection reuse or pooling before the immediate robustness fix lands. | Hold connection reuse explicitly out of scope in design and story contracts. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| What default raised timeout should the proof path use to demonstrate robustness without overstating a universal recommendation? | Epic owner | Open |
| Should the concurrent connection handoff use per-connection worker threads, a small pool, or another minimal concurrency mechanism? | Epic owner | Open |
| Does the CLI/operator surface need explicit timeout flags, config-file keys, or both to make the proof path credible? | Epic owner | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] Hosted servers expose configurable connection I/O timeout instead of requiring the hardcoded 1s default.
- [ ] `RemoteClient` and `TransitClient` expose matching client-side timeout configuration.
- [ ] Accepted hosted connections are no longer served strictly serially.
- [ ] CLI/server proof coverage shows a mixed producer/consumer workload can run with raised timeouts and preserved protocol semantics without routine transport timeout failure.
<!-- END SUCCESS_CRITERIA -->
