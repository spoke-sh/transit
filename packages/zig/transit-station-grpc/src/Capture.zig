//! Adapter capture records. The sink must seal each record before returning;
//! this object never dispatches and never submits a kernel observation.
const std = @import("std");
const rpc = @import("root.zig");
const x = rpc.exchange;
const Self = @This();
pub const Kind = enum(u32) { request_metadata = 1, request_batch = 2, endpoint_policy = 3, initial_metadata = 4, response_message = 5, response_body = 6, half_close = 7, trailers = 8, timing = 9, omission = 10, completion = 11 };
pub const Message = struct {
    pub const magic = "GRM1";
    index: u32,
    length: u32,
    digest: [32]u8,
    pub fn validate(self: Message) !void {
        if (self.index >= 64 or self.length > 16384) return error.InvalidGrpcCapture;
    }
};
pub const HalfClose = struct {
    pub const magic = "GRS1";
    messages: u32,
    wire_bytes: u32,
    pub fn validate(self: HalfClose) !void {
        if (self.messages > 64 or self.wire_bytes > 65536 or self.wire_bytes < self.messages * 5) return error.InvalidGrpcCapture;
    }
};
pub const Timing = struct {
    pub const magic = "GRT1";
    started_ms: u64,
    elapsed_ns: u64,
    pub fn validate(self: Timing) !void {
        if (self.started_ms == 0) return error.InvalidGrpcCapture;
    }
};
pub const Omission = struct {
    pub const magic = "GRO1";
    response_fields: u32,
    request_secrets: u32,
    pub fn validate(self: Omission) !void {
        if (self.response_fields > 128 or self.request_secrets > 64) return error.InvalidGrpcCapture;
    }
};
pub const Completion = struct {
    pub const magic = "GRC1";
    status: u32,
    sent_messages: u32,
    received_messages: u32,
    sent_bytes: u32,
    received_bytes: u32,
    half_closed: enum(u8) { no = 0, yes = 1 },
    pub fn validate(self: Completion) !void {
        if (self.status > 16 or self.sent_messages > 64 or self.received_messages > 64 or self.sent_bytes > 65536 or self.received_bytes > 262144 or self.sent_bytes < self.sent_messages * 5 or self.received_bytes < self.received_messages * 5) return error.InvalidGrpcCapture;
    }
    /// Exchange reserves zero for incomplete capture; RPC OK is status zero.
    pub fn terminalCode(self: Completion) !u32 {
        try self.validate();
        return self.status + 1;
    }
};
pub const Sink = struct { context: *anyopaque, append: *const fn (*anyopaque, Kind, []const u8) anyerror!void };
sink: Sink,
allowlist: []const []const u8 = &.{},
planned: HalfClose,
request_secrets: u32 = 0,
received: u32 = 0,
received_bytes: u32 = 0,
omitted: u32 = 0,
half_closed: bool = false,
initial: bool = false,
terminal: ?u32 = null,
failed: bool = false,
finished: bool = false,
pub fn emit(raw: *anyopaque, event: rpc.transport.Event) !void {
    const self: *Self = @ptrCast(@alignCast(raw));
    if (self.failed or self.finished) return error.GrpcCaptureClosed;
    errdefer self.failed = true;
    switch (event) {
        .initial_metadata, .trailers => |fields| {
            const trailers = event == .trailers;
            if ((trailers and (!self.initial or self.terminal != null)) or (!trailers and self.initial)) return error.InvalidGrpcCapture;
            var buffer: [rpc.Metadata.maximum_bytes]u8 = undefined;
            const block = try rpc.Metadata.capture(fields, self.allowlist, trailers, &buffer);
            const parsed = try rpc.Metadata.decode(block.bytes, trailers);
            try self.sink.append(self.sink.context, if (trailers) .trailers else .initial_metadata, block.bytes);
            self.omitted += block.omitted;
            self.initial = true;
            self.terminal = parsed.status;
        },
        .message => |bytes| {
            if (!self.initial or self.terminal != null or self.received >= 64 or bytes.len > 16384 or bytes.len + 5 > 262144 -| self.received_bytes) return error.InvalidGrpcCapture;
            var digest: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
            const header = try x.codec.encode(Message{ .index = self.received, .length = @intCast(bytes.len), .digest = digest });
            try self.sink.append(self.sink.context, .response_message, header.slice());
            var offset: usize = 0;
            while (offset < bytes.len) {
                const part = bytes[offset..][0..@min(4096, bytes.len - offset)];
                try self.sink.append(self.sink.context, .response_body, part);
                offset += part.len;
            }
            self.received += 1;
            self.received_bytes += @intCast(bytes.len + 5);
        },
        .half_close => {
            if (self.half_closed or self.terminal != null) return error.InvalidGrpcCapture;
            const record = try x.codec.encode(self.planned);
            try self.sink.append(self.sink.context, .half_close, record.slice());
            self.half_closed = true;
        },
    }
}
pub fn finish(self: *Self, result: rpc.transport.Result, timing: Timing) !Completion {
    if (self.failed or self.finished) return error.GrpcCaptureClosed;
    errdefer self.failed = true;
    if (self.terminal != result.status or self.received != result.received_messages or self.received_bytes != result.received_bytes or self.half_closed != result.half_closed or result.sent_messages > self.planned.messages or result.sent_bytes > self.planned.wire_bytes or (self.half_closed and (result.sent_messages != self.planned.messages or result.sent_bytes != self.planned.wire_bytes))) return error.InvalidGrpcCapture;
    const completion: Completion = .{ .status = result.status, .sent_messages = result.sent_messages, .received_messages = result.received_messages, .sent_bytes = result.sent_bytes, .received_bytes = result.received_bytes, .half_closed = if (result.half_closed) .yes else .no };
    const time = try x.codec.encode(timing);
    const omission = try x.codec.encode(Omission{ .response_fields = self.omitted, .request_secrets = self.request_secrets });
    const terminal = try x.codec.encode(completion);
    try self.sink.append(self.sink.context, .timing, time.slice());
    try self.sink.append(self.sink.context, .omission, omission.slice());
    try self.sink.append(self.sink.context, .completion, terminal.slice());
    self.finished = true;
    return completion;
}
