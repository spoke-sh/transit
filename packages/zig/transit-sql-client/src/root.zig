//! Public HTTP/TLS and Unix SQL client. No native signing key or server runtime.
pub const protocol = @import("transit_sql_protocol");
pub const results = @import("transit_sql_results");
pub const Executor = @import("Executor.zig");
pub const Client = @import("Client.zig");
pub const Pending = @import("Pending.zig");
pub const Discovery = @import("Discovery.zig");
test {
    _ = @import("NativeResult.zig");
    @import("std").testing.refAllDecls(@This());
}
