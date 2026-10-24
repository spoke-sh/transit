//! Private operator profile shared by placement and the signed control consumer.
const g = @import("root.zig");
version: u8,
definition: g.catalog.protocol.Growth.Definition,
native_url: []const u8,
ledger: g.Ledger.Configuration,
control_key_file: []const u8,
table_key_file: []const u8,
pending_file: []const u8,
timeout_ms: u32 = 30000,
