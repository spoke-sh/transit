# 8. Service and SDK coverage

[Roadmap](README.md) · **Status:** In Progress

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

The [console assistance](../../apps/transit-cli/docs/console.md#terminal-editing-and-history) extends the
existing grammar/catalog assistance operation with typed coverage and context
status, cursor-local statement scope and settings routing. It retains eight
candidates and the 128-page metadata acquisition budget. Partial scans are
reported as limited; no new catalog authority or full resident catalog is added.
This slice is implemented independently of broader service/SDK parity. Its
current-v1 cutover migrates the native session and shared query consumers together.
[Executed evidence](../../tests/README.md#console-completion-and-editing--2026-10-24)
covers native units, terminal peers and actual TLS session completion. Manual
terminal/SSH delivery and broader service/SDK parity are not established by it.

## Remaining work

### Go SDK

The raw Go client slice implements typed input preparation, current capability
reads, canonical saved-operation recovery and explicit dispatch over the shared
Zig ABI. A bounded native worker preserves stack, cancellation and joined-close
requirements. Go module/native archives, installed consumers, a runnable recovery
example and a required bindings task accompany it. See the
[Go guide](../../sdks/go/README.md) and
[executed raw-client evidence](../../tests/README.md#go-raw-client).

Remaining Go work is catalog/Table, KV/Document and finite-query coverage,
followed by Station handlers, durable calls and recorded HTTP/gRPC outcomes.
Each slice needs idiomatic types, current authorization, bounded ownership and
the existing installed-language recovery schedules. Add Go to the Station
interoperability ring only when both service and requester adapters execute.
Broader relational/SQL-session APIs, supervisor integration and additional
platform distribution retain their own shared-contract and qualification gates.
The raw slice does not complete this milestone or establish those profiles.

### Shared coverage

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
