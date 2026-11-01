# CLI, Board and documentation: qualification history

[Archive index](README.md) · [Tests](../../../tests/README.md)

Console interaction, operator views, browser behavior and documentation publication.

These records preserve their original dates, sources, failures and limits. They
do not define current interfaces or qualify later changes. Commands and then-open
work describe their recorded source; use the [task reference](../../../tasks/README.md)
and [test index](../../../tests/README.md) for current navigation.

## Board contextual Inspector — 2026-10-30

The question is whether one contextual Inspector can replace nested detail panels
without changing query execution, result identity or authorized disclosure. The
[workbench guide](../../../apps/transit-board/docs/workbench.md#activities-and-contextual-inspection)
owns current behavior. Implementation starts from `04f6c692b`; final interaction
source is `c3af94b18`, including the local-navigation return from expanded detail.
No native contract or runtime owner changes in this slice.

The final `nix develop --command just transit-board::workbench-browser` passes
from clean committed source `c3af94b18`. All five installed binaries are
ReleaseSafe builds of that revision, using the ordinary disk-backed `/var/tmp`
fixture. All three Chromium scenarios pass in 24.2 seconds, including the final
expanded-detail/navigation assertion. The installed API schedule passes exact
145-row traversal, verified empty/metadata results, definition guards, read-only
admission, bounded reader capacity and terminal-result revocation. The screenshot
was visually inspected; logs, screenshot and binary hashes remain locally under
`.cache/board-workbench/contextual-inspector/final-manifest.json` and sibling files.

At `462ecc541`, a functional control runs the real installed CLI, node, query host,
SQL gateway and embedded Board, with fixture storage under `/tmp` (tmpfs on this
host). Board is Debug; other roles are ReleaseSafe binaries built before the final
frontend refinements, with unchanged runtime owners. This mixed build control is
not disk durability or uniform-source release qualification. All three Chromium
scenarios pass in 23.9 seconds, and the installed API schedule passes exact
145-row traversal, verified empty/metadata results, definition guards, read-only
admission, bounded reader capacity and actual terminal-result revocation.

The [browser scenarios](../../../apps/transit-board-web/browser/workbench.spec.ts)
cover one Inspector switching between dataset, schema column, result column and
result evidence; 100/45-row window updates; expansion without replacing the result;
unchanged drafts; multiple cells and selected-cell removal; Escape/focus return;
390/720/1280-pixel layouts; original-result recovery after a lost reply; denied
result clearing; and unavailable workbook metadata removing portal content.
Catalog/dataset/workbook accessibility scans report no violations, with no
external requests or browser storage and at most five JavaScript assets below
900,000 bytes each. The runtime screenshot was visually inspected. The final
navigation-return assertion is an addition after this first control.

The ordinary disk-backed workbench attempt stopped before browser assertions:
`transit console failed: ReadFailed` while creating fixture Tables, following
startup authority timeouts. Its installation remains at
`/var/tmp/transit-server-proof-tz5msi8h`. The control script, binary/artifact hashes,
logs and screenshot are retained locally under
`.cache/board-workbench/contextual-inspector/manifest.json` and sibling files.

Clean `installation-ui` at `462ecc541` passes thirteen checks: Board contract,
format/type/unit checks (including all 108 frontend tests), handbook checks and
production build, Node checks, observability, server logging, single-executable
installation, direct Table lifecycle/fault schedules, SQL lifetimes/access/local
authentication, Board inspection and Board query recovery. It then fails
`launchers::local::test-station` during courier readiness recovery with
`transit-admin` `ReadFailed` while waiting for an Arrow reply. The last workbench
API task does not run. This is an incomplete lane. Raw preparation and task
records remain at `/var/tmp/transit-ci-8exfjodd`, including
`src/.cache/ci/runs/installation-ui-pvcmo2ew` and the private Station fixture.

Clean `browser` at `c3af94b18` passes the Board inspection/relational, query,
HTTP and gRPC tasks: five native inspection browser scenarios, one relational,
one query, one HTTP and one gRPC scenario, alongside their owning API/fault
schedules. It stops in `test::reactive-browser` before that browser scenario:
the serving fixture's operation remains `service_admitted`/`admitted` without
a recorded result until its existing wait bound expires. Reactive-view and
workbench tasks later in the lane do not run. This is an incomplete lane;
raw records remain at `/var/tmp/transit-ci-efnkr_2z`, including
`src/.cache/ci/runs/browser-34uz0j7j`.

The [published-application scenario](../../../apps/transit-board-web/browser/application.spec.ts)
passes in 53.5 seconds against the same `c3af94b18` native binaries with the
navigation assertions in `47b86e75a`. The first attempt expected a workspace link
while the Operations sidebar remained selected after a route was removed. The
updated test enters through **Application**, checks its declared destination and
then verifies the published label. It retains SQL/Form/Canvas editing, frozen
publication/recovery, current read denial, desktop/mobile density, 320-pixel layout
and zoom assertions. Only the test changes; production code remains `c3af94b18`.
The direct fixture rerun is recorded separately from the interrupted clean lane.

These passes qualify the implemented topology against existing metadata and
result contracts. They do not complete either interrupted clean lane, establish
their failure causes, or qualify proposed branch comparisons, storage accounting,
operator metrics or Milestone 29 as a whole.

## Board catalog and bounded read workbench — 2026-10-28

The question is whether installed Board can discover Table definitions and
consume one logical SQL result across bounded display windows without becoming
an execution or permission owner. Current behavior and limits belong in the
[workbench guide](../../../apps/transit-board/docs/workbench.md),
[SQL client](../../../packages/zig/transit-sql-client/README.md) and
[result library](../../../packages/zig/transit-sql-results/README.md).

The successful functional control uses the source tree subsequently committed
as `9003d14b3`, the pinned Nix toolchain and definition
`fe0da791b6421a288d3f53bedbfd1804cf5583c2c08e1d121c8120125daeb9f6`.
It runs the real installed CLI, node, SQL gateway, query hosts and embedded Board.
Board is Debug; the other roles are ReleaseSafe. The CLI reports revision
`91e35ce2c`; the SQL gateway includes the later prepared-slot fix. Exact binary
hashes, the control script, logs and screenshot are retained locally in ignored
`.cache/board-workbench/evidence-9003d14b3/manifest.json` and its sibling artifacts.
The control overrides only `LocalInstallation`'s fixture parent to `/tmp`, which
is tmpfs on this host. It is functional evidence, not disk durability or a
uniform-source release qualification.

The [installed fixture](../../../tests/interfaces/installation/board_workbench.py)
passes catalog pagination over eleven Tables; exact definition metadata; all
145 independent row identities across 100- and 45-row windows; repeated
observation/advancement without a different result or observation; verified empty
completion; SHOW, DESCRIBE and EXPLAIN; definition mismatch; four-reader capacity;
expired references; and metadata/terminal-result denial after actual principal
revocation. INSERT, DROP, session settings and effectful row-returning reload
are refused even with a stronger configured SQL account. Independent console
counts remain 145 after each refusal.

Both [Chromium scenarios](../../../apps/transit-board-web/browser/workbench.spec.ts)
pass in 21.1 seconds. They cover catalog continuation, dataset deep-link reload,
metadata navigation without SQL execution, explicit preview, received-window
profiles, keyboard Run, empty completion, earlier-draft attribution, and recovery
of a deliberately lost successful reply with exactly one Run. A denied
observation clears displayed rows and the SQL draft. Catalog, dataset and workbook
accessibility scans report zero violations. There is no horizontal document
overflow at 1280 pixels, no page error or browser storage, and at most five
JavaScript assets, each below 900,000 bytes. The retained 1440-pixel screenshot
shows the dataset and column inspector. These checks do not replace a manual
screen-reader/zoom review or a browser/service memory and latency benchmark.

Earlier attempts exposed and corrected a failed-prepare registry lifetime bug,
missing dataset/workbook deep routes, action-link contrast, a test locator
mismatch, and a test assumption that catalog order followed names. The SQL registry
now publishes a prepared slot only after fallible preparation succeeds; the
installed refusal/closure schedule passes after that correction. Row-returning
reload is marked effectful in typed descriptions without changing its ordinary
row dispatch. Public-client, result-library, SQL-service and Board route unit
checks pass; query-client validation covers full-width values, original-result
identity, lost advancement and late replies after closure. Profile checks cover
five-state counts and integer values beyond JavaScript Number precision.

Clean-source outcomes remain scoped and incomplete:

- `core` at `91e35ce2c` passed the 46 fast checks and exposed an invalid maximum
  storage-path fixture in the client tests. The fixture is corrected to a valid,
  maximally escaped path and its owning package passes. The obsolete lane was
  stopped after the correction; it is not a core-lane pass.
- `experience` at `2d78020c2` passed Board/schema/type checks, the documentation
  site and Node binding checks. That obsolete run was stopped when the SQL
  preparation defect was found; it is not an experience-lane pass.
- `browser` at `6ff62a3ed` passed the five inspection browser scenarios and the
  direct relational API proof. The relational browser's lost-response test
  instead received an upstream 503 before its intended injection; the lane
  stopped there and later browser tasks did not run.
- `interfaces` at `c619ae202` passed SQL wire TLS and result-allocation checks.
  Unix/HTTP/HTTPS each recorded 1,453 requests, 305 queries and zero measured
  memory events or steady-state libc allocation attempts. The TLS cancellation
  fixture also logged a BrokenPipeError while its command returned zero.
  The next SQL gateway proof timed out after 300 seconds amid repeated
  `commit_saved` request timeouts and canceled storage operations. Remaining
  interface tasks did not run.

Ordinary disk-backed installed attempts also encountered startup or seed failures
before the Board assertions, including authority timeouts and recovery-required
outcomes. The tmpfs control separates the successful UI/API schedule from those
failures; it does not establish their root cause or waive disk-backed gates.
Raw clean-run logs are retained with the functional evidence; failed clean
checkouts retain their own runner records. No complete repository, Compose,
provider, physical recovery or full Board product qualification is claimed.

## Direct Board relational recovery — 2026-10-24

`nix develop -c zig build test-direct-board -Doptimize=ReleaseSafe
-Ddirect-board-browser=true` passes **504 public requests** and the real embedded
Chromium worksheet. The installed node stores Table data locally and produces
`.tseg` files; the fixture uses the shared native catalog ABI to provision rows.
Board has a separate read-only inspector and query credential. Both configured
routes select the same direct catalog; the test executes joins/groups over two
independent Tables through `[0, 0]` and `[0, 1]` route selections.

The owner persists exact source bindings, accepted positions and original pin
operations before acquisition. Two corrupted accepted-pin replies and one
corrupted release reply preserve unknown outcomes. Two abrupt node replacements,
Board replacements during acquisition/closure and active execution, and cleanup
with a rotated credential retain the original identities. A source changed
between Explain and Run rejects; explicit closure distinguishes released pins
from acquisitions proven permanently excluded by an advanced frontier. Every
closure keeps the original input and pin operations unchanged. Current denial
blocks cached and terminal pages; no observation implicitly starts new work.

Chromium closes an interrupted query after Board replacement, distinguishes
metadata explanation from Run, recovers a lost open reply and browser reload
without creating another query, and reads exact nullable grouped values. It
clears protected rows and the SQL draft after credential revocation. The final
close waits for its successful response, then the fixture checks closed durable
state and the interrupted query's released native pins. The accessibility scan
reports no violations. Foreign Origin and disabled-route requests reject.

Focused workspace tests cover exclusive journal ownership, owned JSON readback,
startup closure and corrupt connection rejection. Four browser-boundary tests
and strict TypeScript checks pass. The diagnostic suite executes **3,435
projections across 29 declared surfaces**, including the new recovery errors.
The earlier browser attempts were incomplete: one asserted release for a pin
that never existed, another hit a Node stdin pipe error, and another ended while
its close request was still running. The fourth full attempt passes.

This is local direct-service and browser evidence. It does not qualify Follow,
Compose/reference placement, physical reclamation, cleanup without current
CONNECT/USAGE/SELECT, or the final combined repository checks.

## CLI actor Table helper retirement — 2026-10-24

The console already executes through the shared SQL service. Its unreferenced
`ConsoleRelational` implementation and actor `TableRecovery` journal are removed,
including the obsolete journal's unit-test import. Their recovery semantics do
not describe the installed service-owned operation ledger and pin journal.
The diagnostic inventory no longer treats these files as production owners.

In the pinned Nix shell, `zig build test-cli-lifecycle -Doptimize=ReleaseSafe
--summary all` passes **33/33** tests. `just test::cli-diagnostics` passes **193**
server/console cases and **127** artifact/file cases. Diagnostic inventory,
semantic mappings and documentation links pass; the site passes nine tests and
its production build. The DROP TABLE help and SQL reference now state the
direct runtime's missing shared dependency check and Table garbage collector;
they no longer promise the old actor catalog's RESTRICT behavior. This cleanup
does not implement those missing owners or retire the remaining actor consumers.

## Direct completion after console and Go integration — 2026-10-24

The lifecycle branch rebases onto `origin/main` at `84afe73b`, retaining the
console interaction reducer and Go SDK. Direct Table completion now applies the
shared keyword-continuation rule with one bounded catalog page budget and a
final authorization/definition check. The Go declarations are regenerated for
the current shared definition.

In the pinned Nix shell, the query package's ReleaseSafe `test-unit` target
passes **148/148** tests. `just test::console-history` passes the complete PTY
suite. `just test::direct-table-service` passes **651** typed HTTP calls,
including eleven console keyword/range cases and unchanged SQL-editor behavior,
alongside its CRUD/DDL, lost-reply, retained-read, revocation and restart schedules.
`just bindings::check`, the diagnostic inventory and the Markdown link check
pass. These runs do not establish full `just check`, installed Go qualification,
Work items migration or committed-HEAD `just ci-clean` for this branch.

## Console interaction state machine — 2026-10-24

`nix develop --command just test::console-model` passes with 5,278 distinct
states and all 91,198 exported edges replayed against the production Zig editor
reducer. Each edge starts from a shortest representative path to its source;
projected draft/cursor, saved draft, filter, history match/failure, modes and
emitted effects agree. Six independently removed model guards expose the expected
freshness/interruption, uniqueness, metadata-basis, restoration, ownership and
protected-failure violations. The same schedules follow the safe graph in Zig.
A separate fairness configuration passes eventual borrower release, conditional
on request failure/timeout, cancellation join and foreground completion.

An isolated checkout of `6bd1b4c3` removes the actual Zig obsolete-reply guard.
The mutant compiles and the conformance runner rejects `Accept → Type →
ReplyUniqueSame`: the implementation installs an obsolete response where the
model requires no effect. The mismatch and source/binary identities are retained
under `.cache/verification/console-model/zig-obsolete-guard-mutant/`. This single
production-source mutation is a separately executed negative control; the regular
task mutates the six model guards.

`nix develop --command zig build test-cli-lifecycle test-console-history` passes
for the initial extraction. It exercises the complete terminal suite, including
multiline rendering, immediate completion refinement, quiet unique validation,
space-aware insertion, seeded history, draft-preserving cancellation, signals,
persistence and statement outcomes. Native units also check exact metadata-field
comparisons, complete/ready uniqueness and protected-buffer clearing.

The native SQL session proof (`nix develop .#sql-wire --command zig build
test-sql-wire-gateway -Doptimize=ReleaseSafe -- sessions-basic`) passes at
`6bd1b4c3`, including actual console completion, partial words and undo over TLS,
plus existing authentication, concurrent sessions, revocation and recovery.
Repository checks pass the native, diagnostic, terminal and frontend stages.
After correcting the public Internals command example to link its reproduction
guide, `nix develop --command just transit-docs::check` passes ownership, type,
format and production-build checks. Final aggregate and committed-source CI
qualification are reported separately.

The [model guide](../../../tests/verification/models/README.md#finite-console-interaction-model)
and [mechanism account](../../handbook/internals/service-interfaces.md#console-interaction-transitions)
define the abstraction and adapter responsibilities. Logs, model/source/binary
identities, graph and counterexamples are retained in
`.cache/verification/console-model/`. The finite model uses three draft classes,
four filter classes, start/end cursors and one borrower. This is bounded transition
conformance, not an unbounded refinement proof, arbitrary-history/undo coverage,
transport liveness, terminal rendering proof or a latency guarantee.

## Console keyword continuation and unique insertion — 2026-10-24

`nix develop --command just check` passes, including native units, all CLI
diagnostics, the complete terminal suite, frontend checks and the documentation
build. Shared units cover complete keywords, partial/interior words, lowercase
input, retained suffixes, second statements, identifiers, ordinary SQL editor
mode and allocation failure cleanup while advancing grammar.

Real PTYs hold the validation response for a unique completion and inspect every
rendered frame: no candidate menu appears before insertion. `CREATE`, `CREATE `,
`CRE` and `DELETE` complete with one Tab and one undo restores the original draft.
New ambiguity displays the current choices without insertion; Esc cancels hidden
validation. These peers execute no SQL. The no-flash assertion fails against
the preceding implementation by observing a transient `TABLE` menu.

`nix develop .#sql-wire --command zig build test-sql-wire-gateway
-Doptimize=ReleaseSafe -- sessions-basic` passes. Eleven direct native-service
cases establish keyword continuation and exact cursor ranges for `CREATE`,
`ALTER`, `DROP`, `DELETE` and `INSERT`, including lowercase, partial/interior
words, a semicolon and a second statement. A real console over TLS completes
`CREATE` to `CREATE TABLE` without a menu flash, preserves partial-word behavior
and undoes each edit. Existing catalog/settings, authentication, concurrent
session, revocation and recovery checks also pass in this basic session profile.
These results do not extend SQL execution capabilities or the catalog search
budget. Clean-checkout qualification is reported separately.

## Console completion separators — 2026-10-24

`nix develop --command zig build transit test` and `just check` pass for the
completion edit helper and terminal integration. Shared units cover missing
separators on either side of a replacement, partial words, existing whitespace,
qualifier dots, parentheses, operators, comments, quoted/escaped identifiers,
UTF-8 offsets and statement suffixes. Invalid byte ranges and edits exceeding
the 4 KiB limit, including added separators, fail without writing output.

Real PTYs cover twelve acceptance/undo schedules for `SHOW`, `SET`, `RESET`,
partial words, spaces, tabs, newlines, semicolons and quoted column names.
The peer observes exactly two assistance requests per case and no SQL execution.
The cursor follows the candidate; one undo restores the original draft and cursor,
including when a separator was inserted before retained suffix text. Existing
history, idle/refinement, denial, session-loss and cancellation checks also pass.

The new terminal regression fails on the preceding implementation at `4df1ccc8`:
accepting `ALL` after `SHOW` renders `SHOWALL`. These checks establish shared
local editing and terminal behavior over a controlled metadata peer; they do not
extend service authorization or query execution guarantees.

## Responsive console completion menus — 2026-10-24

`just check` and `just test::console-history` pass for the responsive completion
implementation at `1dd2250c`. Real PTYs hold metadata replies to prove that the
first request starts immediately without a placeholder, same-token edits filter
the disclosed list before a response arrives, and acceptance validation leaves
the list visible. Selection survives narrowing, backspacing and reordered fresh
results. Several edits during one request acquire only the latest subsequent
draft; Tab/Enter during refresh neither queues insertion nor executes SQL.

An empty preview waits for current evidence: a later response can reveal a
candidate absent from the old limited shortlist. Context changes hide unrelated
candidates. Static dot-command filtering is synchronous and preserves selection.
Expiry or an instance change from an obsolete acceptance request clears the
retained preview, draft and undo. Existing denial, timeout, idle stability,
history and cancellation schedules also pass.

Shared assistance units cover suffix preservation, active-statement boundaries,
strings/comments, quoted case sensitivity, escaped quotes, UTF-8, disambiguated
columns and dotted settings. These are editor and shared lexical checks; they
do not add service authority guarantees or establish a production latency target.
The accepted interaction is recorded in [D4](https://github.com/spoke-sh/transit/blob/c5b1ab67def9ece225dbff25936cf1bd9155363a/docs/design/transit-cli/D4.md).

## Direct Table completion and console integration — 2026-10-23

The direct Table adapter carries the shared completion coverage/status contract,
cursor-local statement selection and bounded ranking through the current v1
definition `e90c811e59e082a12accb35d8b7d4e4217ed1db5e023c340944b773f1cdd5e2a`.
Both predecessor definitions reject; generated schemas, signing fixtures and
language resources use the integrated definition.

In the pinned Nix shell, the protocol and query packages' ReleaseSafe tests pass
**50/50** and **146/146** respectively.
The ranked-name regression retains the exact definition of a later candidate
that replaces an earlier full-shortlist entry and rejects conflicting definitions
for one displayed name. `zig build test-direct-table-service
-Doptimize=ReleaseSafe --summary all` passes **8/8** build steps and **562** typed
HTTP calls. Its new checks cover second-statement replacement ranges, quoted
text, absent source metadata, limited root-keyword coverage and tab-separated
`.schema` completion. Existing CRUD/DDL, retained reads, exact reply recovery,
restart and current-revocation assertions also pass.

`just test::console-history` passes the real terminal editing, completion,
history, signal and outcome schedules. `just contract::check`,
`just transit-board::contract`, strict query-client TypeScript and **57**
query-client tests pass. Diagnostic inventory/mappings and
`just transit-docs::check` pass, including **9** documentation tests and the site
build. These scoped runs do not establish full repository or clean-checkout
qualification.

`zig build test-server-direct-tables -Doptimize=ReleaseSafe --summary all`
passes **13/13** steps, including installed native-session Table/settings
completion, the original six-statement DDL batch with the query worker stopped,
and restart/name-reuse checks. This build also includes Board's explicit
read-only preparation-recovery retry case. An earlier run timed out at the
batch's 80-second harness deadline while the installation reported
`AuthorityTimeout` and `HttpCapacity`. Isolated statements completed in
5.84–10.25 seconds; the unchanged batch then passed on rerun. These observations
do not identify the earlier delay's cause or establish a latency guarantee.

## Installed SQL client selection — 2026-10-26

The [retained controls and task records](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/lifecycle-ci-clients-2026-10-26/report.json)
identify an environment dependency in hosted run `40278906228`, at merge revision
`e4b4955cb`. Nine experience tasks pass, including installed direct Table SQL,
fault recovery, session lifetimes and the complete standalone SQL authentication
schedule. The source-bundle local SQL task then fails before its first MySQL
connection: the runner-selected executable rejects `--no-login-paths`.
The experience shell had supplied neither database CLI; locally, that original
shell reports `mysql: command not found`.

The corrected shell supplies PostgreSQL 18.6 and MySQL 8.4.11 from the existing
locked nixpkgs input, matching the default developer shell. Both selected paths
are in the Nix store, and MySQL accepts the existing `--no-defaults
--no-login-paths` isolation options. No compiler/library pin or lockfile changes.
`just doctor` passes. At `2f5018ad2` plus the shell change,
`nix develop .#ci-experience --command just test::server-sql-local` passes the
complete installed source-bundle schedule in 293.93 seconds: initial owner
bootstrap, shared data through both real CLIs, optional and required TLS,
plaintext refusal, revoked-login persistence, and exact recovery after an
accepted owner binding loses its reply and the process is killed.

The workload, deadlines and assertions are unchanged. This focused pass does
not complete the failed hosted lane or qualify its unexecuted later tasks.

## Direct catalog administration and installed database clients — 2026-10-23

`just test::direct-table-service` passes 433 typed calls against the real node.
The added authorization compiler checks stable Table references, qualified and
unqualified names, PUBLIC grants/revokes, creator-scoped defaults, explicit role
selection, bounded reads and unsupported schema lifecycle rejection. Compilation
leaves the native policy revision and Table acceptance frontier unchanged.

`just test::server-sql` passes in 122.98 seconds with real PostgreSQL and MySQL
clients over verified TLS. The installation's administration profile resolves
names through the direct catalog. Ungranted discovery returns the structured
`cli.access_denied` diagnostic and creates no plan. Explicit native publication
then grants reader/writer access; Unicode/NULL rows, denied writes, persistent
revocation, regrant, listener replacement, disabled accounts, password rotation
and DELETE all pass. A private boundary refuses direct execution until the
waiting caller and manager have been killed. Restart recovers the original
operation with both database listeners disabled and unavailable PEM paths;
re-enabling access finds its one retained row. Expired and replaced TLS trust
preserve control recovery while gating new admission.

The run uses source-built installed executables, not the separate distribution
bundle. Diagnostic error/outcome checks and documentation links also pass.
This evidence does not qualify direct namespace lifecycle, SDK migration or
captured-query administration. The public CLI still exposes only server/console.

## Stable console completion menus — 2026-10-24

`just check` passes with the idle-refresh timer removed. Real PTYs keep local
dot-command and catalog menus open for six seconds and retain their selected
second item. The catalog peer observes no additional assistance request during
that idle interval, then exactly one fresh request when Tab accepts the item.
Existing metadata-change, denial, session-loss and editing schedules also pass.
The new local-menu regression fails before the fix: the selected `on` entry
returns to `off` when the five-second timer expires. These are editor/client
checks; they do not establish new service or authorization behavior.

## Console completion and editing — 2026-10-24

The [qualification record](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/console-completion-2026-10-24.json)
retains commands, log hashes and real-service observations for the accepted
[interaction](https://github.com/spoke-sh/transit/blob/c5b1ab67def9ece225dbff25936cf1bd9155363a/docs/design/transit-cli/D3.md). In the pinned Nix shells,
`just check`, `just test::unit` and `just test::console-history` pass.
The primary implementation was qualified at revision `3b03aad7`; subsequent
checks add clipped-menu paging and complete-empty-result coverage. A final
session-loss fix and passing PTY rerun prove that expiry or a changed server
identity clears drafts and undo even when its reply belongs to an older draft,
without acquiring another response first. A temporary metadata-service failure
instead preserves the draft and permits retry.

Native units cover cursor-local statement boundaries (including a dot command's
newline), raw-spelling ranking, quoted qualified names, complete/limited candidate
coverage and bounded undo eviction. The real terminal executable's PTYs exercise
Tab/Shift-Tab, acceptance without submission, clear/dismiss, general undo aliases,
isolated history-search undo, duplicate/whitespace/case-insensitive search,
vertical movement, literal bracketed paste, split escape sequences and resize.
Controlled metadata peers prove responsive editing during delayed acquisition,
the one-second request deadline, cancellation of late replies, current-basis
acceptance, revocation cleanup, partial-single-result menus and empty results.
Esc queued during statement execution does not clear a later pasted draft.
These peers establish client behavior, not authoritative metadata acquisition.

`nix develop .#sql-wire --command zig build test-sql-wire-gateway
-Doptimize=ReleaseSafe -- sessions-basic` passes against the actual native service,
including suffix/alias/second-statement/DML scope, settings routing and quoted
text status. A real console PTY over TLS accepts catalog and settings completion
within the editor's one-second request budget. Five direct assistance samples
take 201.600–268.233 ms locally; these are individual observations, not a latency
guarantee. The session profile also passes independent authentication, concurrent
sessions, revocation and restart recovery.

The broader `just test::sql-sessions` attempt fails later at its concurrent
SELECT assertion with `AuthorityUnavailable` / native `HttpCapacity`, after the
new direct assistance assertions pass. That attempt does not establish full
source-worker/session qualification. Neither PTYs nor the basic session profile
establish the user's desktop Ctrl-Space delivery or an SSH/multiplexer path.
Clean-checkout qualification is reported separately from these workspace runs.

## Console multiline editing — 2026-10-23

`just test::console-history` passes in the pinned Nix shell. The real PTY
multiline fixture interprets cursor movement, erasure and scrolling and checks
aligned continuation rows, blank lines, cross-line cursor movement/deletion,
bracketed paste, history recall/search, explicit submission, wrapped lines,
width/height changes, escaped Unicode and drafts taller than the screen.
Submission retains one aligned transcript; cancelling or shortening the draft
removes its old display rows. An independent session peer observes the exact
multiline SQL and verifies that editing does not submit it. This establishes
terminal/client behavior, not SQL execution or durability.

The same task passes the existing history, external editor, signal, help and
statement-outcome schedules. The diagnostic inventory records only the renderer's
additional helper boundaries and propagation counts; public errors are unchanged.
`just check` passes, including native units, CLI and terminal checks, generated
contracts, frontend checks and the documentation production build.

## Bounded direct HTTP client allocation — 2026-10-23

`nix develop --command zig build test -Doptimize=ReleaseSafe` in
`packages/zig/transit-client` passes. A real HTTP exchange with an 8 MiB request
ceiling and 16 MiB response ceiling completes under a 1 MiB fixed allocator
when its actual payload is small. The response remains usable after transport
destruction. Tests also cover oversized requests before dispatch, response
overflow, incremental growth to an exact byte limit, and timeout cleanup.
This verifies allocation follows payload size while preserving wire ceilings;
it does not qualify installed SQL or imply that maximum-sized exchanges fit
every caller's resident budget.

## Console help and statement outcomes — 2026-10-22

`zig build test-console-history` includes the real executable's independent
help and outcome peers alongside history, editor and terminal input checks.
The focused run passes compact/alphabetical help, expanded and case-insensitive
command/topic help, unchanged text in either output mode, argument rejection,
and removal of the public recovery commands without issuing SQL for help.

The outcome peer verifies authoritative completion/counts, rejection, partial
application, unchanged writes, lost execute replies, transient observation
failures, expired sessions, current denial, changed instances, empty results and
incomplete row streams. It checks that discovery of an accepted write uses the
same completion budget as direct acceptance. Interrupt schedules cover submit,
fetch, waiting, completion races and stalled cancellation; trailing batch SQL
is discarded. Each schedule observes exactly one SQL submission. These are
client behavior checks, not write-durability evidence.

`zig build test-cli-lifecycle` passes all 31 checks, including partial-result
warnings alongside typed SQL diagnostics with hidden workflow actions.
`zig build test-cli-diagnostics` passes 193 public CLI cases. Connection files
reject the removed execution selector. The native protocol still admits
captured reads and operation controls; private test clients exercise those
interfaces without adding console commands. `just test::server-sql-lifetimes`
passes native lease expiry, idle PostgreSQL/MySQL plaintext/TLS sessions, explicit
idle expiry and finite partial-frame deadlines.

The real-server reply-loss scenario confirms the original write after lost
execute/status replies, verifies one submission and its stored value, and keeps
another console responsive while a reply is held. `just test::server` passes its
full lifecycle and original-identity restart recovery in 305.75 seconds.
`just check` passes shared units, diagnostic and terminal checks, generated
contracts, frontend checks and the documentation build. The physical ENOSPC
fixture in `tests/server_capacity.py` is migrated to that same native helper;
this change does not claim a new physical-capacity run. Full shared statement
results and coherent table rendering across transport batches remain future
work, directed by the root and CLI agent instructions.

## Two-command Transit CLI

The installed `transit` exposes `server` and `console`. The removed command
routes and global diagnostics option reject before configuration or execution.
`tests/cli_diagnostics.py` exercises the real binary's help, validation, privacy,
configuration and SQL error rendering, including all removed routes.

Native authorization, catalog, application and file-source proofs use private
callers in `tests/operations/`. Build wiring passes the fixture directly or places
it under `zig-out/tests/` through the explicit `test-operation-fixture` target.
It is excluded from the default build installation, runtime `apps` target and
release bundles. It has no user help or supported public interface.
`tests/operation_diagnostics.py` retains private artifact validation and bounded
source-error evidence independently of the installed CLI. File capture and
structured error projection live with these helpers; unused CLI error renderers
and JSON timing output are removed.

Executed focused checks: 192 real CLI cases and 127 native helper cases pass.
The file-source proof also passes its 190 cases, including immutable capture,
checked gzip, cancellation and a 192 MiB input under a 96 MiB address-space limit.
The native public-query proof also passes exact signed retry, fenced restart,
busy admission, cancellation and current read-time revocation through the helper.
`just test::server` passes its full lifecycle in 307.53 seconds, including console
SQL, `.edit` and lost-reply recovery. `just test::server-applications` passes
installation, replacement and retained recovery in 383.44 seconds through the
private application caller.
`just check` passes the shared unit tests, diagnostics and terminal proofs,
generated contracts, frontend checks and documentation production build.

Dated sections below summarize checks at their recorded source revisions. Obsolete
raw transcripts and dependent manifests were removed during repository cleanup;
the summaries retain measured outcomes and limits, but do not claim those archived
bytes are available here. Current validation must be rerun with the owning tasks.
Remaining benchmark budgets and independent regression fixtures stay executable.

## Console external editor — 2026-10-22

The [console](../../../apps/transit-cli/docs/console.md#external-editor) runs `.edit`
through a real foreground editor process and observes saves before submitting
SQL through the existing session owner.

Executed on Linux with the pinned Nix development shell:

- `zig build test-console-history` passes the existing history/input checks and
  `tests/console_edit.py`. Real PTYs and editor subprocesses cover unchanged,
  changed and atomic saves, quit without save, failed SQL and dot-command
  filtering, empty history, session keepalives, editor failure/signals, parent
  interruption, invalid/oversized output, cleanup and result-stream isolation.
  A failed editor after a submitted paste prefix cannot resubmit that prefix.
  The independent session peer observes requests; it does not execute SQL.
- `python3 -B tests/console_edit.py zig-out/bin/transit /usr/bin/vi` also passes
  with the host's Vim 9.1: `:q` submits nothing and `:wq` submits once even when
  the saved bytes are unchanged. The ordinary history gate needs no Vim install.
- `just check` passes, including 558 CLI diagnostic cases, the extended history
  proof, generated contracts, frontend checks and the documentation build.
- `just test::server` passes its complete lifecycle in 301.37 seconds. Its new
  real-service scenario loads a failed SQL history entry, saves a corrected
  SELECT in the editor and verifies complete result delivery from local SQL.

These checks cover the current Linux terminal and filesystem event profile.
They do not qualify every external editor or remote filesystem; editors that
detach require a wait option. Edited SQL creates a fresh request, not recovery
of an earlier admission token.

## Local Board hostname aliases — 2026-10-22

The [local server](../../../apps/transit-cli/docs/server.md) enables a fixed localhost
alias for Board. Its canonical URL remains the numeric loopback origin; each
request's Origin must match its own admitted Host and scheme. The standalone
option and its listener/reactive restrictions belong to
[Board configuration](../../../apps/transit-board/docs/configuration.md).

Executed on Linux with the pinned Nix development shell:

- `just check` passes, including the shared Zig tests, generated contracts,
  frontend checks and documentation production build.
- `just transit-board::test` passes the ingress units and real disk-backed
  inspection proof. The standalone default still rejects an unconfigured
  localhost Host. Units reject aliases for remote listeners, mismatched ports,
  remote origins and reactive configurations.
- `just test::server-board` passes with an omitted public origin and an isolated
  non-default port. Both real URLs serve the embedded UI/assets, health and
  authorized atlas. JSON workspace requests reach their disabled-route responses
  under either matching origin. Cross-origin local pairs, foreign/null origins,
  wrong schemes/ports, hostname suffixes and forwarded headers reject. Missing
  Origin still rejects workspace requests. The complete proof also passes
  revocation, headless toggles, artifact checks, process/storage replacement and
  exact recovery after lost provisioning replies.

Two earlier server-proof attempts failed after the new URL checks: one read
received native `HttpCapacity`, and a later run reached a stale text-log assertion.
The fixture now retries only that identified unavailable GET response within its
existing ten-second read budget and checks the current Board `AccessDenied`
failure event. Denial and other unavailable responses still fail immediately.
The complete rerun passes; the earlier attempts are not counted as passes.

This is HTTP and local lifecycle evidence. It does not qualify browser automation,
IPv6 listeners, remote aliases or aliases for the reactive gateway.

## Unified service logging

The [observability reference](../../handbook/reference/observability.md) owns text/JSON
formats, configuration and stdout separation; the
[Internals account](../../handbook/internals/storage-runtime.md#presenting-observations-consistently)
explains the queue, supervision and readiness boundaries.

Executed during the logging change on Linux with the pinned Zig development shell:

- `just test::telemetry`: both text and JSON complete 10,000 operations with
  drained, stalled and closed stderr and logging off, pinned to one CPU. All
  eight cases exit within the four-second test bound; observed wall times are
  0.12–0.42 seconds. These are single-run observations, not latency targets.
- `just test::server-logging`: four standalone executables pass 24 format/level
  failure cases. A real PTY defaults to text, a pipe retains readiness JSON,
  SQL `SHOW` reports environment overrides, a killed SQL process reports a failed
  error event and recovers, and logging off preserves the readiness receipt.
  Current child launch files carry the selected logging policy.
- `just test::observability`: real Board/client/node spans preserve parentage,
  native receipt semantics, revoked reads and exclusion of private markers.
- `zig build test-cli-lifecycle test-cli-diagnostics`: local process/unit tests
  and 555 real command failures retain error coordinates, privacy, recovery
  advice and uncontaminated stdout.

The first clean experience-lane run passed nine tasks and exposed a launcher
read-retry regression in its final Station task: the helper still matched Zig's
old error-text suffix. The launcher now requests structured terminal error events.
`tests/reference_launcher_state.py` checks exact-read retry, fixed JSON settings
and rejection of malformed, denied, unknown or nonterminal classifications.

`just test::server-logging` exercises real standalone failures, terminal output,
piped readiness, logging-off receipts, YAML/environment precedence, SQL `SHOW`,
supervised child environments and SQL service failure/recovery. It belongs to
the experience lane. The fixture uses separate disk-backed installations and
joins its children; it never starts or modifies the operator's installation.

## Explicit relational Board sessions

[Implementation revision, logs, outcomes and limits](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/relational-board-2026-10-12.json)
record the real Board service and browser against one native node and disk Ursula.
`just test::relational-callers` now includes the optional Board route schedule in
the ordinary growth lane. `just transit-board::relational-browser` adds the actual
browser; the regular Board browser task includes it as well.

The native schedule passes in **15.742 seconds**, including the neutral caller
baseline. Both one-resource aliases and two-resource joins agree with the typed
Zig plan and three-row oracle. It checks explicit configuration, origin rejection,
current metadata/source rights, repeatable pages, authorized active-query
inspection, close under source denial and rejection after Board replacement.
The generated validator accepts those real responses and rejects numeric JSON
substitution for a full-width integer string.

The browser schedule passes in **28.540 seconds** overall; its one Playwright
case takes **10.9 seconds**. Editing and Explain submit no query. A deliberately
lost accepted-open response and a browser reload recover the same active query
and ordinal without another Run. Exact page reads reach terminal coverage.
Current right-source denial clears the visible prefix and SQL draft; closing
still releases the query. The case reports no page errors or Axe violations.

Three browser-boundary units pass exact signed/unsigned values, reference/coverage
rejection and owned requests across pre-dispatch rate refusals. Strict TypeScript,
formatting/lint, focused query/Station ABI suites and diagnostic mappings pass.
The full `just check` also passes the repository units, contracts, projections,
CLI, frontends and production documentation build. The record preserves the first
UI check's wrong diagnostic prop and misplaced standalone type-check invocation.
The final package README navigation sentence follows that full check; committed
HEAD clean lanes still remain a separate final gate.

The fixture holds one output row and uses the existing 16 MiB executor/spill,
8 MiB result, 1,000-row and 100,000-work/request budgets. It makes no large-output
RSS, sustained-input or durable foreign-lifetime claim.

## Console timer command — 2026-10-04

The console timing toggle is `.timer on|off`, including startup scripts, local
dispatch, completion, help, correction messages and settings provenance. Timing
measurements and their machine fields retain their existing definitions.

After locked dependency installation, full pinned `just check` passes, including
**586 real CLI diagnostic cases**, the shared completion fixtures, terminal
color/history/signal checks, generated contracts and the documentation build.
The CLI cases exercise startup precedence, on/off toggles, invalid and extra
arguments, tab separation and timing after diagnostics in both result formats.
`just build::debug transit` also passes.

The Table console integration initially stopped at three stale diagnostic
assertions. The parameter fixture now expects `UnboundParameters` for omitted
bindings (`90a76f05`), matching the existing compilation unit test. The denied
resume and uncertain-cancellation fixtures check `query.saved_work_unresolved`,
the original cause and saved query identity instead of obsolete human summaries.
These corrections do not change runtime behavior or relax no-output/recovery checks.

The final pinned `just test::console table` run passes against disk storage and
native workers in **393.59 s**. It covers batch and PTY commands, timing footer
ordering, completion and settings, exact saved-query and cancellation recovery,
current read denial, interrupted output, and private-CA/hostname checks. An earlier
run was interrupted and is not counted as completed evidence.

Logs: `/var/tmp/transit-timer-check.log`, `/var/tmp/transit-timer-build.log` and
`/var/tmp/transit-timer-console-resumed.log`. Committed-HEAD clean qualification is
not rerun.

## Contextual console SQL highlighting — 2026-10-04

The basic correction at `f8d2f42c` gives identifiers the default terminal
foreground. The contextual implementation records roles in the production
parser and combines them with tolerant lexical tokens for incomplete input.
Drafts and submitted echoes share the classifier; diagnostic excerpts own roles
captured before masking and clipping. These are local presentation values,
without changes to parser acceptance, serialized contracts or dispatch.

Pinned lifecycle and unit checks cover all twelve contextual identifier words
in column, qualifier, source and alias positions; all five state predicates;
aggregate, derived-input, cast, parameter, mutation, declaration and inspection
forms; multiple statements; incomplete quotes, comments and malformed suffixes;
Unicode and the 4,096-byte bound. Renderer checks cover random offset access,
dot-command argument isolation, disabled color, clipped context and plain masked
bytes. This finite corpus does not establish every possible malformed input or
make reference-only grammar executable.

`just test::cli-diagnostics` passes **586 real CLI cases**. New PTY assertions
check every visible byte's color in editable drafts and committed scrollback,
including contextual names and literals. Table/JSON result modes, nonempty
`NO_COLOR`, `TERM=dumb`, diagnostic redaction and unchanged plain text are covered.
`just test::sql` passes the independent grammar/compiler proof: **174 SELECT
ASTs**, **142 plans/Arrow results**, 72 unified-source results, 24 mutation ASTs,
156 declaration ASTs and 37 parameter ASTs, alongside their rejection cases.
`just build::debug transit` rebuilds the installed console.

Full pinned `just check` passes after locked frontend dependency installation,
including diagnostic inventory/mapping/error/outcome/grammar gates, unit tests,
the CLI matrix, terminal history and signal checks, generated contracts,
frontend checks and the documentation build.

Logs: `/var/tmp/transit-highlighting-context-tests.log`,
`/var/tmp/transit-highlighting-pty.log`, `/var/tmp/transit-highlighting-sql.log`
`/var/tmp/transit-highlighting-build.log` and
`/var/tmp/transit-highlighting-check.log`. These are working-tree checks;
the committed-HEAD clean suite and full service integration inventory are not
rerun for this presentation change.

## Console scrollback and diagnostic highlighting — 2026-10-02

Submitted SQL and dot commands use the draft's token colors when committed to
terminal scrollback. The shared SQL diagnostic renderer exposes semantic parts;
the CLI supplies color while retaining the same redacted excerpt, coordinates,
caret and corrective text. Color is disabled for redirected stderr, nonempty
`NO_COLOR` and `TERM=dumb`, independently of table/JSON result mode.

After locked dependencies are installed, pinned `just test::cli-diagnostics` and
full `just check` pass with **450 real CLI cases**. PTY assertions distinguish the
submitted echo from transient editor redraws, including multiline comments,
literals and numbers. They check colored SQL and dot-command errors, unchanged
diagnostic text across color settings, literal/comment redaction, no diagnostic
stdout, and one final timing footer. Forced color does not decorate redirected
output. Existing history, Unicode, resize and scheduled terminal signal checks
also pass. `just build::debug transit` rebuilds the local executable.

Logs: `/tmp/transit-console-highlight-diagnostics.log`,
`/tmp/transit-console-highlight-check.log` and
`/tmp/transit-console-highlight-build.log`. These are working-tree checks; the
full service integration inventory and committed-HEAD clean suite are not rerun.

## Console timing follows command output — 2026-10-02

Timing measurements finish at their existing execution boundary and remain as one
owned report until command output completes. Interactive diagnostics consume the
report after their guidance; batch failures carry it to the final CLI diagnostic.
Successful commands and cancellation messages precede the same timing footer.

Pinned `just test::cli-diagnostics` and full `just check` pass, including 442 real
CLI cases. New cases cover declaration validation and SELECT compilation through
stdin, `-c` and a real PTY in table and JSON modes, with exactly one final timing
line and no timing carried into a later settings command. Running the new checks
against the earlier executable first reproduced timing before the CREATE TABLE
error. Logs: `/tmp/transit-console-timing-before.log`,
`/tmp/transit-console-timing-diagnostics.log` and
`/tmp/transit-console-timing-check.log`.

The first `just test::console table` attempt passed saved-query recovery and read
denial, then stopped because its built console executable disappeared from the
shared Zig cache. That incomplete run is recorded in
`/tmp/transit-console-timing-integration.log`.

The isolated-cache rerun passes:
`ZIG_LOCAL_CACHE_DIR=/tmp/transit-console-timing-cache just test::console table`
inside `nix develop`. It verifies timing after runtime failures, successful
results on a combined stdout/stderr stream, saved-query resume, cancellation
messages and failed cancellation diagnostics. Repeated Ctrl-C, partial-result
interruption, batch exit 130, terminal recovery and explicit-CA TLS also pass.
The console schedule completes in 290.58 seconds; the full Table fixture in
325.29 seconds. Log: `/tmp/transit-console-timing-integration-isolated.log`.
These are working-tree checks; committed-HEAD clean qualification is separate.

## Console error guidance — 2026-10-02

Console diagnostics direct users to statement help and source/schema inspection.
With locked frontend dependencies installed through `just transit-board::install`,
full `just check` passes in `nix develop`, including 434 real CLI diagnostic cases,
terminal history/signal checks, shared Zig units, contract checks, frontend checks,
5049 documentation links and the documentation build. The log is
`/tmp/transit-console-help-check.log`.

`just build::debug transit` also passes. An offline invocation of the built
console with `CREATE TABLE people (id INTEGER, name TEXT);` retains the parse
category, expected types and line 1/column 25 caret, and points to
`.help CREATE TABLE` without a documentation link. `.help SQL` and
`.help CREATE TABLE` both succeed offline and contain their syntax examples.
These are working-tree checks; committed-HEAD clean qualification is separate.

## Handbook grammar inventory and implementation plan

The documentation-first work for issue #31 starts from PR #27's pushed
`9051f0a4209b874ebb4c1ba69aecd50fa7c8225a`. The handbook checkpoint `37996e4f`
adds the public implemented/planned inventory and navigation, corrects stale
state-declaration descriptions, and reconciles system-time comments without
changing any accepted grammar rule or production execution. M38 now consumes
that inventory with staged ledger/semantic/historical work and explicit exits;
no runtime work package is marked complete by this documentation.

Executed in the pinned development shell with locked frontend dependencies:

- Full `just check` passes for the handbook checkpoint, including generated
  contracts, unit/CLI checks, frontend types/tests and production documentation.
  The documentation check reports 4642 local links across 484 files.
- `just test::sql` passes: 49 published SQL examples, 104 SELECT AST comparisons,
  16 syntax exclusions, 14 extensions, 86 actual plans/Arrow checks, 24 unified
  results across three bases/eight page widths, 31 mutation outcome/rejection
  cases, and 182 declaration cases. Proposed syntax uses explicitly labeled text
  blocks; these checks do not accept or qualify the proposed graph/branch forms.
- The initial `just transit-docs::browser` run has two passes and two failures:
  inherited assertions expect the SQL index's old label and still describe
  CREATE TABLE as grammar-only. `7316a9e5` corrects those expectations, retains
  the grammar-only connection check and exercises the new inventory through
  navigation/search with distinct Table-publication and KV/Document labels.
  The corrected root-hosting run passes all four browser tests in 15.6 s.
- `just transit-docs::check` passes after the browser changes; the subsequent
  repository link check, including the roadmap sequence, passes 4647 links
  across 484 files. These are working-tree documentation results, not new
  runtime qualification.

Committed-HEAD `just ci-clean --lane experience` at `37996e4f` **fails** in
`transit-board::query-test`: `tests/board_query.py` receives HTTP 503
`Unavailable` while observing an upload. Board check, documentation check, Node
binding check, observability and Board inspection pass first; the final local
Station launcher task does not run. The failed checkout and task timings remain
at `/var/tmp/transit-ci-e1al9pr1`; the log is
`/tmp/transit-grammar-ci-clean-inventory.log`. A focused rerun of the unchanged query
test in that checkout fails with the same response; its log is
`/tmp/transit-grammar-query-rerun.log`. The failure is unresolved. Neither that run
nor the focused documentation/browser passes establish a clean-lane or complete
clean-suite pass. No graph, foreign-capture, historical-query, branch, merge or
standards-conformance execution is claimed.

## Current Board browser qualification — 2026-10-01

The [browser investigation record](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/m37-board-browser-2026-10-01.json)
reproduces all five hosted browser failures at `31e3c97f`. Retained page context
shows a successfully rendered native v1 Relief atlas and current process/resource
evidence. The fixture instead expects the removed Departure board, inline process
state and old resource-entry presentation. Longer waits cannot satisfy those
obsolete assertions.

The corrected proof selects the current atlas by keyboard, preserves focus across
polling and opens real process/journey routes. It checks consumed/pending input,
the fixture's actual recorded output identity, closed effects, causal references
and accessibility. Resource checks retain exact keys and writer/revision evidence
without exposing application values. Mailbox payloads remain escaped; known denial
clears observations, while temporary unavailability retains the exact earlier
process revision with a stale label. All original assertion deadlines remain.

Full `just check` passes on the development source based on merged `2b078b18` in
213.290 seconds. All five corrected browser tests pass in 20.0 seconds, followed
by the real API outage/load proof. A separate run with an owned disk-backed
`TMPDIR` also passes all five tests and the full API fixture; source hashes and
log digests are retained. CI now uploads failed Playwright traces and page context.
These focused results do not complete the remaining browser/ordinary lanes.

The first clean experience run at `2b078b18` passes Board and documentation tasks,
then fails Node SDK checks on formatting in the newly merged logical-value guide.
The formatting-only correction passes `just bindings::node-check`. Separately,
the earlier local `164b808f` campaign ends after 34 passing tasks when query
delivery exceeds its original 180-second deadline; later growth and bindings tasks
are unrun. That hot-Ursula failure is not attributed to MinIO's free-space guard.

## Public inspection

`just test::inspection` checks scoped discovery, signed queries, fixed pages, cut
expiry, revocation, and disk recovery through the node and public client. Core
unit tests inject final-tail and trim races, test bounded sparse scans, and verify
that scoped outbox/history projections do not disclose hidden endpoints.

## Board qualification

### Compact standalone validator output — 2026-10-26

Hosted run `40293594898` completes all thirteen experience tasks, then its
embedded browser test rejects a query chunk of 913,584 bytes against the
existing 900,000-byte limit. The failed baseline is retained in the
[lifecycle evidence](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/catalog-prefix-2026-10-26/report.json).
All five standalone-validator generators now omit AJV error-message prose.
Their declared API returns boolean validity; client failure codes and Transit
diagnostic payloads remain separately owned. Public schemas, generated type
declarations, validation rules, asset groups and proof bounds are unchanged.

At `d41217807` plus that generator change, the pinned build reports query
831.65 kB, inspection 820.55 kB, application 736.91 kB, entry 416.91 kB and
bundler runtime 0.58 kB. These are rounded uncompressed build sizes, not a
transfer-latency measurement. Vite's separate 500 kB advisory remains enabled.
The [retained record](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/board-validator-output-2026-10-26/report.json)
includes source-patch attribution and the unmodified browser workload.

Six schema-equivalence tests compare the generated configuration against
ordinary AJV validation on positive/negative values, Unicode, unions, required
fields and reference scopes. `just transit-board::browser` passes both the
five-test inspection suite and the direct relational worksheet test in 291.02
seconds including builds. The former checks actual HTTP module responses and
the unchanged five-script/900,000-byte bounds. The latter completes 504 public
requests covering original-pin cleanup, node/Board replacement, cached and
terminal current denial, private origins and explicit cleanup. Real Zig
responses pass generated validation; malformed identities, values and lossy
integers reject. Full `just check` also passes with the catalog-prefix and
generated-validator changes, including regenerated contracts, diagnostic
mappings, Zig tests, frontend checks and the documentation build. The final
evidence links pass the documentation checker. Committed-HEAD clean-checkout
qualification remains a separate gate.

### Embedded asset splitting — 2026-10-04

Pinned `just build::debug` emits five JavaScript assets totaling **2,175,523
bytes**, with a largest chunk of **819,589 bytes**, compared with the previously
reported 7,232,360-byte single bundle. The entry is 406.17 kB, inspection 636.88
kB, query/reactive 819.58 kB, application 312.28 kB and bundler runtime 0.58 kB.
Repeated standalone validator fragments are shared during generation; the public
schemas and generated declarations remain unchanged. Shared chunks load on entry,
with module preloading disabled and route renderers kept together. The two chunks
above Vite's 500 kB advisory still produce warnings; the warning limit is unchanged.

Full `just check` passes, including validator drift, 77 Board unit tests and the
documentation build. An initial run stopped on generator formatting, which was
corrected. The final conservative nested-reference guard then passes three focused
schema-sharing comparisons and unchanged regeneration of all five validator
packages. Fixtures check positive/negative values, bounds, Unicode, unions,
boolean schemas, reference scopes, constant data and nested reference targets.

`just transit-board::browser` passes all five Chromium tests in 18.6 seconds;
its real embedded/API proof records 0.092 seconds maximum control latency. The
browser checks cold entry, navigation and direct nested-route reload, successful
JavaScript responses, at most five scripts and each below 900 kB.
`just transit-board::query-browser` passes its API/recovery proof and the 47.9-second
browser run, including exact retry and clearing on current revocation. No host
connection/request bound is raised. Logs are
`/var/tmp/transit-board-splitting-{build,browser,query-browser,check-final}.log`.
These runs do not establish a clean committed-HEAD CI pass.

### Inspection and browser proofs

`just transit-board::check` checks exact Zig/OpenAPI regeneration, generated TypeScript and
standalone validator drift, strict TypeScript, Vite+ formatting/lint and unit tests.
`just transit-board::test` runs Zig ingress tests and `tests/board.py` against disk-backed
Ursula. A copy of the Board binary runs alone in an empty directory with an empty
executable search path, serving embedded assets and the exact OpenAPI artifact.
An independent Python consumer follows process/output/effect evidence; generated
JS validators consume actual Zig responses and reject malformed identities/data.

The API proof checks current grants, scoped lists and edges, unsafe deployment
principals, missing API/asset routes, Host/Origin/forwarded-header rejection,
direct reads without viewer credentials, no cookies or session/mutation/proxy routes,
closed-unknown effects, blocked inputs, history cut/trim gaps and storage restart.
Core tests deterministically inject revocation/tail and physical-trim races.
Board projection tests reject mixed-resource pages before they could overflow
the 32-edge budget. Revoked Transit grants reject reads even with old Board
cookies or arbitrary bearer headers; these headers stay out of diagnostics.
The initial local load run (Linux x86_64, pinned tools) completed five control
writes during 25 refresh requests; the maximum observed latency was 43 ms.
Requests exceeding Board's 10 upstream reads/second admission rate were rejected.
A slow incomplete Board request also left the authority available. This is a
bounded reference measurement, not a throughput/fairness or latency guarantee.

`just transit-board::browser-install` and `just transit-board::browser` run pinned Chromium against
that same real binary/API. Checks cover direct access, typed runtime validation, nested
routes/lazy assets, arrivals/departures and uncertainty, keyboard focus through
polling, escaped opaque payloads and authorized state-resource views, denial clearing and connection retry,
and absence of Board cookies or browser storage. Axe checks the journey against WCAG A/AA;
this does not replace a full assistive-technology audit. Local screenshots/traces
remain ignored under `.cache/`. Remote TLS termination and identity federation
are outside this private/loopback profile.

The Kubernetes/Substrate run on 2026-09-23 passed using the pinned images/tools.
Board observed PID 1 at generation 2, then the same PID at generation 4 with a
new worker incarnation. After disk Ursula and node replacement it still exposed
state `1153`; it also exposed permanently expired PID 48. Retained history began
at position 52 after checkpoint/physical trim; inspection reported
`prefix_reclaimed`, and later PID 1 termination remained visible. This preserved
the existing M1 controller-crash, worker-recovery, expiry and gVisor isolation
proof. Local evidence is in ignored `.cache/reference/proof-d585cab0/evidence.json`;
its enclosing directory contains private disposable keys and must not be published.

Board ran as a non-root, read-only-filesystem pod without a service-account token,
using only a dedicated inspect grant. A second unprivileged container in that
pod's network namespace first reached Transit, then received transport denials
for raw Ursula service/pod/admin endpoints and actual Substrate/Kubernetes API
addresses. The default Kind CNI does not enforce NetworkPolicy: the owned proof
uses an init-container firewall, permitting Transit, DNS and loopback Board
port-forwarding. Production clusters need equivalent enforced egress policy;
the fixture is not a portable NetworkPolicy conformance claim. The cluster and
registry were removed through the ownership-checking teardown command.

Qualification caught and corrected three assumptions: HTTP header views cannot
be accessed after Zig's body reader changes state; Kubernetes port-forwarding
needs a loopback exception inside the confined pod; and Substrate's headless API
service must resolve to a ready EndpointSlice address for a valid denial probe.
The probe rejects DNS errors/timeouts as evidence of egress denial, so an invalid
target cannot produce a passing isolation result.

## Service instrumentation qualification

`just test::telemetry` tests the real bounded stderr writer on one CPU (Linux):
10,000 completions with logging disabled, drained, stalled and closed pipes.
Every completion reaches local metrics despite log drops; stdout remains JSON.
The initial debug build measured 0.12–0.42 seconds total per scenario, including
100 ms of deliberate wait and up to 200 ms flushing; emission was 9–74 ms.
These are measured proof results, not throughput targets or arbitrary I/O guarantees.

`just transit-board::test` also asserts fixed routes, request/timeout outcomes, ignored
public trace headers, quiet successful probes and credential/query redaction in
real service logs. See [telemetry](../../../packages/zig/telemetry/README.md) for limits.

`just test::observability` follows a real Board request through the public client
and node, checking distinct correlated spans, existing receipt retries, revoked
reads, duplicate/untrusted trace headers and absence of credentials/state.
No raw storage dependency is introduced into Board and no durable schema changes.

Storage/recovery spans are checked as children of the actual authority request.
The existing disk, service, maintenance and caller proofs run with instrumentation
active. Maintenance deadline checks inspect the structured error field. The
bootstrap proof separates stdout and stderr to verify the machine interface,
while the provider reader continues to identify bootstrap records in combined logs.
The stalled-writer proof shrinks its Linux pipe to 4 KiB and asserts the writer
is actually blocked before shutdown; it cannot pass merely by fitting all logs
into the OS buffer.

The observability proof also runs the real node on one CPU with unread stderr:
after filling its 4 KiB pipe, an incomplete HTTP request still hits the 800 ms
deadline, and a signed input plus exact retry still returns one durable receipt.
This qualifies control progress under diagnostic pressure, not just logger exit.
Replay and retries are observed as recovery or receipts; no metric claims they
are fresh commits. No protocol, signature, or durable-history schema changed.
The caller proxy proof drops a response after a real commit, then injects a
malformed 503. Both attempts remain `uncertain`; only the exact successful retry
reports `receipt`. Each attempt has a distinct span linked to the same proposal.
A focused invariant test preserves a known receipt when the response write fails
and checks that a new service instance resets its local counters.

`just launchers::local::test` and `just launchers::compose::test` passed with JSON
request records and saved per-service settings across restart. The native proof
checks visible foreground Board logs, manager-log rotation through three cycles,
two bounded backups and configured child-log rotation. Compose checks each
service's environment and Docker log budget. Native copy/truncate can lose
diagnostics and overshoot between checks; it is not a filesystem quota.

The Kubernetes/Substrate observability run passed the existing controller-crash,
worker replacement, disk Ursula/authority recovery, expiry and isolation proof.
It also checked JSON events from Board, Transit, maintenance and the controller,
and the effective kubelet rotation settings (5 MiB, three files). Evidence is
in ignored `.cache/reference/proof-7f71fb4c/evidence.json`; its enclosing directory
contains private test keys. Provider-owned log/snapshot stores and host proof
files are outside the CRI log budget.

Qualification exposed a packaging assumption: a Zig artifact reused from a
private launcher cache can have mode `0700`. Reference image assembly now sets
published executable modes explicitly to `0755`, so the non-root container user
can execute them. The controller-crash fixture now waits for the structured
`created` progress observation; continuous controller stdout is no longer used
as a diagnostic interface. `--once` retains its single machine-readable result.

## Console command history

`just test::console-history` passes against the real executable in a controlling
Linux PTY with an isolated home directory. It checks SQL and dot-command history
across restarts, incremental Ctrl-R search and older matches, explicit acceptance
before execution, Up/Down draft restoration, Escape/Ctrl-G/Ctrl-C, Unicode,
multiline search/paste and narrow terminal resize. An idle listener asserts that
editing, recall and the deliberately invalid commands send no native requests.

The file checks cover `0600` permissions, more than eight retained commands,
concurrent console appends and recall, brief lock contention and bounded busy-lock
fallback, malformed/oversized/control-bearing/torn records, and unavailable homes,
directories and symlinks. Batch input leaves the history file untouched. The
fixture uses bounded records; it does not establish search latency for arbitrarily
large files or host power-loss durability. The test is included in `just check`.
Logs: `/tmp/transit-history-final-focused.log` and
`/tmp/transit-history-focused.log` (ReleaseSafe). Full `just check` also passes,
including 422 CLI diagnostic cases, generated contracts, frontend checks and the
production documentation build (`/tmp/transit-history-final-check.log`).

The first Table integration attempt passed terminal completion, denial/history
clearing and recovery checks, then stopped during the final idle-Ctrl-C scenario
with exit 130. Its prompt matcher could accept the `.show` transcript or the
previous query's queued prompt. The fixture now requires an empty prompt after
the `.show` echo before sending the idle interrupt. That failed attempt is not
counted as a passing console proof; its log is `/tmp/transit-history-console.log`.

The corrected pre-rebase `just test::console table` run passes in **253.60 s**,
including **219.99 s** of console checks. It retains the disk-backed 41-row,
six-segment query/recovery fixture, current denial and editor clearing, exact
uncertain upload/cancellation retry, repeated interrupts, discarded pasted tails,
result-prefix/completion races, prompt reuse and batch exit 130. Explicit private
CA reads pass, while system-trust and hostname mismatches reject. Log:
`/tmp/transit-history-final-console.log`. These results do not claim host power-loss
durability or additional query source/placement coverage.

After rebasing onto `e82c8430`, full `just check` passes again, including the real
history PTY fixture, all 422 CLI diagnostics, generated contracts, frontend tests
and the production handbook build (`/tmp/transit-history-rebased-check.log`).
No clean-checkout CI or additional placement proof was run for this change.

## M24 console qualification

`just test::console table` passes the actual versioned command against forty-one
rows on disk Ursula, bounded cold storage and separate native query workers.
The combined recovery/console proof took **186.62 seconds** excluding compilation;
the added console checks took 105.30 seconds. The Linux controlling-PTY fixture
measured completion at 970.18 ms cold / 290.37 ms warm and 15,208,448 bytes RSS
high-water (64 MiB fixture ceiling). These single-run costs include current
authorization; they do not establish an interactive latency target.

Coverage includes offline help/version, strict options/configuration and relative
credential paths, multiline/comment-aware SQL, rejection before mutation, one
private locked recovery record, a lost reply followed by SIGKILL and exact signed
retry, verified bounded pages, machine/human formats and current denial. The real
PTY covers whole-token replacement, Tab/Enter acceptance, undo, UTF-8 editing with
safe visible escapes, bracketed paste, queued-input invalidation, metadata expiry,
resize, history clearing and interrupt restoration. A stalled stdout exits through
a joined two-second write deadline without submitting cancellation. Native HTTPS
schema reads pass with an explicit private CA; untrusted roots and a different
hostname reject. Existing `query` keeps its independent contract.

The first terminal attempt delayed every metadata read in the test; the fixture
now delays one read. A later test stopped consuming PTY display bytes while
waiting for JSON output; it now drains both streams, and the editor coalesces
queued redraws. The signal path buffers one command before presentation and
checks interruption before emitting it. The space-exhausted run above is not
counted as passed.

The same actual-command, PTY and explicit TLS proof also passes for KV and
Document with their distinct source adapters:

| Source   | Combined native proof | Added console checks | Cold / warm completion | Terminal RSS high-water |
| -------- | --------------------- | -------------------- | ---------------------- | ----------------------- |
| KV       | 195.32 s              | 123.43 s             | 792.42 / 276.61 ms     | 16,261,120 bytes        |
| Document | 738.32 s              | 141.55 s             | 356.81 / 57.08 ms      | 16,265,216 bytes        |

Document provisioning accounts for 493.70 seconds of its total; the fixture
retains twelve rows across two segments, 64 resident authority pages and
133,852,226 cold bytes. KV retains forty-one rows across six segments, eight
resident pages and 26,816,531 cold bytes. Both cap Ursula hot storage at 8 MiB.
These focused costs do not change M10's hosted CI budget. The separate server
lifecycle and physical-capacity evidence follows below.

## M27 local Board qualification

`just test::server-board` exercises the actual embedded executable against native
MinIO and disk Ursula. Its version-3 fixture covers both command aliases, fresh
default UI, headless initialization followed by first enablement, disabled port
preflight, exact Host/Origin checks, real JavaScript assets and machine readiness.
The generic separately compiled work-item application declares resource inspection
under declaration v2; another application's undeclared resource remains hidden.
Replacement retains IDs, resource revocation survives toggles/restart, and principal
revocation rejects UI startup without restoring grants.

The owned-failure schedules kill Board, node, Ursula and management, verify child
cleanup and retained identities/receipts, and reject missing/changed/incompatible
artifacts and conflicts with every configured listener. Explicit fault peers lose
accepted Board principal-creation and application inspection-grant responses;
recovery must replay identical signed bytes and return the same native receipt.
These peers are test infrastructure, not runtime dependencies.

`just test::server-board-package` builds the Nix local package and consumes only
its exported executable manifest. It starts from an unrelated temporary working
directory with unavailable PATH, fetches the embedded UI and authorized atlas,
forwards `--no-ui`, then resumes the same retained Board identity. The package
closure excludes Node, Python, Vite+ and pnpm. Existing M24/M25 recovery tasks now
request headless operation explicitly. `contract::check` independently verifies
the v2 inspection declaration digest; a unit fixture preserves v1 signed bytes.

Focused qualification passed after rebasing the implementation onto the gateway
host-alias changes. The Board lifecycle/revocation schedule completed in 33.37
seconds; both lost-reply schedules recovered the exact accepted request/receipt.
The Nix packaged consumer passed with a 14-path runtime closure excluding Node,
Python, Vite+ and pnpm. `just check`, `just doctor`, contract drift checks and the
headless server/application regressions passed. The rebased headless core
lifecycle took 37.26 seconds; application replacement/recovery took 122.70 seconds,
and application fault recovery took 28.40 seconds.

`just ci-clean` is running against implementation commit `e077519`. Core, growth,
experience and launcher lanes have passed; the binding lane remains in progress.
This is not yet a completed ordinary clean qualification, and it does not include
the separately selected browser or physical-capacity lanes.

Initial focused attempts exposed a port-conflict fixture needing socket reuse
after shutdown and a reply-loss assertion needing the public tagged-union shape.
One concurrent-build M24 attempt observed `AuthorityTimeout` and failed the console
status assertion. Those attempts are not counted as passes; subsequent focused
and rebased regression runs passed without weakening the assertions.

The scope is trusted local Linux x86_64, loopback shared viewers, explicit resource
grants and unlimited retained history. It does not qualify per-user login,
browser query/operator credentials, history import, an in-place older-runtime
upgrade, power loss or broader platforms. New tasks remain separately selectable;
no expanded hosted CI budget is claimed.

## M26 documentation handbook

`just transit-docs::check` checks the real Docusaurus package: Vite+ formatting
and lint, strict TypeScript, six source/reference tests and production static
rendering with broken links/anchors treated as errors. The initial site included
all 31 foundational Markdown files. The catalog includes every public guide/reference and Internals page, with
selected owning component/wire guides. Its ownership test checks full coverage
and unique routes/sources. Internals has a separate sidebar and participates in
search. A separate snapshot check rejects milestone IDs, milestone wording and
roadmap references in usage/reference page labels, routes and raw content,
including link targets and component guides. The contributor index may name
separate source sections; scientific accounts can cite scoped proof records.
Roadmap, Design and History retain separate repository indexes and stay outside
the primary catalog/search. It also checks every
Markdown wire contract, generated API reference content and exact downloadable
description source.
Those references share current concepts, guarantees and failure semantics with
users, developers and agents. API pages render operations, nested
fields, union alternatives and bounds from the checked Board/serving OpenAPI and
reactive AsyncAPI; downloaded descriptions retain their original bytes.

`just transit-docs::browser` builds and serves the actual output with Chromium.
Four checks cover desktop navigation/search/API anchors, exact downloads,
mobile menu and overflow, light/dark accessibility, and every published Mermaid
diagram, plus workload-to-performance/session navigation, code languages and
search discovery. Internals coverage includes desktop/mobile navbar entry, its
scientific standard and template, labeled search results, linked technical
accounts/diagrams and source links to the separate Roadmap/Design indexes. `TRANSIT_DOCS_BASE_URL=/handbook/ just transit-docs::browser` runs the same
proof below a path prefix. Screenshots and failures stay in
`.cache/verification/docs-browser`; the server belongs to that proof and starts
no Transit processes. Accessibility checks exercise selected pages; they are not
a manual audit of every document or an all-browser compatibility claim.

The local quickstart and first-application commands were also executed from the
published Markdown blocks: the pinned Nix bundle initialized a fresh version-2
installation, a console query returned uint64 count zero after verified completion,
and the independently compiled work-item worker installed and committed one row.
After graceful server stop and ordinary restart without `--initialize`, the same
query was resumed and the application row remained visible. The temporary server
was stopped; no existing launcher installation was modified. These are onboarding
checks, not new runtime/failure qualification or public release evidence.

`just check`, `just doctor` and `just test::reactive-descriptions` pass locally.
The latter validates the existing generated descriptions against pinned official
schemas and checks reflected-type drift. The experience lane owns the site check
on ordinary runs. Documentation-only PRs run that same check in the small `docs`
Nix shell; the aggregate CI gate rejects a skipped/failed selected job. Hosted
feedback/cost for this addition remains unmeasured. No site was published and
this work does not constitute a full ordinary `ci-clean` run.

A documentation-only clean clone of committed `20ccdd3` passed the exact CI
filtered install (`vp install --frozen-lockfile --filter transit --filter @transit/docs`),
`just transit-docs::check` and all three production browser checks at `/`.
The separate `/handbook/` build and browser checks also pass, including regular
file navigation and byte equality for all three specification downloads. The
clean clone had no inherited `node_modules`, generated documentation or site
output; it reused the locked package/tool downloads and installed Chromium.
This is focused site evidence, not the full ordinary `just ci-clean` suite.

The public/internal documentation reorganization passes `just check` after the
locked workspace install, plus all three production browser checks at `/` and
`/handbook/`. The catalog now has 56 pages, including all 36 public guides and
references; internal plans, reviews and historical design are absent from site
navigation/search. The updated ownership test requires every public page and
rejects its links to internal records. Agent instructions, component entry links
and invariant owners now use the public explanations. The complete glossary and
developer workflow have public owners, with internal section pointers preserving
older references. Source validation passes 3,885 local links across 415 Markdown
files; a separate path check resolves all 114 local documentation image references.
This pass changes documentation/navigation and source pointers, not runtime
semantics. It does not rerun runtime deployment proofs, the full ordinary clean
CI suite or hosted timing. The previously executed onboarding proof remains the
basis for the unchanged runnable commands.

The capability-snapshot pass removes delivery-plan references from all 56
published pages and all 35 Markdown wire documents, including source links and
SQL grammar guidance. It replaces stale implementation-status prose with the
existing qualified capability profiles. `just check` passes with the five
source/reference tests; all three production browser checks pass at `/`, and
source validation passes 3,904 local links across 415 Markdown files. The guard
also checks generated reference text and original specification downloads.
This documentation-only pass does not rerun runtime deployment proofs or the
full ordinary clean CI suite.

The interface-language pass replaces maturity labels and broad readiness caveats
with direct operations, platform requirements, compatibility rules and concrete
limits across the handbook and wire contracts. `just check` passes after the
locked workspace install. The final site-only format/type/test/build run and all
three browser checks pass after updating the homepage and shared footer. Source
validation passes 3,900 links across 415 Markdown files. A separate built-output
audit checks every HTML page and all 56 search entries for the removed maturity
wording. No runtime integration or deployment proof was rerun for this prose change.

After rebasing the handbook onto `7f08401`, the quickstart and application guides
use version-3 server configuration with supervised Board, matching the local
bundle's executable manifest. The CLI reference includes `--no-ui`, and public
guides describe Board's separate identity and explicit application inspection
grants. `just check` passes after the locked workspace install; the final focused
site check and all three production browser checks at `/` also pass. Source
validation passes 3,915 links across 416 Markdown files. These checks cover
documentation integration; the revised version-3 onboarding commands, runtime
deployment proofs and full ordinary clean CI suite were not rerun in this pass.

### Workload architecture and examples — 2026-09-29

The public workload/performance references and example gallery pass `just check`
after the locked workspace install, including 174 CLI cases and six documentation
content tests. The added excerpt check matches the Python, TypeScript, Rust and
Zig snippets to contiguous lines of their executable owners, allowing common
indentation only. The final focused site format/lint/type/content checks pass.
All four production browser checks pass at `/` and `/handbook/`, including
language rendering, gallery navigation into measured costs and planned session
semantics, and search discovery. Source validation resolves 4,052 local links
across 424 Markdown files before this ledger entry.

The featured source also passes Python's strict mypy configuration (21 files),
the TypeScript example package's `tsc --noEmit`, Rust's `cargo check --locked
--offline` with the built native libraries, and `zig build examples`, under the
pinned Nix tools. The snippets reuse existing applications: their full SDK,
Document, connector and query integration schedules are linked rather than
rerun for this documentation change. No performance experiment is rerun or new
runtime speedup established. Fresh interactive sessions/cancel-on-exit and bulk
storage improvements remain explicitly planned; no new wire/runtime behavior,
site deployment or full clean CI run is claimed.

### Interface navigation and SQL statement reference — 2026-09-29

The interface navigation and fourteen new SQL reference pages pass `just check`
after the locked frontend install. Existing routes stay stable. The four
production browser checks pass at both `/` and `/handbook/`, covering top-level
interface categories, SELECT/DDL/application navigation, statement search,
mobile navigation, generated descriptions/downloads, diagrams and accessibility.
The workload navigation assertion now follows the implemented interactive-session
reference instead of expecting its earlier unimplemented wording.

`just test::sql-grammar` parses 37 published examples and requires coverage of
every statement rule in `TransitExtensions.g4` plus its historical-read fragment.
The existing 103 PostgreSQL/ANTLR AST cases, 17 syntax exclusions and 13 extension
cases also pass. Administrative examples establish syntax only, not executable
DDL or effects. `just test::application-grammar` passes the complete published
application program through the independent parser and real offline compiler,
then checks its canonical model round-trip alongside the existing rejection
and schema cases. These changes add no runtime SQL capability or new recovery
guarantee; those remain under their owning service proofs.

### Public Internals and separated engineering records

The documentation reorganization based on `b79a8a8` publishes 12 Internals pages:
nine consolidated technical accounts, an overview, the scientific standard and a
writing template. The complete site has 86 pages. Delivery plans live in
`docs/roadmap/`, UI/UX reviews in `docs/design/`, earlier technical records in
`docs/history/` and reserved decision guidance in `docs/decisions/`. These source
records remain linked without becoming individual catalog/search entries.

Executed locally on Linux x86_64 with the pinned Nix development shell and frozen
workspace installation:

- `just check` passed after consolidation: core/contract checks, Zig units,
  177 CLI diagnostic cases, frontend checks and the documentation production build.
- `just transit-docs::check` passed for the final structure as part of `just check`:
  formatting/lint, strict types, six content tests and broken-link/anchor checking.
- `nix develop --command bash -c 'cd docs/handbook && vp exec playwright test'`
  passed all four checks against the production root build in 14.4 seconds.
  Coverage includes Internals desktop/mobile navigation, labeled search results,
  standard/template and technical-account links, separate Roadmap/Design source
  links, every published Mermaid diagram and the existing interface checks.
- `python3 -B tests/docs.py` resolved 4,359 local links across 455 Markdown files.
  A source-path audit found retained destinations for all 249 original engineering
  files. All 114 review images resolve and retain their original bytes.
- `TRANSIT_DOCS_BASE_URL=/handbook/ just transit-docs::browser` rebuilt the
  consolidated site and passed the same four browser checks in 13.6 seconds.

The scientific accounts cite existing runtime evidence and add no runtime
qualification. The checks above establish documentation structure and selected
rendering/interaction behavior, not scientific correctness of every claim.
No deployment proof, hosted-cost measurement, live publication or `just ci-clean`
run is claimed for this uncommitted worktree.

## CLI diagnostic qualification

`just test::cli-diagnostics` runs the actual `transit` executable against invalid
invocations and owned temporary files, without a provider. The same check runs
within `just check` as a separately named core check. It verifies concise error
transcripts, command-specific and application-operation help, required/duplicate/
inapplicable options, application subcommands, query-shell arity, explicit console
environment precedence, configuration JSON parser coordinates and semantic fields,
missing executables/credentials, occupied listener coordinates, privacy, escaped
and bounded paths, exit codes, and stdout/stderr separation. It also checks that
invalid input creates no installation. This is CLI failure-presentation evidence;
server lifecycle and durable console recovery retain their separate proofs above.

The earlier labeled-diagnostic qualification at `720ced6` passed **95 real
command cases** with the pinned Zig 0.17 compiler, `just check` and the server
lifecycle proof in **28.60 seconds** excluding compilation. That historical run
checked separate cause and outer-exhaustion identifiers.

The concise-output implementation passes **125 real command cases**, including
exact short option errors, useful file/field/listener coordinates, escaped paths,
untranslated executable failures, and offline application-operation help. Help
still rejects duplicate, unknown and incomplete supplied options before effects.
`just check` passes, including diagnostic rendering checks for unknown cause and
outer failure, exact retry guidance, interruption without cancellation, and
restart exhaustion after child exit or listener conflict. The handbook production
build passes. `just test::server` passes in **29.13 seconds** excluding compilation,
including independent console output, manager/worker recovery and a final
exhaustion message that identifies the underlying child failure and role.

`just test::console table` also passes with the concise formatter: **177.62 seconds**
for the combined proof, including **99.20 seconds** of console checks, excluding
compilation. It covers real PTY interaction, private-CA TLS and trust/hostname
refusal, recovery-lock exclusion, killed-session exact retry, current denial,
interrupted waits and bounded machine output. This run qualifies the shared
presentation change on Table; it does not add a new source or transport profile.

`just test::server-faults` passes with the same formatter: the core lifecycle took
**30.20 seconds** and the additional bootstrap/gateway/rollback schedules took
**17.50 seconds**, excluding compilation. The checks retain native denial and
machine-status distinctions, bounded control under stalled data, exact recovery
of persisted bootstrap intent, and refusal of configuration/artifact drift and
provider history below the recorded authority observation.

`just test::server-board` passes its preflight, incompatible-Board, lifecycle and
interrupted-provisioning schedules. The lifecycle portion took **32.63 seconds**;
it covers defaults/toggles, embedded assets, application replacement, revoked
inspection access and owned failures. Both inspection-principal and application
lost-reply/manager-death schedules recover the exact saved request and receipt.
No committed-HEAD `ci-clean` run is claimed for this working-tree qualification.

## Unified CLI and conventional configuration

The unified console removes slash aliases and manual namespace/upload/result
controls from its primary interface. Real command fixtures exercise `-c`, `-f`,
streamed stdin and final statements without semicolons, first-error stopping,
dot-only commands, lossless pages and table rendering. A lost reply persists the
original signed request before recovery; `.resume` retries that exact request
and prints the same query's result. Cancellation settles the original pending
request and sends cancellation without uploading the remaining bundle. A new
query cannot replace unresolved intent. The PTY and TLS fixtures retain editing,
completion, current denial, private-CA trust, signal handling and output bounds.

The working-tree checks recorded so far are:

| Check                                                                                             | Executed outcome                                                                                                                                                                                                                                                                                                 |
| ------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `just test::cli-diagnostics`                                                                      | 160 real command cases passed: partial defaults, project/home selection, explicit file selection and missing-file refusal, malformed YAML/JSON, nesting bounds, typed environment precedence, rc merge/relative paths, flag precedence, adjacent executable lookup before PATH and explicit executable overrides |
| `just test::console table`                                                                        | Passed in 301.26 s including 222.10 s of console checks; PTY cold/warm completion 1080.16/344.63 ms; 16,756,736-byte terminal RSS high-water                                                                                                                                                                     |
| `just test::console kv`                                                                           | Passed in 415.14 s including 342.07 s of console checks; PTY cold/warm completion 600.78/590.67 ms; 17,444,864-byte terminal RSS high-water                                                                                                                                                                      |
| `just test::console document`                                                                     | Passed in 827.56 s including 253.45 s of console checks; PTY cold/warm completion 322.35/69.79 ms; 17,195,008-byte terminal RSS high-water                                                                                                                                                                       |
| `just test::public-query`                                                                         | Compatibility Table v1 dot commands, exact retry, cancellation, fenced recovery and current read denial passed                                                                                                                                                                                                   |
| `zig build test-unified-query -Doptimize=ReleaseSafe -Dunified-source=table -Dunified-shell=true` | Compatibility unified shell and native recovery passed in 148.18 s                                                                                                                                                                                                                                               |
| `just test::server-faults`                                                                        | Core lifecycle 31.05 s; bootstrap/gateway/rollback schedules 18.16 s; independent automatic console query, exact provisioning recovery and identity/rollback refusal passed                                                                                                                                      |
| `just test::server-capacity`                                                                      | Accepted automatic query, real ext4 ENOSPC, finite control/shutdown and recovery of the original query passed in 19.62 s                                                                                                                                                                                         |
| `just check`                                                                                      | Passed core/contracts, 160 CLI cases, frontend checks/tests and the production documentation build                                                                                                                                                                                                               |
| `just doctor`                                                                                     | Passed; the existing absent `~/.cargo/bin` PATH entry was reported by kubectl's plugin listing                                                                                                                                                                                                                   |

The first offline package build exposed a stale frontend dependency-store hash
that omitted dependencies already present in the workspace lockfile. Refreshing
that fixed-output hash allowed the offline Board asset build to pass without
changing package versions or the lockfile. The initial packaged defaults proof
passed first creation, bare restart, Board and automatic SQL with an unavailable
PATH. A subsequent run qualifies adjacent lookup with a copied CLI, neighboring
provider links and no executable manifest.

Earlier in-progress console runs exposed stale diagnostic expectations and an
undersized output-pressure fixture after help became shorter. KV and Document runs also
reached the initial one-minute wait budget. The completion budget is now five
minutes, accommodating the real finite source workers. Completed result streaming
now uses finite page/per-request/output bounds separately from the budget for
waiting on completion. The PTY result wait now follows the longer finite query wait rather than the
old receipt-response deadline. Those failed runs are not counted as passed evidence.
The final package run passes with a copied CLI, adjacent executables, no manifest
and unavailable PATH, including initialization/restart, Board, automatic SQL and
retained identity. The extended defaults proof also restarts using equivalent
partial YAML and whole-object/nested environment overrides, preserving the same
normalized configuration and provisioning identities. The default console now derives its endpoint from server topology and its scoped
identity from retained installation state, without a generated connection file.
The diagnostics cover this path, YAML connections, mode-only rc files, changed
gateway defaults and environment precedence, and incomplete-installation refusal.
The lifecycle and physical-capacity proofs above were repeated after removing the
generated console file. Configuration uses YAML while rc files remain dot-command
scripts. No committed-HEAD `ci-clean` or push is claimed by these checks.

The packaged follow-up passes bare-console automatic SQL without either
`console.json` or `console.yaml`, along with adjacent executable discovery,
Board toggles and retained identity. Its ports are now reserved independently
and supplied through the environment, avoiding interference with a developer's
running default server. Equivalent YAML and nested environment settings preserve
the same normalized configuration. The earlier fixed-port run collided with an
already-running server and is not counted as a pass.

Submitted input now remains in terminal scrollback before results. A shared
controlling PTY running `SELECT * FROM items;` against the actual local server
checks the echoed statement, bordered empty result and zero-row count. The
separate-output PTY checks multiline transcripts and the continuation prompt
without contaminating JSON stdout.

The final `just test::server` run passes in **49.35 s**, including the shared
terminal transcript check. `just test::server-applications` passes in **89.067 s**
with YAML management, declaration and replacement input, equivalent YAML/JSON
caller exports, retained identities and migration recovery. Its manager RSS
high-water is 28,164,096 bytes and its largest checkpoint is 2867 bytes. YAML
initialization frames use the native custom codec through the same token decoder
as JSON. The earlier value-decoder failure and the run interrupted by rebuilding
a pinned executable are not counted as passes; the fixture now copies its CLI
before startup so concurrent builds cannot change retained artifact identity.
The final diagnostics report 160 passing cases, and `just check` passes.

### Console settings presentation

The `.show` presentation follow-up passes `just check` and
`zig build test-cli-lifecycle` with the pinned Zig 0.17 compiler. The renderer
checks exact name/colon alignment, automatic selection, boolean `on`/`off`, enum
values and escaped controls. `just test::cli-diagnostics` passes **163 real
command cases**, including settings in both query result modes, home/project and
explicit rc origins, environment and flag precedence, interactive-command origins
in batch input, automatic topology defaults and escaped connection filenames.

`just test::console table` passes in **328.22 s** excluding compilation, including
**241.03 s** of console checks over 41 rows on disk Ursula. Settings inspection
preserves the exact uncertain recovery record and sends no native mutation or
retry. A following SQL statement still emits verified JSON. The controlling PTY
checks `.show` in both modes, `.mode` and `.connect` origins, unchanged saved work,
and the existing editing, denial, signal and TLS schedules. Terminal RSS high-water
is **17,854,464 bytes** under the fixture's 64 MiB ceiling.

`just test::server` passes its core lifecycle in **48.16 s** excluding compilation,
including automatic `(automatic)` settings in shared terminal scrollback before
an independent SQL result. These runs qualify settings presentation; they do not
add a timing setting or establish query latency targets. Clean-checkout CI is
reported separately against the committed revision.

The rebase of native Arrow rendering and timing onto the aligned settings change
passes `just check` with **177 CLI cases** and `zig build test-cli-lifecycle`.
`.show` retains aligned text in both result modes and adds `timing` as `on`/`off`
plus its origin. The merged batch check verifies settings text followed by a
complete JSON query result, with timing confined to stderr; PTY checks preserve
timing and its origin across `.connect`. `just test::console table` passes in
**295.35 s**, including **215.79 s** of console checks, 41 rows/six segments,
saved-intent recovery, current denial, cancellation, TLS and terminal interruption.
Terminal RSS high-water is **13,688,832 bytes**. These are functional integration
results, not a new query performance comparison.

### Native table rendering and query timing

The console renders verified native Arrow batches directly, avoiding the previous
Arrow-to-hex-to-Arrow conversion before presentation. Table output has box borders,
column names/types, numeric alignment and a final row count. JSON retains its
lossless page envelope. `.timing` is off by default, can be set in rc scripts or
interactively, survives connection changes, and emits attempt/phase wall time
only to stderr.

`just check` passes with 163 CLI cases. The additional cases cover merged timing
preferences, interactive overrides and invalid rc values. Native renderer units
pass for all six scalar types, 64-bit extrema, escaping and all five cell states,
including conflict identities. `just test::console table` passes in **300.73 s**,
including **219.79 s** of console checks: saved-intent recovery, six result segments,
current denial, automatic SQL, separate timing/JSON output, PTY connection changes,
TLS trust failures and bounded output. PTY cold/warm completion measures
1079.45/359.18 ms with 13,574,144-byte RSS high-water. These are executed checks,
not a new latency guarantee. The renderer units were repeated after extending
coverage to boolean, binary and conflict cells and passed.

The latency investigation uses isolated empty local Tables, disk Ursula/MinIO,
eight resident authority pages and frozen executable copies. Initial probes
inadvertently combined an optimized CLI with a Debug node; the node's
SHA-256 exactly matches a rebuilt Debug artifact and the developer's running
node. Those observations must not be reported as ReleaseSafe engine performance:

- Repeated table queries took 62.48 and 82.55 s; JSON took 82.60 s and COUNT took
  78.95 s. An empty result and changing output format did not explain the delay.
- A console-only HTTP counting proxy measured 63.32 s: preparation 144 ms,
  compilation 338 ms, submission/advancement 13,122 ms, wait 47,367 ms,
  fetch/verification 2336 ms, render below 1 ms and persistence 16 ms. It counted
  513 native calls, mostly point reads. The proxy did not count worker/courier
  traffic and its timings include queues and transport, not just engine work.
- Fresh Debug-node installations with 64 versus eight cached pages took
  20.82 versus 62.85 s, consuming 16.86 versus 52.52 node CPU seconds. This proves
  cache sensitivity in that build, not a cache-size fix or optimized performance.
  No cache budget, authorization gate or durability behavior was changed.

`just test::console-latency` builds all three Transit executables in ReleaseSafe,
freezes and hashes them, and measures repeated table/JSON/COUNT queries with node
CPU and client phase times. It uses its own installation and listeners, checks
timing on failed SQL, and imposes no latency threshold. It does not touch an
existing installation or restart a developer's server. Render time cannot explain
the observed long waits; repeated signed reads, polling, page decoding and digest
verification remain the relevant paths for further profiling.

The consistently ReleaseSafe run passes with first/repeated table queries at
**13.64/18.46 s**, JSON at **19.72 s**, and COUNT at **17.65 s**. The first table
attempt spends 23 ms preparing, 48 ms compiling, 2919 ms submitting/advancing,
10,204 ms waiting, 430 ms fetching/verifying, below 1 ms rendering and 11 ms in
separately measured persistence. Authority CPU is 5.98 s for that query and
8.37/8.39/7.78 s for the remaining queries. Thus Debug execution amplifies the
problem, but optimized empty queries remain slow. This comparison does not
attribute the improvement to the renderer. The server transcript/lifecycle check
also passes with the native tables in **47.42 s**. No latency optimization to the
query engine or storage is claimed by this change.

A controlled ReleaseSafe cache probe with the same executables and separate fresh
installations measures **13.95 s / 6.10 node CPU s** with eight resident pages and
**5.73 s / 1.94 node CPU s** with 64. This confirms substantial page-cache sensitivity
after removing the Debug-build confounder. Even the larger diagnostic cache leaves
seconds of native work for an empty result; the shipped eight-page budget remains
unchanged. No other qualification or build ran concurrently with these final
measurements; the developer's existing server remained running throughout.

The final ReleaseSafe console-only proxy probe takes **13.79 s** and counts
**382 native requests**: 110 resource reads, 218 entry reads (one non-success
response), eight capability reads, four sends, 38 process reads and four batched
entry reads. Resource/entry calls alone account for 7.95 s of proxy-observed
wall time. Rendering again measures below 1 ms. These counts exclude all worker
and courier requests, so they are a lower bound on system request amplification.
The next performance work should distinguish redundant status polling, repeated
authority/data page reads and page verification cost before selecting batching,
cache-policy or scheduling changes. Existing current-authority and complete-result
checks must remain covered by denial and recovery proofs.

The timing command requires `on` or `off`. CLI diagnostics pass **174 real command
cases**, including missing/blank, invalid and extra timing arguments in both
output modes, tab-separated settings, batch stopping and no stdout contamination.
Offline controlling-PTY checks exercise the real console in table and JSON modes:
`Usage: .timing on|off` leaves an enabled setting intact, the prompt accepts `.show`
and `.timing off` afterward, and terminal attributes are restored on exit.
`just check` passes with these cases, and the focused CLI diagnostics pass again
after keeping timing-argument errors out of query-recovery diagnostics.

### Native query latency: whole-node attribution

Leased snapshot foundation: `nix develop --command zig build test` and
`zig build transit-node` pass with independent signing vectors, malformed response
coverage, stable old reads across writes, fresh cuts, zero journal advancement,
repeated close, restart invalidation, current resource revocation, principal
replacement, retirement, per-principal admission, lease renewal and hard expiry.
These deterministic tests do not establish the console integration or physical
page reclamation safety; append-only pages remain required.

The console latency runner also supports `--repeat`, `--age-queries` and
`--instrument`. On 2026-09-29, the owned instrumented empty-Table run completed
in 71.303 s, first output 71.295 s, sampled console RSS 14,241,792 bytes.
It observed 1,800 native attempts (including background workers), 51 command
attempts and 50,366 provider attempts. A separate three-second idle window had
101 native attempts. The Python proxies materially increase cost and polling;
these numbers are attribution/control evidence, not a speed comparison with
the earlier uninstrumented baseline. Failed proxy experiments and a concurrent
build race are excluded. The script retains failed fixtures and cleans up only
its own processes. Populated-source and restart/cache matrix coverage remains
to be added with interactive-session qualification.

A subsequent isolated disk-backed profile counts all native callers, including
source/requester workers and the courier. ReleaseSafe builds of the same node and
query host are held fixed; the profiling node adds per-request page counter deltas
and monotonic timers around provider page requests, page decoding and backend
page verification. Diagnostics contain operation names, numeric actor identities,
status, durations and counters, without credentials, keys or values. Temporary
LRU and bounded-range experiments use a detached checkout and are not part of the
shipped engine. Raw traces, source patches, the driver and binary hashes are
retained locally under `.cache/transit-latency/` with
`deep-profile-manifest.json`. These are diagnostic samples, not latency targets.

The local server sets **100 ms** worker/courier idle intervals, overriding the
query host executable's standalone 20 ms default. For a first empty Table SELECT
with the shipped eight-page cache and 100 ms intervals, the profile measures
**12.96 s**: prepare 21 ms, compile 50 ms, submit 2,951 ms, wait 9,547 ms, fetch
373 ms, render below 1 ms and persist 10 ms. It observes:

- **1,120 native requests**, of which 384 are console requests, 367 source-worker,
  153 requester-worker, 203 courier and 13 manager requests.
- **31,466 page-cache misses** and 22,815 hits; every miss reads a separate
  immutable page record through the Ursula HTTP client.
- **51 durable native updates**, including four upload sends, 17 view opens,
  17 turns and 13 deliveries. The source takes 12 turns and the requester five.
- **1,471 staged pages**, about 1.84 MB of attempted page JSON payload for an empty
  result. These exclude root-journal payloads, HTTP framing and provider WAL/
  replication amplification. All cache/polling experiments stage the same number
  of pages.
- **12.58 s inside the serialized node handlers**, including 9.16 s of page
  provider I/O, 0.58 s decoding fetched pages and 0.39 s of backend fetch digest
  checks. The remaining handler time includes signature checks, tree work, the
  core's additional digest checks and root-journal I/O; it is not attributed to
  any one of those operations by this probe.

Within the query window, source-worker step spans total 8.756 s while their native
client request spans total 8.701 s. The approximately 55 ms remainder includes
local bookkeeping and query computation; this empty-query observation does not
establish execution costs for populated tables or more complex SQL. The timings
and whole-node counts locate the delay in native orchestration and storage.

Grouping the same recorded request counters by mutation gives **1,069 read
requests / 8.63 handler seconds** and **51 update requests / 3.94 handler seconds**.
These times include each operation's checks and I/O and partition the 12.58-second
handler total; they must not be added to the overlapping 9.16-second page-I/O
measurement. The page cache misses 58% of its 54,281 loads, and the 51 updates
average 28.8 staged pages each. These are derived attributions of the existing
trace, not a new benchmark or a predicted speedup from removing an operation.

Controlled first-query experiments, each on a fresh installation:

| Page cache | Worker/courier idle interval | Diagnostic change                        | Elapsed | Page misses |
| ---------: | ---------------------------: | ---------------------------------------- | ------: | ----------: |
|          8 |                       100 ms | Baseline                                 | 12.96 s |      31,466 |
|          8 |                        20 ms | Faster polling                           | 15.52 s |      36,604 |
|         64 |                        20 ms | Larger cache                             |  5.50 s |         624 |
|          8 |                       200 ms | Slower polling                           | 15.67 s |      31,642 |
|          8 |                       100 ms | LRU replacement                          | 12.50 s |      27,397 |
|          8 |                       100 ms | Stop scans at the catalog range boundary | 11.99 s |      24,548 |

LRU and range-bounded scans reduce reads but do not resolve multi-second empty
queries. These single elapsed samples are subject to host variance and do not
qualify either experimental engine change. Slower polling primarily helps idle
work: at 100 ms, three idle seconds use 0.24 node CPU seconds and cause 114 native
requests/924 page misses; at 20 ms these rise to 0.97 CPU seconds and 467 requests/
3,832 misses. At 200 ms they fall to 0.12 CPU seconds and 61 requests/481 misses,
but query completion takes longer. Polling must be evaluated alongside wake-up
latency and durable work, not reduced blindly.

The running developer node's executable hash still matches the earlier Debug
control. Its 86.9-second reported query is consistent with the already measured
Debug amplification; an optimized CLI does not replace an already running Debug
node. The developer installation was neither queried nor restarted by the probes.

The benchmark now supports reproducible fixture-only controls and idle CPU
measurement, building to its own output prefix:

```sh
just test::console-latency --single
just test::console-latency --single --resident-pages 64
just test::console-latency --single --worker-interval-ms 200
```

It hashes and freezes the selected binaries, applies controls only to its own
child configurations, verifies the result and joins all owned processes. The
next changes should reduce repeated native metadata/point reads and intermediate
page staging within bounded operations, and reduce result-publication turns
where the existing atomic mutation budget permits. Current-authority checks,
retained versions, exact receipts and final result verification remain required.

The extended benchmark passes against the uninstrumented ReleaseSafe binaries
both without overrides (**14.01 s**, 6.12 node CPU seconds) and with the fixture-only
64-page/100-ms controls (**5.69 s**, 1.91 node CPU seconds). Both return the verified
empty typed table; render time is below 1 ms. Idle node CPU is 0.24 and 0.14 seconds
respectively over three seconds. Binary hashes match between runs. No build or
other qualification ran concurrently with these measurements; the developer's
existing server remained running. These controls reproduce the cache sensitivity
without relying on the profiling node.

`just check` passes after adding the benchmark controls and attribution notes,
including the 174 CLI cases, Zig unit checks, generated contracts, frontend checks,
public documentation validation and site build. The diagnostic range experiment
also passed the standalone core's existing unit suite in its isolated checkout;
no engine change is promoted on that evidence alone.

### Fresh interactive console execution

On 2026-09-29, `just test::interactive-query` passes for a 41-row Table,
41-row KV prefix and 12-row Document list on owned disk Ursula/MinIO. Every
statement has a distinct session ID, retains its source basis, streams bounded
frames and marks only terminal coverage complete. SELECT, COUNT, LIMIT, empty
output and table/JSON rendering make zero durable update requests. SIGINT during
a gated source read releases the lease without output; resource revocation after
a prefix prevents completion and a restored grant permits a new statement.
The Document fixture takes about 501 seconds including provisioning; its two
measured SELECTs take 0.469 and 0.439 seconds with 82 native requests. Provisioning
is excluded from query timing and remains costly.

`just test::interactive-query --source table --rows 257 --age 128` also passes:
retained state exceeds the source batch, with unrelated durable history before
the read. An empty Table with `--resident-pages 0` passes, including the added
closed-output-consumer case: failed output closes its snapshot. These are finite
scenarios, not load percentiles. The populated fixture counts requests through a
proxy without query workers; its timings are not default-server timings.

The separate default-server runner, without proxies or concurrent qualification,
returns eight empty SELECT/COUNT samples in 121–146 ms, first SELECT 131 ms and
first stdout 128 ms. It uses the default cache and background workers. The
executable hashes and per-phase data are emitted by `tests/console_latency.py`.
`--execution durable` selects the old lifecycle explicitly; `--age-queries`
always uses that lifecycle to create actual durable history.

`just check` passes after the console switch, including unit tests, CLI
configuration/diagnostics, generated-contract checks and the public site build.
`zig build test-cli-lifecycle` passes. Later bounded-workspace/LIMIT-zero changes
are exercised by the ReleaseSafe fixture and empty-cache control above.
Physical reclamation remains unsupported. Deterministic snapshot tests cover
lease expiry/restart/epoch and concurrent source changes; these console proofs
do not establish a multi-node session service or host power-loss behavior.

### Bounded tree mutations and immutable page batches

On 2026-09-29, the unit suite passes bounded range termination, an independent
257-key map across 160 mixed mutation batches, retained cuts,
no-op/duplicate/budget handling and failure or acknowledgement loss at every
staging step. Packed-cache tests cover LRU eviction, disabled cache and recency
counter wrap. Per-frame receipt tests reject failed, missing, duplicate, malformed
and incomplete coordinates before modifying returned references.

The real-disk commands pass in ReleaseSafe:

```sh
zig build test-pages -Doptimize=ReleaseSafe -- --keys 256 --cache 2 --mutation-batch 1
zig build test-pages -Doptimize=ReleaseSafe -- --keys 256 --cache 2 --mutation-batch 8
zig build test-pages -Doptimize=ReleaseSafe -- --cold-s3 --keys 1024 --cache 2
just test::storage
just test::service
just test::growing-service-release
```

The primitive checks every retained value after SIGKILL/restart and root-only
checkpoint/trim. The HTTP fault peer forwards actual accepted immutable batches,
then drops the whole reply, corrupts a coordinate or substitutes a failed frame.
No references are returned, no staging retry occurs, authority remains unchanged
and both retained roots still read. The first trial incorrectly expected batch
coordinates in top-level headers; it failed closed with `InvalidAppendReceipt`.
That trial is excluded. The corrected per-frame JSON decoder and all three fault
modes pass. Page locators remain format 2, with mixed single and batch records.

With one binary and two cache slots, the 256-key write/verification phase stages
1,960 pages for single updates versus 330 for batches, makes 5,820 versus 2,617
page HTTP attempts and encodes 4,099,816 versus 1,252,826 attempted payload bytes.
Elapsed samples overlapped other qualification and are not used as performance
comparisons. The artifacts include binary hash, revision, dirty status and
per-phase counters under `.cache/verification/pages-*-batch*.json`.

The growing service suite preserves exact receipts after lost replies and disk
restart, current read denial, retirement, maintenance snapshot/page reply loss,
trim timeout, growing Station recovery, multi-turn query publication and explicit
quota/control reserve behavior. The generic storage and legacy service suites
also pass. These checks do not authorize page GC or establish host power-loss
or horizontal-throughput guarantees.

The earlier interactive change also passes `just test::console table`, including
durable recovery, controlling-PTY input/editing/interrupt behavior, command/file/
stdin stopping rules and private-CA/hostname checks. The complete run took about
290 seconds including provisioning and query worker/node/store restart.

### Interactive Table access paths

The unit suite compares every primary-key and value-column comparison against
independent full predicate evaluation over 43 keys, including int64 minimum,
maximum, absent keys and a nullable value. Equality and tail-range access use one
source batch; unsupported access predicates retain full scanning and denial is
preserved. `just test::interactive-query --source table --rows 257 --age 128`
passes with the storage batches and Table seeks, including equality, both range
directions, COUNT with equality, maximum-key exhaustion, empty LIMIT, distinct
sessions, interrupted reads, closed output and denial after a prefix.
Full scans make 174 native attempts; each selected key/range query makes 14 and
no durable updates. The elapsed samples overlap qualification and are not SLOs.

### Final interactive performance qualification

`just check` passes with the final production changes, including source checks,
unit tests, CLI diagnostics, generated contracts, Board tests and the Docusaurus
build. Additional snapshot tests then pass in `zig build test`: all 64 slots
across eight principals, refusal without eviction, owner-only close, admission
after release, clock rollback, uncertain deadlines and expiry during read
materialization without renewal or authority writes.

The final `just test::interactive-query` passes all three sources with the
bounded adapter workspace and cancellation diagnostic. SIGINT returns 130 and
"query cancelled", with no durable resume advice. Output failure releases its
snapshot. Document SELECT takes 0.318–0.344 seconds with 82 reads; LIMIT zero
avoids traversal and takes 0.082 seconds with 26 reads. The whole Document proof
includes provisioning and takes 373.63 seconds. These are diagnostic observations.

`just test::server` passes in 16.57 seconds, including transcript rendering,
default discovery, a fresh query after supervisor/node/provider replacement,
identity preservation and child cleanup. Its first attempt still expected
`.resume` in the default console and failed; that obsolete expectation was
replaced with a fresh SELECT. Explicit durable resume remains qualified by the
separate `just test::console table` proof. The closed-page provider's 64-key batch
fixture also passes all restart/checkpoint/trim phases.

A final default-server measurement with `--repeat 2 --age-queries 2` uses the
ReleaseSafe executables, default cache and background workers, no proxies and no
concurrent qualification. Eight SELECT/COUNT table/JSON samples take 159–196 ms.
A separate `--single --instrument` run has 14 console native reads, 10 background
reads, zero command attempts and 188 provider attempts during the query. Its
three-second idle interval has 108 native and 553 provider attempts. These are
transport counts, not distinct commits, and proxy elapsed time is kept separate.

The final public documentation link check and diff whitespace check pass.
No existing developer installation was restarted or reinitialized by these tests.

### Console query interruption and prompt reuse

The issue #19 regression fixtures add controlling-PTY checks for Ctrl-C before
submission, during uncertain upload, during source work and during paged result
display or `.resume`. They exercise repeated signals, discarded trailing SQL,
completed-query races, exact retry after an unconfirmed cancellation and a fresh
statement at the same prompt. Batch interruption checks exit 130. The default
interactive fixture separately checks snapshot release and a fresh statement
without durable requests or recovery state.

Before rebasing onto interactive execution, the durable interruption cases and
terminal/TLS checks passed in two local `just test::console table` attempts. The
enclosing proof failed in its final retained-version cleanup: the expanded
history required paging, then an explicit fixed read position with the cursor.
The corrected cleanup and rebased behavior are pending qualification; those
partial runs are not full-suite passes. Earlier clean-checkout runs were stopped
when their tested revisions were superseded. Hosted CI did not start because of
the GitHub account billing/spending limit. Current PR validation reports the
revision and result of subsequent runs.

### Combined reads, control caching and bounded transport

The next read-path revision adds canonical `snapshot_read` fixtures and generated
native schema coverage. `just contract::check` and `just test::unit` pass. Core
tests distinguish the captured source from final current metadata, allow an
injected unrelated publication during materialization, reject current revocation,
retain a slot after failed finish validation, and enforce byte-limited continuation
and expiry. Immutable control-cache tests cover scan eviction pressure, changed
roots, unpublished candidates and retained roots; cached bytes cannot grant access.

`just test::serving-http` passes with three exchanges on one socket, advertised
closure at the configured cap and health progress between exchanges. The existing
deadline, cancellation/join, partial header/body and capacity cases still pass.
`just test::server-faults` passes the real growing node/gateway, including socket
reuse, fresh sessions after an idle connection expires, stalled body isolation,
false control-hint rejection, full data admission with control parsing and signed
denial still available, interrupted provisioning and rollback refusal. Its final
lifecycle/fault runs take 17.05/16.85 seconds. Health under data pressure takes
2.91 ms in that run; this is a sample, not a latency bound.

The transport change also passes `just test::service` for legacy close-after-reply
authorities and `just test::growing-service-release` for exact retry, malformed
replies, revocation, resource reads, current/retained versions, node/provider
restart, maintenance uncertainty, quota reserve and durable Station/query recovery.
The latter includes a 41-row, 9,984-byte durable result through staging, sealing,
publication, partial consumption and retained acknowledgement. No transport retry
is introduced. Growing authority work remains serialized; these finite proofs
do not establish per-principal fairness or offered-load throughput.

### Document chunk prefetch and request ceilings

The Station unit suite now publishes a nine-chunk index node through ordinary
bounded turns, reads it in two prefetch batches and checks the decoded value.
Corrupt prefetched bytes fail the Publication digest; unavailable batches and
current denial also fail, including denial on a verified node-cache hit.
`just check` passes with these tests and the transport changes.

The Document-only interactive fixture passes with 30 native requests for a full
12-row scan, 29 for `LIMIT 3`, and three for `LIMIT 0`, with zero durable updates.
Its full-scan completion samples are 106–171 ms including the counting proxy;
provisioning and failure cases take 260.74 seconds overall. Other qualification
ran concurrently, so these are not isolated latency measurements. Fresh sessions,
bounded complete/incomplete framing, cancellation, output failure and
revocation after a prefix pass. The runner enforces native request ceilings for
all source fixtures, independently of elapsed time, to catch amplification
regressions without selecting a host-dependent latency threshold.

### Read-path performance qualification

The final `just test::interactive-query` passes Table, KV and Document with the
request ceilings enabled. The 41-row Table/KV scans each use eight native reads;
small/LIMIT-zero reads use three. The Document rerun uses 30 full-scan reads and
takes 261.50 seconds including provisioning and fault cases. A separate
`--source table --rows 257 --age 128` run passes with 39 full-scan reads and three
for equality/range reads, compared with the earlier 174 and 14. All SELECTs issue
zero durable updates; fixture setup is counted separately.

`just test::console-latency --repeat 2` runs without concurrent qualification or
proxies. Its eight empty SELECT/COUNT table/JSON samples complete in 14.98–18.18 ms
including CLI startup. The first SELECT completes in 16.75 ms, with first output
at 15.17 ms; console phases total 11–14 ms. Sampled console RSS is 13–16 MB, node
RSS 23–24 MB. The same fixture's first query before this round took 91.10 ms;
one baseline and eight new samples do not establish tail latency or attribute
the speedup to individual changes. The historical user installation is not a
controlled comparison.

A separate `--single --instrument` run uses the same executable hashes and no
concurrent qualification. Three console reads plus one background read cause
11 provider attempts (10 HEAD, one GET), with zero updates. Three idle seconds
contain 16 native and 60 provider attempts; uninstrumented idle node CPU is
0.03 seconds. The historical profile recorded 108 native/553 provider idle
attempts. Proxy timing is not mixed into the uninstrumented measurements.

The final CLI SHA-256 is
`e6609d87b8d52e4c2e46bec806889428ed849bdd9149279a0e0ce7bc35057e63`,
node `09acf58ff4093a1709f0c4c353837da9ceba4a039e66a5b90a837b6b4f17a9af`,
and query host `c6de4c3320a5179add330cc81689fbc1edc226ae89d8f7458c7cc8815728c699`.
All use pinned ReleaseSafe builds, disk Ursula and MinIO. The runner freezes its
executables and uses owned temporary state. No running developer installation
is restarted or reinitialized.

`just test::console-latency --single --execution durable` also passes with the
new local idle backoff. It runs alongside Document provisioning, so its elapsed
time is not used as a controlled durable-performance result. `just check` passes
the final implementation: unit tests, diagnostics, generated contracts, frontend
checks and the production documentation build. Later edits only explain measured
behavior, compatibility and remaining scope; `just transit-docs::check` passes
again for those edits. No push is performed, so the pre-push `just ci-clean` gate
is not run.

## Public command documentation

The published handbook assumes the complete local bundle is installed and invokes
`transit` through `PATH`. Source setup and proof commands remain with repository
tooling owners. The launcher overview retains `/guides/launchers`; its full
runbook remains outside the site catalog and search. This follows the public
documentation scope in [Public documentation](../../README.md).

Executed for this documentation change:

- `just check` passed the native/contract/unit checks, 174 CLI diagnostic cases,
  frontend checks/tests and production documentation build.
- `just transit-docs::check` passed: formatting/lint, strict TypeScript, seven
  content/reference tests and the production build. The content guard rejects
  Nix/Just commands and path-qualified Transit invocations in published code.
- `python3 -B tests/docs.py` passed 4,334 local links across 453 Markdown files.
- `nix develop --command bash -c 'cd docs/handbook && vp exec playwright test'`
  passed all four production browser checks at `/`, covering desktop/mobile
  navigation, search, generated downloads, diagrams and accessibility.
- The built search index was checked for repository command invocations and
  local Transit executable paths; none remain across its 92 entries.

These checks validate documentation and rendering. They do not rerun bundle
builds, application installation, provider recovery or deployment qualification.

### Explicit source aliases

The `feat/sql-source-aliases` continuation implements explicit `FROM source AS
alias` through the shared Zig parser, compiler and scoped completion owner.
Fuze and query package tests pass. Equivalent aliased/unaliased queries produce
identical canonical plans for row, state-test, count, sum and restricted-derived
forms. Checks reject hidden original qualifiers, escaped inner aliases, unknown
actual sources and duplicate columns. Completion fixtures keep the declared
source authority separate from alias spelling, including quoted case and typed
literal hints.

Eight additional independent completion fixtures expose and correct a missing
dot continuation after a source qualifier, including an alias that also names a
column, quoted case, hidden/foreign sources and an already qualified column.
The first run fails the original-source continuation case (63/64 package tests
pass); after the correction all 64 query package tests pass. Logs are
`/tmp/transit-sql-source-aliases-completion-before.log` and
`/tmp/transit-sql-source-aliases-completion-after.log`. This changes suggestions,
not source authority, parsing or the saved-plan format.

`just test::sql` passes **113** Zig/ANTLR/PostgreSQL SELECT AST comparisons,
**92** real plans and independent paged Arrow checks, and **19** grammar
exclusions. The unified fixture checks **28** independent results at three source
kind bases and eight page widths, plus nine explicit failure cases. Mutation and
declaration fixtures also pass unchanged. The log is
`/tmp/transit-sql-source-aliases-sql.log`. These are compiler/engine proofs;
installed native/port/ten-SDK inspection and SQL-shell recovery checks are
separate.

Full `just check` passes on the initial source tree and again at rebased
`512ebcb4`, including the completion correction. The latter log is
`/tmp/transit-sql-source-aliases-rebased-check.log`. The first installed attempt
stops before provisioning because this fresh worktree has no built Python wheel;
no caller case ran. The failed log is
`/tmp/transit-sql-source-aliases-installed.log`. All standalone Zig and ten SDK
package builds subsequently pass. The installed run passes KV and Table in
**386.41 s / 374.20 s**, including inspection agreement across thirteen
native/port/SDK callers and SQL-shell admission, exact retry, source/requester/
node/store recovery, current denial, retained rows and joined cleanup. Document
qualification also passes in **1726.68 s**, including **1465.98 s** provisioning:
twelve rows/two segments/9,880 bytes, with its existing 64 authority pages and
8 MiB hot store. The entire three-source command exits successfully. The log is
`/tmp/transit-sql-source-aliases-installed-built.log`; its frozen binaries precede
the rebase and completion-only correction. KV/Table retain eight authority pages;
these different fixture profiles do not establish comparable native latency.

Committed-head `just ci-clean --lane core --work-root /var/tmp` passes all
**22 tasks in 1309.02 s** at `34b0b96f`. The report is
`.cache/ci/clean/34b0b96f175e-transit-ci-ocwpgt5q/core.meta.json`; the log is
`/tmp/transit-sql-source-aliases-ci-clean-core.log`. Rebase onto merged #44 at
`b8b224ce` preserves all three original commits unchanged. Clean growth at
rebased `512ebcb4` includes #44's catalog read reduction and the corrected
snapshot fixture, but fails in query delivery at the unchanged 180-second
deadline (**592.17 s** task / **752.95 s** lane). Three tasks pass and seventeen
are unrun, including the corrected fixture. The earlier failed attempts remain
failed; this result does not establish their cause. The log is
`/tmp/transit-sql-source-aliases-ci-clean-growth.log`, with its failure checkout
retained at `/var/tmp/transit-ci-0sct7l0m`.

Clean experience at final alias head `93c3832b` passes five tasks, then fails
Board's cancellation-result observation with HTTP **503 Unavailable**
(**93.33 s** task / **261.17 s** lane). The final Station task is unrun. The log
is `/tmp/transit-sql-source-aliases-ci-clean-experience.log`, with its failure
checkout retained at `/var/tmp/transit-ci-knqo9ipr`. Neither lane is passed;
the implementation is published as tracking draft PR #47.

The declarative benchmark adds an aliased selected-count component beside its
unaliased equivalent; all **29 components** and nine rejection probes pass with
257 rows, three rows per page and five samples. Compile medians are **0.582 /
0.707 microseconds** for unaliased/aliased SQL; execution medians are **76.816 /
75.703 microseconds**. The canonical plans and independently checked outputs
agree. These samples overlap other qualification and do not establish an
execution speedup or native latency. Full workloads remain blocked. The report
is `/tmp/transit-sql-source-aliases-benchmark.json`, with dirty source based on
`d5541301` and exact manifest/harness/binary provenance. The benchmark runner's
negative controls, documentation links and verification inventory checks pass.

### Typed output-name plan checkpoint

The `feat/sql-output-aliases` continuation introduces owned names by output
position and a mandatory definition in `FZP1`. Five independent Python byte
fixtures cover renamed rows, repeated inputs with distinct names, named count
and sum, and default names. Fuze tests compare exact bytes and output schemas,
retain input basis/schema identity, and reject old/foreign definitions,
colliding names, hidden slots and malformed owned names. Decoded names remain
owned when the encoded input is changed. Fuze package tests pass after migrating
two limit-field corruption probes to the replacement wire offsets.
The full unit task passes after two inline signing digests are recomputed with
independent canonical JSON/SHA-256. The first broader run passes 493/494 tests
and exposes that stale expected digest; it remains distinct from the corrected
pass in `/tmp/transit-sql-output-aliases-unit-fixed.log`.

A source-behavior regression publishes an integrity-valid bundle with a foreign
plan definition, then verifies one terminal rejection reply to the original peer
and correlation without retaining a source version. The first run fails because
the new decoder error escapes the disposition mapping (64/65 tests pass).
Classifying incompatible-plan and invalid-output-name errors as failed requests
makes all 65 query-package tests pass. The before/after logs are
`/tmp/transit-sql-output-aliases-rejection-before.log` and
`/tmp/transit-sql-output-aliases-rejection-after.log`. This is an in-memory
behavior proof; it does not replace installed or disk-backed recovery evidence.

The shared native definition, generated protocol/installation/ABI/host/browser
resources, neutral bundles and signing fixtures are replaced together. Native
fixtures use independent SHA-256 and OpenSSL signatures; rejection of the actual
retired definition remains explicit. `just test::sql` passes its existing 113
parser comparisons, 92 plan/Arrow checks, 28 three-source/eight-page-width cases,
and mutation/declaration checks under the new plan encoding. This checkpoint
does not yet enable output-alias SQL syntax or qualify installed caller recovery
and performance under the replacement definition. Its logs are
`/tmp/transit-sql-output-aliases-model-test-fixed.log`,
`/tmp/transit-sql-output-aliases-wire-sql.log` and
`/tmp/transit-sql-output-aliases-fixtures.log`.

### SQL output-alias lowering checkpoint

The shared parser, reference grammar and compiler accept explicit `AS` names on
row positions and count/sum results. Restricted derived aggregates resolve
renamed inner columns back to original source indices. Predicates continue to
resolve original source names. Owned-name, scope, duplicate-output, identifier
bound, completion and EXPLAIN fixtures exercise this behavior without granting
source access or widening query execution budgets.

`just test::sql` passes **134** Zig/ANTLR/PostgreSQL AST comparisons, **105**
independently encoded plans and Arrow results, and **44** six-type/five-state
result cases across three source bases and eight page widths. The latter includes
renamed negative zero, full-width uint64, binary, null/missing/error/conflict
cells, repeated inputs, empty results and named aggregates; **17** cases check
explicit compile/execution failures. All **56** public SQL examples parse.
The Fuze/query package tests, existing mutation and declaration checks also pass
in `/tmp/transit-sql-output-aliases-syntax-final-focused.log`.

The initial checks expose two test assumptions: result types were inferred from
output names, and a repeated identical projection expected `DuplicateColumn`
instead of the existing `DuplicateProjection`. The independent checker now
derives types from input positions and aggregate semantics; the precise error
expectation is corrected. Initial failures remain in
`/tmp/transit-sql-output-aliases-parser-expanded-unit.log` and
`/tmp/transit-sql-output-aliases-parser-sql.log`; the corrected SQL pass is in
`/tmp/transit-sql-output-aliases-parser-sql-fixed.log`.

The first full `just check` exposes stale browser inspection rules that required
unique input projections and fixed output names. The browser now validates
matching widths, distinct valid output names and aggregate types independently
of aliases. Shared native fixtures include repeated renamed inputs, named count
and renamed derived sum; malformed duplicate outputs, widths and count types
still reject. The failed full run is
`/tmp/transit-sql-output-aliases-syntax-check.log` and the focused browser check is
`/tmp/transit-sql-output-aliases-browser-inspection.log`.
The corrected full `just check` passes, including generated-contract checks,
Zig tests, browser validation and the documentation build, in
`/tmp/transit-sql-output-aliases-syntax-check-fixed.log`.

This compiler checkpoint does not establish neutral-plan/SDK output-name round
trips, installed recovery, performance or committed-head clean qualification.
Those remain required before publishing the output-alias increment.

### Neutral and installed SDK output-name checkpoint

The neutral plan now preserves optional names by output position through
decode/prepare and workspace compiled metadata. A regression compiles named
SQL, decodes its bundle through the neutral API, then prepares it through the
actual ABI codec and compares exact bytes and publication identity. Before the
fix, 12/13 binding tests pass and this regression exposes lost names and a
changed digest; afterward all pass. Ownership checks mutate the original name
buffers, and malformed names or vectors with the wrong width reject. Logs are
`/tmp/transit-sql-output-aliases-neutral-before.log` and
`/tmp/transit-sql-output-aliases-neutral-after.log`.

All ten public SDK plan APIs expose these names. The neutral/ABI cutover replaces
the shared native definition with
`00177e103bcb1a8208abd6958d79c9f3f471caf62d4a0c87957072356fd28214`;
generated contracts, host/browser resources and independent signed fixtures move
together. Both the preceding native definition and the retired main
definition remain explicit rejection cases. The plan-definition identifier and
`FZP1` layout from the preceding checkpoint are unchanged.

The shared native/port codec suite passes **52 cases**. All eight SDK package
build tasks pass, then `python3 -B tests/sdk_unified.py` installs and executes
all **ten language consumers** in a fresh temporary directory. Each consumer
compares default and named bundles against independent bytes for KV, Table and
Document, retaining six-type/five-state Arrow and malformed-input checks. The
new `just bindings::unified-codecs` task composes those build tasks and this
standalone proof. These are pure codec checks: no signed authority caller or
disk recovery is exercised. Logs are
`/tmp/transit-sql-output-aliases-neutral-unit.log`,
`/tmp/transit-sql-output-aliases-sdk-build.log` and
`/tmp/transit-sql-output-aliases-installed-codecs.log`.

Full `just check` passes, including generated-contract drift, runtime units,
**21** query-browser tests and the documentation build. Python mypy passes;
`just test::sql` retains the preceding **134/105/44/17/56** checks, and
`just bindings::node-check` passes **39 tests**. Logs are
`/tmp/transit-sql-output-aliases-neutral-check.log`,
`/tmp/transit-sql-output-aliases-neutral-mypy.log` and
`/tmp/transit-sql-output-aliases-neutral-sql-node.log`.
Initial generation attempts fail on fixture ordering and a formatting-wrapper
invocation; their logs remain in
`/tmp/transit-sql-output-aliases-neutral-generate.log` and
`/tmp/transit-sql-output-aliases-neutral-generate-fixed.log`. Fixtures are regenerated before dependent
schemas, formatting uses `vp fmt`, and the subsequent full check passes.

Installed authority/CLI named-schema checks, exact retry, current denial,
disk-backed recovery, performance measurements and committed-HEAD clean lanes
remain required. Earlier source-alias failures remain separate evidence.

### Installed named-output recovery checkpoint

The disk-backed unified-query schedule now uses an explicit `Result` output
name in the Zig bundle and all ten SDK constructors. Document's other output
positions retain their default names. Independently decoded Arrow must carry
the exact renamed schema and original values. The SQL shell uses a quoted
output alias, saves its original bundle/request across shell exit, and checks
names on each returned page. Inspection includes named count and repeated
inputs with distinct names, both under current access and subsequent denial.

The first installed attempt fails before upload because its new inspection
fixture expects mixed case from an unquoted SQL identifier. Quoting `Result`
corrects the fixture without changing compiler case rules. That failure remains
in `/tmp/transit-sql-output-aliases-installed-recovery.log`.

The corrected schedule passes KV named-plan preparation and SQL inspection
across **13 native/port/installed caller variants**, then exact signed upload
retry and worker/node/disk-store restart after staging a segment. After restart,
the cold store refuses writes with **507 `XMinioStorageFull`**: its shared 1.8 TB
backing filesystem has only 17 GB available. Ursula reaches its existing 8 MiB
hot-store boundary and returns `ColdBackpressure`; native staging reports 503.
No storage quota or operation deadline is increased. This is incomplete recovery
evidence: completed results, post-restart disclosure denial, CLI execution and
the Table/Document schedules are not qualified by this run.
The run exits unsuccessfully at the unchanged **900-second** post-restart
deadline, with namespace 1 / correlation 86 still `admitted` and no manifest.
Table and Document are unrun. The fixture's normal cleanup completes; the
separately retained log snapshot is diagnostic evidence, not a recoverable
copy of the store.

The corrected log is
`/tmp/transit-sql-output-aliases-installed-recovery-fixed.log`. A private log
snapshot is retained at `/var/tmp/transit-sql-output-aliases-capacity-evidence`.
The six frozen runtime artifact hashes are in
`/tmp/transit-sql-output-aliases-installed-artifacts.json`; their runtime source
is `4e9a8bca`, before the later compiler optimization. The unchanged limits and
remaining gates still apply after capacity is restored.

Full `just check` passes on the subsequent optimized source tree, including
generated-contract drift, runtime units, browser validation and the documentation
build, in `/tmp/transit-sql-output-aliases-optimized-check.log`. This does not
complete the storage-dependent installed schedule or committed-HEAD clean lanes.

### Output-alias integration with located diagnostics and console writes

The continuation rebases without conflicts onto `2704c153`, including #49's
wire-access investigation and #50's located diagnostics, authorized console
write routes and canonical saved-write validation. Parser locations, diagnostic
redaction and the existing mutation/catalog execution owners remain in use.
The PostgreSQL/MySQL milestone is a proposal, not an implemented listener.

Real CLI regression cases expose stale duplicate-projection advice that forbids
repeated inputs. Shared local/remote diagnostics now describe distinct output
names and explicit `AS`; invalid output-name shapes also receive binding advice.
Malformed alias syntax retains its exact location. The bounded remote rendering
tests pass, including output-name failures; runtime errors still keep their
owning authority/recovery disposition.

The initial CLI regression fails in
`/tmp/transit-sql-output-aliases-rebased-diagnostics-before.log`. The next run
exposes a new fixture using `id` against its configured `key` column; that fixture
is corrected without changing binding rules, and its failure remains in
`/tmp/transit-sql-output-aliases-rebased-focused.log`. The corrected **422 real
CLI cases** pass, including the socket trap that rejects any authority contact
for invalid SQL. Fuze package tests and the full independent SQL proof pass:
134 ASTs, 105 plan/Arrow cases, 44 results, 17 failures and 56 public examples.
Logs are `/tmp/transit-sql-output-aliases-rebased-fuze.log` and
`/tmp/transit-sql-output-aliases-rebased-focused-fixed.log`.
Full `just check` also passes on the rebased integration tree in
`/tmp/transit-sql-output-aliases-rebased-check.log`; final local documentation
links pass in `/tmp/transit-sql-output-aliases-rebased-docs.log`.

The expression reference and grammar inventory now consistently describe output
names and repeated inputs. Earlier measurements and installed artifacts retain
their original pre-rebase source identities; the rebase does not qualify new
installed write routes or resolve the recorded cold-store capacity failure.

### Output aliases with the combined local Table writer

The output-alias continuation rebases onto `65c9c669`, retaining the combined
local Table query/writer and automatic console write route from `a0a9375e`.
The rebase preserves author dates and resolves definition/generated-resource
conflicts by generating a combined current native definition:
`1b790ef9b226fa9d5ee27622dd7fbfd51cb56eb764574594c0a792d4170bf0a2`,
the SHA-256 of
`transit.native.v1.local-writer.sql-output-name-callers.2026-09-30`.
The output-name `FZP1` definition stays unchanged. Schemas, ABI resources, browser
validators and independent SHA-256/OpenSSL signing fixtures are regenerated.
Explicit regressions reject alias-only, local-writer-only and intermediate
definitions. No installation history is converted or reset.

The first full check fails one protocol fixture because the independently
recomputed entries-query digest omitted the existing `resource` and `revision`
null fields. Correcting the expected canonical bytes preserves production
signing. The failed log is
`/tmp/transit-sql-output-aliases-local-writer-check.log`; full `just check` and
`just test::sql` then pass in
`/tmp/transit-sql-output-aliases-local-writer-check-fixed.log`.

That combined command's subsequent `just test::server` fails before its local
console transcript: the bindings shell's `TRANSIT_SQL_TOOLS` build setting leaks
into automatic server configuration and correctly rejects as unknown. Evidence
remains at `/var/tmp/transit-server-proof-i9no6k0w`. A focused run removes only
the shell's `TRANSIT_SQL_TOOLS` and `TRANSIT_GSON_JAR` variables, retaining the
same pinned tools and unchanged fixture. It passes the real console write,
readiness, current-denial and restart schedule in **36.51 s**; its log is
`/tmp/transit-sql-output-aliases-local-writer-server.log`. This local-server proof
does not complete the separate installed all-source recovery or clean gates.

### Predicate truth foundation

The `feat/sql-boolean-predicates` worktree starts from output-alias checkpoint
`e77b804a`. `Unified.Plan.predicateTruth` preserves unknown for null/missing
comparisons, while `matches` still selects only true. Exact state tests remain
two-valued; evaluated type errors, conflicts, unknown columns and mismatched
scalar types retain their errors. Pure AND/OR/NOT truth operations do not yet
enable compound SQL or change canonical plans, native definitions or SDK APIs.

Pinned standalone Fuze tests pass **139/139**, including all nine truth pairs,
three negations, all 25 cell/state-test pairs and 108 comparisons across the six
scalar types. The literal expectations cover full-width integer ordering, byte
ordering and the null/missing negation regression. The log is
`/tmp/transit-sql-boolean-truth-fuze.log`.

After locked frontend installation, `just check` and `just test::sql` both pass
in `/tmp/transit-sql-boolean-truth-check.log`. The independent SQL proof retains
134 SELECT AST comparisons, 105 plan/Arrow cases, 44 result cases across three
source bases/eight page widths and 17 explicit failures. This verifies unchanged
existing selection and serialization; compound evaluation order, syntax,
canonical encoding, caller reachability and recovery remain unimplemented.
The output-alias storage and committed-HEAD clean gates remain open.

### Bounded Boolean evaluation component

`Unified.PredicateProgram` executes postfix Boolean composition over the same
typed predicate atoms used by existing plans. It rejects empty programs, stack
underflow, trailing roots and more than 64 instructions. Schema validation checks
all atoms. Evaluation is eager in instruction order, keeps null/missing unknown
and preserves the first evaluated error. This is a pure component; compound SQL,
saved plans, caller values and installed recovery are not enabled by it.

Pinned Fuze checks pass **51 executed tests**, with the separate 93-test upstream
suite cached, in `/tmp/transit-sql-boolean-program-fuze.log`. New fixtures check
both operators over every pair of true/false/null/missing cells, all 64 inputs to
`(a OR b) AND NOT c`, exact work limits, malformed programs, complete binding and
first-error order. False AND conflict and true OR type-error deliberately fail;
explicit state predicates still inspect those states successfully. The existing
independent SQL proof also passes unchanged in
`/tmp/transit-sql-boolean-program-sql.log`. Neither this evidence nor Boolean truth
identities permits reordering or suppressing fallible atoms.

### Owned Boolean plans and neutral codecs

The continuation based on `518bb880` owns up to 64 predicate instructions in
`Unified.Plan` and canonical `FZP1`, while decoded projection/literal bytes retain
their input-buffer lifetime. Plan copies retain independent instruction storage.
Neutral native/port codecs and inspection preserve order and expose the same
instruction bound; schema generation overrides only that sequence field. Native
and plan definition identifiers change together. Missing/previous definitions
reject without executing or resetting accepted work.

Fuze passes **56 executed tests** (the upstream suite is cached); the query
package passes **66 tests**. Checks cover every scalar encoding, all instruction
prefix truncations, malformed tags/lengths/stack shapes, scalar and total byte
limits, copied instruction ownership, neutral round trips with exact Publication
identity, literal-free inspection, and changed-plan checkpoint rejection. A
compound Table predicate retains the general scan and current read denial.
The browser boundary rejects malformed programs and accepts exactly 64
instructions; all **22 query-client tests** pass after correcting a generated
schema that initially applied the generic eight-item bound to programs.

The expanded native/port proof passes **88 cases**, including seven independently
encoded compound plans, canonical Publication commitments, previous-definition
rejection and instruction-limit failures. Source-qualified full `just check`,
independent `just test::sql` and `just test::unified-codec` results are recorded
in `/tmp/transit-sql-boolean-plan-check-final.log`. Earlier attempts failed on
stale raw-SDK hashes and three independent signature/digest fixtures; the current
canonical bytes were regenerated with Python/OpenSSL and the unchanged rejection
checks retained. Logs remain `/tmp/transit-sql-boolean-plan-check.log` and
`/tmp/transit-sql-boolean-plan-check-fixed.log`.

Before this extension, committed clean core passes **22/22** at output-alias
source `4a646f2b` in **1071.05 s**, and at Boolean foundation `518bb880` in
**875.55 s**. Completion/timing records are respectively
`transit-sql-output-aliases/.cache/ci/clean/4a646f2b6b5e-transit-ci-o2u7e86p` and
`transit-sql-boolean-predicates/.cache/ci/clean/518bb8802998-transit-ci-rm3n8vct`.
Those runs do not qualify later program changes, other lanes or installed
all-source recovery. SQL Boolean parsing, typed SDK constructors and current
installed recovery remain outstanding.

The [owned-plan cost report](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/benchmarks/results/2026-10-01-boolean-plan-costs.json)
retains source patches, frozen binary hashes and every paired sample. The first
inline plan doubled paged-aggregate time. Pointer-based plan methods and
`Bound.validate` remove redundant plan copies while retaining complete per-page
schema, source and canonical fingerprint checks; paired aggregate time falls
about 49% against that initial implementation. A separate lowering rewrite
showed no consistent improvement and was reverted. Against the foundation,
final compile medians remain **15–36% higher** (about 0.18–0.24 µs extra), and
paged aggregate medians are **2.6–2.8% higher**. This shared-host component evidence
is not a native throughput or complete performance pass. It predates merged #42
and must be requalified with its shared logical/file primitives.

### Native Boolean SQL and compact owned syntax

The Boolean-SQL continuation after `e07bd2c9` adds NOT/AND/OR and parentheses
through the shared production/reference grammar, native lowering, editor
completion, located errors and EXPLAIN. The allocation-free parser owns a
compact literal pool bounded by the 4096-byte statement, up to 64 postfix
instructions and 64 pending operators/group delimiters. Copies have no internal
borrowed pointers. Single-atom parentheses preserve the existing canonical atom;
Boolean operators are not simplified or reordered. Native compilation uses
`SqlLowering.lowerAtom` and the saved-program owner rather than another
comparison definition. File plans explicitly reject compound programs.

Full `just check`, `just test::sql` and `just test::file-query` pass in
`/tmp/transit-sql-boolean-parser-final-check.log`. The independent proof compares
**151 Zig/ANTLR/PostgreSQL ASTs and 122 canonical plans/Arrow cases**, checks
**56 result cases across three source bases/eight page widths**, and rejects
**22 explicit binding/execution failures**. It includes null/missing negation,
precedence/grouping, full-width scalars, eager errors behind determining operands,
whole-query limits and unchanged alias scopes. All **57 documentation examples**
parse. File-query qualification passes **95 real CLI cases**, including explicit
compound rejection and the unchanged large-input memory bound.

Fuze passes **93 executed tests** with its upstream suite cached; logs include
`/tmp/transit-sql-boolean-parser-inplace-tests.log` and
`/tmp/transit-sql-boolean-parser-atom-tests.log`. Fixtures cover copied literal
ownership, exact instruction/nesting limits, malformed compact spans, complete
input rejection, source-order errors and allocation-failure cleanup for multiple
owned literals. The query package's 66-test run adds Boolean cursor fixtures;
full checks also exercise compound EXPLAIN's final authority check and omission
of literals. Initial test-only serializer error-set, cell-constructor and EOF
coordinate failures are corrected; their logs remain in
`/tmp/transit-sql-boolean-parser-{sql,tests,tests-fixed}.log`.

The [Boolean SQL cost report](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/benchmarks/results/2026-10-01-boolean-sql-costs.json)
retains five paired experiments, frozen hashes, raw samples and cumulative source
patches on `051c766a`. Initial SELECT compilation regresses 64–91% versus that
saved-program control. Borrowing the AST inside compilation improves those
medians 7–10%; filling caller-owned AST/predicate storage improves another
15–33% versus the pointer-only version. A special single-atom path gives mixed
results (predicate cases about 3% faster, no-WHERE cases 4.5–5.2% slower) and is
reverted. Final SELECT compilation remains **18.6–33.5% higher** than the control,
about **0.17–0.48 microseconds extra**. Existing paged aggregate medians are
2.3–2.8% lower. These shared-host component samples do not qualify compound
throughput, the logical/file controls, installed callers or end-to-end latency.

The predecessor `051c766a`, rebased onto main `85746270`, passes doctor, all
91 logical-codec fixtures per native/port boundary and 100 logical Arrow cases.
Node qualification first finds an inherited formatting error in the logical
value guide; `e07bd2c9` corrects it and all 39 Node tests then pass. Logs are
`/tmp/transit-sql-boolean-post42-logical-node.log` and
`/tmp/transit-sql-boolean-post42-node-fixed.log`.

Committed-HEAD clean core at **`051c766a` fails after 17 passing tasks**.
`test::service` receives `503 AuthorityUnavailable` when submitting its first
retained KV turn, before replay assertions (18.34 s); the final four tasks are
unrun. Total lane time is **1215.07 s**. Station and disk write/recovery/checkpoint/
trim proofs pass, including the 604.85-second storage task. Cause remains
unestablished. The failed checkout is `/var/tmp/transit-ci-mv9l_ft8`; its metadata
is also copied to `transit-sql-boolean-predicates/.cache/ci/clean/051c766a976d-service-failure`.
The command log is `/tmp/transit-sql-boolean-owned-clean-core.log`. A separate
diagnostic clone at `/var/tmp/transit-sql-service-diagnostic-8jwnky5h` prints
internal error names. Its first focused service run passes, but the fixture's
explicit cleanup still removes its store despite disabling automatic cleanup;
no retained-store claim follows. That helper is corrected for a subsequent
instrumented capture. These are investigative runs, not replacement clean
passes or an established cause. The original failed checkout remains unchanged.
Diagnostic logs are `/tmp/transit-sql-boolean-service-diagnostic.log` and
`/tmp/transit-sql-boolean-service-diagnostic-retained.log`.

Typed program APIs/inspection across all ten SDKs, compound file-plan admission,
installed current-definition recovery/authorization, final performance controls
and committed-head clean qualification remain open. The earlier named-output
all-source recovery failure remains failed; this syntax increment does not
complete it or the original SQL operation scope.

## Console input flush and signal schedule — 2026-10-01

A full SQL-branch check at `2cbd1a00` failed waiting for a fresh prompt after
Ctrl-C in history search. A controlled Linux PTY schedule reproduces the same
stall against a freshly built main `a4ba1124`: `poll` reports readable input,
the terminal flushes it on Ctrl-C, the actual signal handler completes, and a
later `read` blocks with `VMIN=1`. No additional key arrives before the existing
15-second prompt deadline. This demonstrates the race on main without proving
the exact interleaving of the original unscheduled failure.

Raw terminal input now uses `VMIN=0/VTIME=0`; polling owns the wait. Signal flags
are checked after reading and before interpreting a byte or end-of-input. An
empty raw-terminal read without a hangup returns to polling; ordinary stream EOF
and terminal hangup retain their end-of-input meaning. Normal input/escape waits,
output deadlines, cancellation, exit status and terminal restoration retain
their existing limits and behavior.

`just test::console-history` includes the real-syscall interposer
[console_input_gate.c](../../../tests/interfaces/cli/console_input_gate.c) and
[four scheduled cases](../../../tests/interfaces/cli/console_signals.py). The parent waits for a ready read,
applies a flush/signal, waits for the real handler's acknowledgment when needed,
checks the terminal queue, then releases the read. Cases cover a flushed Ctrl-C
during search, an empty read without a signal, Ctrl-C overriding queued Ctrl-D,
and SIGTERM after a flush. They assert prompt/exit behavior, a later ordinary
Ctrl-D, no result stdout/native requests/history submission, and exact terminal
attribute restoration. The interposer is loaded only by these proof children.

All four cases and the existing history suite pass on the correction. The same
test fails on its first scheduled case against the frozen main control.
Source hashes, control logs and development failures (archived)
retain their distinct outcomes. Pinned `just transit-board::install`, full
`just check` and `zig build test-cli-lifecycle` pass, exit 0; log
`/var/tmp/transit-console-race-proof/full-check.log`. This includes all 422 CLI
diagnostic cases, units, generated contracts and both frontend checks/builds.
Committed-HEAD clean qualification remains pending. This is local terminal
evidence, not a new query recovery or SDK compatibility claim.

## Handbook consolidation and static publication preparation (2026-10-21)

Documentation-only validation for the move into `docs/handbook` and the interface
coverage review:

- `python3 -B tests/docs.py`: 5,246 local links across 552 Markdown files pass.
- `just transit-docs::check` in the pinned docs shell: Vite+ lint/format, strict
  TypeScript, nine content/reference tests and the production build pass.
- The final production build and all five Chromium checks pass after the content
  review. They exercise navigation, static search, diagrams, desktop/mobile
  accessibility, canonical URLs, sitemap/robots, the 404 artifact and byte-exact
  downloads of OpenAPI/AsyncAPI descriptions, native schemas and setting metadata.
- `python3 -B tests/ci_runner.py` passes, including handbook-only selection,
  conservative shared-file selection, rename handling and failure propagation.
- The component directory links all 55 app/library README owners. The final
  static artifact has 353 files and no source Markdown or temporary server bundle.

Runtime execution and `ci-clean` are not run for this documentation refactor, as
requested. These checks establish documentation/build behavior, not new runtime
qualification. Cloudflare deployment, DNS/TLS, CDN routing/cache behavior and
rollback are not exercised; local Docusaurus preview cannot establish them.

## GitHub Pages handbook workflow (2026-10-21)

The publication workflow and site defaults at `c29d6c13` target
`https://spoke-sh.github.io/transit/`. Focused validation passes:

- `nix develop --command actionlint .github/workflows/handbook.yml`.
- Locked dependency installation in `nix develop .#docs`, followed by
  `just transit-docs::check`: Vite+ lint/format, strict TypeScript, all nine
  content/reference tests and the production build.
- `vp exec playwright test` in `docs/handbook` against that same output:
  all five browser checks pass with the default `/transit/` base path. These
  cover canonical URLs, sitemap/robots, navigation, search, exact schema
  downloads, diagrams and desktop/mobile accessibility.
- `python3 -B tests/docs.py`: 5,248 local links across 552 Markdown files pass.

GitHub's repository API confirms Pages uses `build_type: workflow`, the default
site URL, no custom domain and enforced HTTPS. The `github-pages` environment
has a single deployment branch rule for `main`. The first public deployment
requires merging the workflow; live CDN routing, cache behavior and rollback
have not been exercised. Runtime suites and `ci-clean` are not run for this
scoped documentation/publication change, as requested.

## Published handbook observations (2026-10-21)

The [Pages publication run](https://github.com/spoke-sh/transit/actions/runs/39715399883)
at source `5c1099f7a734bf4a3fce630cce9ae922737308df` completed both build and
deployment successfully after the data-first handbook change. The GitHub API
reports workflow publication, enforced HTTPS and no custom domain for
`https://spoke-sh.github.io/transit/`.

Direct HTTPS checks of the public homepage, introduction, data-model reference
and quickstart returned HTTP 200 and their new content. The public search index
included `reference/data-model`. These observations were repeated before moving
the completed publication work out of the future roadmap. They establish a
published revision and content availability at those checks, not general CDN
cache behavior or continuous availability.

The preceding handbook pass also passed the production build, nine documentation
unit checks and five local Chromium checks, including desktop/mobile navigation,
search, accessibility and exact generated downloads. Its task-dataset walkthrough
ran against an isolated installation with two consoles, schema defaults, schema
evolution and restart persistence. That fixture was stopped and removed; no
operator installation was changed.

Live browser/keyboard coverage, controlled revert/republication and a superseded
workflow rerun have not been exercised. These remain explicit
[publication qualification work](../../roadmap/42-qualification-and-benchmarks.md#documentation-publication).
No runtime behavior or new runtime guarantee is established by this documentation
framing change.

## Handbook cutover checks and dark diagram contrast — 2026-10-24

The handbook check and all five production browser checks pass at both the root
path and `/handbook/`. The first browser run found insufficient contrast on a
dark-mode Mermaid edge label (4.43 against the required 4.5). The stylesheet now
sets dark edge-label text to white; the unchanged accessibility assertions pass.
The corrected root and prefixed browser runs took 26.4 and 23.9 seconds.

Separately, the regenerated Unified fixtures pass all 142 query-package tests.
The Board workspace check and CLI diagnostics (96 artifact/file and 193
server/console cases) also pass. These scoped runs do not replace the pending
combined repository check or committed-HEAD clean CI.

## CLI discovery fixture environment — 2026-10-26

The [hosted core run](https://github.com/spoke-sh/transit/actions/runs/40262338677/job/121377263598)
passes its unit stage, then fails the CLI fixture's HOME-based configuration
discovery. The fixture inherits `XDG_CONFIG_HOME`, allowing the runner's ambient
directory to bypass its controlled HOME. With the retained ReleaseSafe CLI from
`6139782ba`, explicitly setting that variable to an empty owned directory
reproduces the failure. Filtering only the ambient value in `5bcbdd9b7` passes
all 193 diagnostics cases against the same binary and directory. Explicit
HOME/XDG/`TRANSIT_CONFIG` precedence cases retain their individual overrides.

The [before/after record and compressed logs](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/cli-xdg-2026-10-26/report.json)
identify the executable and fixture sources, hashes and commands. This changes
test isolation only; it does not change CLI discovery rules or complete the
current-source clean core lane.

