# Working on documentation

These instructions apply throughout `docs/`, alongside the
[repository instructions](../AGENTS.md). Read the scoped instructions when editing
[Handbook](handbook/AGENTS.md), [Design](design/AGENTS.md) or
[Roadmap](roadmap/AGENTS.md).

## Choose the owner

Use the [documentation index](README.md#where-documentation-lives) to place a
change. Keep that index short: link readers to owners instead of repeating their
contents or contributor instructions.

- Put runnable workflows in `handbook/guides/` and current concepts, interfaces,
  limits and compatibility in `handbook/reference/`.
- Put consolidated models, mechanisms, invariants and rationale in
  `handbook/internals/`. Architecture explanations follow the
  [scientific standard](handbook/internals/standard.md).
- Put delivery plans and status in `roadmap/`, and UI/UX proposals and reviews
  in `design/`. Neither establishes implemented behavior.
- Preserve earlier accounts in `history/` with their dates, outcomes, source
  links and limits. Link current owners; do not retroactively certify old claims.
- Keep exact wire specifications in [contracts](../contracts/), component usage
  beside its package/app, language guides in [SDKs](../sdks/README.md), and
  executed proof details in the [proof ledger](../tests/README.md).

Keep one current explanation of each behavior. Update its owner and link other
surfaces to it. A user must be able to understand an interface without reading
a plan, design review or historical record.

## Make claims traceable

Read the affected public topic, component guide and contract before changing its
explanation. Use the [glossary](handbook/reference/glossary.md) for names and the
[component directory](handbook/reference/components.md) to find implementation owners.

Lead with data, computation and policies, then explain the mechanisms that fulfill
them. Connect declarations to public operations, dependencies, authorization and
inspectable outcomes. Keep definition, acceptance, activation, progress and
completion distinct.

Describe current interfaces in the present tense, with concrete supported cases,
limits and failure behavior. Label proposed, offline and unverified behavior
explicitly. Avoid maturity labels, blanket readiness caveats and unsupported
performance promises. Follow the current [versioning policy](handbook/reference/versioning.md).

## Maintain links and evidence

Keep Markdown readable in the repository. When moving or removing material,
update indexes and inbound links, preserve useful anchors and retain attributable
historical evidence. Generated descriptions and schemas keep their owning source;
do not maintain another copy in prose.

Run `python3 -B tests/docs.py` from the repository root inside `nix develop` for
local links and fences, and check diff whitespace. For published content or site
changes, use the [handbook validation workflow](handbook/README.md#validation-and-hosting).
Follow the repository workflow for any accompanying implementation changes.
Report what ran and what did not; a skipped, incomplete or documentation-only
check establishes no new runtime guarantee.
