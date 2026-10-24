# 8. Service and SDK coverage

[Roadmap](README.md) · **Status:** Planned

Extend source, type and lifecycle limits documented by
[connectors](../handbook/reference/connectors.md), [reactive APIs](../handbook/reference/reactive.md),
[Flight/ADBC](../handbook/reference/flight.md) and the [SDKs](../handbook/reference/sdks.md).
Transport support alone does not establish a new execution profile.

Consume the neutral catalog/snapshot operations in
[#125](https://github.com/spoke-sh/transit/issues/125), changefeed/consumer
positions in [#127](https://github.com/spoke-sh/transit/issues/127), and array/state
export contract in [#128](https://github.com/spoke-sh/transit/issues/128).
Each adapter must preserve the selected transaction/feed profile, current
authorization and loss/error representation; transport convenience cannot
silently downgrade complete changes to refresh notifications or five-state
values to ordinary NULLs.

## Console assistance slice

The accepted [console interaction](../design/transit-cli/D3.md) extends the
existing grammar/catalog assistance operation with typed coverage and context
status, cursor-local statement scope and settings routing. It retains eight
candidates and the 128-page metadata acquisition budget. Partial scans are
reported as limited; no new catalog authority or full resident catalog is added.
This slice is in progress independently of broader service/SDK parity. Its
current-v1 cutover migrates the native session and shared query consumers together.

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

Enterprise identity/delegation is owned by the
[Control & Policy Plane milestone](09-control-and-policy-plane.md).
The [published-resource milestone](10-published-resources-and-investigations.md)
owns shared result/investigation semantics; [MCP and Apps](12-mcp-service-and-apps.md)
adapt them to selected hosts. This milestone's existing native adapter work may
proceed independently; it must not imply those new access or collaboration
profiles are already supported. Extend parity only after each owner qualifies it.

## Completion evidence

Use pinned independent peers and real installed clients. Qualify revocation, slow
consumers, partial replies, leases/expiry, accepted-operation recovery, shutdown
and bounded memory. Measure admission/control fairness across callers. Update the
support matrix per delivered slice; one client/platform does not prove universal
interoperability.

Run the same declare/apply/inspect/change/recover scenario through the qualified
interfaces and compare object identities, definition revisions and outcomes.
Document differences in type and lifecycle coverage beside each caller.
