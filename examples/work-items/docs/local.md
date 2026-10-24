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
Data binding follows explicit authorization provisioning after those
identities and the configured direct Table service exist. Worker replacement reads the retained data binding;
it does not create roles, register domains or restore grants.

Obtain the three named connections through management `connect` requests and
save the responses as `operator.json`, `writer.json` and `inspector.json` before
running these domain commands:

```sh
mkdir -m 700 work-items-authorization
./zig-out/bin/work-items provision-authority admin.json \
  operator.json writer.json inspector.json work-items-authorization data-target.json data-binding.json
./zig-out/bin/work-items operator.json initialize-catalog catalog-initialize.json data-binding.json
./zig-out/bin/work-items operator.json authorize authorize.json
./zig-out/bin/work-items operator.json prepare-table initial.json 1
./zig-out/bin/work-items writer.json put first-put.json 1 0
./zig-out/bin/work-items inspector.json inspect
./zig-out/bin/work-items operator.json prepare-table target.json 2
./zig-out/bin/work-items operator.json begin begin.json
./zig-out/bin/work-items operator.json step step-1.json
./zig-out/bin/work-items operator.json inspect
```

`admin.json` uses the shared authorization connection profile: version 1, native URL,
current-definition connection with the application's realm and principal 0,
and an explicit root `seed_file`. Keep it private. Provisioning binds the three
exported callers to their current native roles and creates an ordinary NOLOGIN
Table owner role. It grants the operator INHERIT/SET membership and the explicitly named worker
login role SET membership without inheritance. The worker selects that role only
for direct data calls, preserving its native execution permission mask. The
owner role receives database CONNECT and namespace USAGE/CREATE. Future
Tables owned by this role grant the writer SELECT/INSERT/UPDATE and inspector
SELECT. Native application resource reads remain a separate permission.

`data-target.json` contains the current `definition`, a direct `connection`
(`scope`, `branch`, `audience`, the catalog caller's `principal` and optional
selected `role`), that caller's `seed_file`, `namespace`,
`first_object` and `worker_login_role`. Choose these from the configured data
service and current native authorization inspection. Keep the file private.
The catalog credential must have CONNECT and namespace visibility; root
administration does not implicitly grant those data privileges or role selection.
The `worker_login_role` must be the
worker's existing enabled login role; supplying another role grants that role
access and leaves the worker unable to run. Provisioning checks the existing
service and namespace. It does not create domains, a catalog or a namespace.
The service's configured registrar owns native Table registration. Reserve the
application's global Table IDs and names within this namespace explicitly.

Provisioning records each exact authorization change in the private directory
before submission. Repeat the identical command and directory after an unknown
outcome. Completed steps retain their original outcomes and do not reapply
revoked grants. The twelve changes publish separately; a failure can leave
visible partial provisioning. A competing policy change fails explicitly. Each
invocation advances at most 128 native steps per change; `AuthorizationStillPending`
requires repeating that same command. Serialize other root commands with this
workflow. The returned binding contains object identities, not credentials.

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
against the original source basis. It refuses after 1000 row-cursor steps. This verification is
specific to the example and unchanged logical source and target positions; it is not a generic
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
