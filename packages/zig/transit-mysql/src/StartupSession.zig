//! Pure classic-protocol connection admission. The host owns credential and
//! crypto work, TLS and session publication; none can be inferred from bytes.
const std = @import("std");
const m = @import("root.zig");
const w = m.wire.Startup;
const Self = @This();
pub const Options = struct { tls: w.Tls, generation: u64, id: u32, nonce: [20]u8 };
const State = enum { greeting, header, body, response, upgrade, lookup, selected, password_header, password, verified, admit, admitted, output, failed, done };
options: Options,
continuation: w.Continuation,
backend: m.Backend,
state: State = .greeting,
after_output: State = .done,
header: [4]u8 = @splat(0),
bytes: [8192]u8 = @splat(0),
length: usize = 0,
secure: bool = false,
prefix: ?m.Handshake.Prefix = null,
account: w.Name = .{},
database: w.Name = .{},
failure: ?anyerror = null,
pub fn init(allocator: std.mem.Allocator, options: Options) !Self {
    for (options.nonce) |byte| if (byte == 0) return error.InvalidAuthentication;
    var result: Self = .{ .options = options, .continuation = try .init(options.generation), .backend = .{ .allocator = allocator, .maximum = 8192 } };
    result.backend.bytes = try .initCapacity(allocator, 2048);
    return result;
}
pub fn deinit(self: *Self) void {
    self.abort(error.WireSessionClosed);
    self.erase();
    self.backend.deinit();
}
pub fn erase(self: *Self) void {
    std.crypto.secureZero(u8, &self.bytes);
}
pub fn abort(self: *Self, err: anyerror) void {
    self.continuation.abort(err);
}
pub fn complete(self: *Self, token: w.Token, result: w.Result) !void {
    try self.continuation.complete(token, result);
}
fn send(self: *Self, bytes: []const u8, next: State) !void {
    self.after_output = next;
    self.state = .output;
    try self.continuation.issue(.{ .output = bytes });
}
fn fail(self: *Self, err: anyerror, message: []const u8) !void {
    self.failure = err;
    try self.send(try self.backend.failure(1045, "28000".*, message), .failed);
}
fn input(self: *Self, bytes: []u8, next: State) !void {
    self.state = next;
    try self.continuation.issue(.{ .input = bytes });
}
pub fn poll(self: *Self) !?w.Event {
    return self.advance() catch |err| {
        self.abort(err);
        return err;
    };
}
fn advance(self: *Self) !?w.Event {
    while (true) {
        if (try self.continuation.event()) |event| return event;
        switch (self.state) {
            .greeting => {
                const capabilities = if (self.options.tls == .disabled) m.Handshake.capabilities & ~m.Handshake.ssl else m.Handshake.capabilities;
                try self.send(try self.backend.greeting(self.options.id, self.options.nonce, capabilities), .header);
            },
            .header => {
                self.erase();
                try self.input(&self.header, .body);
            },
            .body => {
                try self.continuation.ok();
                self.length = try m.Frame.frameSize(&self.header, self.backend.sequence, 8192) - 4;
                if (self.length == 0) return error.InvalidAuthentication;
                self.backend.sequence +%= 1;
                try self.input(self.bytes[0..self.length], .response);
            },
            .response => {
                try self.continuation.ok();
                if (self.prefix == null and self.length == 32) {
                    self.prefix = try m.Handshake.upgrade(self.bytes[0..self.length]);
                    if (self.options.tls == .disabled) return error.TlsRequired;
                    self.state = .upgrade;
                    try self.continuation.issue(.upgrade);
                    continue;
                }
                if (self.options.tls == .required and !self.secure) {
                    try self.fail(error.TlsRequired, "TLS is required");
                    continue;
                }
                if (self.prefix == null) self.prefix = try m.Handshake.plaintext(self.bytes[0..self.length]);
                const response = try m.Handshake.response(self.bytes[0..self.length], self.prefix.?);
                try self.account.set(response.account);
                try self.database.set(response.database orelse return error.GatewayDatabaseDenied);
                self.state = .lookup;
            },
            .upgrade => {
                try self.continuation.ok();
                self.secure = true;
                self.state = .header;
            },
            .lookup => {
                self.erase();
                self.state = .selected;
                try self.continuation.issue(.{ .lookup = .{ .account = self.account.slice(), .database = self.database.slice() } });
            },
            .selected => {
                const result = try self.continuation.take();
                if (result == .failed) {
                    try self.fail(result.failed, "Authentication failed");
                    continue;
                }
                if (result.method == .password) {
                    if (!self.secure) {
                        try self.fail(error.TlsRequired, "Password authentication requires TLS");
                        continue;
                    }
                    try self.send(try self.backend.fullAuthentication(), .password_header);
                } else self.state = .admit;
            },
            .password_header => try self.input(&self.header, .password),
            .password => {
                try self.continuation.ok();
                self.length = try m.Frame.frameSize(&self.header, self.backend.sequence, m.wire.Authentication.max_password_bytes + 1) - 4;
                if (self.length == 0) return error.InvalidAuthentication;
                self.backend.sequence +%= 1;
                try self.input(self.bytes[0..self.length], .verified);
            },
            .verified => {
                try self.continuation.ok();
                self.state = .admit;
                try self.continuation.issue(.{ .password = try m.Handshake.password(self.bytes[0..self.length]) });
            },
            .admit => {
                if (self.continuation.result != null) {
                    const result = try self.continuation.take();
                    self.erase();
                    if (result == .failed) {
                        try self.fail(result.failed, "Authentication failed");
                        continue;
                    }
                }
                self.state = .admitted;
                try self.continuation.issue(.admit);
            },
            .admitted => {
                const result = try self.continuation.take();
                if (result == .failed) {
                    try self.fail(result.failed, "Account or database access denied");
                    continue;
                }
                try self.send(try self.backend.ok(0, false), .done);
            },
            .output => {
                try self.continuation.ok();
                self.state = self.after_output;
            },
            .failed => return self.failure.?,
            .done => {
                self.erase();
                return null;
            },
        }
    }
}
