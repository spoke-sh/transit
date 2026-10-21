//! One bounded socket with an optional TLS session. Protocol negotiation owns
//! the upgrade; framing and output retain the same deadlines in both modes.
const tls = @import("transit_tls_server");
const Self = @This();
transport: *tls.Transport,
secure: ?tls.Session = null,
pub fn upgrade(self: *Self, context: *const tls.Context) !void {
    self.secure = try tls.Session.accept(context, self.transport);
}
pub fn readExact(self: *Self, bytes: []u8) !void {
    if (self.secure) |*session| {
        var offset: usize = 0;
        while (offset < bytes.len) {
            const count = try session.read(bytes[offset..]);
            if (count == 0) return error.EndOfStream;
            try self.transport.inputStarted();
            offset += count;
        }
        return;
    }
    return self.transport.readExact(bytes);
}
pub fn writeAll(self: *Self, bytes: []const u8) !void {
    if (self.secure) |*session| return session.writeAll(bytes);
    return self.transport.writeAll(bytes);
}
pub fn finish(self: *Self) !void {
    if (self.secure) |*session| try session.finish();
}
pub fn deinit(self: *Self) void {
    if (self.secure) |*session| session.deinit();
}
