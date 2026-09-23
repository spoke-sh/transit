# Project documentation

Markdown in this directory is the source of truth for scope and planning.
Documentation describes intended behavior unless explicitly marked implemented.
Technical choices and their rationale live alongside the relevant design in
these foundational documents.

| Document | Status | Read it for |
| --- | --- | --- |
| [Glossary](GLOSSARY.md) | Shared vocabulary | Official names, execution terms, transport, and packaging |
| [Scope](SCOPE.md) | Bounded M1 implemented; later scope planned | Generic kernel goals, first outcomes, and application boundaries |
| [Architecture](ARCHITECTURE.md) | M1 libraries/services implemented; framework planned | Transit, Station, library/executable decomposition, and dependency boundaries |
| [Security](SECURITY.md) | Signed authority and reference isolation proved within scope | Authentication, authorization, realms, revocation, credentials, and trusted boundaries |
| [Conformance](CONFORMANCE.md) | Adversarial results and profile limits | Adversarial scenarios, proof ownership, implementation gates, and guarantee limits |
| [Transit — kernel](TRANSIT.md) | Experimental executable M1 profile | Processes/PIDs, lifecycle, enforced sequences, ownership, and replay |
| [Client](CLIENT.md) | Implemented Zig client and v2 contract resource | Caller-owned application logic, opaque state, retries, and future language bindings |
| [Streams](STREAMS.md) | Realm-journal mapping and recovery proved | Unbounded durable mailboxes, delivery, commits, and retention |
| [Retention](RETENTION.md) | M1 expiry, trim, deletion and capacity proofs | Application opt-in, process/mailbox expiry, compaction, tombstones, and reclamation |
| [Station — framework](STATION.md) | Proposed behaviors | GenServer, supervision, scoped registries, and request/reply |
| [Connectors](CONNECTORS.md) | HTTP direction established; contract draft | Request/response stream groups, interpolation, capture, and attempts |
| [Deployment](DEPLOYMENT.md) | Pinned reference recovery/isolation harness | Runtime bindings, Kubernetes/Substrate, isolation, recovery, and portability |
| [Ursula integration](URSULA.md) | Pinned disk, live-read and deletion integration | ursula-zig, persistence, and recovery boundaries |
| [Roadmap](ROADMAP.md) | Kernel-first plan | Milestones and observable completion criteria |
| [Development](DEVELOPMENT.md) | Current tooling | Setup, commands, and toolchain maintenance |
| [Decision records](decisions/README.md) | Reserved for future use | Guidance and a template for later decision records |

## How to plan work

1. Capture a use case and its limits in `SCOPE.md`.
2. Locate the change and its package boundaries in `ARCHITECTURE.md`. Keep kernel
   invariants in `TRANSIT.md`, durable transport in `STREAMS.md`, resource lifetime
   and retention in `RETENTION.md`, Station behaviors in `STATION.md`, effect
   capture in `CONNECTORS.md`, and runtime boundaries in `DEPLOYMENT.md`.
   Put identity, authorization, and trust boundaries in `SECURITY.md`; map
   adversarial validation to `CONFORMANCE.md` without duplicating the contracts.
3. Explain technical choices, tradeoffs, and supporting evidence in the document
   that owns the topic. Keep Ursula integration details in `URSULA.md` and tool
   setup/versioning in `DEVELOPMENT.md`.
4. Break implementation into roadmap milestones with observable exit criteria.
5. Update `GLOSSARY.md` when shared terms or official names change. Update status
   and supporting evidence as work lands. Keep future plans distinguishable from
   features that can actually be run.

Add focused design documents as questions grow too large for these foundations.
Do not duplicate the same requirements across several documents.

Trading is an intended application of the primitives. The current sequence of
work proves the kernel, framework, connectors, and reference deployment first.
