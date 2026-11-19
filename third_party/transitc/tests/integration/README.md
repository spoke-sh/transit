# Upstream Transit integration

Run `nix develop --command just test-integration` from the repository root.
The shell provides the upstream `transit` package and Python; no pip dependencies,
sibling checkout, downloads during tests, or running server are needed.

The same suite is `checks.<system>.integration` in the flake. `nix flake check`
runs it in the sandbox, including in CI. To run only this check on x86_64 Linux:

```sh
nix build .#checks.x86_64-linux.integration --no-link --print-build-logs
```

## What is checked

Seven integration tests invoke the actual upstream executable:

- `build --check` verifies a two-file module graph and publishes no artifact.
- Two independent builds produce the hand-written `expected.sql`, identical
  provenance, correct source/output hashes, the pinned compiler revision, and
  four statement mappings.
- Default builds reuse intact artifacts and reject corrupted SQL without
  overwriting it.
- Missing entries and unknown targets fail with bounded structured diagnostics
  and no build artifact.
- Invalid SQL produces the expected syntax diagnostic and exact byte coordinates.
- `transit test` executes Table writes, duplicate-key rejection, and row checks
  in two isolated cases; both pass and their temporary runtime state is removed.
- A deliberately incorrect row expectation returns failure while producing a
  complete report, proving that the runtime assertions actually execute.

The fixture is adapted from Transit's `tests/fixtures/application-tests/` at
[`c1f2680d9353175e58ad503e750e7b4da76a84c5`](https://github.com/spoke-sh/transit/tree/c1f2680d9353175e58ad503e750e7b4da76a84c5/tests/fixtures/application-tests).
The build target adds an update and select; expected SQL is maintained explicitly,
not regenerated from the compiler being tested. Fixture `.transit` files and SQL
expectations live separately so expected output cannot be captured as source.

Each test copies source into a fresh temporary workspace and supplies isolated
home/config/cache/data/temp paths to its child process. It does not inherit
Transit credentials or settings. Subprocesses have deadlines; unexpected exits,
missing/malformed JSON, incomplete reports, or a wrong revision fail the suite.
No test is silently skipped when Transit is missing.

`upstream_transit.py` remains the seven-case upstream baseline. `parity.py`
compares transitc with that exact binary across five fixture families and four
negative cases. SQL, source maps, provenance semantics and diagnostic envelopes
must match exactly; only compiler revision, executable digest and input/cache
identity differ. Repeated transitc builds must be byte-identical.

`execute_sql.py` compiles with transitc, removes source, and executes its SQL using
the pinned runtime's real installation fixture. It verifies complete typed rows
and retained restart. Runtime helpers are imported from `TRANSIT_UPSTREAM_SOURCE`,
the frozen Nix source, not a sibling checkout. The standalone compiler does not
acquire a service dependency from this integration fixture.

`just test-workspace`, `just test-grammar` and `just test-types` cover dependency
failures/publication, independent syntax/formatting, and bounded typed/program
correspondence respectively. Each evidence category keeps its premises.

## Upstream identity and updates

The current upstream pin is
[`e7434306334e3692c6f3e123cba0d278fa412196`](https://github.com/spoke-sh/transit/tree/e7434306334e3692c6f3e123cba0d278fa412196).
The fixture retains its original attribution above. The
[extraction inventory](../../docs/roadmap/README.md) records the source changes
since that original basis; these seven tests do not cover every new language feature.

`flake.nix` names the exact GitHub revision and `flake.lock` records its content
hash. `TRANSIT_UPSTREAM_BIN` and `TRANSIT_UPSTREAM_REVISION` are exported by the
default shell; the runner verifies the executable's reported revision before
running any tests. Nix checks pass these inputs explicitly.

To upgrade the baseline, review the new upstream source/CLI contracts, change
the revision in `flake.nix`, run `nix flake lock`, and re-enter the shell. Run
`just test-integration` and `nix flake check`, and review changed expectations
against the source contract rather than accepting new output automatically.
Update this guide and the extraction source inventory when adopting a new basis.

For an explicitly selected local build, the runner also accepts
`--transit /absolute/path/to/transit --expected-revision FULL_GIT_COMMIT`.
Such a run does not replace the pinned Nix check and still validates the revision.

## Validation

On 2026-11-18, all seven tests passed on x86_64 Linux both through
`nix develop --command just test-integration` and the sandboxed integration
derivation. `just check`, the handbook check, and workflow lint also passed.
Flake evaluation passed for all four declared systems; ARM and Darwin test
execution was not performed.

On 2026-11-19, the refreshed `e7434306334e3692c6f3e123cba0d278fa412196` pin
passed all seven unchanged tests on x86_64 Linux through
`nix develop --command just check test-integration` and
`nix build .#checks.x86_64-linux.integration --no-link --print-build-logs`.
Both runs verified the executable's exact revision; no fixture expectations
needed updating. The bootstrap check and `nix flake check --print-build-logs`
also passed. After `nix develop .#docs --command just docs-install`, the handbook
passed `nix develop --option eval-cache false .#docs --command just docs-check`
and `nix develop --option eval-cache false .#docs --command env TRANSITC_DOCS_BASE_URL=/ npm run docs:build`.
The evaluation-cache override avoided contention with the concurrent upstream
build; it changed no toolchain or test inputs. These results establish the small
upstream baseline only, not extracted-compiler parity or other host platforms.

`execute_sql.py` compiles the Table fixture with a separate declared name (the
runtime provisions `items` itself), verifies exact emitted SQL, removes the
source workspace, and executes the artifact on the pinned real Transit host.
It checks completed rows and the same rows after retained restart. Runtime
fixture helpers come from the pinned flake source, with writable proof evidence
under this repository. Failed installations remain available for investigation.
This is separate from compile-only parity and does not qualify every runtime
feature or native host platform.
