//! Native public observations for ordered programs. A caller owns the scratch
//! lifetime through checkpoint retention; Fuze itself has no clock or entropy.
const std = @import("std");
const q = @import("root.zig");
const a = q.fuze.ApplicationProgram;
const V = a.Values.Value;
const Self = @This();
scratch: std.mem.Allocator,
io: std.Io,
scope: ?q.ApplicationExecution.Context = null,

pub fn recovery(self: *Self) q.ApplicationRecovery.Host {
    return .{ .context = self, .ready = requireReady, .bind = bind };
}
pub fn available() a.Types.Requirements {
    return .{ .functions = .initMany(&.{ .random_token, .digest, .commitment, .now, .seconds, .current_revision, .url, .json_object, .s256, .length, .secure_equal, .operation_id, .json_value, .json_integer, .identity_digest }) };
}
pub fn requireReady(_: *anyopaque, allocator: std.mem.Allocator, declaration: q.ManagedApplication.Declaration) !void {
    var bound = try declaration.bind(allocator);
    defer bound.deinit();
    try bound.requirements.requireAvailable(available());
}
fn finish(context: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(context));
    if (self.scope) |*scope| std.crypto.secureZero(u8, std.mem.asBytes(scope));
    self.scope = null;
}
fn bind(context: *anyopaque, scope: q.ApplicationExecution.Context) !q.ApplicationExecution.BoundHost {
    const self: *Self = @ptrCast(@alignCast(context));
    self.scope = scope;
    self.scratch = scope.scratch;
    return .{ .expressions = self.host(), .release = finish };
}
pub fn host(self: *Self) a.Evaluation.Host {
    return .{ .context = self, .lookup = lookup, .evaluate = evaluate, .condition = condition };
}
fn lookup(_: *anyopaque, _: []const u8) !V {
    return error.UnknownProgramVariable;
}
fn condition(_: *anyopaque, _: V) !bool {
    return error.ProtectedProgramValue;
}
fn evaluate(context: *anyopaque, _: a.Id, operation: a.Evaluation.Operation, args: []const V) !V {
    const self: *Self = @ptrCast(@alignCast(context));
    if (operation != .function) return error.ProtectedProgramValue;
    for (args) |arg| try arg.public();
    return self.function(operation.function, args);
}
fn bytes(value: V) ![]const u8 {
    return switch (value) {
        .text, .binary => |data| data,
        else => error.ProgramTypeMismatch,
    };
}
/// Constant work for equal-length byte strings, without a matching-prefix exit.
/// Length is checked separately; NULL handling belongs to the typed helper.
pub fn secureEqual(left: []const u8, right: []const u8) bool {
    return left.len == right.len and std.crypto.timing_safe.compare(u8, left, right, .big) == .eq;
}
fn function(self: *Self, name: a.Function, args: []const V) !V {
    switch (name) {
        .json_object => return a.Json.object(self.scratch, args),
        .json_value, .json_integer => {
            if (args.len != 2 or args[1] != .text) return error.ProgramArgumentMismatch;
            if (args[0] == .null) return .null;
            if (args[0] != .json) return error.ProgramTypeMismatch;
            return a.Json.project(self.scratch, args[0].json, args[1].text, if (name == .json_integer) .integer else .text);
        },
        .url => {
            if (args.len != 2 or args[0] != .text or args[1] != .json) return error.ProgramArgumentMismatch;
            return a.Json.url(self.scratch, args[0].text, args[1].json);
        },
        .secure_equal => {
            if (args.len != 2) return error.ProgramArgumentMismatch;
            if (args[0] == .null or args[1] == .null) return .{ .boolean = false };
            return .{ .boolean = secureEqual(try bytes(args[0]), try bytes(args[1])) };
        },
        .current_revision => {
            if (args.len != 2 or args[0] != .text) return error.ProgramArgumentMismatch;
            const scope = self.scope orelse return error.InvalidTransactionGuard;
            for (scope.declaration.resources) |binding| {
                if (std.mem.eql(u8, binding.name().slice(), args[0].text))
                    return q.ApplicationData.currentRevision(self.scratch, scope.client, binding, args[1]);
            }
            return error.UnknownProgramResource;
        },
        .now => {
            if (args.len != 0) return error.ProgramArgumentMismatch;
            const value = std.Io.Clock.real.now(self.io).toMicroseconds();
            return .{ .timestamp = std.math.cast(i64, value) orelse return error.Overflow };
        },
        .seconds => {
            if (args.len != 1 or args[0] != .integer) return error.ProgramArgumentMismatch;
            return .{ .duration = try std.math.mul(i64, args[0].integer, std.time.us_per_s) };
        },
        .length => {
            if (args.len != 1) return error.ProgramArgumentMismatch;
            if (args[0] == .null) return .null;
            if (args[0] != .text) return error.ProgramTypeMismatch;
            return .{ .integer = @intCast(try std.unicode.utf8CountCodepoints(args[0].text)) };
        },
        .digest, .commitment, .s256 => {
            if (args.len != 1) return error.ProgramArgumentMismatch;
            if (args[0] == .null) return .null;
            var digest: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(try bytes(args[0]), &digest, .{});
            if (name != .s256) return .{ .binary = try self.scratch.dupe(u8, &digest) };
            const encoder = std.base64.url_safe_no_pad.Encoder;
            const text = try self.scratch.alloc(u8, encoder.calcSize(digest.len));
            return .{ .text = encoder.encode(text, &digest) };
        },
        .random_token => {
            if (args.len != 1 or args[0] != .integer or args[0].integer < 16 or args[0].integer > 64) return error.ProgramArgumentMismatch;
            var entropy: [64]u8 = undefined;
            defer std.crypto.secureZero(u8, &entropy);
            const selected = entropy[0..@intCast(args[0].integer)];
            try self.io.randomSecure(selected);
            const encoder = std.base64.url_safe_no_pad.Encoder;
            const text = try self.scratch.alloc(u8, encoder.calcSize(selected.len));
            return .{ .text = encoder.encode(text, selected) };
        },
        .identity_digest => {
            if (args.len != 3) return error.ProgramArgumentMismatch;
            for (args) |arg| if (arg != .text) return error.ProgramTypeMismatch;
            const digest = q.catalog.BrowserDeclarations.Identity.digest(args[0].text, args[1].text, args[2].text);
            return .{ .text = try std.fmt.allocPrint(self.scratch, "{x}", .{digest}) };
        },
        .operation_id => {
            if (args.len != 2 or args[0] != .uuid or args[1] != .text) return error.ProgramArgumentMismatch;
            var hash = std.crypto.hash.sha2.Sha256.init(.{});
            hash.update("transit.application.operation-id.v1\x00");
            hash.update(&args[0].uuid);
            var length: [8]u8 = undefined;
            std.mem.writeInt(u64, &length, args[1].text.len, .big);
            hash.update(&length);
            hash.update(args[1].text);
            var result = hash.finalResult()[0..16].*;
            result[6] = (result[6] & 0x0f) | 0x80;
            result[8] = (result[8] & 0x3f) | 0x80;
            return .{ .uuid = result };
        },
        else => return error.ProgramResourceKindMismatch,
    }
}

test "application public observations have exact units and canonical identities" {
    const t = std.testing;
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    var self: Self = .{ .scratch = arena.allocator(), .io = t.io };
    const host_ = self.host();
    const duration = try host_.evaluate(host_.context, 1, .{ .function = .seconds }, &.{.{ .integer = -3 }});
    try t.expectEqual(@as(i64, -3_000_000), duration.duration);
    try t.expectError(error.Overflow, host_.evaluate(host_.context, 1, .{ .function = .seconds }, &.{.{ .integer = std.math.maxInt(i64) }}));
    const length = try host_.evaluate(host_.context, 1, .{ .function = .length }, &.{.{ .text = "é😀" }});
    try t.expectEqual(@as(i64, 2), length.integer);
    const digest = try host_.evaluate(host_.context, 1, .{ .function = .digest }, &.{.{ .text = "abc" }});
    try t.expectEqualStrings("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", try std.fmt.allocPrint(arena.allocator(), "{x}", .{digest.binary}));
    const s256 = try host_.evaluate(host_.context, 1, .{ .function = .s256 }, &.{.{ .text = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk" }});
    try t.expectEqualStrings("E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", s256.text);
    const first = try host_.evaluate(host_.context, 1, .{ .function = .operation_id }, &.{ .{ .uuid = @splat(7) }, .{ .text = "exchange" } });
    const same = try host_.evaluate(host_.context, 2, .{ .function = .operation_id }, &.{ .{ .uuid = @splat(7) }, .{ .text = "exchange" } });
    const other = try host_.evaluate(host_.context, 1, .{ .function = .operation_id }, &.{ .{ .uuid = @splat(7) }, .{ .text = "profile" } });
    try t.expectEqualSlices(u8, &first.uuid, &same.uuid);
    try t.expect(!std.mem.eql(u8, &first.uuid, &other.uuid));
    try t.expectEqual(@as(u8, 8), first.uuid[6] >> 4);
    try t.expectEqual(@as(u8, 2), first.uuid[8] >> 6);
    try t.expectError(error.ProtectedProgramValue, host_.evaluate(host_.context, 1, .{ .function = .digest }, &.{.{ .capability = .{ .id = @splat(1) } }}));
    const payload = try host_.evaluate(host_.context, 1, .{ .function = .json_object }, &.{ .{ .text = "authenticated" }, .{ .boolean = false } });
    try t.expectEqualStrings("{\"authenticated\":false}", payload.json);
    try t.expectEqualStrings("false", (try host_.evaluate(host_.context, 1, .{ .function = .json_value }, &.{ payload, .{ .text = "$.authenticated" } })).text);
    try t.expectEqualStrings("https://example.test/?authenticated=false", (try host_.evaluate(host_.context, 1, .{ .function = .url }, &.{ .{ .text = "https://example.test/" }, payload })).text);
    try t.expect((try host_.evaluate(host_.context, 1, .{ .function = .secure_equal }, &.{ digest, digest })).boolean);
    try t.expect(!secureEqual("abc", "abd"));
    try t.expect(!secureEqual("abc", "abcd"));
    try t.expect(secureEqual("", ""));
}

test "application public host admits data programs before input and rejects protected input schemas" {
    const t = std.testing;
    var parsed = try a.parse(t.allocator,
        \\CREATE DATAFLOW x FROM QUEUE events AS event AS BEGIN
        \\  LET time = NOW();
        \\  REQUIRE event.id = 1 ELSE 'Rejected';
        \\END;
    , null);
    defer parsed.deinit();
    const id: a.Types.Field = .{ .name = "id", .value = .{ .kind = .integer } };
    var public = try a.Types.bind(t.allocator, parsed.program, &.{.{ .name = "events", .kind = .queue, .fields = &.{id} }}, null);
    defer public.deinit();
    try public.requirements.requireAvailable(available());
    // Even an unused request handle makes this a protected input profile.
    // A data-only host must not claim the row and strand its response owner.
    var protected = try a.Types.bind(t.allocator, parsed.program, &.{.{ .name = "events", .kind = .queue, .fields = &.{ id, .{ .name = "request", .value = .{ .kind = .capability } } } }}, null);
    defer protected.deinit();
    try t.expectError(error.ApplicationHostUnavailable, protected.requirements.requireAvailable(available()));
}
