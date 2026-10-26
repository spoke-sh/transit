# Inspect with Board

Board displays evidence obtained through Transit's public read APIs. Open the
`board_url` printed by the [local server](quickstart.md), use the
[development launcher](../../../launchers/README.md), or configure the
[standalone service](../../../apps/transit-board/docs/configuration.md).
Use it to follow process history, state resources, ownership and retained work.

The default local server serves Board at both `http://127.0.0.1:19107` and
`http://localhost:19107`. A configured Board port applies to both addresses.
Use one address consistently: requests with an `Origin` header must match their
own scheme, hostname and port. Other hostnames and forwarded headers reject.

## Start from an identity and an observed cut

Use **Process directory** or **Resource directory** to return to the atlas from
an open workspace. Selecting the directory already shown in the URL also returns
to its object list, where you can select and enter another resource.

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

Resource participation pages carry their own association observation cut. Worker
progress can invalidate a continuation between pages. Board clears that page and
reports the changed observation; use **Refresh participation** to start from a
fresh cut. This action reads current associations and does not resume or replace
a query. Pages from the two cuts cannot be combined.

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

**Run query** explicitly submits a finite query. For a Table source, **Enable Live
draft** authorizes a finite budget within which complete valid edits can start
queries. Editing does not open or reset that budget. Preserve query namespace,
request and result identity through unknown replies; complete-result verification
precedes presenting a complete answer. **Follow changes** separately refreshes an
eligible submitted query under its own budget. The [Live Table guide](../../../apps/transit-board/docs/reactive.md)
describes scheduling, pause and recovery. Continuous SQL and speculative partial
draft execution are unsupported.

The optional application editor uses the shared compiler and neutral definition.
Review the whole valid proposal and publish conditionally with the operator's
current authority. A visual edit or accepted upload is not an activated interface
or completed data migration. See [application semantics](../reference/applications.md)
and the [Board application guide](../../../apps/transit-board/docs/application.md).

Board's UI is a projection of these contracts. Drawings, labels and rendered
forms cannot create additional operations, hidden grants or unsupported SQL.
