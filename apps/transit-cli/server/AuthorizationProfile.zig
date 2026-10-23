//! Private connection emitted for explicit native authorization callers.
version: u8,
connection: @import("transit_query").wire.AuthorizationBridge.Connection,
url: []const u8,
seed_file: []const u8,
request_timeout_ms: u32 = 5000,
