# Project documentation

Start with [scope](SCOPE.md), [architecture](ARCHITECTURE.md), and the
[glossary](GLOSSARY.md). The [roadmap](roadmap/README.md) distinguishes completed M1/M2 profiles
from planned framework, connector, and application milestones. These profiles
are experimental; their bounded implementation does not imply support for every target requirement.

## Foundations

| Document | Owns |
| --- | --- |
| [Scope](SCOPE.md) | Goals, application boundaries, and open questions |
| [Architecture](ARCHITECTURE.md) | Layers, dependency direction, and component map |
| [Glossary](GLOSSARY.md) | Official names and shared terminology |
| [Transit](TRANSIT.md) | Processes, PIDs, legal sequences, ownership, and replay |
| [Caller model](CLIENT.md) | Application computation and the public client boundary |
| [Security](SECURITY.md) | Identity, authorization, revocation, and trust boundaries |
| [Streams](STREAMS.md) | Mailboxes, ordering, durable admission, and delivery |
| [Retention](RETENTION.md) | Application lifetime contracts, compaction, and reclamation |
| [Board](BOARD.md) | Planned inspection UI/API, observation semantics, and higher-level lenses |
| [Station](STATION.md) | Planned behaviors, supervision, and registries |
| [Connectors](CONNECTORS.md) | Planned HTTP capture, attempts, and bounded reconciliation |
| [Deployment](DEPLOYMENT.md) | Runtime bindings, recovery, isolation, and portability |
| [Ursula](URSULA.md) | Storage-provider choice and authority boundary |
| [Conformance](CONFORMANCE.md) | Adversarial obligations and limits on guarantees |
| [Roadmap](roadmap/README.md) | Milestones and observable exit criteria |

For hands-on work, use [development](DEVELOPMENT.md) and the
[component READMEs](ARCHITECTURE.md#planned-monorepo-decomposition).

## Where documentation lives

| Location | Content |
| --- | --- |
| Root [README](../README.md) | Orientation, status, and a short runnable start |
| `docs/` | Scope, cross-component design, invariants, and tradeoffs |
| [docs/roadmap/](roadmap/README.md) | Milestone index and individual scope, criteria, and status files |
| Package/app READMEs | Implemented APIs, dependencies, configuration, operations, and local limits |
| [contracts/](../contracts/) | Exact versioned wire/provider specifications and generated schema |
| [examples/](../examples/README.md) | Complete calling programs and how to run them |
| [launchers/](../launchers/README.md) | Running and inspecting persistent development environments; lifecycle and trust limits |
| [tests/](../tests/README.md) | Proof commands, failure schedules, results, and qualification limits |
| [deploy/reference/](../deploy/reference/README.md) | Reference setup, prerequisites, and teardown |
| [nix/](../nix/README.md), [tasks/](../tasks/README.md) | Toolchain maintenance and command reference |
| [AGENTS.md](../AGENTS.md) | Working instructions and required reading |

Document a fact where it is owned and link to it from the broader design. Keep
technical choices and rationale alongside that topic. Preserve failure findings
and validation limits when moving details; avoid duplicate specifications.
Future components stay in the design docs until they have real implementation.

## Planning a change

1. Define its use case and limits in scope, then identify the architecture owner.
2. Update that owner's design and adversarial requirements before claiming a guarantee.
3. Tie implementation to a roadmap milestone with observable exit criteria.
4. Update component usage and proof evidence with the code. Mark proposals and
   unsupported cases explicitly; update the glossary when terminology changes.

Keep [decision guidance](decisions/README.md) and its template for future use;
we are not maintaining separate decision records at this stage.
