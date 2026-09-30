# Build your first application

Local application installation uses a separately compiled Zig worker
and a language-neutral JSON installation/bootstrap contract. Application code
links public packages; it does not import the CLI's internals or become a node
handler. The example uses public path dependencies in this checkout;
release-distributed dependency consumption is not supported.

Start the version-1 server in the [local quickstart](quickstart.md), then use the
work-item application. It owns a typed Table, domain commands and a resumable
migration. Keep the server running while building and installing the application.

## Build and install

In a second Nix development shell, from the repository root:

```sh
export PATH="$PWD/.cache/transit-local/bin:$PATH"
export TRANSIT_MANAGEMENT="$PWD/.cache/docs-start/.transit/management.yaml"
(cd examples/work-items && zig build -Doptimize=ReleaseSafe)
export WORK_ITEMS="$PWD/examples/work-items/zig-out/bin"
cd .cache/docs-start
"$WORK_ITEMS/work-items" manifest "$WORK_ITEMS/transit-work-items" > application.json
transit app install --config "$TRANSIT_MANAGEMENT" --file application.json --operation install-1
transit app status --config "$TRANSIT_MANAGEMENT" --application work-items
```

Poll `status` until `installed` is true and the role is `ready`. Native
provisioning, worker readiness and domain initialization are separate states.
The installation [declaration contract](../../contracts/APPLICATION_INSTALLATION_V1.md)
defines roles, resource names, permissions, callers and initialization frames.

## Use the application as a caller

From `.cache/docs-start`, keeping the exported variables from the previous step:

```sh
transit app connect --config "$TRANSIT_MANAGEMENT" \
  --application work-items --caller writer --output writer.json
transit app connect --config "$TRANSIT_MANAGEMENT" \
  --application work-items --caller inspector --output inspector.json
"$WORK_ITEMS/work-items" inspector.json inspect
```

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
it actually needs. The [work-item source](../../examples/work-items/README.md) is
the runnable consumer; [caller semantics](../reference/callers.md) explains turns and exact
recovery. See [SDKs](../reference/sdks.md) for client and framework APIs in other
languages. The local supervisor's worker adapter is Zig.

Continue with [replacement and recovery](../../apps/transit-cli/docs/applications.md)
and the application's [migration commands](../../examples/work-items/docs/local.md).
A compatible role replacement preserves durable IDs and current revocations;
changing a binary in place or rerunning installation with changed intent is not
an upgrade procedure.
