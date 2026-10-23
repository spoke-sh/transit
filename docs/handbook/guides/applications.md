# Build your first application

Use a custom worker when your data needs application-defined validation,
transformation or coordination. The [quickstart](quickstart.md) covers Table
creation, queries and schema changes through the server's existing catalog.
This guide extends that experience with a worker that owns domain commands and
a resumable data migration.

Local application installation uses a separately compiled Zig worker
and a language-neutral JSON installation/bootstrap contract. Application code
links public packages; it does not import the CLI's internals or become a node
handler. The example uses public path dependencies in this checkout;
release-distributed dependency consumption is not supported.

Start the version-1 server in the [local quickstart](quickstart.md), then use the
work-item application. It owns a typed Table, domain commands and a resumable
migration. Keep the server running while building and installing the application.

## Build and install

Use the repository’s [pinned Zig toolchain](../../../nix/README.md) to build the
example. In a second terminal with `transit` on `PATH`, from the repository root
(the parent of `.cache/docs-start` in this walkthrough):

```sh
(cd examples/work-items && zig build -Doptimize=ReleaseSafe)
export WORK_ITEMS="$PWD/examples/work-items/zig-out/bin"
"$WORK_ITEMS/work-items" manifest "$WORK_ITEMS/transit-work-items" > application.json
```

Submit the declaration through the shared `Application` client using the local
server's management profile. Save the signed install request before dispatch;
observe `status` until `installed` is true and the role is `ready`. The
[local application guide](../../../apps/transit-cli/docs/applications.md) describes
this API workflow. `transit` has no application-management command.

## Use the application as a caller

Use management `connect` requests to obtain the named writer and inspector
connections, and save their neutral JSON responses privately as `writer.json`
and `inspector.json`. They reference scoped caller keys. Native provisioning,
worker readiness and domain initialization are separate states.

Wait until `inspect` shows an initialized domain head before sending a write:

```sh
"$WORK_ITEMS/work-items" writer.json put put-1.json 1 0
"$WORK_ITEMS/work-items" inspector.json inspect
```

If the write's response is lost, repeat it with **the same** `put-1.json` recovery
file. It contains frozen signed intent. A new file is a new command. Keep caller
files, seed references and recovery files private and out of Git.

## Understand the boundary

The installer manages application deployment. A worker receives only its named
bindings and scoped credentials through the neutral bootstrap. A domain caller
uses a separate exported connection. An inspector cannot write; a domain operator
cannot install or rotate workers. All still share the trusted local OS account.

For your own worker, implement the bootstrap and role contract, link
`transit-client` / Station public packages, and declare the resources and rights
it actually needs. The [work-item source](../../../examples/work-items/README.md) is
the runnable consumer; [caller semantics](../reference/callers.md) explains turns and exact
recovery. See [SDKs](../reference/sdks.md) for client and framework APIs in other
languages. The local supervisor's worker adapter is Zig.

Continue with [replacement and recovery](../../../apps/transit-cli/docs/applications.md)
and the application's [migration commands](../../../examples/work-items/docs/local.md).
A compatible role replacement preserves durable IDs and current revocations;
changing a binary in place or rerunning installation with changed intent is not
an upgrade procedure.
