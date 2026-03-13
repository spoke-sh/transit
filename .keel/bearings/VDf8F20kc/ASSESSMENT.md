---
id: VDf8F20kc
---

# Research WireGuard Underlay And Server Transport Strategy — Assessment

## Scoring Factors

| Factor | Score | Rationale |
|--------|-------|-----------|
| Impact | 4 | Transport choices will strongly shape future server and replication ergonomics, security posture, and deployment complexity. |
| Confidence | 4 | The distinction between underlay security and application protocol semantics is already clear in the available evidence. |
| Effort | 2 | This is a narrow research and sequencing question, not a new storage or replication implementation effort. |
| Risk | 3 | The main risk is architectural confusion if WireGuard is treated as a substitute for `transit`'s protocol rather than a deployment primitive. |

*Scores range from 1-5:*
- 1 = Very Low
- 2 = Low
- 3 = Medium
- 4 = High
- 5 = Very High

## Analysis

### Findings

- The strongest conclusion is architectural separation: use WireGuard, if at all, as an optional secure underlay for trusted node interconnect, not as the `transit` replication protocol itself [SRC-01] [SRC-02] [SRC-05].
- The official embedding and limitations guidance reinforces that WireGuard deployment mode matters. Kernel deployment, userspace embedding, and heterogeneous client environments are not the same problem [SRC-03] [SRC-04].
- That makes this bearing more like a design guardrail than a standalone execution stream: it should constrain future replication and transport work, not become a separate epic by itself [SRC-05] [SRC-06].

### Opportunity Cost

If this question is ignored, later server work may conflate network security, transport, and replication protocol semantics into one muddy design problem. The cost of clarifying it now is low compared with reworking the future server and replication story later [SRC-05] [SRC-06].

### Dependencies

- The eventual server protocol and replication bearing must still define framing, acknowledgements, multiplexing, and replication units independently of the encrypted underlay choice [SRC-05].
- Operator expectations around private mesh deployment versus general network access must remain explicit when server transport work begins [SRC-01] [SRC-04].

### Alternatives Considered

- Treat WireGuard as the primary application transport, but that would confuse secure underlay with application protocol and leave core server semantics under-specified [SRC-01] [SRC-02] [SRC-05].
- Ignore WireGuard entirely and choose only an application transport, but that would miss a pragmatic secure-cluster deployment option for server-to-server traffic [SRC-01] [SRC-03].
- Convert the bearing into its own execution epic now, but that would overstate the amount of standalone product work here relative to its actual role as a constraint on future replication work [SRC-05] [SRC-06].

## Recommendation

[ ] Proceed → convert to epic [SRC-01] [SRC-02]
[x] Park → revisit later [SRC-01] [SRC-05]
[ ] Decline → document learnings [SRC-01]
