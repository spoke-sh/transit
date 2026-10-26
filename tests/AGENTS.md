# Working on tests

Start with the [test index](README.md), the owning package/contract and the
[task reference](../tasks/README.md). Keep library units beside their package and
language-only units beside their SDK. This directory owns cross-component and
installed-consumer checks, independent oracles and verification infrastructure.

## Find and register the boundary

- Identify the invariant, public operation, backend and failure schedule before
  adding a driver. Extend the owning scenario instead of copying a whole fixture.
- Follow the [suite inventory](runner/suite.json) and
  [invariant catalog](verification/invariants.json). Register new runnable checks
  and their execution owner; distinguish nested checks from additional executions.
- Keep direct Table/storage acceptance separate from Station/application turns.
  Preserve provider-specific coverage when migrating a generic local fixture.
- Put new files in the appropriate domain directory with README/AGENTS navigation.
  Only README.md and AGENTS.md belong at the root. Existing root files and old
  directories have explicit [migration exceptions](runner/layout.json); remove
  each exception when moving its file. Do not add exceptions for new work.

## Fixtures and independent oracles

Share process management, ports, fault injection, bounded waits and artifact
capture. Keep expected values and semantic oracles independent of the production
implementation. Do not make a test pass by using its actual result as its oracle.
Use explicit binary paths and matching source/definition/profile identities.
Separate immutable build artifacts from mutable installation state.

Each fixture owns and joins its processes. Preserve private failed installations
when original-outcome investigation requires them. Exclude credentials from
published logs and artifacts. Retain the original saved request after uncertainty;
never replay a write as a new identity. Readiness, expiry and test-budget clocks
have different meanings. Do not increase deadlines to conceal a regression.

Physical disk, process death, injected I/O failure and modeled power loss establish
different claims. Keep those boundaries explicit. A fast in-memory control does
not replace disk qualification. Bound resource usage and avoid concurrent heavy
proofs that contend for the same disk, build output or installation.

## Validate and record

Run the smallest meaningful owning checks while iterating, then the affected
caller/fault and clean-source integration checks. Changes to shared contracts,
native authority, fixtures or build inputs require their dependent coverage.
Report exactly what ran and what did not; task registration is not executed proof.

Keep this README an index. Current behavior belongs in the handbook, reusable
methods beside their test owner, qualification accounts in
[history topics](../docs/history/qualification/README.md), and raw records under
ignored runner output and CI artifacts. The [evidence owner](evidence/README.md)
documents specifically retained reproducibility references. Use issues/PRs for
active investigations and handoffs.
Never append progress diaries or full command transcripts to `tests/README.md`.
Preserve original outcomes, source attribution and hashes when moving records.
