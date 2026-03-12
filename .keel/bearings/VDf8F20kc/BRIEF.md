# Research WireGuard Underlay And Server Transport Strategy — Brief

## Context

The current server and replication research still leaves the transport question open. This bearing exists to decide whether `transit` should treat WireGuard as a serious transport candidate, and if so, whether it belongs as the primary application transport or as a secure underlay beneath a separate `transit` protocol.

## Objectives

- Decide whether WireGuard should be treated as an optional node-to-node underlay, a primary transport candidate, or a non-goal for `transit`.
- Separate encrypted network underlay concerns from application-level replication and server protocol concerns.

## Scope

### In Scope

- WireGuard protocol and deployment properties relevant to server-to-server `transit` traffic.
- Tradeoffs between kernel WireGuard underlay, userspace embedding, and application-level transports.
- The boundary between secure underlay and `transit`'s own framing, acknowledgements, and replication semantics.

### Out Of Scope

- Designing the full `transit` server protocol in this bearing.
- Replacing the existing multi-node replication/server bearing.
- Browser, UI, or end-user client transport design beyond noting deployment implications.

## Research Questions

- Should `transit` standardize on WireGuard only as an optional secure underlay for trusted node meshes?
- What still has to be solved by the `transit` application protocol even if WireGuard is present?
- Does userspace WireGuard embedding preserve enough of the kernel-path benefit to matter for `transit`?

## Open Questions

- Should the future `transit` server wire protocol target QUIC/TCP semantics over arbitrary networks while optionally running under WireGuard for private cluster traffic?
- How much key-management and peer-topology burden is acceptable before WireGuard stops being a pragmatic deployment primitive?
