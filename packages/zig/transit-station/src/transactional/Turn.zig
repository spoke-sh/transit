//! Private detached behavior interface. The host supplies one bounded private
//! read capability; the body cannot submit, settle or sign database work.
const std = @import("std");
const c = @import("transit_catalog");
const p = c.protocol;
const Self = @This();

pub const Limits = struct {
    bytes: usize = 64 * 1024,
    reads: u16 = 16,
    writes: u16 = 16,
    outputs: u16 = 4,

    pub fn validate(self: Limits) !void {
        if (self.bytes == 0 or self.bytes > 64 * 1024 or self.reads == 0 or self.reads > 16 or
            self.writes == 0 or self.writes > 16 or self.outputs > 4) return error.InvalidTurnLimits;
    }
};
pub const Binary = c.DirectTableProtocol.Binary;
pub const Put = struct { key: Binary, value: Binary };
pub const Table = struct { sql: []const u8, parameters: []const ?c.fuze.Types.Values.Atom };
pub const Draft = struct {
    pub const json_schema_sequence_bounds = .{ .puts = 16, .tables = 16, .outputs = 4 };
    puts: []const Put,
    tables: []const []const u8,
    outputs: []const Binary,
    journal: Binary,
};
pub const Row = struct { cells: []const c.fuze.Types.Values.Cell, encoded_bytes: usize };
pub const Read = struct {
    context: *anyopaque,
    get: *const fn (*anyopaque, std.mem.Allocator, []const u8) anyerror!?[]const u8,
    row: ?*const fn (*anyopaque, []const c.fuze.Types.Values.Cell) anyerror!?Row = null,
    table: ?*const fn (*anyopaque, Table) anyerror!void = null,
};

allocator: std.mem.Allocator,
limits: Limits,
reader: Read,
source: p.StreamQueue.RecordIdentity,
input: []const u8,
puts: std.ArrayList(Put) = .empty,
tables: std.ArrayList([]const u8) = .empty,
outputs: std.ArrayList(Binary) = .empty,
journal_bytes: Binary = .{ .base64 = "" },
bytes: usize = 0,
reads: u16 = 0,
poisoned: bool = false,

pub fn init(allocator: std.mem.Allocator, limits: Limits, reader: Read, source: p.StreamQueue.RecordIdentity, input: []const u8) !Self {
    try limits.validate();
    try source.validate();
    if (input.len > limits.bytes) return error.TurnCapacity;
    return .{ .allocator = allocator, .limits = limits, .reader = reader, .source = source, .input = input, .bytes = input.len };
}

fn own(self: *Self, bytes: []const u8) ![]const u8 {
    if (bytes.len > self.limits.bytes - self.bytes) return error.TurnCapacity;
    const copy = try self.allocator.dupe(u8, bytes);
    self.bytes += bytes.len;
    return copy;
}

fn binary(self: *Self, bytes: []const u8) !Binary {
    if (bytes.len > self.limits.bytes - self.bytes) return error.TurnCapacity;
    const result = try Binary.encode(self.allocator, bytes);
    self.bytes += bytes.len;
    return result;
}

pub fn get(self: *Self, key: []const u8) !?[]const u8 {
    errdefer self.poisoned = true;
    if (self.poisoned) return error.PoisonedTurn;
    if (self.reads == self.limits.reads) return error.TurnCapacity;
    self.reads += 1;
    var at = self.puts.items.len;
    while (at != 0) {
        at -= 1;
        var key_buffer: [c.storage.KVPartition.max_key_bytes]u8 = undefined;
        var scratch = std.heap.FixedBufferAllocator.init(&key_buffer);
        if (std.mem.eql(u8, try self.puts.items[at].key.decode(scratch.allocator(), key_buffer.len), key)) {
            const bytes = try self.puts.items[at].value.decode(self.allocator, self.limits.bytes - self.bytes);
            self.bytes += bytes.len;
            return bytes;
        }
    }
    const bytes = try self.reader.get(self.reader.context, self.allocator, key) orelse return null;
    if (bytes.len > self.limits.bytes - self.bytes) return error.TurnCapacity;
    self.bytes += bytes.len;
    return bytes;
}

/// Typed primary-key values address the one immutable declared Table.
pub fn readTable(self: *Self, key: []const c.fuze.Types.Values.Cell) !?[]const c.fuze.Types.Values.Cell {
    errdefer self.poisoned = true;
    if (self.poisoned) return error.PoisonedTurn;
    if (self.reads == self.limits.reads) return error.TurnCapacity;
    self.reads += 1;
    const read = self.reader.row orelse return error.UnsupportedTableRead;
    const row = try read(self.reader.context, key) orelse return null;
    if (row.encoded_bytes > self.limits.bytes - self.bytes) return error.TurnCapacity;
    self.bytes += row.encoded_bytes;
    return row.cells;
}

pub fn put(self: *Self, key: []const u8, value: []const u8) !void {
    errdefer self.poisoned = true;
    if (self.poisoned) return error.PoisonedTurn;
    if (key.len == 0 or key.len > c.storage.KVPartition.max_key_bytes or self.puts.items.len + self.tables.items.len >= self.limits.writes)
        return error.TurnCapacity;
    try self.puts.append(self.allocator, .{ .key = try self.binary(key), .value = try self.binary(value) });
}

pub fn table(self: *Self, sql: []const u8, parameters: []const ?c.fuze.Types.Values.Atom) !void {
    errdefer self.poisoned = true;
    if (self.poisoned) return error.PoisonedTurn;
    if (self.puts.items.len + self.tables.items.len >= self.limits.writes) return error.TurnCapacity;
    const Atom = c.fuze.Types.Values.Atom;
    const fixed = try std.math.mul(usize, parameters.len, @sizeOf(?Atom));
    if (fixed > self.limits.bytes - self.bytes) return error.TurnCapacity;
    self.bytes += fixed;
    const owned = try self.allocator.alloc(?Atom, parameters.len);
    for (parameters, owned) |parameter, *copy| {
        copy.* = if (parameter) |atom| blk: {
            const extra: usize = if (atom == .bytes) atom.bytes.len else if (atom == .capability) 32 else 0;
            if (extra > self.limits.bytes - self.bytes) return error.TurnCapacity;
            self.bytes += extra;
            break :blk try c.fuze.Types.Values.cloneAtom(self.allocator, atom);
        } else null;
    }
    const text = try self.own(sql);
    try self.tables.append(self.allocator, text);
    const stage = self.reader.table orelse return error.UnsupportedTableWrite;
    // The host retains the typed, bound work in the ordinary transaction owner
    // before execution. The draft keeps SQL for inspection, never JSON-encodes
    // binary scalar parameters or attempts to reconstruct accepted statements.
    try stage(self.reader.context, .{ .sql = text, .parameters = owned });
}

pub fn emit(self: *Self, bytes: []const u8) !void {
    errdefer self.poisoned = true;
    if (self.poisoned) return error.PoisonedTurn;
    if (self.outputs.items.len >= self.limits.outputs) return error.TurnCapacity;
    try self.outputs.append(self.allocator, try self.binary(bytes));
}

pub fn journal(self: *Self, bytes: []const u8) !void {
    errdefer self.poisoned = true;
    if (self.poisoned) return error.PoisonedTurn;
    self.journal_bytes = try self.binary(bytes);
}

pub fn finish(self: *Self) !Draft {
    if (self.poisoned) return error.PoisonedTurn;
    return .{ .puts = self.puts.items, .tables = self.tables.items, .outputs = self.outputs.items, .journal = self.journal_bytes };
}

test "private transactional turn poisons caught reads and owns handler scratch" {
    const t = std.testing;
    const Reader = struct {
        fail: bool = false,
        fn get(raw: *anyopaque, allocator: std.mem.Allocator, _: []const u8) !?[]const u8 {
            const self: *@This() = @ptrCast(@alignCast(raw));
            if (self.fail) return error.AccessDenied;
            return try allocator.dupe(u8, "retained");
        }
    };
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    var reader: Reader = .{};
    const source: p.StreamQueue.RecordIdentity = .{
        .target = .{ .definition = p.Growth.current_definition, .interpretation = .{ .object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 7 }, .revision = 1, .digest = @splat(1) }, .partition = 0 },
        .operation = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .principal = 4, .operation = 5 },
        .ordinal = 0,
    };
    var turn = try init(arena.allocator(), .{}, .{ .context = &reader, .get = Reader.get }, source, "input");
    var scratch: [512]u8 = @splat(42);
    try turn.put("first", &scratch);
    try turn.emit(&scratch);
    @memset(&scratch, 0);
    try t.expectEqual(@as(u8, 42), (try turn.get("first")).?[0]);
    try t.expectEqual(@as(u8, 42), (try (try turn.finish()).outputs[0].decode(arena.allocator(), 512))[0]);
    reader.fail = true;
    _ = turn.get("unread") catch null;
    try t.expectError(error.PoisonedTurn, turn.finish());
    try t.expectError(error.PoisonedTurn, turn.put("second", "hidden"));
    reader.fail = false;
    for (0..4) |ceiling| {
        _ = arena.reset(.retain_capacity);
        var bounded = try init(arena.allocator(), .{ .reads = 1, .writes = 1, .outputs = 1, .bytes = 8 }, .{ .context = &reader, .get = Reader.get }, source, "");
        switch (ceiling) {
            0 => {
                _ = try bounded.get("one");
                try t.expectError(error.TurnCapacity, bounded.get("two"));
            },
            1 => {
                try bounded.put("a", "b");
                try t.expectError(error.TurnCapacity, bounded.put("c", "d"));
            },
            2 => {
                try bounded.emit("first");
                try t.expectError(error.TurnCapacity, bounded.emit("second"));
            },
            3 => try t.expectError(error.TurnCapacity, bounded.put("k", "12345678")),
            else => unreachable,
        }
        try t.expectError(error.PoisonedTurn, bounded.finish());
    }
    var failing = std.testing.FailingAllocator.init(t.allocator, .{ .fail_index = 0 });
    var exhausted = try init(failing.allocator(), .{}, .{ .context = &reader, .get = Reader.get }, source, "input");
    try t.expectError(error.OutOfMemory, exhausted.put("a", "b"));
    try t.expectError(error.PoisonedTurn, exhausted.finish());
}
