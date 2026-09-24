# Working in Rey

## Before changing code

Read [README.md](README.md), [scope](docs/SCOPE.md), and
[architecture](docs/ARCHITECTURE.md) first. Use the [glossary](docs/GLOSSARY.md)
for names. Read the affected package/app README for implementation, configuration,
and limits; the [component map](docs/ARCHITECTURE.md#planned-monorepo-decomposition)
links them. Treat proposed design as intent, not implemented behavior.

Follow the contracts for the area you change:

| Area | Required references |
| --- | --- |
| Protocol, processes, ownership | [Transit](docs/TRANSIT.md), [v2 profile](contracts/TRANSIT_V2.md) |
| Authentication, grants, credentials, trust | [Security](docs/SECURITY.md), [service contract](contracts/SERVICE_V2.md) |
| Storage, delivery, producer/consumer behavior | [Streams](docs/STREAMS.md), [Ursula boundary](docs/URSULA.md) |
| Lifetimes, expiry, compaction, deletion, capacity | [Retention](docs/RETENTION.md) |
| Caller APIs and language bindings | [Caller model](docs/CLIENT.md), [public protocol package](packages/zig/transit-protocol/README.md) |
| Operator/agent inspection, Board UI/API | [Board](docs/BOARD.md), [M2 plan](docs/roadmap/M2.md) |
| Service logs, metrics, traces, probes | [Observability](docs/OBSERVABILITY.md), [M2 follow-up](docs/roadmap/M2-OBSERVABILITY.md) |
| Behaviors, supervision, names | [Station](docs/STATION.md) |
| Effects, capture, secret interpolation | [Connectors](docs/CONNECTORS.md) |
| Kubernetes, provider bindings, recovery | [Deployment](docs/DEPLOYMENT.md), [runtime contract](contracts/RUNTIME_SUBSTRATE_V1.md) |
| Local/Compose lifecycle and developer environments | [Launchers](launchers/README.md) |

Read [conformance](docs/CONFORMANCE.md) for adversarial obligations and tie work
to a [roadmap milestone](docs/roadmap/README.md). Preserve the proved M1 gates before
expanding framework or real-effect integrations.

## Implementation rules

- Keep the Transit kernel generic and Station above it. Reasoning loops, goals,
  delegation, and trading policy belong to applications; LLM/tool access belongs
  in connectors.
- Name streaming-runtime artifacts and deployments Transit; Rey is the monorepo
  and application context. Board and Station belong to the Transit subsystem;
  use `transit-board*` and `transit-station*` for their artifact names. Keep Board
  and Station as readable names in prose. Follow the [glossary](docs/GLOSSARY.md)
  for roles.
- Write kernel, framework, connectors, and backends in Zig. Use strict TypeScript
  and Vite+ for frontends. Keep external infrastructure in its upstream language.
- Respect the architecture's dependency direction. Core depends on the public
  protocol, never Station or a provider. Applications use the client; the node
  must not import handlers or claim protocol validation proves honest computation.
- Keep deterministic transitions separate from storage, clocks, and effects.
  Make Zig allocation, ownership, lifetimes, errors, and resident bounds explicit.
  Durable backlog is not an in-memory queue. Never silently discard accepted work.
- Enforce current scoped authorization separately from PID ownership, including
  reads/replay. Preserve fencing, permanent retirement, and recorded destinations;
  provider state, names, and restored snapshots cannot grant execution rights.
- Retention defaults to unlimited and requires application opt-in. Keep expiry,
  reconciliation closure, and physical cleanup distinct. Quota pressure and
  storage outages never authorize expiry; preserve control/recovery evidence.
- Put effects behind recorded intents, authorization, and outcomes. Replay must
  not dispatch. Unknown remote outcomes require connector policy; closure cannot
  promise external cancellation or make retry safe. Keep secrets as references
  in transcripts and keep credentials/private datasets out of Git and logs.
- Use the pinned `ursula`/`ursulactl` overlay tools and upstream `ursula-zig` only
  inside the Ursula backend. Pin external Zig revisions/hashes in the consuming
  package. Use disk-backed Ursula for durability tests.
- Keep Board inspection-only for M2. Use public `transit-client` read surfaces;
  no raw storage/provider access, hidden mutations, or unqualified cached views.
  Preserve source evidence and kernel facts when adding interpretation lenses.
- Keep instrumentation with its domain owner and I/O outside deterministic core.
  Bound telemetry work, cardinality and sinks; exclude credentials and payloads.
  Preserve machine stdout and distinguish transport attempts from durable results.
  Telemetry loss or failure must not change authority or stall control progress.
- Keep Kubernetes/Substrate as the reference runtime and AX excluded. Providers
  handle physical lifecycle; durable Transit history remains execution authority.
- Give real libraries their own manifests, direct dependencies, modules, and
  checks; use package interfaces rather than sibling source imports. Entry points
  compose them. Add directories only for real work. Test the real example binaries.
- Define versioned neutral contracts and shared fixtures before wiring languages
  together. Regenerate the schema from public types; do not maintain divergent
  copies. Validate data at runtime across boundaries, including TypeScript.
- Do not choose trading venues, strategies, latency targets, or live requirements
  implicitly. Future monetary state needs explicit fixed-point/decimal rules.

## Documentation and validation

Use scoped Conventional Commit subjects: `type(scope): description`, such as
`feat(transit): add inspection queries`, `test(board): verify access boundaries`,
or `docs(roadmap): update milestone status`. Include a scope for every commit.
When rewriting history, preserve the original author date and use
`git rebase --committer-date-is-author-date`. For individual `git commit --amend`
operations, set `GIT_COMMITTER_DATE` to that commit's author date.

Follow the [documentation ownership guide](docs/README.md#where-documentation-lives).
Keep scope/design in `docs/`, wire specifications in `contracts/`, implementation
and usage beside their package/app, and proof details in `tests/README.md`.
Update the owning document with meaningful changes and distinguish implemented,
proposed, and unverified behavior. Keep rationale with its topic. Do not add ADRs
yet; preserve `docs/decisions/README.md` and `TEMPLATE.md` for future use.

Enter `nix develop` and use [just tasks](tasks/README.md). Use the pinned Zig 0.17
compiler and standard library, not examples from older releases. Run `just check`
and the relevant [focused/integration proofs](tests/README.md); report what ran
and what could not. Toolchain changes also require `just doctor`, deliberate
lockfile updates, and the [toolchain workflow](nix/README.md). Use `vp` for future
frontend dependency operations, checks, tests, and builds. Keep onboarding
commands runnable; never add placeholder tasks that report success.
