# Working in Rey

## Read before changing the project

- Read `README.md`, `docs/SCOPE.md`, and `docs/ARCHITECTURE.md` first.
- Use `docs/GLOSSARY.md` for official names and shared terminology.
- Read `docs/SECURITY.md` for authentication, authorization, credentials, and
  trusted boundaries. Use `docs/CONFORMANCE.md` for adversarial proof obligations.
- Read `docs/TRANSIT.md` for processes, PIDs, kernel protocol, and ownership changes.
- Read `docs/STREAMS.md` for producer, consumer, storage, or contract work.
- Read `docs/RETENTION.md` for process/mailbox lifetimes, expiry, compaction,
  tombstones, and background reclamation.
- Read `docs/STATION.md` for framework behaviors, supervision, and name registries.
- Read `docs/CONNECTORS.md` for effects, HTTP capture, and interpolation.
- Read `docs/DEPLOYMENT.md` for Kubernetes, Substrate, and runtime integration.
- Read `docs/URSULA.md` for Ursula integration and persistence requirements.
- Use `docs/ROADMAP.md` to keep changes tied to a concrete milestone.
- Treat proposed architecture as a starting point, not implemented behavior.
  Record meaningful changes to scope or architecture in the same change as code.

## Project constraints

- Transit is the kernel; Station is the framework. Rey is the monorepo containing
  them, their adapters, executables, and applications. Keep these names and roles
  consistent with `docs/GLOSSARY.md`.
- Use TypeScript and Vite+ for frontend applications and frontend tooling.
- Write the kernel, framework, connectors, and application backends in Zig.
  Node.js is a frontend development/build dependency. External infrastructure
  such as Ursula and Substrate keeps its upstream implementation language.
- Treat the kernel as a generic execution protocol. LLM calls and tools belong
  in connectors/framework capabilities; reasoning loops, goals, agent delegation,
  and trading policy belong above the kernel.
- Use Ursula as the external Durable Streams implementation described in
  `docs/ARCHITECTURE.md` and `docs/URSULA.md`. Its upstream implementation
  language does not change Rey's application language boundaries.
- Use the `ursula` and `ursulactl` binaries from the `ursula-overlay` flake input;
  update its pin deliberately instead of installing a separate server version.
- Use `rupurt/ursula-zig` inside the Ursula adapter. Pin its revision and package
  hash in that package's `build.zig.zon` when code is added; import the upstream
  client's exported `ursula` module. Keep Rey's
  retry/reconnect, checkpoint, and protocol policies above the client library.
- Make durable protocol history authoritative for process execution. Enforce
  legal transitions, ordered input, committed effects, and fenced ownership;
  do not substitute conventions or after-the-fact logging for enforcement.
- Authenticate every ingress and bind provenance at a trusted boundary. Enforce
  current realm/action/resource grants separately from PID ownership; provider
  authentication, registry lookup, and framework APIs never grant Transit rights.
  Record authorization decisions and policy revisions without storing credentials.
- Distinguish historical acceptance from current permission. Define revocation
  ordering for commits/delivery/dispatch authorization and protect read/replay
  surfaces too.
  Treat an authorized external attempt as potentially in flight; stale ownership
  is not proof that retrying it is safe.
- Give each Transit process an ordered, logically unbounded durable mailbox.
  Bound resident memory and read windows. Never silently discard accepted
  messages to handle overload or advance progress past unfinished work.
- Build actors and GenServers on Transit processes. Keep the durable PID,
  activation reference, registered name, and runtime binding distinct. Recovery
  preserves the PID; logical termination retires it permanently. Replacement
  processes receive new PIDs and explicit policy for outstanding work.
- Retention defaults to unlimited. Applications must opt into finite lifetime,
  history removal, and compaction semantics. Record effective policies and
  validate dependencies before accepting work; quota pressure is not expiry
  authorization. Suspension must fit the recovery window. The cutoff for new
  work may leave bounded settlement rights for specifically authorized work;
  it must not allow fresh turns or chains of effects. Final retirement forbids
  activation and application commits. Connectors own reconciliation policy;
  Transit enforces its authority, ordered closure, and rejection of late results.
- Keep logical expiry separate from physical cleanup. Required checkpoints and
  retirement evidence remain durable after history/payload reclamation. A
  storage outage is not proof of expiry; old snapshots cannot revive expired
  PIDs. Reject unsupported guarantees at the adapter boundary.
- Preserve control authority through bootstrap, full-store conditions, and
  retention. Reserve bounded capacity for control/maintenance progress; restoring
  old history cannot automatically authorize live execution or external effects.
- Implement name registries through durable protocol operations. Record resolved
  destination PIDs before delivery; rebinding a name must not redirect committed
  messages, retries, or replies. Lookup caches never grant execution authority.
- Put external effects behind recorded intents and connector outcomes. Handler
  code must not bypass this boundary with direct network, clock, or tool access.
- Use Kubernetes and Agent Substrate as the reference deployment architecture.
  Keep protocol identities and semantics independent of pods and provider APIs.
  AX is excluded; do not introduce a second authoritative task queue/store.
- Reconcile durable runtime bindings and provider-operation intents through
  adapters. Use Substrate for physical placement and sandbox lifecycle. Provider
  state, binding revisions, and restored snapshots cannot grant ownership;
  validate and fence current authority at commit and effect boundaries.
- Use disk-backed Ursula for durability/recovery tests. Its default in-memory
  runtime is only suitable for disposable protocol experiments.
- Use the Zig 0.17 development version pinned by `flake.lock`. Check the pinned
  compiler and standard library before copying examples from older Zig versions.
- Keep dependencies small and explicit. Add directories when they contain real
  work; the layout in the architecture document is a plan.
- Follow the library/executable decomposition in `docs/ARCHITECTURE.md`.
  The `transit-core` library must not depend on Station, Ursula, or a deployment provider;
  adapters and executable entry points compose those dependencies. Package
  boundaries alone do not enforce runtime capabilities or isolation.
  Logical stream identity, retained boundaries, and lifecycle semantics belong
  to Transit; Ursula cursors, TTLs, and deletion APIs remain adapter mechanisms.

## Planning and documentation

- Keep scope, plans, and technical design in Markdown under `docs/`.
- Distinguish established constraints, proposals, assumptions, and implemented
  features.
- Document technical choices and their rationale directly in the relevant
  foundational document. Keep tradeoffs, consequences, open questions, and
  validation evidence alongside the design; update that document as it evolves.
  Do not maintain separate decision records at this stage.
- Keep `docs/decisions/README.md` and `docs/decisions/TEMPLATE.md` available for
  future use.
- Do not choose a venue, strategy, latency target, or live-trading
  requirement implicitly while scaffolding unrelated work.
- Keep README onboarding commands runnable. Do not add placeholder tasks that
  report success when no build or tests were run.

## Implementation conventions

- Keep application computation in callers. Transit authority validates protocol
  transitions and recovers recorded state; it must not import application handlers.
  Callers use `transit-client`, whose only protocol dependency is `transit-protocol`.
  Generate language-neutral resources from those public types, and keep fixtures
  and generated schema current with `just generate-contract`/`just check-contract`.
  Use Zig calling programs for conformance; additional language bindings are future work.
- Keep domain transitions separate from transport, storage, clocks, and external
  effects so a recorded input sequence can be replayed deterministically.
- Prove the selected handler-execution boundary before claiming deterministic
  re-execution or arbitrary native-code isolation. Protocol validation is not
  proof of honest computation. Keep trusted connector execution explicit.
- In Zig, make allocation, ownership, lifetimes, error handling, and queue bounds
  explicit, distinguishing durable backlog from in-memory buffers. Use `zig fmt`
  and the native Zig build/test workflow.
- In TypeScript, enable strict checking. Validate data at runtime when it crosses
  a boundary; TypeScript types alone do not validate stream payloads.
- Define versioned language-neutral contracts and shared fixtures before wiring
  frontend and backend together. Avoid hand-maintained divergent schemas.
- Keep trading-specific constraints in application code and design. Monetary
  state uses explicit fixed-point/decimal rules, with risk and execution ordered
  through the same kernel primitives as other applications.
- Design for duplicate delivery, restart, stale owners, backpressure, and lag.
  Distinguish durable admission, turn completion, and effect completion.
- Replay consumes recorded outcomes without redispatching effects. Recovery of
  an uncertain external attempt requires the connector's explicit policy.
- Keep secrets out of ordinary stream transcripts and Git. Record typed secret
  references and interpolation provenance; fetch workers resolve credentials.
  Keep private datasets and local stream files out of Git. Use synthetic
  endpoints and fixtures for development and recovery tests.

## Tools and validation

- Enter `nix develop`; use `just` as the repository command entry point.
- Run `just check` for the current foundation checks. It does not claim to test
  application behavior. Run `just doctor` after toolchain changes.
- Satisfy the M1 design gates in `docs/ROADMAP.md` before expanding framework or
  real-effect integrations. Record failed proofs and revise their owning design.
- When frontend code exists, expose Vite+ checks, tests, and builds through
  `just`; use `vp` for frontend tooling and dependency operations.
- When backend code exists, expose `zig fmt --check`, builds, and focused tests
  through `just`. Add protocol conformance, bypass rejection, and crash/replay
  tests. Kubernetes worker-failure recovery is part of the first milestone.
- Commit dependency lockfiles and update related toolchain documentation when
  changing versions. Keep toolchain upgrades deliberate and reviewable.
- Report what changed, what was verified, and any checks that could not run.
