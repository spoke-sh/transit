# 29. Reactive context, subscriptions and agent activation

[Roadmap](README.md) · **Status:** Planned

Let applications arrange for useful context to become available when meaningful
business evidence changes. A source update, completed assessment, stale proposal
and approved publication are different events. Agents and humans can observe
the same versioned event without an open MCP connection owning the application.

## Prerequisites and scope

Extend [managed computation scheduling](11-sql-and-dataflows.md),
[first-class strings and search](13-vectorized-strings-and-search.md),
[native multi-model lexical/structural, vector and hybrid retrieval](16-multi-model-and-foreign-relations.md),
[enterprise RLS, masking and WLM governance](24-control-and-policy-plane.md),
[published resources](25-published-resources-and-investigations.md),
[proposal lifecycle](26-reviewed-data-collaboration.md) and the
[MCP service](28-mcp-service-and-apps.md). Durable source/change semantics stay
with their current owners; this milestone supplies consumer-specific conditions,
governed hybrid context assembly (combining relational/bitemporal filters,
declarative lexical, proximity (`NEAR`) and structural search—starting with
Block-Max BM25 without being locked to bag-of-words—and vector/graph similarity
under a single `SnapshotId`, branch and security-barrier `policy_epoch`),
context delivery and protocol projections within the caller's WLM resource
group. Reasoning loops remain applications, while speculative research into
declarative sequence/span maps, context-conditioned continuation and
branch-verified agency is tracked in
[Milestone 34](34-declarative-language-context-and-synthesis.md).

## Delivery sequence

1. **Declare meaningful activation.** Bind the resource/branch, selected event
   kind, condition, audience/delegation, computation and execution budgets.
   Separate source invalidation, a completed successor and a business predicate.
   Do not invoke a model on every WAL update by default. Define coalescing,
   deduplication, scheduling fairness and repeated-condition behavior explicitly.
2. **Retain durable application interests.** Define authorized subscription
   identity, source basis, progress, delivery/acknowledgement and lifetime separate
   from MCP transport attachments. Reconnect cannot silently create new work.
   Distinguish complete ordered changes from net changes and refresh hints;
   unavailable retained coverage requires an explicit reset or failure.
3. **Activate with an exact evidence basis.** Record the trigger, completed
   resource revision, branch and input basis supplied to an application. Bind
   any external agent/LLM invocation to a separately authorized connector intent.
   A new basis cannot relabel earlier reasoning. A changed destination can make
   a proposal stale without changing its reviewed candidate or merging it.
4. **Project subscriptions and tasks into MCP.** Select the methods and extension
   semantics of the qualified revision. Notifications identify authorized resource
   versions; tasks reference durable computation/validation/approval operations.
   A task acknowledgement is not business completion. Preserve original identity
   through polling, additional input, disconnect, restart and cancellation. A
   host receiving a notification does not prove an agent ran or accepted work.
5. **Expose progress and enforce lifecycle.** Show last completed revision,
   pending successor, freshness/lag and attributable stopped or blocked work.
   Define pause, revoke, close, expire and resume behavior. Bound active work and
   buffers independently of retained history; retention defaults to unlimited
   unless an explicit supported policy permits expiry. Preserve control capacity
   when consumers stall and prevent feedback loops from consuming unbounded work.

## Formal model follow-through

Extend the [T5 handoff and checkpoint candidate](19-formal-semantics-and-correspondence.md#t5-snapshot-to-history-handoff-and-consumer-checkpoints)
when the durable-interest and activation contracts settle. Preserve the declared
meaning of every-change capture, net changes or latest-result notification;
check resume, duplicate application, explicit gaps and current disclosure.
Connect selected models to production activation/recovery schedules and record
assumptions and deferrals. A transport notification does not prove complete
business-condition coverage or authorize an agent's subsequent action.

## Completion evidence

A delivery assessment changes while the agent host is disconnected. Reattach
to the original authorized interest and retrieve the identified completed
revision, preserving the selected delivery profile. Exercise duplicate signals,
`A -> B -> A`, source schema change, incomplete recomputation, missing history,
revocation, task restart, stale review, feedback loops and exhausted budgets.

Verify branch analysis never appears as authoritative destination data. Compare
every completed revision with finite recomputation. Measure source-to-result,
result-to-notification and notification-to-application admission separately;
socket delivery is not a business latency or exactly-once execution guarantee.

Extend that journey through an authorized action and a later business observation.
Bind the initial assessment, original action identity and subsequent observation
without replacing the original prediction. Exercise delayed, missing and
contradictory feedback as well as known success and failure. Use the
[observation measures](32-qualification-and-benchmarks.md#observation-and-consequence-evidence)
to qualify both sides of the loop; a notification or completed tool call alone
does not establish the application's business consequence.

The [MCP Tasks extension](https://modelcontextprotocol.io/extensions/tasks/overview)
provides an interaction mechanism; Transit owners supply durable outcomes.
