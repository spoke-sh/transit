# From data to decisions with people and agents

A useful business answer needs more than access to records. People need to know
what the data means, which version supports the answer, who may inspect it and
what can safely happen next. Transit connects data, computation and policy so
applications can preserve that evidence as information and participants change.

The stories below describe the **proposed collaboration experience**. They are
illustrative application scenarios, not runnable features or measured outcomes.
Transit currently supplies typed data, scoped authorization, query source
evidence and recorded external effects. Enterprise identity federation,
published business resources, shared investigation contexts, writable branches,
reviewed merges and MCP access are not implemented as this integrated experience.
The [availability table](#available-building-blocks-and-proposed-capabilities)
links each existing building block to its supported interface.

## The observation and feedback loop

> Observe → form a model → imagine alternatives → act → observe the consequences → revise.

This loop connects the stories. Our product thesis starts with applications that
can already supply useful modeling, reasoning and action selection. Transit
targets the infrastructure around that reasoning: **make the relevant world
observable before a decision, and make the consequences observable afterward.**
Model quality and decision quality still need their own application evaluation.

Observation here means usable business evidence: an order's state, an inventory
change, a supplier commitment or a delivery outcome, with its meaning, source,
version, freshness and access policy. Native data and connected systems both
contribute. Operational logs, metrics and traces help diagnose delivery of that
evidence; the application's authorized data and recorded outcomes establish what
it can actually inspect.

| Stage | Application question | Contribution of the proposed data foundation |
| --- | --- | --- |
| Observe | What is happening, and what is missing from this picture? | Relevant typed evidence, source versions, freshness and explicit gaps under current access |
| Form a model | How do I interpret these observations? | A retained basis and definitions that keep facts, assumptions and derived conclusions distinguishable |
| Imagine alternatives | What might happen if we changed this? | Branches and comparable computations over a known basis, with scenario results identified as such |
| Act | Which permitted change should we make? | Intent, review where required, conditional publication and separately authorized external effects |
| Observe the consequences | What actually happened after that action? | The original operation's outcome and subsequent business observations linked to their evidence |
| Revise | How should the next decision change? | Comparable prior predictions and later observations, preserved with their original context |

People and applications own goals, hypotheses, decisions and revision. Transit
supplies the data, computation and policy boundaries that make the loop
inspectable. Revising a hypothesis can produce a new application definition or
decision; it does not require automatic model training or a reasoning engine in
the kernel.

For example, Elena predicts that a different allocation will improve delivery.
An approved allocation change has its own recorded outcome. A later warehouse
observation can show that stock moved, and a carrier observation can show whether
the order arrived on time. Those are separate facts. A successful command reply
does not establish delivery; a missing carrier observation leaves the delivery
outcome unknown. Linking these records lets Elena compare prediction with
observation. Establishing that her change caused an improvement requires a
separate application-specific causal evaluation.

### What progress means

The target dimension is **the quality and speed of observation and feedback**:
how often can an application obtain the evidence its decision needs, and then
inspect the consequences within the time that matters to that decision?
Track evidence coverage together with time to an authorized, usable observation
and the cost of producing it. Measure initial observations and consequence
observations separately, and retain the connection between them.

A known failure can provide complete feedback. Missing, stale or conflicting
evidence remains visible and does not become a successful observation merely
because a request returned. Improvements must preserve source attribution,
current authorization and honest uncertainty. This is a product direction to
evaluate incrementally; the integrated measures are not implemented metrics or
measured improvements today.

## Maya needs an answer she can explain

Maya manages deliveries for one region. A customer asks whether an order will
arrive on time. Inventory, delivery commitments and supplier observations come
from different systems. A list of database tables leaves Maya to discover their
meaning and reconcile their dates before she can answer.

In the proposed experience, her application publishes a **delivery-risk
assessment**. Its definition names the business question, source dependencies,
units and time conventions, computation, freshness requirements and permitted
audience. This is an application-level resource over existing data kinds; it
does not require a new kernel storage kind or a screen to exist.

Maya signs in through her enterprise identity provider. The access plane binds
that identity to a Transit principal and current roles. Her assistant has an
identified application actor and a limited delegation to inspect assessments
for her region. Knowing Maya's name or acting on her behalf does not grant the
assistant all of Maya's powers.

The assistant retrieves an assessment and presents a chart with a short answer.
Maya selects an order and asks why it is at risk. The chart, explanation and
drilldown identify the same completed assessment revision. Related queries use
one declared investigation basis, even while new orders arrive. Refresh selects
a new basis explicitly; it does not rewrite the evidence behind the earlier
answer. Independent source observations remain a source vector unless their
owners establish stronger consistency.

The supplier observation is older than the inventory snapshot. The assessment
shows that difference and whether it meets the requested freshness. A malformed
supplier quantity remains a conversion failure; it does not become zero stock.
The assistant can explain the limitation or request an authorized refresh. It
cannot turn absent evidence into a confident delivery promise.

Maya can share an approved summary with a customer-service colleague who lacks
access to supplier records. That requires an explicit derived-publication policy:
the computation's source authority, the permitted summary and the recipient's
access are checked separately. Parameters and drilldowns cannot expose the raw
records through the summary. Withdrawal and source-permission changes follow
the publication's declared ownership and disclosure rules.

**User outcome:** Maya can explain her answer, show its evidence and decide
whether it is fresh enough for the customer's question. A report, an agent
conversation and an interactive MCP App can represent the same resource; a host
without Apps still receives useful typed data and text. Provenance establishes
what the answer used, not that every upstream record or model judgment is true.

The current [query interfaces](queries.md), [data types](sql/types.md) and
[connector captures](connectors.md) supply parts of this evidence. The unified
publication, identity and investigation experience remains proposed.

## Elena compares alternatives without changing operations

Elena asks two agents to investigate the at-risk orders. One proposes a different
inventory allocation; the other explores revised delivery commitments. Both
start from the same selected data and definition versions.

In the proposed branch model, each agent creates an authorized branch within the
same realm. Each branch has an identity, ancestry and a separately advancing
head. Changes stay on the selected branch; other participants' accepted work is
preserved. Permissions remain governed by current realm policy, including the
explicit rules for branch visibility and sharing.

Branch creation does not inherently export data, transfer ownership or create a
new authority boundary. A higher-level project/application fork relationship
could be built separately. Immutable storage sharing is an implementation
technique underneath the branch's observable behavior.

Each agent publishes a proposal containing its exact source and destination
basis, proposed changes, constraints, assumptions and computed delivery impact.
Elena opens the two reports side by side. The displayed improvements are
scenario results, clearly attributed to their branches; they are not claims
that the production allocation has changed. A narrative and chart point to the
same candidate and evidence, including incomplete or conflicting inputs.

The installation permits branching and sharing but prohibits merging. Elena can
choose an alternative for discussion, ask for another analysis and preserve the
decision record. Every merge attempt rejects, as does an equivalent direct write
to the protected destination through SQL, an SDK or an agent tool. This is a
useful complete policy for planning and investigation.

Another installation permits human-approved publication. There, Elena reviews a
specific merge candidate against a specific destination version. Approval is an
authenticated operation bound to that intent. Her delegated assistant cannot
claim her human approval powers, and an Approve button alone is not proof of an
authorized human action.

If the destination changes during review, the proposal must be re-evaluated and
reviewed against the new state. Even edits to different rows can jointly
overallocate inventory. A conflict-free structural merge still needs domain
validation. If the publication reply is lost, the original operation's outcome
settles what happened; sending a new mutation can create new work.

**User outcome:** people and agents can explore alternatives, compare their
business consequences and retain an accountable decision without giving every
participant production write authority. Publishing a data change does not itself
authorize an email, shipment or external payment. Historical data selection
cannot restore revoked permissions or replay past effects.

Current [Tables](tables.md) preserve definitions and mutation outcomes, and
[Documents](documents.md) retain accepted edits and explicit conflicts. General
writable branches and reviewed merges remain proposed. The
[branching account](../internals/state-model.md#schema-history-and-branches)
explains the model and its evidence limits.

## Omar wants attention when the situation changes

Omar runs customer operations. He wants an agent to reconsider a delivery plan
when a completed assessment identifies a new risk. He does not want a message
for every inventory edit or an expensive model call for every source update.

In the proposed experience, the application declares a meaningful condition over
the assessment, its audience and branch, the permitted activation, and budgets.
Source changes first drive the selected computation. A new completed assessment
can satisfy the condition; an incomplete successor cannot masquerade as a
finished answer. The old complete result retains its original basis and visible
freshness while work proceeds.

An application subscription preserves its identity and progress independently of
Omar's chat connection. A compatible MCP host can observe notifications and
long-running tasks. Closing the chat does not erase the declared interest or
cancel accepted work. Reattachment preserves the selected delivery semantics;
unavailable history requires an explicit failure or reset rather than a silent
claim that every change was delivered.

A notification identifies the completed assessment and its source basis. It does
not prove an agent has run. The application's separately authorized activation
records which evidence the agent receives. An agent can prepare another branch
proposal while the protected operational state remains unchanged.

If the application consults an external MCP service, its connector records an
authorized attempt and captures the permitted observation. Later review reads
that evidence instead of invoking the external tool again. A timeout after a
remote action leaves an unknown outcome until the selected reconciliation policy
can establish more. Captured inputs support repeatable inspection; they do not
make an external service immutable or guarantee deterministic model output.

**User outcome:** Omar gets attention tied to meaningful business evidence, with
enough context to act and enough history to explain the decision later. Pending
work, exhausted budgets, stale evidence and denied access remain observable.
Coalescing, deduplication and delivery guarantees are explicit application
contracts; socket delivery alone establishes none of them.

Current [reactive views](reactive.md) distinguish refresh hints from completed
results, and [connectors](connectors.md) preserve external uncertainty. General
managed agent activation, MCP subscriptions/tasks and recorded outbound MCP are
proposed extensions.

## What the Control & Policy Plane contributes

The proposed access formalization connects trusted enterprise identity to stable
principals, managed memberships, bounded delegation and resource/branch policy.
OIDC authentication, IAM membership, Transit grants and runtime execution
ownership answer different questions. The plane must define who manages each
binding, how fresh external membership must be, how offboarding propagates and
what happens when an identity provider is unavailable.

Data owners check current access and conditional publication; process/effect
owners check execution and dispatch authority. SQL, SDKs, MCP and Apps use those
same operations. A cached result, old data version, resource URI or model
instruction cannot supply permission. Report disclosure can differ from source
access only through an explicitly authorized publication contract.

Reasoning and business decisions remain application responsibilities. Transit
preserves the data basis, policy decisions, accepted operations and observable
outcomes that make those decisions inspectable. Its current
[security reference](security.md) describes the implemented authorization model.

## Available building blocks and proposed capabilities

| Need in the stories | Available building block | Proposed integrated capability |
| --- | --- | --- |
| Inspect typed data and its interpretation | [Table lifecycle](tables.md), [query profiles](queries.md), [cell states](sql/types.md) | Published business resources with meaning, audience, freshness and optional presentation |
| Govern access | [Native principals, roles and current grants](security.md) | Enterprise identity bindings, IAM lifecycle and explicit agent delegation/approval |
| Keep related answers attributable | Query-bound schemas/source snapshots and captured result evidence | A retained investigation basis shared across related calls and participants |
| Explore alternatives safely | Versioned resource reads and data-owner publication boundaries | Branching within a realm, comparable proposals and policy-controlled merges |
| Present one answer consistently | [Application definitions and bindings](applications.md) | Headless resources projected into reports, MCP resources/tools and optional Apps |
| React to relevant change | Selected [Table watches and refresh](reactive.md), typed maintained query owners | Managed conditions, durable interests and agent activation with MCP subscriptions/tasks |
| Preserve external evidence | Recorded finite [HTTP/gRPC effects](connectors.md) and selected outbound Flight | Selected recorded MCP capabilities, with explicit capture and reconciliation |

For a runnable starting point, [create and query a dataset](../guides/quickstart.md),
then choose supported [application and interface building blocks](../guides/choose-interface.md).
The stories add no executable SQL, CLI commands or new permission semantics.
