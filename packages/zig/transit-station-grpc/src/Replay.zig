//! Read-only transcript verification. Prefixes are provisional until coverage
//! and the terminal record agree. No network or secret resolver is accepted.
const std = @import("std");
const rpc = @import("root.zig");
const x = rpc.exchange;
const c = rpc.Capture;
const Self = @This();
pub const Policy = enum { captured, require_unredacted };
pub const Part = struct { kind: c.Kind, bytes: x.p.Value, complete: bool };
client: *x.Client,
reference: x.Client.Reference,
cursor: x.Exchange.Cursor,
validator: Validator,
done: bool = false,
failed: bool = false,
pub fn open(client: *x.Client, reference: x.Client.Reference, policy: Policy) !Self {
    const cursor = try client.open(reference);
    if (cursor.descriptor.protocol != rpc.protocol_format) return error.WrongExchangeProtocol;
    return .{ .client = client, .reference = reference, .cursor = cursor, .validator = .{ .terminal_code = cursor.descriptor.terminal_code, .policy = policy } };
}
pub fn read(self: *Self) !?Part {
    if (self.failed) return error.GrpcReplayFailed;
    if (self.done) return null;
    errdefer self.failed = true;
    const part = try self.client.read(self.reference, self.cursor);
    const kind = std.enums.fromInt(c.Kind, part.kind) orelse return error.InvalidGrpcCapture;
    const last = if (part.next) |next| next.member_cursor == null else true;
    try self.validator.push(kind, part.bytes.slice(), last);
    if (part.next) |cursor| self.cursor = cursor else {
        _ = try self.validator.finish();
        self.done = true;
    }
    return .{ .kind = kind, .bytes = part.bytes, .complete = self.done };
}
/// Feed exact segment boundaries from a verified Exchange reader. Direct users
/// must independently verify coverage; successful parsing does not grant trust.
pub const Validator = struct {
    terminal_code: u32,
    policy: Policy = .captured,
    stage: enum { metadata, batch, endpoint, response, omission, completion, done } = .metadata,
    buffer: [rpc.Batch.maximum_bytes]u8 = undefined,
    used: usize = 0,
    segment_kind: ?c.Kind = null,
    segment_bytes: usize = 0,
    shape: rpc.Shape = .unary,
    descriptor_digest: [32]u8 = undefined,
    request_secrets: u32 = 0,
    metadata_digest: [32]u8 = undefined,
    metadata_record: [8192]u8 = undefined,
    metadata_length: usize = 0,
    limits: rpc.transport.Limits = .{},
    allowed_metadata: [64][32]u8 = undefined,
    allowed_count: usize = 0,
    batch_digest: [32]u8 = undefined,
    planned_count: u32 = 0,
    planned_prefix: [65]u32 = @splat(0),
    initial: bool = false,
    status: ?u32 = null,
    half_closed: bool = false,
    pending: ?c.Message = null,
    message_bytes: u32 = 0,
    hash: std.crypto.hash.sha2.Sha256 = undefined,
    received: u32 = 0,
    received_bytes: u32 = 0,
    completion: ?c.Completion = null,
    failed: bool = false,
    pub fn push(self: *Validator, kind: c.Kind, bytes: []const u8, last: bool) !void {
        if (self.failed) return error.GrpcReplayFailed;
        errdefer self.failed = true;
        if (self.stage == .done) return error.InvalidGrpcCapture;
        if (self.segment_kind) |active| {
            if (active != kind) return error.GrpcReplayGap;
        } else self.segment_kind = kind;
        self.segment_bytes += bytes.len;
        if (self.segment_bytes > (if (kind == .request_batch or kind == .response_body) @as(usize, 4096) else 8192)) return error.InvalidGrpcCapture;
        if (self.stage == .batch and kind == .endpoint_policy) {
            const batch = try rpc.Batch.decode(self.buffer[0..self.used], self.shape, .{});
            self.batch_digest = (try x.Publication.Digest.of(rpc.protocol_format, self.buffer[0..self.used])).digest;
            self.planned_count = @intCast(batch.count);
            for (batch.messages(), 0..) |message, index| self.planned_prefix[index + 1] = self.planned_prefix[index] + @as(u32, @intCast(message.len)) + 5;
            self.used = 0;
            self.stage = .endpoint;
        }
        if (kind == .response_body) {
            if (self.stage != .response) return error.GrpcReplayGap;
            const pending = self.pending orelse return error.GrpcReplayGap;
            if (bytes.len > pending.length - self.message_bytes) return error.GrpcReplayGap;
            self.hash.update(bytes);
            self.message_bytes += @intCast(bytes.len);
        } else {
            if (bytes.len > self.buffer.len - self.used) return error.InvalidGrpcCapture;
            @memcpy(self.buffer[self.used..][0..bytes.len], bytes);
            self.used += bytes.len;
        }
        if (!last) return;
        try self.end(kind);
        self.segment_kind = null;
        self.segment_bytes = 0;
        if (kind != .request_batch) self.used = 0;
    }
    fn messageComplete(self: *Validator) !void {
        const header = self.pending.?;
        if (header.length != self.message_bytes) return;
        if (!std.mem.eql(u8, &self.hash.finalResult(), &header.digest)) return error.GrpcReplayGap;
        self.received += 1;
        self.received_bytes += header.length + 5;
        if (self.received_bytes > self.limits.response_bytes) return error.InvalidGrpcCapture;
        self.pending = null;
    }
    fn metadata(self: *Validator, bytes: []const u8, trailers: bool) !rpc.Metadata.Block {
        if (bytes.len > self.limits.metadata_bytes) return error.GrpcReplayGap;
        const block = try rpc.Metadata.decode(bytes, trailers);
        for (block.entries()) |field| {
            if (rpc.Metadata.required(field.name)) continue;
            var digest: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(field.name, &digest, .{});
            const allowed = for (self.allowed_metadata[0..self.allowed_count]) |candidate| {
                if (std.mem.eql(u8, &candidate, &digest)) break true;
            } else false;
            if (!allowed) return error.GrpcReplayGap;
        }
        return block;
    }
    fn end(self: *Validator, kind: c.Kind) !void {
        const bytes = self.buffer[0..self.used];
        if (self.pending != null and kind != .response_body) return error.GrpcReplayGap;
        switch (kind) {
            .request_metadata => {
                if (self.stage != .metadata) return error.GrpcReplayGap;
                var memory: [131072]u8 = undefined;
                var arena: std.heap.FixedBufferAllocator = .init(&memory);
                var owned = try rpc.Request.parse(arena.allocator(), bytes);
                defer owned.deinit();
                self.metadata_length = bytes.len;
                @memcpy(self.metadata_record[0..bytes.len], bytes);
                self.metadata_digest = (try x.Publication.Digest.of(rpc.protocol_format, bytes)).digest;
                self.shape = owned.request.shape;
                self.descriptor_digest = owned.request.descriptor_digest;
                for (owned.request.metadata) |field| if (field.value == .secret) {
                    self.request_secrets += 1;
                };
                self.stage = .batch;
            },
            .request_batch => if (self.stage != .batch or self.segment_bytes == 0) return error.GrpcReplayGap,
            .endpoint_policy => {
                if (self.stage != .endpoint or bytes.len == 0 or bytes.len > 8192) return error.GrpcReplayGap;
                var memory: [131072]u8 = undefined;
                var arena: std.heap.FixedBufferAllocator = .init(&memory);
                var owned = try rpc.Policy.parse(arena.allocator(), bytes);
                defer owned.deinit();
                const policy = owned.policy;
                var request = try rpc.Request.parse(arena.allocator(), self.metadata_record[0..self.metadata_length]);
                defer request.deinit();
                try policy.validateRequest(request.request);
                self.limits = policy.limits;
                if (self.planned_count > self.limits.request_messages or self.planned_prefix[self.planned_count] > self.limits.request_bytes) return error.GrpcReplayGap;
                for (0..self.planned_count) |index| if (self.planned_prefix[index + 1] - self.planned_prefix[index] - 5 > self.limits.message_bytes) return error.GrpcReplayGap;
                self.allowed_count = policy.response_metadata.len;
                for (policy.response_metadata, 0..) |name, index| std.crypto.hash.sha2.Sha256.hash(name, &self.allowed_metadata[index], .{});
                if (policy.shape != self.shape or !std.mem.eql(u8, &policy.descriptor_digest, &self.descriptor_digest) or !std.mem.eql(u8, &policy.metadata_digest, &self.metadata_digest) or !std.mem.eql(u8, &policy.batch_digest, &self.batch_digest)) return error.GrpcReplayGap;
                self.stage = .response;
            },
            .initial_metadata => {
                if (self.stage != .response or self.initial) return error.GrpcReplayGap;
                self.status = (try self.metadata(bytes, false)).status;
                self.initial = true;
            },
            .response_message => {
                if (self.stage != .response or !self.initial or self.status != null) return error.GrpcReplayGap;
                const header = try x.codec.decode(c.Message, try x.p.Value.init(bytes));
                if (header.index != self.received or self.received >= self.limits.response_messages or header.length > self.limits.message_bytes) return error.GrpcReplayGap;
                self.pending = header;
                self.message_bytes = 0;
                self.hash = .init(.{});
                try self.messageComplete();
            },
            .response_body => {
                if (self.segment_bytes == 0) return error.GrpcReplayGap;
                try self.messageComplete();
            },
            .half_close => {
                if (self.stage != .response or self.half_closed or self.status != null) return error.GrpcReplayGap;
                const half = try x.codec.decode(c.HalfClose, try x.p.Value.init(bytes));
                if (half.messages != self.planned_count or half.wire_bytes != self.planned_prefix[self.planned_count]) return error.GrpcReplayGap;
                self.half_closed = true;
            },
            .trailers => {
                if (self.stage != .response or !self.initial or self.status != null) return error.GrpcReplayGap;
                self.status = (try self.metadata(bytes, true)).status;
            },
            .timing => {
                if (self.stage != .response or self.status == null) return error.GrpcReplayGap;
                _ = try x.codec.decode(c.Timing, try x.p.Value.init(bytes));
                self.stage = .omission;
            },
            .omission => {
                if (self.stage != .omission) return error.GrpcReplayGap;
                const omission = try x.codec.decode(c.Omission, try x.p.Value.init(bytes));
                if (omission.request_secrets != self.request_secrets or (self.policy == .require_unredacted and (omission.request_secrets != 0 or omission.response_fields != 0))) return error.GrpcReplayGap;
                self.stage = .completion;
            },
            .completion => {
                if (self.stage != .completion) return error.GrpcReplayGap;
                const done = try x.codec.decode(c.Completion, try x.p.Value.init(bytes));
                if (done.status != self.status or try done.terminalCode() != self.terminal_code or done.received_messages != self.received or done.received_bytes != self.received_bytes or (done.half_closed == .yes) != self.half_closed or done.sent_messages > self.planned_count) return error.GrpcReplayGap;
                const prefix = self.planned_prefix[done.sent_messages];
                if (done.sent_bytes < prefix or (done.sent_messages == self.planned_count and done.sent_bytes != prefix) or (done.sent_messages < self.planned_count and done.sent_bytes >= self.planned_prefix[done.sent_messages + 1])) return error.GrpcReplayGap;
                if (self.half_closed and done.sent_messages != self.planned_count) return error.GrpcReplayGap;
                if ((self.shape == .unary or self.shape == .client_streaming) and (self.received > 1 or (done.status == 0 and self.received != 1))) return error.InvalidGrpcShape;
                self.completion = done;
                self.stage = .done;
            },
        }
    }
    pub fn finish(self: *Validator) !c.Completion {
        if (self.failed) return error.GrpcReplayFailed;
        if (self.stage != .done or self.segment_kind != null or self.pending != null) return error.GrpcReplayGap;
        return self.completion orelse return error.GrpcReplayGap;
    }
};
