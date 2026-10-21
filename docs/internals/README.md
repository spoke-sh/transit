# Internals

Internals explains how Transit works: its models, mechanisms, invariants,
tradeoffs and evidence. These nine accounts consolidate the earlier overlapping
topic documents. The [guides and reference](../README.md) explain how to use and
operate Transit; exact interface and wire definitions remain with their owners.

## System and execution

| Account | Question |
| --- | --- |
| [System model and authority boundaries](system-model.md) | Which components can decide what, and under which trust assumptions? |
| [Execution, authorization and recovery](execution-model.md) | What permits a process to advance after concurrency, revocation or failure? |
| [State, publication and lifetime](state-model.md) | How do atomic visibility, lifetime and proposed schema history/branching fit the same authority boundary? |

## Programming and interfaces

| Account | Question |
| --- | --- |
| [Clients, SDKs and Station](client-framework.md) | How do language APIs preserve shared protocol and ownership semantics? |
| [Query planning, snapshots and results](query-engine.md) | What makes a finite result attributable and complete, and how can standards and additional data models fit that boundary? |
| [External effects and uncertain outcomes](effect-lifecycle.md) | What can durable execution establish about an external operation? |
| [Serving, reactive views and Board](service-interfaces.md) | How do network and visual interfaces preserve authority and result truth, and how would shared SQL sessions separate connections from durable work? |

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

These accounts began by consolidating the repository's documented mechanisms at
source revision `b79a8a8`; revised sections identify their own source basis and
distinguish design analysis from implementation. They add no runtime qualification.
Each links current interface and implementation owners, the relevant recorded
proof and earlier reasoning.
Use the revision, configuration and limits attached to each experiment when
reproducing it; a documentation build does not rerun those experiments.

[Engineering history](../history/README.md) preserves the detailed source records.
[Roadmap](../roadmap/README.md) owns delivery plans; [Design](../design/README.md)
owns UI/UX proposals and review outcomes. Those records are separate from these
accounts of system behavior and remain available through repository links.
