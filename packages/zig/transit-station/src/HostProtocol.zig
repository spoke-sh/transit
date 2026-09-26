//! Line-framed transport for runtimes using an isolated native host process.
const abi = @import("Abi.zig");
const p = @import("transit_station").protocol;
const raw = @import("client_abi").host;
pub const version = 1;
pub const Config = struct { url: []const u8, seed_file: ?[]const u8 = null, server: ?abi.Config = null, growing_server: ?abi.growing.Config = null, timeout_ms: u32 = 5000 };
pub const Request = union(enum) {
    hello: void,
    next: u64,
    apply: abi.actions.Action,
    finish: bool,
    pending: void,
    growing_capabilities: void,
    growing_prepare: u64,
    growing_dispatch: void,
    growing_apply: struct { scope: u64, action: abi.growing.actions.Action },
    growing_finish: struct { scope: u64, failed: bool },
    growing_discard: u64,
    growing_pending: void,
    arrow_cell: struct { ipc: []const u8, row: u32, column: u32 },
    frame: struct { kind: u32, correlation: []const u8, payload: p.Value },
    prepare: raw.Prepare,
    call: []const u8,
    metadata: []const u8,
    client_capabilities: void,
};
