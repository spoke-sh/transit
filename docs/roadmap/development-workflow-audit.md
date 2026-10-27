# Workflow migration ownership audit

[Working plan](development-workflow.md) · [Per-file disposition](development-workflow-migration.json)

This audit explains the execution boundaries behind the disposition of all 1,405
original test files. It is a migration review, not a second task registry or an
executed qualification report. The original reference-consumer lists in the JSON
map describe the starting revision; moved consumers now resolve through their own
dispositions and the owners below.

The final disposition preserves 670 files with their domain owners and archives
735 generated observations at their original revision and hash. The root contains
only README.md and AGENTS.md. New runner/harness controls and owner instructions
are additional files, not unexplained changes to the original inventory.

## Execution and artifact boundaries

For each nonarchived file, its `owner` and `role` in the map select the boundary
below. Navigation files are checked as documentation. Helpers, compiler inputs
and independent oracles run through their consumers; they do not acquire a
standalone task merely because they have a Python or Zig extension. These are
families of consumers, not a claim that every named task reads every file.

The [suite inventory](../../tests/runner/suite.json) remains authoritative for
ordinary, browser, focused and external task ownership. Literal recipe nesting
and reviewed indirect nesting are checked separately. The
[check inventory](../../tests/runner/checks.json) owns fast/contract/native scopes;
[build registration](../../build/checks.zig) supplies exact native artifacts and
[shared modules](../../build/test_modules.zig) supply cross-domain type identity.

Comparison with the frozen starting inventory preserves all 103 ordinary tasks,
external task lists and literal recipe nesting. The 39-task growth lane now has
20 storage/catalog/query tasks and 19 SQL/transport tasks in `interfaces`; every
ordinary task still runs exactly once, and other lane memberships are unchanged.
Eight lanes share the existing seven-job concurrency ceiling. The native
aggregate's indirect owner changes from `test::unit` to `check::native`, with all
52 aggregate edges accounted for in the component/fixture/fault profiles. All 14
original SDK scenario identities remain; proof paths follow their file moves and
the post-commit allocation scenario follows that native task rename. The only
additional SDK scenario records the collation repairs already included in the
qualified comparison source. It is not removed to improve timing.

| File owner | Scenario/task consumers | Required artifacts and qualification boundary |
| --- | --- | --- |
| `runner` | `just check fast`, `just check contracts`, native scopes and `just ci` lane runners | Python/Just inventories; native exporters only for compiled contract scopes. Fake-child controls establish failure/selection behavior, not runtime correctness. CI budgets retain their own measured source/inventory. |
| `harness` | Native, SDK, installation and external-profile drivers; fast process/artifact controls | Explicit client/authority artifact sets, private installations and owned child processes. Local native storage and disk Ursula have separate fixture classes. No mutable installation is shared between independent schedules. |
| `catalog` | `test::catalog`, `test::direct-catalog-abi`, authorization tasks, direct Table service and SDK catalog schedules | Independent type/signing fixtures, native operation modules, generated ABI and port peers. Definitions, current-policy checks and installed publication remain separate claims. The unregistered logical-family helper is identified below. |
| `storage` | Native fault scope; `test::storage`, `test::pages`, `test::growing`, block/collection/retention tasks and `test::direct-table-service` | Local WAL/object/Table executables, or explicitly configured disk Ursula/cold-store peers. Physical disk/reopen/process death differ from deterministic simulation and injected in-process errors. |
| `query` | `test::sql`, file/logical/Arrow tasks, public/relational/unified query and lifecycle schedules | Private operation executable, independent SQL/Arrow oracles, native query peers and explicit provider fixtures. Compiler agreement does not establish installed publication or recovery. |
| `runtime` | Station, callers, state, delivery/Vortex, Document, effect and runtime-upgrade tasks | Native authority, application/worker binaries and named provider fixtures. Station actors qualify application execution; they are not the future direct storage acceptance path. |
| `interfaces` | Native contracts, CLI/Board, SQL session/wire, HTTP/reactive/gRPC/Flight, server and deployment tasks; separate browser lane | Reflected exporters, installed native services, pinned independent protocol clients, Board assets/Chromium and explicit deployment infrastructure. Reference-provider tasks and optional installed fault profiles remain distinct from ordinary CI. |
| `sdk` | Binding recipes, shared scenario catalog, installed language schedules and the interoperability ring | Immutable native inputs, separate Debug/ReleaseSafe packages and private installed consumers. The registry names every shared language entry point. Catalog checks nested in SDK aggregates are required executions, not extra ordinary tasks. |
| `verification` | Formal lane; property/simulation tasks; separate mutation and discovery profiles | TLA+/Lean inputs, native transition drivers and saved JSON schedules. Files are executable proof inputs, including corpora loaded by directory enumeration. Model, simulation and physical-fault claims remain separate. |
| `fixtures` | gRPC generation/native modules and reactive-description validators | Independent protocol/schema inputs and their upstream licenses. These are active inputs, not archived observations; changing them retains dependent qualification. |
| `performance` | Existing benchmark recipes and directly documented matrix/comparator/gate commands | Explicit optimized probes, pinned comparator shells and preserved workload/budget identities. Large-input cgroup, disk-cache conditioning and physical-device tests require their documented environments. A runner/oracle pass does not recalibrate a performance budget. |
| `index` / archived `evidence` | Documentation checks and archive integrity | Original hashes and immutable Git objects. No runtime, build, fixture or budget may consume routine archived output as a correctness input. |

## Dynamic and manually invoked consumers

The import audit checks explicit local Python imports, including function-local
ones. It cannot prove string-built compiler inputs, copied programs, directory
enumeration, Zig module registration or imports from example applications. Those
boundaries were reviewed against their actual call sites:

- `sdk_unified.py` selects Java and BEAM controller names before appending source
  extensions. Both ordinary and direct-capture variants remain copied inputs.
  Shared language dispatch is explicit in `consumer_registry.py`.
- The C/C++ installer constructs HTTP/gRPC/Document peer names and copies their
  C/C++ source and header together. `c_logical_values.py` constructs the C and C++
  codec filenames. Lazy preparation changes when these peers compile; it does
  not remove their schedules or installed-header checks.
- SQL wire `clients.py` selects `libpq.c` and `libmysqlclient.c` from the pinned
  independent client family, compiles them and executes the resulting programs.
- `examples/station-document/run.py` imports the Document Board helper;
  `examples/serving/run.py` imports the physical reactive-placement helper.
  Their example, browser and placement tasks retain those consumers.
- Simulation runners enumerate their owned corpora. All 24 original replay
  files keep their bytes; absence from a literal-filename search is not absence
  from execution. Formal drivers similarly supply their model/config paths.
- Performance `file_workers.py`, `six.py`, `large.py` and `vector_gates.py` have
  direct command examples in the owning measurement guide. Historical budget
  files are supplied explicitly to their gate commands. They are not ordinary
  CI outcomes and are not silently regenerated for a new source or machine.
- SQL-session `resources.py` is a manually invoked read-only observer documented
  in the service-interface Internals account. It does not assert correctness or
  run automatically merely because a session test starts.
- `reactive_fixtures.py` is a manual generator of independent golden bytes for
  the serving package. Its output is committed contract input; it is not a test
  result. Invocation uses the repository test launcher after the move.

Two files already lacked executable consumers at the starting revision:
`sdk/binding_port_fixture.py` and `catalog/tables/table_logical_types.py`.
They remain with their semantic owners and are explicitly identified as
unregistered. Neither counts as live host-boundary or SQL-to-disk coverage.
Connecting or replacing them requires an owning scenario and current contract
validation; this migration does not silently add their assertions to a measured
baseline or imply that an unused helper has passed.

`interfaces/sql_wire/reference-transcript.json` was also unconsumed. Inspection
of `reference.py` establishes that it prints sanitized message-kind observations;
no check reads the saved JSON. The file therefore joins the immutable observation
archive. The real reference task, independent clients and protocol assertions
remain executable and retain their own environmental requirements.

## Reproduce the structural audit

From the pinned development shell:

```sh
python3 -B tests/runner/layout.py --complete --archive-integrity
python3 -B tests/runner/imports.py --json
python3 -B tests/runner/test_task_coverage.py
python3 -B tests/runner/docs.py
```

The layout check rejects missing/duplicate dispositions, missing destinations,
old paths and changed archived bytes. The import and task controls detect their
declared boundaries; the reviewed dynamic cases above are not inferred from
those controls. Actual installed, browser, provider, fault and performance
results are recorded by their runners and reconciled in the working plan.
