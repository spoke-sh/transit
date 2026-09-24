//! Provider-neutral binding evidence. Opaque identities are interpreted only by
//! the selected runtime adapter. They never confer execution rights themselves.
const std = @import("std");
pub const Binding = struct {
    revision: u64,
    operation: u64,
    instance: [16]u8,
    resource: [32]u8,
    workload: [32]u8,
    incarnation: ?[16]u8 = null,
    desired: enum { running, stopped },
    phase: enum { pending, unknown, ready, stopped } = .pending,
    /// Non-null until a recorded workload switch has been observed stopped.
    /// The Actor/resource identity is unchanged; this grants no execution right.
    upgrade_from: ?[32]u8 = null,
    activation: ?Activation = null,
    last_worker_incarnation: ?[16]u8 = null,

    pub fn jsonStringify(self: Binding, out: anytype) !void {
        // Preserve pre-upgrade checkpoint bytes when no upgrade is outstanding.
        // Bindings are response/checkpoint values, never signed request bodies.
        try out.beginObject();
        inline for (@typeInfo(Binding).@"struct".field_names) |name| {
            if (comptime std.mem.eql(u8, name, "upgrade_from")) {
                if (self.upgrade_from != null) {
                    try out.objectField(name);
                    try out.write(self.upgrade_from);
                }
            } else {
                try out.objectField(name);
                try out.write(@field(self, name));
            }
        }
        try out.endObject();
    }
};
pub const Activation = struct { worker_incarnation: [16]u8, generation: u64 };
pub const Intent = struct {
    pid: u64,
    expected_revision: u64,
    instance: [16]u8,
    resource: [32]u8,
    workload: [32]u8,
    desired: enum { running, stopped } = .running,
};
pub const Observation = struct {
    pid: u64,
    revision: u64,
    operation: u64,
    incarnation: ?[16]u8,
    outcome: enum { ready, unknown, stopped },
};
/// Same application contract and opaque state, on the existing provider resource.
/// The old activation must already be fenced and observed stopped. Provider
/// switching and fresh activation are separate, recoverable operations.
pub const Upgrade = struct {
    pid: u64,
    expected_revision: u64,
    expected_workload: [32]u8,
    workload: [32]u8,
    expected_code: u32,
    expected_state_revision: u64,
};
pub const Activate = struct {
    pid: u64,
    revision: u64,
    expected_generation: u64,
    worker: u8,
    public_key: [32]u8,
    worker_incarnation: [16]u8,
};
