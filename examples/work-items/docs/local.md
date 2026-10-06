# Separate build and local iteration

The package's own `build.zig` compiles `transit-work-items` (the data worker) and
`work-items` (the domain operator) against public Transit package dependencies.
Follow [local application installation](../../../apps/transit-cli/docs/applications.md)
to start an application-enabled neighborhood and export writer, inspector and operator
connections. No application command uses the realm root key or edits manager
records.

`work-items manifest /absolute/path/to/transit-work-items` emits the declaration.
Its `work-items-v1` data role owns one resource, accepts explicit ledger/catalog initialization and initial Table preparation
frames, and maps the public bootstrap's named bindings into application-owned
configuration. The operator, writer and inspector receive separate scoped keys.
The worker uses a fresh in-memory key and the public growing ownership handshake.

```sh
transit app connect --config /absolute/local-transit/management.json \
  --application work-items --caller operator --output operator.json
./zig-out/bin/work-items operator.json authorize authorize.json
./zig-out/bin/work-items operator.json prepare-table initial.json 1
./zig-out/bin/work-items writer.json put first-put.json 1 0
./zig-out/bin/work-items inspector.json inspect
./zig-out/bin/work-items operator.json prepare-table target.json 2
./zig-out/bin/work-items operator.json begin begin.json
./zig-out/bin/work-items operator.json step step-1.json
./zig-out/bin/work-items operator.json inspect
```

Initial Table preparation reconciles the creation already admitted by installation
and waits for its publication. A courier must deliver recorded self-messages;
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
`inspect` reads bounded Table row cursors and, after activation, checks each target
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
