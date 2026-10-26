# Working on operation proof drivers

Follow [test instructions](../AGENTS.md). These Zig modules compose public client
operations for cross-component checks; their root build targets and
[test recipes](../../tasks/test.just) own execution. Trace a module's imports and
build target before adding a scenario.

Keep drivers thin over owning packages. They must not become another catalog,
authorization or SQL recovery implementation. Use independent expected outcomes,
preserve original operation identity and make memory/buffer lifetimes explicit.
Run the affected built driver through its real parent harness. Compilation alone
does not qualify a public caller or failure schedule.
