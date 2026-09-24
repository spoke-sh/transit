//! Generic process controls. Behavior initialization and restart policy live above Transit.
const p = @import("root.zig");
pub const max_required = 4;
pub const Control = struct {
    phase: enum { initializing, ready, suspended } = .initializing,
    required: [max_required]?p.Value = @splat(null),
    resume_before_ms: ?u64 = null,
};
pub const Create = struct {
    code: u32 = 1,
    initial_state: p.Value = .{},
    deadline_ms: ?u64 = null,
    settle_before_ms: ?u64 = null,
    allow_trim: bool = false,
    collect_catalog: bool = false,
    required: [max_required]?p.Value = @splat(null),
};
pub const Fence = struct { pid: u64, expected_generation: u64 };
pub const Command = union(enum) {
    create: Create,
    initialize: Fence,
    @"suspend": struct { pid: u64, expected_generation: u64, resume_before_ms: u64 },
    @"resume": Fence,
    retry: struct { pid: u64, expected_generation: u64, failure: u64 },
    expire_suspension: u64,
};
pub fn pid(command: Command) ?u64 {
    return switch (command) {
        .create => null,
        .expire_suspension => |id| id,
        inline else => |c| c.pid,
    };
}
pub fn validate(command: Command) !void {
    if (command == .create) {
        const c = command.create;
        try c.initial_state.validate();
        for (c.required, 0..) |slot, index| if (slot) |name| {
            try p.State.key(name);
            for (c.required[0..index]) |previous| if (previous) |other| if (name.eql(other)) return error.InvalidStateKey;
        };
    }
}
