//! One fenced host request or borrowed output at a time. This is an in-process
//! continuation contract, not a new wire protocol or durable operation identity.
const std = @import("std");
const w = @import("Wire.zig");
pub const Handle = u64;
pub const Values = []const ?w.fuze.Types.Values.Atom;
pub const Prepared = struct {
    handle: Handle,
    parameters: []const w.fuze.Types.Type,
    fields: []const w.fuze.Types.Field,
    mutation: bool,
    empty: bool,
    /// Typed command tag for a row result; mutation still controls admission.
    row_command: w.results.Command = .select,
};
pub const Diagnostic = struct { state: [5]u8, message: []const u8, detail: ?[]const u8 };
pub const Bound = struct { prepared: Handle, values: Values };
pub const Guard = union(enum) { none, prepared: Handle, read: Handle, completion: Handle };
pub const Output = struct { bytes: []const u8, guard: Guard = .none };
pub const Request = union(enum) {
    begin,
    end,
    status,
    prepare: []const u8,
    destroy: Handle,
    validate: Handle,
    bind: Bound,
    open_read: Bound,
    close_read: Handle,
    next_batch: struct { read: Handle, maximum: u8 },
    write: Bound,
    select_database: []const u8,
    reset,
    diagnostic: anyerror,
    output: Output,
};
pub const Result = union(enum) {
    ok,
    status: w.results.Transaction.SessionState,
    prepared: Prepared,
    read: Handle,
    batch: w.ReadBatch,
    completion: w.results.CommandCompletion,
    diagnostic: Diagnostic,
    written: usize,
    /// For output a write was attempted: close, never append an error frame to
    /// a possibly transmitted prefix.
    failed: anyerror,
    /// Authority failed before this attempt wrote bytes. A refusal after any
    /// partial drain also closes; a fresh output may become a protocol error.
    refused: anyerror,
};
pub const Token = struct { generation: u64, sequence: u64 };
pub const Event = struct { token: Token, request: Request };

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
    pub fn issue(self: *Continuation, request: Request) !void {
        if (self.closed) |err| return err;
        if (self.pending != null or self.result != null) return error.WireRequestPending;
        try self.advance();
        if (request == .output and request.output.bytes.len == 0) return error.InvalidWireOutput;
        self.pending = request;
        self.offset = 0;
    }
    fn advance(self: *Continuation) !void {
        if (self.sequence == std.math.maxInt(u64)) return error.WireSessionExhausted;
        self.sequence += 1;
    }
    pub fn event(self: *const Continuation) !?Event {
        if (self.closed) |err| return err;
        var request = self.pending orelse return null;
        if (request == .output) request.output.bytes = request.output.bytes[self.offset..];
        return .{ .token = .{ .generation = self.generation, .sequence = self.sequence }, .request = request };
    }
    pub fn complete(self: *Continuation, token: Token, result: Result) !void {
        if (self.closed != null or token.generation != self.generation or token.sequence != self.sequence or self.pending == null)
            return error.StaleWireCompletion;
        const request = self.pending.?;
        if (request == .output) switch (result) {
            .written => |count| {
                const remaining = request.output.bytes.len - self.offset;
                if (count == 0 or count > remaining) return error.InvalidWireDrain;
                // Each fragment gets a fresh token; duplicate completion must
                // never consume the following fragment of the same frame.
                try self.advance();
                self.offset += count;
                if (count != remaining) return;
                self.pending = null;
                self.result = .ok;
                return;
            },
            .failed => |err| {
                self.abort(err);
                return;
            },
            .refused => |err| {
                if (self.offset != 0) {
                    self.abort(err);
                    return;
                }
                self.pending = null;
                self.result = .{ .failed = err };
                return;
            },
            else => return error.UnexpectedWireCompletion,
        };
        const expected: std.meta.Tag(Result) = switch (request) {
            .begin, .end, .status => .status,
            .prepare => .prepared,
            .open_read => .read,
            .next_batch => .batch,
            .write => .completion,
            .diagnostic => .diagnostic,
            else => .ok,
        };
        if (result != .failed and std.meta.activeTag(result) != expected) return error.UnexpectedWireCompletion;
        self.pending = null;
        self.result = result;
    }
    pub fn take(self: *Continuation) !Result {
        const result = self.result orelse return error.WireCompletionMissing;
        self.result = null;
        if (result == .failed) return result.failed;
        return result;
    }
    /// Suppress execution/output. Borrowed requests remain alive until the host
    /// joins outstanding work; abort is not durable rollback.
    pub fn abort(self: *Continuation, err: anyerror) void {
        self.closed = err;
        self.pending = null;
        self.result = null;
    }
};

test "continuations fence connections, duplicate completions and partial drains" {
    const t = std.testing;
    var c = try Continuation.init(7);
    try c.issue(.{ .output = .{ .bytes = "abc" } });
    const first = (try c.event()).?;
    try t.expectError(error.StaleWireCompletion, c.complete(.{ .generation = 8, .sequence = first.token.sequence }, .{ .written = 1 }));
    try t.expectError(error.InvalidWireDrain, c.complete(first.token, .{ .written = 0 }));
    try c.complete(first.token, .{ .written = 1 });
    try t.expectError(error.StaleWireCompletion, c.complete(first.token, .{ .written = 1 }));
    const second = (try c.event()).?;
    try t.expectEqualStrings("bc", second.request.output.bytes);
    try c.complete(second.token, .{ .written = 2 });
    try t.expect((try c.take()) == .ok);
    try c.issue(.{ .prepare = "SELECT 1" });
    const pending = (try c.event()).?;
    c.abort(error.Cancelled);
    try t.expectError(error.StaleWireCompletion, c.complete(pending.token, .{ .failed = error.Cancelled }));
    try t.expectError(error.Cancelled, c.event());
}

test "output refusal is recoverable only before bytes; I/O failure always closes" {
    const t = std.testing;
    for ([_]bool{ false, true }) |partial| {
        var c = try Continuation.init(1);
        try c.issue(.{ .output = .{ .bytes = "abc", .guard = .{ .read = 1 } } });
        if (partial) try c.complete((try c.event()).?.token, .{ .written = 1 });
        try c.complete((try c.event()).?.token, .{ .refused = error.AccessDenied });
        if (partial) try t.expectError(error.AccessDenied, c.event()) else try t.expectError(error.AccessDenied, c.take());
    }
    var c = try Continuation.init(1);
    try c.issue(.{ .output = .{ .bytes = "abc" } });
    try c.complete((try c.event()).?.token, .{ .failed = error.BrokenPipe });
    try t.expectError(error.BrokenPipe, c.event());
}
