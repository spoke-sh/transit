# Separate build and local iteration

The package's own `build.zig` compiles `transit-work-items` (the data worker) and
`work-items` (the domain operator) against public Transit package dependencies.
Follow [local application installation](../../../apps/transit-cli/docs/applications.md)
to start an application-enabled neighborhood and export writer, inspector and operator
connections. Ordinary application commands use those scoped credentials. The
separate `provision-authority` command takes an explicit administrator connection
and uses public authorization operations; no command edits manager records.

`work-items manifest /absolute/path/to/transit-work-items` emits the declaration.
Its `work-items-v1` data role owns one resource, accepts ledger initialization,
and maps the public bootstrap's named bindings into application-owned
configuration. The operator, writer and inspector receive separate scoped keys.
The worker uses a fresh in-memory key and the public growing ownership handshake.
Catalog initialization follows explicit authorization provisioning after those
identities exist. Worker replacement reads the retained catalog configuration;
it does not create roles, register domains or restore grants.

```sh
transit app connect --config /absolute/local-transit/management.json \
  --application work-items --caller operator --output operator.json
transit app connect --config /absolute/local-transit/management.json \
  --application work-items --caller writer --output writer.json
transit app connect --config /absolute/local-transit/management.json \
  --application work-items --caller inspector --output inspector.json
mkdir -m 700 work-items-authorization
./zig-out/bin/work-items provision-authority admin.json \
  operator.json writer.json inspector.json work-items-authorization catalog-authority.json
./zig-out/bin/work-items operator.json initialize-catalog catalog-initialize.json catalog-authority.json
./zig-out/bin/work-items operator.json authorize authorize.json
./zig-out/bin/work-items operator.json prepare-table initial.json 1
./zig-out/bin/work-items writer.json put first-put.json 1 0
./zig-out/bin/work-items inspector.json inspect
./zig-out/bin/work-items operator.json prepare-table target.json 2
./zig-out/bin/work-items operator.json begin begin.json
./zig-out/bin/work-items operator.json step step-1.json
./zig-out/bin/work-items operator.json inspect
```

`admin.json` uses the public `transit auth` configuration: version 1, native URL,
current-definition connection with the application's realm and principal 0,
and an explicit root `seed_file`. Keep it private. Provisioning binds the three
exported callers to their current native roles, creates an ordinary NOLOGIN owner
role and grants the operator INHERIT/SET membership. It registers the database,
schema and Table domains with the data worker as registrar. Future Tables grant
the writer SELECT/INSERT/UPDATE and the inspector SELECT, plus database CONNECT
and schema USAGE. Existing native resource-read grants remain explicit broad
application access; these exports are not Table-isolated service clients.

Provisioning records each exact authorization change in the private directory
before submission. Repeat the identical command and directory after an unknown
outcome. Completed steps retain their original outcomes and do not reapply
revoked grants. The fourteen changes publish separately; a failure can leave
visible partial provisioning. A competing policy change fails explicitly. Each
invocation advances at most 128 native steps per change; `AuthorizationStillPending`
requires repeating that same command. Serialize other root commands with this
workflow. The returned profile contains object identities, not credentials.

Initial Table preparation selects the registered ordinary owner role and waits
for publication. A courier must deliver recorded self-messages;
the application-enabled local neighborhood supplies it. Each new step needs a
new recovery filename. After an unknown outcome, repeat
the exact command with its existing filename. The saved command includes the
migration ordinal and arguments; inspecting newer progress never silently changes
an uncertain step. Begin pauses ordinary writes. Steps stage one transformed row at a time,
then verify every target row and activate the data contract. Inspect exposes the
head, retained migration progress and decoded cursor separately. After epoch 2 is
visible, the operator explicitly releases writes:

```sh
./zig-out/bin/work-items operator.json release release.json
```

The selected [migration](migration.md) transforms integer states 0/1 into 10/20.
`inspect` checks current SELECT while reading bounded Table row cursors and,
after activation, checks each target
against the retained source. It refuses after 1000 row-cursor steps. This verification is
specific to the example and its unchanged source snapshot; it is not a generic
post-migration query or permission to rewrite arbitrary future values.

A compatible replacement can occur between migration steps. Use the current
role revision as the deployment compare-and-set value; preserve the declared
`work-items-v1` contract and application configuration. Stable PID/resource IDs,
data epoch, migration ordinal and ownership generation remain separate. Physical
worker readiness does not release writes or declare migration completion.

The example is deliberately small: one writer resource, four mutations per turn,
19-row integration qualification and explicit command recovery files. It does
not select migration steps automatically, arbitrary transforms, distributed
placement, multi-resource atomicity or a language-specific SDK host beyond Zig.
