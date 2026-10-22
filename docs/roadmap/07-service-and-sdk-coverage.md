# 7. Service and SDK coverage

[Roadmap](README.md) · **Status:** Planned

Extend source, type and lifecycle limits documented by
[connectors](../handbook/reference/connectors.md), [reactive APIs](../handbook/reference/reactive.md),
[Flight/ADBC](../handbook/reference/flight.md) and the [SDKs](../handbook/reference/sdks.md).
Transport support alone does not establish a new execution profile.

## Remaining work

- Expose the qualified data/computation lifecycle through each selected SDK and
  service adapter: definitions, apply/recovery, dependencies, policy references
  and observed progress. Reuse neutral types and owning operations; transport
  parity does not imply every kind, lifetime or administrative action is supported.
- Extend Flight/ADBC and reactive interfaces beyond selected source/type profiles
  with shared codecs, metadata, current authorization and exact source bases.
  Finite results, refresh and continuous subscriptions remain distinct.
- Define interactive outbound streaming/resumption: durable acknowledgements,
  receiver admission, cancellation, unknown outcomes, reconciliation and restart.
  A reopened socket cannot imply safe replay.
- Broaden SDK/host/platform coverage through the shared Zig implementation,
  installed consumers and neutral fixtures. Host scheduling and temporary handler
  memory are not durable state.
- Define identity/sharing before exposing private inspection or collaboration to
  multiple users. Viewer authentication, upstream grants and application rights
  remain separate responsibilities.

## Completion evidence

Use pinned independent peers and real installed clients. Qualify revocation, slow
consumers, partial replies, leases/expiry, accepted-operation recovery, shutdown
and bounded memory. Measure admission/control fairness across callers. Update the
support matrix per delivered slice; one client/platform does not prove universal
interoperability.

Run the same declare/apply/inspect/change/recover scenario through the qualified
interfaces and compare object identities, definition revisions and outcomes.
Document differences in type and lifecycle coverage beside each caller.
