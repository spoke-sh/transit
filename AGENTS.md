# Working on Transit

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
| State resources, associations, KV/Table/Document APIs | [State](docs/STATE.md), [M7](docs/roadmap/M7.md), [Document M17](docs/roadmap/M17.md) |
| Declarative interfaces, SQL, Fuze/query planning and execution | [Query language](docs/QUERY_LANGUAGE.md), [grammar contract](contracts/sql/README.md), [Fuze](docs/FUZE.md), [Tables](docs/TABLES.md) |
| Arrow IPC/C interfaces, Flight/Flight SQL, ADBC | [Arrow](docs/ARROW.md) |
| Lifetimes, expiry, compaction, deletion, capacity | [Retention](docs/RETENTION.md) |
| Caller APIs and language bindings | [Caller model](docs/CLIENT.md), [SDK milestone M11](docs/roadmap/M11.md), [public protocol package](packages/zig/transit-protocol/README.md) |
| Operator/agent inspection, Board UI/API | [Board](docs/BOARD.md), [query language](docs/QUERY_LANGUAGE.md), [grammar contract](contracts/sql/README.md), [M2 plan](docs/roadmap/M2.md) |
| Service logs, metrics, traces, probes | [Observability](docs/OBSERVABILITY.md), [M4](docs/roadmap/M4.md) |
| Behaviors, supervision, names | [Station](docs/STATION.md) |
| Effects, capture, secret interpolation | [Connectors](docs/CONNECTORS.md), [gRPC](docs/GRPC.md) for RPC work |
| Kubernetes, provider bindings, recovery | [Deployment](docs/DEPLOYMENT.md), [runtime contract](contracts/RUNTIME_SUBSTRATE_V1.md) |
| Local/Compose lifecycle and developer environments | [Launchers](launchers/README.md) |

Read [conformance](docs/CONFORMANCE.md) for adversarial obligations and tie work
to a [roadmap milestone](docs/roadmap/README.md). Preserve the proved M1 gates before
expanding framework or real-effect integrations. Preserve the
[M8 runtime readiness](docs/roadmap/M8.md) contracts and qualification limits when
building Station; the [pre-Station review](docs/reviews/PRE_STATION.md) records their rationale.
Use the [testing strategy](docs/TESTING.md) and [M10](docs/roadmap/M10.md) for
verification, CI changes and scale qualification. Distinguish planned checks
from executable evidence; never treat a skipped or incomplete proof as passed.

## Implementation rules

- Keep the Transit kernel generic and Station above it. Reasoning loops, goals,
  delegation, and trading policy belong to applications; LLM/tool access belongs
  in connectors.
- Name streaming-runtime artifacts and deployments Transit; Rey is the intended
  downstream trading application. Board, Station and Fuze belong to Transit;
  use `transit-board*`, `transit-station*` and `transit-fuze*` for their artifacts.
  Keep their readable names in prose. Follow the [glossary](docs/GLOSSARY.md)
  for roles.
- Write kernel, framework, connectors, and backends in Zig. Use strict TypeScript
  and Vite+ for frontends. Keep external infrastructure in its upstream language.
  M9's language bindings and M11's public SDKs, host adapters, examples and
  conformance tests may use their target languages; share the Zig client/framework
  through the [binding boundary](docs/CLIENT.md#language-neutral-boundary) instead of duplicating
  protocol semantics. Keep query execution Zig native and outside kernel authority;
  follow [Fuze](docs/FUZE.md) for DataFusion/Acero inspiration and query boundaries.
  Neither upstream engine is a runtime dependency.
- Keep generated wire/ABI declarations separate from language-native public APIs.
  SDKs own types, codecs, handler dispatch, scheduling and packaging; the shared
  Zig implementation owns protocol and framework semantics. Preserve uncertainty,
  durable call identity and cancellation distinctions through convenience APIs;
  host tasks and handler fields are not durable state.
- Design Board and other operator interfaces as views over Transit's declarative
  model. Map objects, forms, diagrams and actions to the SQL grammar and shared
  typed contracts in [Query language](docs/QUERY_LANGUAGE.md#declarative-model-and-visual-interfaces).
  SQL, visual editing, CLI and SDK surfaces must share validation and semantics:
  queries lower to Fuze plans; declarations and controls use their owning public
  operations, never a separate UI configuration authority. Show definitions,
  dependencies, proposed changes and observed state distinctly. Distinguish
  executable syntax, reference-grammar-only forms and missing grammar/semantics;
  propose missing contracts explicitly instead of inventing runnable SQL or
  treating parser acceptance as execution support. Edits may schedule qualified
  read queries in a visible, scoped Live worksheet session, as proposed in
  [Board console D4](docs/design/board-console/D4.md#live-execution-snapshot-and-stream).
  Keep exact, speculative and earlier-draft results distinct; bind work to its
  draft, query, source basis and budget. Probability may guide scheduling, never
  authorization or result truth. Editing does not implicitly apply administrative
  changes or dispatch external effects. Live execution and continuous queries
  require their own contracts; M13's implemented explicit-submit profile remains.
- Respect the architecture's dependency direction. Core depends on the public
  protocol, never Station or a provider. Applications use the client; the node
  must not import handlers or claim protocol validation proves honest computation.
- Keep deterministic transitions separate from storage, clocks, and effects.
  Make Zig allocation, ownership, lifetimes, errors, and resident bounds explicit.
  Durable backlog is not an in-memory queue. Never silently discard accepted work.
- Keep durable collection size independent of resident memory. Bound pages,
  caches, operation batches and active work; enforce explicit deployment quotas.
  Fixed total-cardinality arrays in the legacy profile are constraints to replace,
  not the target programming model. Do not raise constants or require retention
  opt-in as a substitute for the growing-state foundation required by M10.
- Enforce current scoped authorization separately from PID ownership, including
  reads/replay. Preserve fencing, permanent retirement, and recorded destinations;
  provider state, names, and restored snapshots cannot grant execution rights.
- Retention defaults to unlimited and requires application opt-in. Keep expiry,
  reconciliation closure, and physical cleanup distinct. Quota pressure and
  storage outages never authorize expiry; preserve control/recovery evidence.
- Follow the implemented state-resource profile: associations do not grant access
  or imply lifetime ownership. Preserve the commit boundary between mutations,
  input progress, and outputs. M7 supports one mutated KV resource per turn;
  inline values do not acquire resource dependencies implicitly. Consult the
  [state contract](contracts/STATE_V1.md) for exact bounds and compatibility.
- Put effects behind recorded intents, authorization, and outcomes. Replay must
  not dispatch. Unknown remote outcomes require connector policy; closure cannot
  promise external cancellation or make retry safe. Keep secrets as references
  in transcripts and keep credentials/private datasets out of Git and logs.
- Use the pinned `ursula`/`ursulactl` overlay tools and upstream `ursula-zig` only
  inside the Ursula backend. Pin external Zig revisions/hashes in the consuming
  package. Use disk-backed Ursula for durability tests.
- Keep Board inspection-only for M2. Use public `transit-client` read surfaces;
  no raw storage/provider access, hidden mutations, or unqualified cached views.
  Interpret runtime/framework primitives with source evidence; keep application
  value decoding out of Board; the experimental counter lens was removed in M7.
  Board admits viewers through its private deployment boundary without access
  keys or sessions; its upstream Transit identity still requires a read-only grant.
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
Keep component READMEs navigable; place substantial configuration, recovery, or
integration guides in that component's `docs/` and link them from its README.
Update the owning document with meaningful changes and distinguish implemented,
proposed, and unverified behavior. Keep rationale with its topic. Do not add ADRs
yet; preserve `docs/decisions/README.md` and `TEMPLATE.md` for future use.

Register design items in the [design index](docs/design/README.md). Keep one
linear review sequence and summary table per item in `docs/design/<item>/README.md`,
with one `D<number>.md` per review in that directory. Use the shared template,
preserve recorded outcomes, and distinguish accepted design from implemented behavior.
Use black-and-white wireframes for structure and interaction reviews. Introduce
color only when visual styling is explicitly being reviewed; keep meaning in
labels, geometry and line styles.

Keep the roadmap linear: give additional work its own numbered milestone and
renumber upcoming milestones and references, following the
[sequencing rule](docs/roadmap/README.md#maintaining-the-sequence).

Enter `nix develop` and use [just tasks](tasks/README.md). Use the pinned Zig 0.17
compiler and standard library, not examples from older releases. Install locked
frontend dependencies with `just transit-board::install`, then run `just check`
and the relevant [focused/integration proofs](tests/README.md). Before pushing,
run `just ci-clean` against committed HEAD to expose dependencies hidden by local
build outputs; report what ran and what could not. Toolchain changes also require `just doctor`, deliberate
lockfile updates, and the [toolchain workflow](nix/README.md). Use `vp` for future
frontend dependency operations, checks, tests, and builds. Keep onboarding
commands runnable; never add placeholder tasks that report success.
