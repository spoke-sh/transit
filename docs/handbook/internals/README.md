# Internals

Internals explains how Transit stores and operates on application data: its
models, mechanisms, invariants, tradeoffs and evidence. Start with the
[data model](../reference/data-model.md), then trace how definitions, computation
and policies relate to accepted data and observable progress. Durable execution
supplies the authority, publication and recovery mechanisms behind that model.

These nine accounts explain those mechanisms. The [guides and reference](../../README.md)
own usage and supported behavior; exact interface and wire definitions remain
with their owners. A shared way to reason about declarations does not imply
that every data kind already has the same executable lifecycle.

## Data and computation

| Account | Question |
| --- | --- |
| [System model and authority boundaries](system-model.md) | How do declarations relate to accepted data and observable outcomes, and which owners can establish each fact? |
| [State, publication and lifetime](state-model.md) | How do atomic visibility, lifetime and proposed schema history/branching fit the same authority boundary? |
| [Query planning, snapshots and results](query-engine.md) | What makes a finite or maintained result attributable and complete for its source basis? |

## Execution and interfaces

| Account | Question |
| --- | --- |
| [Execution, authorization and recovery](execution-model.md) | What permits a data operation or worker to advance after concurrency, revocation or failure? |
| [Clients, SDKs and Station](client-framework.md) | How do language APIs preserve shared protocol and ownership semantics? |
| [External effects and uncertain outcomes](effect-lifecycle.md) | What can durable execution establish about an external operation? |
| [SQL sessions, serving and operator interfaces](service-interfaces.md) | How do network and visual interfaces preserve authority and result truth, and how do shared SQL sessions separate connections from durable work? |

## Runtime and evidence

| Account | Question |
| --- | --- |
| [Storage, placement and observation](storage-runtime.md) | What do persistence, providers and telemetry each establish? |
| [Verification and the limits of evidence](verification-method.md) | Which methods support a claim, and what do they leave unproved? |

## Scientific standard and source basis

Internals and architecture explanations follow the [scientific standard](standard.md):
explicit questions and assumptions, precise claims, inspectable reasoning,
traceable evidence, reproducible methods, alternatives and limits. The
[technical account template](template.md) supports new and substantive revisions.

The declaration/observation framing uses the implemented owners at source
`5c1099f7`; it adds no common catalog, scheduler or runtime guarantee. These
accounts began by consolidating the repository's documented mechanisms at
source revision `b79a8a8`; revised sections identify their own source basis and
distinguish design analysis from implementation. They add no runtime qualification.
Each links current interface and implementation owners, the relevant recorded
proof and earlier reasoning.
Use the revision, configuration and limits attached to each experiment when
reproducing it; a documentation build does not rerun those experiments.

[Engineering history](../../history/README.md) preserves the detailed source records.
[Roadmap](../../roadmap/README.md) owns delivery plans; [Design](../../design/README.md)
owns UI/UX proposals and review outcomes. Those records are separate from these
accounts of system behavior and remain available through repository links.
