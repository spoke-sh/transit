# Working on runtime applications

Find the app through the [component directory](../docs/handbook/reference/components.md),
then read its README and any scoped instructions. Entry points compose public
package interfaces; keep reusable behavior in the owning library and interface
semantics in the public handbook/contracts. Runtime applications do not import
consumer SDKs or example handlers.

Keep control/policy, direct data and application execution distinct. A CLI,
gateway or UI must call the existing owner for validation, authorization and
publication. Direct Table ingestion and scans do not become Station turns.
Board inspection uses public read clients; editable/query capabilities retain
their separate explicit authority and execution contracts.

Use the app's existing task from the [task index](../tasks/README.md). In
`nix develop`, run focused component checks, then the affected real entry point
and failure schedule. For Board changes, install locked dependencies with
`just transit-board::install`, use `just transit-board::check`, and select the
affected integration/browser task. Use `vp` for frontend operations.

Preserve machine stdout, meaningful exit status, owned process cleanup and exact
accepted-work recovery. Local readiness, a compiled binary and a successful
browser render establish different evidence. Changes to installed paths,
packaging or fixture setup require committed-source clean checks. Keep current
usage/limits in the app guide; put run narratives in qualification history.
