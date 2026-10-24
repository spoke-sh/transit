//! Application-owned counter work over the general typed Table. Accepted calls
//! wait in paged durable KV; a frozen delta is never recomputed after staging.
const std = @import("std");
const serving = @import("transit_serving");
const s = serving.station;
const p = s.protocol;
const f = s.fuze;
pub const Data = @import("CounterData.zig");
pub const object = 1;
pub const schema: f.TableSchema.Schema = .{ .object = object, .revision = 1, .next_column = 3, .columns = &.{
    .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
    .{ .id = 2, .name = "count", .type = .int64 },
}, .primary_key = &.{1} };
pub const progress_key = p.Value.init("data-progress") catch unreachable;
pub const continuation = p.Value.init("counter.drive") catch unreachable;
const prefix = "\x00counter.pending/";
const Pending = struct {
    input: u64,
    principal: u64,
    origin: u64,
    correlation: u64,
    key: i64,
    delta: i64,
    intent: [32]u8,
    prepared: ?struct { identity: f.TableRow.Identity, value: i64, insert: bool } = null,
    fn keyFor(input: u64) p.Value {
        var bytes: [prefix.len + 8]u8 = undefined;
        @memcpy(bytes[0..prefix.len], prefix);
        std.mem.writeInt(u64, bytes[prefix.len..], input, .big);
        return p.Value.init(&bytes) catch unreachable;
    }
    fn definition() [32]u8 {
        var bytes: [32]u8 = undefined;
        _ = std.fmt.hexToBytes(&bytes, @tagName(p.Growth.current_definition)) catch unreachable;
        return bytes;
    }
    fn encode(self: Pending) !p.Value {
        if (self.input == 0 or self.input > p.max_counter or self.principal > p.max_counter or self.origin == 0 or self.origin > p.max_counter or self.correlation == 0) return error.InvalidCounterWork;
        var bytes: [256]u8 = undefined;
        var out: std.Io.Writer = .fixed(&bytes);
        try out.writeAll("SCW1");
        try out.writeAll(&definition());
        inline for (.{ "input", "principal", "origin", "correlation" }) |name| try out.writeInt(u64, @field(self, name), .little);
        try out.writeInt(i64, self.key, .little);
        try out.writeInt(i64, self.delta, .little);
        try out.writeAll(&self.intent);
        try out.writeByte(@intFromBool(self.prepared != null));
        if (self.prepared) |value| {
            try out.writeAll(&try value.identity.encode());
            try out.writeInt(i64, value.value, .little);
            try out.writeByte(@intFromBool(value.insert));
        }
        return p.Value.init(out.buffered());
    }
    fn decode(bytes: p.Value) !Pending {
        try bytes.validate();
        var in: std.Io.Reader = .fixed(bytes.slice());
        if (!std.mem.eql(u8, try in.take(4), "SCW1")) return error.InvalidCounterWork;
        if (!std.mem.eql(u8, try in.take(32), &definition())) return error.IncompatibleDefinition;
        var value: Pending = .{ .input = try in.takeInt(u64, .little), .principal = try in.takeInt(u64, .little), .origin = try in.takeInt(u64, .little), .correlation = try in.takeInt(u64, .little), .key = try in.takeInt(i64, .little), .delta = try in.takeInt(i64, .little), .intent = (try in.takeArray(32)).* };
        switch (try in.takeByte()) {
            0 => {},
            1 => {
                const identity = try f.TableRow.Identity.decode(try in.takeArray(20));
                const result = try in.takeInt(i64, .little);
                const insert = switch (try in.takeByte()) {
                    0 => false,
                    1 => true,
                    else => return error.InvalidCounterWork,
                };
                value.prepared = .{ .identity = identity, .value = result, .insert = insert };
            },
            else => return error.InvalidCounterWork,
        }
        if (in.bufferedLen() != 0 or !(try value.encode()).eql(bytes)) return error.InvalidCounterWork;
        return value;
    }
};
fn intentDigest(bytes: []const u8) [32]u8 {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update(bytes);
    return hash.finalResult();
}
fn wake(turn: *s.Turn) !void {
    try turn.cast(turn.delivery.pid, continuation);
}
pub fn enqueue(turn: *s.Turn, ingress: u64, frame: s.Frame) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    if (try s.Frame.source(turn.delivery.input) != ingress) return error.UnexpectedServingIngress;
    if (frame.kind != .call) return error.UnsupportedServingInvocation;
    const invocation = try serving.Codec.decode(serving.Model.Invocation, 'i', frame.payload);
    if (invocation.codec != 1 or invocation.payload.len != 16) return turn.reply(try p.Value.init("InvalidCounterCommand"));
    const pending: Pending = .{
        .input = turn.delivery.input.position,
        .principal = invocation.principal,
        .origin = ingress,
        .correlation = frame.correlation,
        .key = std.mem.readInt(i64, invocation.payload.data[0..8], .little),
        .delta = std.mem.readInt(i64, invocation.payload.data[8..16], .little),
        .intent = intentDigest(frame.payload.slice()),
    };
    const key = Pending.keyFor(pending.input);
    if (try turn.read(key) != null) return error.CounterWorkAlreadyExists;
    try turn.write(key, try pending.encode());
    try wake(turn);
}
fn first(turn: *s.Turn) !?Pending {
    var source = turn.committed();
    const page = try source.page(try p.Value.init(prefix));
    const entry = page.entries[0] orelse return null;
    if (!std.mem.startsWith(u8, entry.key.slice(), prefix)) return null;
    const pending = try Pending.decode(entry.value);
    if (!entry.key.eql(Pending.keyFor(pending.input))) return error.InvalidCounterWork;
    return pending;
}
fn finish(turn: *s.Turn, pending: Pending, value: p.Value, applied: bool) !void {
    try turn.write(Pending.keyFor(pending.input), null);
    if (applied) {
        const current = if (try turn.read(progress_key)) |prior| try prior.asInteger() else 0;
        try turn.write(progress_key, p.Value.integer(try std.math.add(i64, current, 1)));
    }
    try turn.send(pending.origin, .{ .kind = .reply, .correlation = pending.correlation, .payload = value });
    try wake(turn);
}
pub fn drive(allocator: std.mem.Allocator, turn: *s.Turn, client: Data.Client, binding: Data.Binding) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    if (try s.Frame.source(turn.delivery.input) != turn.delivery.pid) return error.AccessDenied;
    var pending = (try first(turn)) orelse return;
    var declared = schema;
    declared.object = binding.object;
    if (pending.prepared == null) {
        var metadata = try Data.definition(client, binding, declared);
        defer metadata.deinit();
        const selected = try Data.get(allocator, client, metadata.value, declared, pending.key);
        const next = std.math.add(i64, if (selected) |row| row.value else 0, pending.delta) catch return finish(turn, pending, try p.Value.init("CounterOverflow"), false);
        pending.prepared = .{
            .identity = if (selected) |row| row.identity else try serving.query.catalog.DirectTableProtocol.Rows.insertIdentity(.{ .scope = binding.scope, .principal = client.connection.principal, .operation = pending.input }, 0),
            .value = next,
            .insert = selected == null,
        };
        const prepared = pending.prepared.?;
        var intent = try Data.mutation(allocator, client, metadata.value, declared, pending.input, .{ .identity = prepared.identity, .key = pending.key, .value = next }, prepared.insert);
        defer intent.deinit();
        // Staging carries no admission. Commit eligibility and the exact frozen
        // row before a subsequent continuation can contact the acceptance owner.
        const reference = try Data.stage(client, &intent, binding.namespace);
        try Data.prepare(allocator, turn, .{ .resource = turn.view.resource, .worker = turn.delivery.pid, .input = pending.input, .invocation = pending.intent, .reference = reference });
        try turn.write(Pending.keyFor(pending.input), try pending.encode());
        return wake(turn);
    }
    const prepared = pending.prepared.?;
    switch (try Data.advance(allocator, turn, client, pending.input, pending.intent)) {
        .pending => return wake(turn),
        .committed => |evidence| if (evidence.outcome.matched != 1) return error.CounterRowChanged,
        .rejected, .cancelled => return finish(turn, pending, try p.Value.init("CounterMutationRejected"), false),
    }
    var result: [8]u8 = undefined;
    std.mem.writeInt(i64, &result, prepared.value, .little);
    // Only original accepted data evidence permits progress and reply. A lost
    // native turn repeats receipt inspection without applying the delta again.
    try finish(turn, pending, try p.Value.init(&result), true);
}
