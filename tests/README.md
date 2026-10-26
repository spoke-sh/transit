# Tests

Find checks by the behavior they protect. Package unit tests stay beside their
implementation; this directory owns cross-component checks, installed consumers,
independent oracles, formal verification and qualification artifacts.

Start with the [contribution rules](AGENTS.md), [task reference](../tasks/README.md)
and [verification guarantees](../docs/handbook/reference/verification.md).
Executed results live in the [qualification history](../docs/history/qualification/README.md)
and its linked raw artifacts. This index is not a passing-test ledger or an agent
handoff log. A listed task establishes no passing result at the current revision.

## Find an owner

| Area | Entry points |
| --- | --- |
| Formal models and implementation correspondence | [Model guide](verification/models/README.md), [verification guide](verification/README.md), [SQL rewrite specification](../contracts/sql/FuzeRewrite.lean) |
| Invariants, bounds and SDK scenarios | [Invariant catalog](verification/invariants.json), [classified limits](verification/limits.json), [SDK scenarios](sdk/sdk.json) |
| CI selection, lanes and cost | [Task inventory](runner/suite.json), [runner](runner/ci.py), [selection](runner/ci_select.py), [cost reporting](runner/ci_cost.py), [budgets](runner/ci-budgets.json) |
| Local check orchestration | [Runner index](runner/README.md), [check inputs](runner/checks.json), [check commands](../tasks/check.just) |
| Local storage, WAL, segments and recovery | [Storage package](../packages/zig/transit-storage/README.md), [local backend](../packages/zig/transit-backend-local/README.md), [process-death schedules](storage/local/local_storage_faults.py), [storage task recipes](../tasks/test.just) |
| Catalog, Table and named-resource lifecycles | [Catalog package](../packages/zig/transit-catalog/README.md), [direct service schedules](storage/tables/direct_table_service.py), [installed Table checks](interfaces/installation/server_direct_tables.py) |
| Query execution and relational computation | [Query package](../packages/zig/transit-query/README.md), [SQL oracle checks](query/sql), [query test recipes](../tasks/test.just) |
| Database protocols and sessions | [Wire checks](interfaces/sql_wire/README.md), [session checks](interfaces/sql_sessions/README.md), [installed SQL checks](interfaces/installation/server_sql_local.py) |
| Station, delivery, resources and effects | [Station package](../packages/zig/transit-station/README.md), [simulation guide](verification/README.md), [runtime test recipes](../tasks/test.just) |
| SDKs and isolated installed consumers | [Installed checks](sdk/README.md), [SDK guide](../sdks/README.md), [binding tasks](../tasks/bindings.just) |
| CLI, Board, serving and reactive interfaces | [CLI](../apps/transit-cli/README.md), [Board](../apps/transit-board/README.md), [Board tasks](../tasks/transit-board.just), [interface test recipes](../tasks/test.just) |
| Flight and Arrow | [Flight checks](interfaces/flight/README.md), [independent Arrow check](query/arrow/arrow.py) |
| Installation, launchers and reference deployments | [Launchers](../launchers/README.md), [launcher tasks](../tasks/launchers.just), [installed server fixture](interfaces/installation/server.py) |
| Shared fixtures and test support | [Service harness](harness/README.md), [data fixture rules](fixtures/AGENTS.md), [native module composition](../build/README.md), [fixture ownership rules](AGENTS.md#fixtures-and-independent-oracles) |
| Retained observations and original outcomes | [Evidence index](evidence/README.md), [integrity check](runner/layout.py) |
| Performance experiments | [Workloads, runners and active budgets](performance/README.md) |

Use the owning recipes above to find exact binary inputs and environments.
The [provider conformance driver](storage/providers/storage.py) runs Ursula,
while [local fault schedules](storage/local/local_storage_faults.py) exercise
local WAL/object storage. Actors belong to application execution; direct Table
data has its own acceptance owner. Shared native modules have explicit
[build imports](../build/test_modules.zig) across these domains.

## Choose checks

Enter the pinned `nix develop` environment. List tasks with `just --list` or
`just --list --list-submodules`. Use the owning package or focused recipe during
iteration; [tasks/README.md](../tasks/README.md) documents commands and dependencies.

| Change | First checks | Additional qualification |
| --- | --- | --- |
| Documentation and archive links | `python3 -B tests/runner/docs.py`, `git diff --check` | Site checks for published content; archive integrity for moved evidence |
| Formal model or correspondence | Its task from the [model guide](verification/models/README.md) | Named negative controls and affected concrete implementation schedules |
| Package implementation | Package tests and affected public contract fixtures | Domain caller, failure and recovery checks |
| Shared protocol, ABI or definition | Owning generators/checks and independent fixtures | All affected consumers and incompatible-definition rejection |
| SDK adapter | Language checks and an isolated installed consumer | Shared conformance scenarios affected by the boundary |
| Storage or native authority | Focused owner and fault checks | Physical disk, accepted-work recovery, current-policy and growth schedules |
| Build, fixture or CI infrastructure | Runner/tooling checks and affected real tasks | Committed-source clean qualification of affected lanes |

`just check` lists validation scopes. Use `just check fast` for local static/oracle
feedback and `just check all` for the broad repository check. The current `test::unit` target
also contains disk and process-death checks; it is not a pure in-memory unit
profile. `just ci clean --lane NAME` runs one lane from committed HEAD without
workspace build outputs. A successful lane is not the complete suite. Full
qualification and explicit deployment requirements remain recorded in the
[task inventory](runner/suite.json) and owning acceptance criteria.

## Reproduce and preserve failures

Keep the original revision, build profile, definition, command, backend and
fixture identity. Recover uncertain writes using their saved operation; do not
submit replacement work to manufacture a successful result. Join owned processes
before cleanup. Retain needed failed installations privately, and keep credentials
out of logs and committed artifacts. A tmpfs run cannot establish physical-disk
durability, and SIGKILL is not a power-loss experiment.

Use [verification instructions](verification/AGENTS.md) for formal, simulation and
mutation outcomes, and [evidence instructions](evidence/AGENTS.md) for
source-attributed artifacts. Failed, interrupted, skipped and inconclusive results
remain distinct from passes.

## Record results

- Put current supported behavior and limits in the owning public reference.
- Put reusable reproduction instructions with the test or domain owner.
- Put accepted qualification narratives in the relevant
  [history topic](../docs/history/qualification/README.md), linking raw results.
- Keep active investigations and handoffs in issues/PRs; delivery status belongs
  in the roadmap.
- Preserve source revisions, original failures and artifact hashes. A historical
  pass does not qualify a newer implementation or contract definition.

The [archive migration map](../docs/history/qualification/migration.json) locates
all headings formerly held in this README. In-repository evidence links point
directly to their new topic owners.
