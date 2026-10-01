//! Local command drafts, never signed recovery or execution authority. Disk scans
//! retain one bounded record, independently of the number of saved statements.
const std = @import("std");
const max_bytes = @import("transit_query").fuze.Sql.max_statement_bytes;
const Signals = @import("Signals.zig");
const Self = @This();
const memory_limit = 8;
const record_limit = max_bytes * 6 + 2;

io: std.Io,
allocator: std.mem.Allocator,
file: ?std.Io.File = null,
floor: u64 = 0,
memory: [memory_limit][max_bytes]u8 = undefined,
lengths: [memory_limit]usize = @splat(0),
count: usize = 0,

pub const Entry = struct { position: u64, length: usize };

pub fn open(self: *Self, home: ?[]const u8) !void {
    const directory = home orelse return error.HomeDirectoryUnavailable;
    if (directory.len == 0) return error.HomeDirectoryUnavailable;
    const path = try std.fs.path.join(self.allocator, &.{ directory, ".transit_history" });
    defer self.allocator.free(path);
    const file = std.Io.Dir.cwd().createFile(self.io, path, .{ .read = true, .exclusive = true, .permissions = .fromMode(0o600) }) catch |err| switch (err) {
        error.PathAlreadyExists => try std.Io.Dir.cwd().openFile(self.io, path, .{ .mode = .read_write, .follow_symlinks = false }),
        else => return err,
    };
    errdefer file.close(self.io);
    if ((try file.stat(self.io)).kind != .file) return error.InvalidHistoryFile;
    try file.setPermissions(self.io, .fromMode(0o600));
    self.file = file;
}

pub fn close(self: *Self) void {
    if (self.file) |file| file.close(self.io);
    self.file = null;
}

pub fn clear(self: *Self) void {
    std.crypto.secureZero(u8, std.mem.asBytes(&self.memory));
    self.lengths = @splat(0);
    self.count = 0;
    // Denial clears recall for this session, without deleting a user's file.
    self.floor = self.end() catch std.math.maxInt(u64);
}

pub fn end(self: *Self) !u64 {
    return if (self.file) |file| (try file.stat(self.io)).size else self.count;
}

fn eligible(statement: []const u8) bool {
    const trimmed = std.mem.trim(u8, statement, " \t\r\n");
    if (trimmed.len == 0 or trimmed.len > max_bytes) return false;
    if (!std.unicode.utf8ValidateSlice(statement)) return false;
    for (statement) |byte| if ((byte < 32 and byte != '\n' and byte != '\r' and byte != '\t') or byte == 127) return false;
    return statement.len <= max_bytes;
}

pub fn remember(self: *Self, statement: []const u8) !void {
    if (!eligible(statement)) return;
    if (self.count == memory_limit) {
        for (0..memory_limit - 1) |i| {
            self.memory[i] = self.memory[i + 1];
            self.lengths[i] = self.lengths[i + 1];
        }
        self.count -= 1;
    }
    @memcpy(self.memory[self.count][0..statement.len], statement);
    self.lengths[self.count] = statement.len;
    self.count += 1;
    const file = self.file orelse return;
    // Lock only the append, so simultaneous consoles do not replace each
    // other's history and a busy file cannot hold up command execution.
    const deadline = std.Io.Clock.awake.now(self.io).toMilliseconds() + 250;
    while (!try file.tryLock(self.io, .exclusive)) {
        if (Signals.interrupted() or std.Io.Clock.awake.now(self.io).toMilliseconds() >= deadline) return error.HistoryBusy;
        try self.io.sleep(.fromMilliseconds(10), .awake);
    }
    defer file.unlock(self.io);
    const offset = try self.end();
    var storage: [record_limit + 2]u8 = undefined;
    defer std.crypto.secureZero(u8, &storage);
    var writer: std.Io.Writer = .fixed(&storage);
    if (offset > 0) {
        var last: [1]u8 = undefined;
        if (try file.readPositionalAll(self.io, &last, offset - 1) != 1) return error.HistoryChanged;
        // Keep a torn record separate; never truncate or repair old content.
        if (last[0] != '\n') try writer.writeByte('\n');
    }
    try std.json.Stringify.value(statement, .{}, &writer);
    try writer.writeByte('\n');
    try file.writePositionalAll(self.io, writer.buffered(), offset);
    try file.sync(self.io);
}

fn decode(self: *Self, start: u64, finish: u64, output: []u8) !?Entry {
    if (finish <= start or finish - start > record_limit) return null;
    var storage: [record_limit]u8 = undefined;
    defer std.crypto.secureZero(u8, &storage);
    const bytes = storage[0..@intCast(finish - start)];
    if (try self.file.?.readPositionalAll(self.io, bytes, start) != bytes.len) return error.HistoryChanged;
    const parsed = std.json.parseFromSlice([]const u8, self.allocator, bytes, .{}) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => return null,
    };
    defer {
        std.crypto.secureZero(u8, @constCast(parsed.value));
        parsed.deinit();
    }
    if (!eligible(parsed.value)) return null;
    @memcpy(output[0..parsed.value.len], parsed.value);
    return .{ .position = start, .length = parsed.value.len };
}

pub fn previous(self: *Self, before: u64, output: []u8) !?Entry {
    const file = self.file orelse {
        if (before == 0 or self.count == 0) return null;
        const index: usize = @intCast(@min(before, self.count) - 1);
        @memcpy(output[0..self.lengths[index]], self.memory[index][0..self.lengths[index]]);
        return .{ .position = index, .length = self.lengths[index] };
    };
    var finish = @min(before, try self.end());
    var storage: [4096]u8 = undefined;
    defer std.crypto.secureZero(u8, &storage);
    while (finish > self.floor) {
        var last: [1]u8 = undefined;
        if (try file.readPositionalAll(self.io, &last, finish - 1) != 1) return error.HistoryChanged;
        const complete = last[0] == '\n';
        const line_end = if (complete) finish - 1 else finish;
        var start = line_end;
        while (start > self.floor) {
            if (Signals.interrupted()) return error.ConsoleInterrupted;
            const base = @max(self.floor, start -| storage.len);
            const block = storage[0..@intCast(start - base)];
            if (try file.readPositionalAll(self.io, block, base) != block.len) return error.HistoryChanged;
            if (std.mem.lastIndexOfScalar(u8, block, '\n')) |index| {
                start = base + index + 1;
                break;
            }
            start = base;
        }
        if (complete) if (try self.decode(start, line_end, output)) |entry| return entry;
        finish = start;
    }
    return null;
}

pub fn next(self: *Self, after: u64, output: []u8) !?Entry {
    const file = self.file orelse {
        if (after + 1 >= self.count) return null;
        const index: usize = @intCast(after + 1);
        @memcpy(output[0..self.lengths[index]], self.memory[index][0..self.lengths[index]]);
        return .{ .position = index, .length = self.lengths[index] };
    };
    const limit = try self.end();
    var start = after;
    var offset = after;
    var storage: [4096]u8 = undefined;
    defer std.crypto.secureZero(u8, &storage);
    while (offset < limit) {
        if (Signals.interrupted()) return error.ConsoleInterrupted;
        const block = storage[0..@intCast(@min(storage.len, limit - offset))];
        if (try file.readPositionalAll(self.io, block, offset) != block.len) return error.HistoryChanged;
        for (block, 0..) |byte, i| if (byte == '\n') {
            const finish = offset + i;
            if (start > after) if (try self.decode(start, finish, output)) |entry| return entry;
            start = finish + 1;
        };
        offset += block.len;
    }
    return null;
}
