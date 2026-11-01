//! Ephemeral connection admission events. Credentials, TLS, randomness and
//! session authority stay with the host. All borrows end only after it joins.
const std = @import("std");
pub const Token = @import("WireSession.zig").Token;
pub const Tls = enum { disabled, optional, required };
pub const Method = enum { trust, password };
pub const Selection = struct { account: []const u8, database: []const u8 };
pub const Request = union(enum) {
    input: []u8,
    output: []const u8,
    upgrade,
    lookup: Selection,
    scram_start: []const u8,
    scram_finish: []const u8,
    password: []const u8,
    /// Recheck credentials and authority, reserve the session and command
    /// buffers before reporting success. Failure must release partial admission.
    admit,
    cancel: [8]u8,
};
pub const Result = union(enum) {
    ok,
    received: usize,
    written: usize,
    method: Method,
    challenge: []const u8,
    proof: [46]u8,
    failed: anyerror,
};
pub const Event = struct { token: Token, request: Request };
pub const Name = struct {
    bytes: [63]u8 = @splat(0),
    len: u8 = 0,
    pub fn set(self: *Name, value: []const u8) !void {
        if (value.len == 0 or value.len > self.bytes.len) return error.InvalidAuthentication;
        @memcpy(self.bytes[0..value.len], value);
        self.len = @intCast(value.len);
    }
    pub fn slice(self: *const Name) []const u8 {
        return self.bytes[0..self.len];
    }
};
pub const Continuation = struct {
    generation: u64,
    sequence: u64 = 0,
    pending: ?Request = null,
    result: ?Result = null,
    offset: usize = 0,
    closed: ?anyerror = null,
    pub fn init(generation: u64) !Continuation {
        if (generation == 0) return error.InvalidWireGeneration;
        return .{ .generation = generation };
    }
    fn advance(self: *Continuation) !void {
        if (self.sequence == std.math.maxInt(u64)) return error.WireSessionExhausted;
        self.sequence += 1;
    }
    pub fn issue(self: *Continuation, request: Request) !void {
        if (self.closed) |err| return err;
        if (self.pending != null or self.result != null) return error.WireRequestPending;
        if (request == .input and request.input.len == 0) return error.InvalidWireMessage;
        if (request == .output and request.output.len == 0) return error.InvalidWireOutput;
        try self.advance();
        self.offset = 0;
        self.pending = request;
    }
    pub fn event(self: *const Continuation) !?Event {
        if (self.closed) |err| return err;
        var request = self.pending orelse return null;
        switch (request) {
            .input => |bytes| request = .{ .input = bytes[self.offset..] },
            .output => |bytes| request = .{ .output = bytes[self.offset..] },
            else => {},
        }
        return .{ .token = .{ .generation = self.generation, .sequence = self.sequence }, .request = request };
    }
    pub fn complete(self: *Continuation, token: Token, result: Result) !void {
        if (self.closed != null or token.generation != self.generation or token.sequence != self.sequence or self.pending == null)
            return error.StaleWireCompletion;
        const request = self.pending.?;
        if (request == .input or request == .output) {
            if (result == .failed) {
                self.abort(result.failed);
                return;
            }
            const input = request == .input;
            if ((input and result != .received) or (!input and result != .written)) return error.UnexpectedWireCompletion;
            const count = if (input) result.received else result.written;
            const remaining = (if (input) request.input.len else request.output.len) - self.offset;
            if (count == 0 or count > remaining) return error.InvalidWireDrain;
            try self.advance();
            self.offset += count;
            if (count != remaining) return;
            self.pending = null;
            self.result = .ok;
            return;
        }
        const expected: std.meta.Tag(Result) = switch (request) {
            .lookup => .method,
            .scram_start => .challenge,
            .scram_finish => .proof,
            else => .ok,
        };
        if (result != .failed and std.meta.activeTag(result) != expected) return error.UnexpectedWireCompletion;
        // A failed upgrade can never authorize plaintext fallback or another
        // frame on a transport with uncertain TLS state.
        if (request == .upgrade and result == .failed) {
            self.abort(result.failed);
            return;
        }
        self.pending = null;
        self.result = result;
    }
    pub fn take(self: *Continuation) !Result {
        const result = self.result orelse return error.WireCompletionMissing;
        self.result = null;
        return result;
    }
    pub fn ok(self: *Continuation) !void {
        const result = try self.take();
        if (result == .failed) return result.failed;
        if (result != .ok) return error.UnexpectedWireCompletion;
    }
    /// Fence completions immediately; erase/free only after the host has joined
    /// every input/output/credential borrower.
    pub fn abort(self: *Continuation, err: anyerror) void {
        self.closed = err;
        self.pending = null;
        self.result = null;
    }
};

test "startup input and output fence partial, duplicate and cancelled completions" {
    const t = std.testing;
    var bytes: [3]u8 = undefined;
    for ([_]bool{ false, true }) |input| {
        var c = try Continuation.init(9);
        try c.issue(if (input) .{ .input = &bytes } else .{ .output = "abc" });
        const first = (try c.event()).?;
        try t.expectError(error.StaleWireCompletion, c.complete(.{ .generation = 8, .sequence = first.token.sequence }, .{ .failed = error.Cancelled }));
        try t.expectError(error.InvalidWireDrain, c.complete(first.token, if (input) .{ .received = 0 } else .{ .written = 0 }));
        try c.complete(first.token, if (input) .{ .received = 1 } else .{ .written = 1 });
        try t.expectError(error.StaleWireCompletion, c.complete(first.token, .{ .failed = error.Cancelled }));
        const second = (try c.event()).?;
        try t.expectEqual(@as(usize, 2), if (input) second.request.input.len else second.request.output.len);
        c.abort(error.Cancelled);
        try t.expectError(error.StaleWireCompletion, c.complete(second.token, .{ .failed = error.Cancelled }));
        try t.expectError(error.Cancelled, c.event());
    }
}
