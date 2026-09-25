//! Line-framed transport for runtimes using an isolated native host process.
const abi = @import("Abi.zig");
const p = @import("transit_station").protocol;
pub const version = 1;
pub const Config = struct { url: []const u8, seed_file: ?[]const u8 = null, server: ?abi.Config = null, timeout_ms: u32 = 5000 };
pub const Request = union(enum) {
    hello: void,
    next: u64,
    apply: abi.actions.Action,
    finish: bool,
    pending: void,
    arrow_cell: struct { ipc: []const u8, row: u32, column: u32 },
    frame: struct { kind: u32, correlation: []const u8, payload: p.Value },
    prepare: struct { kind: u32, seed_file: []const u8, document: []const u8 },
    call: []const u8,
};
