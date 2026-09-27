//! Allowlisted exchange evidence. Adapter context and captured payloads stay opaque.
const std = @import("std");
const x = @import("transit_exchange");
const p = x.p;
const Ex = x.Exchange;

pub const Detail = union(enum) {
    capture: struct {
        exchange: []const u8,
        protocol: u32,
        phase: x.Phase,
        caller: u64,
        input: u64,
        owner: u64,
        parent: []const u8,
        effect: u64,
        attempt: u64,
        executor: u64,
        reconcile_before_ms: u64,
        segments: u32,
        max_segments: u32,
        bytes: []const u8,
        capture_bytes: []const u8,
        segment_bytes: u32,
        pending_kind: u32,
        terminal_code: u32,
        collected: u32,
        coverage: [32]u8,
    },
    obligations: struct {
        exchange: []const u8,
        dependents: []const u8,
        disposition: @FieldType(Ex.Control, "disposition"),
        caller: @FieldType(Ex.Control, "caller"),
        effect: u64,
    },
    lineage: struct {
        exchange: []const u8,
        root: []const u8,
        parent: []const u8,
        ordinal: u32,
        reason: Ex.FollowupReason,
        policy: []const u8,
        policy_revision: []const u8,
    },
    attempts: struct { exchange: []const u8, limit: u32, used: u32, unsettled: u32 },
};
fn decimal(allocator: std.mem.Allocator, value: u64) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{d}", .{value});
}
pub fn decode(allocator: std.mem.Allocator, writer: u64, key: p.Value, value: p.Value) !?Detail {
    try key.validate();
    try value.validate();
    if (key.len != 15 or !std.mem.eql(u8, key.data[0..2], "\x00E")) return null;
    const id = std.mem.readInt(u64, key.data[2..10], .big);
    if (id == 0 or std.mem.readInt(u32, key.data[11..15], .big) != 0) return null;
    return switch (key.data[10]) {
        'd' => blk: {
            const d = x.Descriptor.decode(value) catch return null;
            if (d.owner != writer) return null;
            // Kernel counters must remain exactly representable in Board JSON.
            for ([_]u64{ d.caller, d.input, d.owner, d.effect, d.attempt, d.executor, d.reconcile_before_ms }) |counter| if (counter > p.max_counter) return null;
            break :blk .{ .capture = .{
                .exchange = try decimal(allocator, id),
                .protocol = d.protocol,
                .phase = d.phase,
                .caller = d.caller,
                .input = d.input,
                .owner = d.owner,
                .parent = try decimal(allocator, d.parent),
                .effect = d.effect,
                .attempt = d.attempt,
                .executor = d.executor,
                .reconcile_before_ms = d.reconcile_before_ms,
                .segments = d.segments,
                .max_segments = d.max_segments,
                .bytes = try decimal(allocator, d.bytes),
                .capture_bytes = try decimal(allocator, d.capture_bytes),
                .segment_bytes = d.segment_bytes,
                .pending_kind = d.pending_kind,
                .terminal_code = d.terminal_code,
                .collected = d.collected,
                .coverage = d.chain,
            } };
        },
        'c' => blk: {
            const c = x.codec.decode(Ex.Control, value) catch return null;
            if (c.effect > p.max_counter) return null;
            break :blk .{ .obligations = .{ .exchange = try decimal(allocator, id), .dependents = try decimal(allocator, c.dependents), .disposition = c.disposition, .caller = c.caller, .effect = c.effect } };
        },
        'l' => blk: {
            const link = Ex.Link.decode(value) catch return null;
            const l = link.lineage;
            if (l.parent == id or l.root == id) return null;
            break :blk .{ .lineage = .{ .exchange = try decimal(allocator, id), .root = try decimal(allocator, l.root), .parent = try decimal(allocator, l.parent), .ordinal = l.ordinal, .reason = l.reason, .policy = try decimal(allocator, l.policy), .policy_revision = try decimal(allocator, l.policy_revision) } };
        },
        'b' => blk: {
            const b = x.codec.decode(Ex.AttemptBudget, value) catch return null;
            break :blk .{ .attempts = .{ .exchange = try decimal(allocator, id), .limit = b.limit, .used = b.used, .unsettled = b.unsettled } };
        },
        else => null,
    };
}

test "exchange evidence keeps wide identities and omits immutable adapter context" {
    const t = std.testing;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const id = std.math.maxInt(u64);
    const d: x.Descriptor = .{ .protocol = 1, .caller = 9, .input = 8, .parent = 0, .owner = 2, .reconcile_before_ms = 10000, .segment_bytes = 1024, .capture_bytes = 8192, .max_segments = 64 };
    const result = (try decode(allocator, 2, Ex.key(id, 'd', 0), try d.encode())).?.capture;
    try t.expectEqualStrings("18446744073709551615", result.exchange);
    try t.expectEqualStrings("0", result.parent);
    try t.expectEqual(.preparing, result.phase);
    try t.expectEqual(@as(u64, 0), result.attempt);
    try t.expectEqual(null, try decode(allocator, 3, Ex.key(id, 'd', 0), try d.encode()));
    try t.expectEqual(null, try decode(allocator, 2, Ex.key(id, 'd', 1), try d.encode()));
    const link: Ex.Link = .{ .lineage = .{ .root = id, .parent = id, .ordinal = 2, .reason = .retry, .policy = id, .policy_revision = id }, .context = try p.Value.init("private-adapter-context") };
    const lineage = (try decode(allocator, 2, Ex.key(1, 'l', 0), try link.encode())).?;
    const json = try std.json.Stringify.valueAlloc(allocator, lineage, .{});
    try t.expect(std.mem.indexOf(u8, json, "private-adapter-context") == null);
    try t.expectEqualStrings("18446744073709551615", lineage.lineage.policy_revision);
    var bad = try d.encode();
    bad.data[3] = '9';
    try t.expectEqual(null, try decode(allocator, 2, Ex.key(id, 'd', 0), bad));
    // Recognizing a magic inside an arbitrary application value is forbidden.
    try t.expectEqual(null, try decode(allocator, 2, try p.Value.init("application"), try d.encode()));
    const budget: Ex.AttemptBudget = .{ .limit = 3, .used = 2, .unsettled = 1 };
    try t.expectEqual(@as(u32, 1), (try decode(allocator, 2, Ex.key(id, 'b', 0), try x.codec.encode(budget))).?.attempts.unsettled);
    const control: Ex.Control = .{ .dependents = id, .disposition = .closed_unknown, .caller = .held, .effect = 19 };
    try t.expectEqualStrings("18446744073709551615", (try decode(allocator, 2, Ex.key(id, 'c', 0), try x.codec.encode(control))).?.obligations.dependents);
}
