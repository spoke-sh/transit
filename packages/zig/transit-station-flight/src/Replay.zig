//! Interpret only a currently authorized, completely verified M16 transcript.
//! Returned schema/batches are provisional until the explicit complete event.
const std = @import("std");
const root = @import("root.zig");
const rpc = root.rpc;
const f = root.flight;
const a = f.query.fuze.arrow;
const Self = @This();
pub const Event = union(enum) { schema: []const u8, batch: struct { ipc: []const u8, rows: u64 }, complete: rpc.Capture.Completion };
transcript: rpc.Replay,
schema: [8192]u8 = undefined,
schema_length: usize = 0,
message: [16384]u8 = undefined,
message_length: usize = 0,
expected_length: ?usize = null,
ipc: [16384]u8 = undefined,
batches: u32 = 0,
done: bool = false,
failed: bool = false,

pub fn open(client: *rpc.exchange.Client, reference: rpc.exchange.Client.Reference) !Self {
    return .{ .transcript = try rpc.Replay.open(client, reference, .captured) };
}
/// One message, schema copy and caller workspace; no retained history allocation.
/// Output borrows self until the next call. No replay path can dispatch an RPC.
pub fn next(self: *Self, workspace: []u8) !?Event {
    if (self.failed) return error.FlightReplayFailed;
    if (self.done) return null;
    errdefer self.failed = true;
    while (try self.transcript.read()) |part| {
        switch (part.kind) {
            .response_message => {
                if (self.expected_length != null) return error.InvalidFlightCapture;
                const header = try rpc.exchange.codec.decode(rpc.Capture.Message, part.bytes);
                if (header.length == 0 or header.length > self.message.len) return error.InvalidFlightCapture;
                self.expected_length = header.length;
                self.message_length = 0;
            },
            .response_body => {
                const expected = self.expected_length orelse return error.InvalidFlightCapture;
                const bytes = part.bytes.slice();
                if (bytes.len > expected - self.message_length) return error.InvalidFlightCapture;
                @memcpy(self.message[self.message_length..][0..bytes.len], bytes);
                self.message_length += bytes.len;
                if (self.message_length == expected) {
                    self.expected_length = null;
                    return try self.decode(workspace);
                }
            },
            else => {},
        }
        if (part.complete) {
            const complete = try self.transcript.validator.finish();
            if (complete.status != 0) return error.FlightRemoteFailure;
            if (self.expected_length != null or self.schema_length == 0 or self.batches == 0 or complete.received_messages != self.batches + 1) return error.InvalidFlightCapture;
            self.done = true;
            return .{ .complete = complete };
        }
    }
    return error.InvalidFlightCapture;
}
fn writeHeader(writer: *std.Io.Writer, header: []const u8) !void {
    if (header.len == 0 or header.len > 8192) return error.InvalidFlightIpc;
    const aligned = std.mem.alignForward(usize, header.len, 8);
    try writer.writeInt(u32, 0xffffffff, .little);
    try writer.writeInt(u32, @intCast(aligned), .little);
    try writer.writeAll(header);
    try writer.splatByteAll(0, aligned - header.len);
}
fn decode(self: *Self, workspace: []u8) !Event {
    if (workspace.len < 1024 * 1024) return error.FlightWorkspaceTooSmall;
    var fixed: std.heap.FixedBufferAllocator = .init(workspace[0..65536]);
    var arrow_fixed: std.heap.FixedBufferAllocator = .init(workspace[65536..]);
    var decoded = try f.grpc.protobuf.decode(f.Wire.FlightData, fixed.allocator(), self.message[0..self.message_length], .{ .max_arena_bytes = 65536 });
    defer decoded.deinit();
    const data = decoded.value;
    if (self.schema_length == 0) {
        if (data.data_body.len != 0) return error.InvalidFlightIpc;
        var output: std.Io.Writer = .fixed(&self.schema);
        try writeHeader(&output, data.data_header);
        var input: std.Io.Reader = .fixed(output.buffered());
        var reader = a.IpcStreamReader(*std.Io.Reader).init(arrow_fixed.allocator(), &input);
        defer reader.deinit();
        const value = try reader.readSchema();
        if (value.fields.len == 0 or value.fields.len > 2 or input.bufferedLen() != 0) return error.UnsupportedFlightType;
        for (value.fields) |field| if (field.data_type.* != .int64) return error.UnsupportedFlightType;
        self.schema_length = output.buffered().len;
        return .{ .schema = self.schema[0..self.schema_length] };
    }
    var output: std.Io.Writer = .fixed(&self.ipc);
    try output.writeAll(self.schema[0..self.schema_length]);
    try writeHeader(&output, data.data_header);
    try output.writeAll(data.data_body);
    try output.writeAll(&.{ 255, 255, 255, 255, 0, 0, 0, 0 });
    const ipc = try f.Ipc.parts(output.buffered(), workspace[65536..]);
    self.batches += 1;
    return .{ .batch = .{ .ipc = output.buffered(), .rows = ipc.rows } };
}

test "typed replay rejects malformed envelopes and truncated Arrow bodies" {
    const t = std.testing;
    const workspace = try t.allocator.alloc(u8, 8 * 1024 * 1024);
    defer t.allocator.free(workspace);
    var builder = try a.Int64Builder.init(t.allocator, 2);
    defer builder.deinit();
    try builder.append(std.math.maxInt(i64));
    try builder.appendNull();
    var array = try builder.finish();
    defer array.release();
    const kind: a.DataType = .{ .int64 = {} };
    var batch = try a.RecordBatch.initBorrowed(t.allocator, .{ .fields = &.{.{ .name = "value", .data_type = &kind, .nullable = true }} }, &.{array});
    defer batch.deinit();
    var bytes: [8192]u8 = undefined;
    const ipc = try f.query.fuze.encode(t.allocator, batch, &bytes);
    const parts = try f.Ipc.parts(ipc, workspace);
    var replay: Self = .{ .transcript = undefined };
    replay.message_length = try f.grpc.protobuf.encodeInto(&replay.message, f.Wire.FlightData{ .data_header = parts.schema_header, .data_body = "invalid schema body" }, .{});
    try t.expectError(error.InvalidFlightIpc, replay.decode(workspace));
    replay.message_length = try f.grpc.protobuf.encodeInto(&replay.message, f.Wire.FlightData{ .data_header = parts.schema_header }, .{});
    try t.expect((try replay.decode(workspace)) == .schema);
    replay.message_length = try f.grpc.protobuf.encodeInto(&replay.message, f.Wire.FlightData{ .data_header = parts.batch_header, .data_body = parts.batch_body[0 .. parts.batch_body.len - 1] }, .{});
    if (replay.decode(workspace)) |_| return error.TestUnexpectedResult else |_| {}
    replay.message_length = try f.grpc.protobuf.encodeInto(&replay.message, f.Wire.FlightData{ .data_header = parts.batch_header, .data_body = parts.batch_body }, .{});
    try t.expectEqual(@as(u64, 2), (try replay.decode(workspace)).batch.rows);
    replay.message[0] = 0;
    try t.expectError(error.FieldNumberZero, replay.decode(workspace));
}
