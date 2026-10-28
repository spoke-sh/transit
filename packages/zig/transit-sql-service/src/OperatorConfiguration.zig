//! Private operator profile shared by placement and the signed control consumer.
const g = @import("root.zig");
version: u8,
definition: g.catalog.protocol.Growth.Definition,
native_url: []const u8,
execution: g.DatabaseAccount.Configuration,
table_key_file: []const u8,
timeout_ms: u32 = 30000,
