# Inspect with Board

Board displays evidence obtained through Transit's public read APIs. Open the
URL printed by the [development launcher](../../launchers/README.md), or configure
the [standalone service](../../apps/transit-board/docs/configuration.md).
Use it to follow process history, state resources, ownership and retained work.

## Start from an identity and an observed cut

1. Find the process/resource and confirm its realm and logical identity.
2. Inspect lifecycle, ownership generation and committed progress.
3. Follow input, turn, output or attempt references to their source evidence.
4. Check retained boundaries and current permissions before calling a view complete.
5. For application success, inspect its domain outcome using the application's
   decoder; generic Board metadata cannot prove a business operation succeeded.

A page is an authorized observation, not a lock on the system. Independent panels
can have different source cuts. Show freshness and gaps; a cached result cannot
extend history retention or survive known permission denial. Framework lenses
interpret allowlisted Station/connector metadata and do not decode arbitrary
private application values.

## Private viewer boundary

Everyone who can reach the deployment can inspect its configured shared scope.
There is no per-viewer sign-in, access key or session in this profile. Keep it
on a private network. Board's upstream identity still needs read-only grants;
it has no direct storage/provider access.

Optional query and application workspaces use separately configured identities
and capabilities. Enabling them does not turn ordinary inspection into an
administrative credential. See [Board OpenAPI](../reference/board-api.md) for the
actual inspection endpoints and [security](../reference/security.md) for scope.

## Queries and definitions

Submit a finite query explicitly. Typing or changing SQL does not automatically
execute it. Preserve query namespace, request and result identity through unknown
replies; complete-result verification precedes presenting a complete answer.
Follow changes refreshes an eligible submitted query under explicit budgets.
It is not continuous SQL or speculative execution while editing.

The optional application editor uses the shared compiler and neutral definition.
Review the whole valid proposal and publish conditionally with the operator's
current authority. A visual edit or accepted upload is not an activated interface
or completed data migration. See [application semantics](../reference/applications.md)
and the [Board application guide](../../apps/transit-board/docs/application.md).

Board's UI is a projection of these contracts. Drawings, labels and rendered
forms cannot create additional operations, hidden grants or unsupported SQL.
