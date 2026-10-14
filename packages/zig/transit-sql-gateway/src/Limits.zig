//! Deployment/session/work bounds; none limits durable Table cardinality.
const Self = @This();
pub const statement_bytes = 4096;
pub const max_frame_bytes = 4 * 1024 * 1024 + 8192;
pub const max_parameters = 256;
pub const max_name_bytes = 63;
pub const max_accounts = 32;
connections: u16 = 64,
connections_per_account: u8 = 8,
authentications: u8 = 4,
prepared_statements: u8 = 16,
portals: u8 = 4,
frame_bytes: u32 = max_frame_bytes,
cycle_bytes: u32 = max_frame_bytes,
cycle_messages: u16 = 64,
session_bytes: u32 = 16 * 1024 * 1024,
handshake_ms: u32 = 5000,
command_ms: u32 = 30000,
idle_ms: u32 = 30000,
write_ms: u32 = 5000,
pub fn validate(self: Self) !void {
    if (self.connections == 0 or self.connections > 256 or self.connections_per_account == 0 or self.connections_per_account > self.connections or self.authentications == 0 or self.authentications > 16 or self.authentications > self.connections) return error.InvalidGatewayLimits;
    if (self.prepared_statements == 0 or self.prepared_statements > 64 or self.portals == 0 or self.portals > 8) return error.InvalidGatewayLimits;
    if (self.frame_bytes < statement_bytes + 16 or self.frame_bytes > max_frame_bytes or self.cycle_bytes < self.frame_bytes or self.cycle_bytes > 2 * max_frame_bytes or self.cycle_messages == 0 or self.cycle_messages > 256) return error.InvalidGatewayLimits;
    if (self.session_bytes < self.cycle_bytes or self.session_bytes > 64 * 1024 * 1024) return error.InvalidGatewayLimits;
    inline for (.{ self.handshake_ms, self.command_ms, self.idle_ms, self.write_ms }) |ms| if (ms == 0 or ms > 270000) return error.InvalidGatewayLimits;
}
test "limits reject impossible and unbounded work profiles" {
    const t = @import("std").testing;
    try (Self{}).validate();
    try t.expectError(error.InvalidGatewayLimits, (Self{ .frame_bytes = max_frame_bytes + 1 }).validate());
    try t.expectError(error.InvalidGatewayLimits, (Self{ .session_bytes = 1 }).validate());
    try t.expectError(error.InvalidGatewayLimits, (Self{ .command_ms = 300001 }).validate());
}
