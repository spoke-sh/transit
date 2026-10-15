//! Private general Table recovery. Immutable intent is synced before the small
//! mutable progress record; no native send belongs in this filesystem owner.
const std = @import("std");
const c = @import("transit_catalog");
const p = c.protocol;
const g = p.Growth;
const Self = @This();
pub const max_record_bytes = 32768;
pub const IntentFile = struct { digest: [32]u8, bytes: u32 };
pub const Record = struct {
    version: u8,
    definition: g.Definition,
    key: [32]u8,
    connection: c.TableClient.Connection,
    operation: ?IntentFile,
    pending: ?c.TableClient.Prepared,
    input: ?u64,
    complete: bool,
    cancelling: bool,
};
io: std.Io,
allocator: std.mem.Allocator,
path: []const u8,
lock: std.Io.File,
record: Record,
intent: ?c.TableIntent = null,
intent_commitment: ?IntentFile = null,
failed: bool = false,

pub fn open(io: std.Io, allocator: std.mem.Allocator, path: []const u8, client: *c.TableClient) !Self {
    try client.connection.validate();
    const lock_path = try std.fmt.allocPrint(allocator, "{s}.lock", .{path});
    defer allocator.free(lock_path);
    const lock = try std.Io.Dir.cwd().createFile(io, lock_path, .{ .truncate = false, .permissions = .fromMode(0o600) });
    errdefer lock.close(io);
    if (!try lock.tryLock(io, .exclusive)) return error.ConsoleRecoveryInUse;
    var self: Self = .{
        .io = io,
        .allocator = allocator,
        .path = path,
        .lock = lock,
        .record = .{ .version = 1, .definition = g.current_definition, .key = client.key.public_key.toBytes(), .connection = client.connection, .operation = null, .pending = null, .input = null, .complete = false, .cancelling = false },
    };
    errdefer if (self.intent) |*intent| intent.deinit();
    const bytes = std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(max_record_bytes)) catch |err| {
        if (err == error.FileNotFound) return self;
        return err;
    };
    defer erase(allocator, bytes);
    const parsed = try std.json.parseFromSlice(Record, allocator, bytes, .{});
    defer parsed.deinit();
    const record = parsed.value;
    if (record.version != 1 or !std.meta.eql(record.definition, g.current_definition) or !std.meta.eql(record.connection, client.connection) or !std.meta.eql(record.key, self.record.key)) return error.ConsoleRecoveryIdentityMismatch;
    const canonical = try std.json.Stringify.valueAlloc(allocator, record, .{});
    defer erase(allocator, canonical);
    if (!std.mem.eql(u8, bytes, canonical)) return error.InvalidConsoleRecovery;
    self.record = record;
    if (record.operation) |file| {
        if (file.bytes < c.TableIntent.prefix_bytes or file.bytes > c.TableIntent.max_bytes) return error.InvalidConsoleRecovery;
        const intent_path = try self.intentPath(file);
        defer allocator.free(intent_path);
        const intent_bytes = try std.Io.Dir.cwd().readFileAlloc(io, intent_path, allocator, .limited(c.TableIntent.max_bytes));
        defer erase(allocator, intent_bytes);
        if (!std.meta.eql(file, commitment(intent_bytes))) return error.InvalidConsoleRecovery;
        self.intent = try c.TableIntent.restore(allocator, intent_bytes);
        self.intent_commitment = file;
        try client.connection.header(self.intent.?.header);
    }
    try self.validate(client);
    return self;
}
fn commitment(bytes: []const u8) IntentFile {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return .{ .digest = digest, .bytes = @intCast(bytes.len) };
}
fn erase(allocator: std.mem.Allocator, bytes: []u8) void {
    std.crypto.secureZero(u8, bytes);
    allocator.free(bytes);
}
fn intentPath(self: *const Self, file: IntentFile) ![]u8 {
    return std.fmt.allocPrint(self.allocator, "{s}.intent-{s}", .{ self.path, std.fmt.bytesToHex(file.digest, .lower) });
}
pub fn validate(self: *const Self, client: *c.TableClient) !void {
    if (self.record.version != 1 or !std.meta.eql(self.record.definition, g.current_definition) or !std.meta.eql(self.record.connection, client.connection) or !std.meta.eql(self.record.key, client.key.public_key.toBytes())) return error.ConsoleRecoveryIdentityMismatch;
    if (self.record.operation == null) {
        if (self.intent != null or self.intent_commitment != null or self.record.pending != null or self.record.input != null or self.record.complete or self.record.cancelling) return error.InvalidConsoleRecovery;
        return;
    }
    const intent = if (self.intent) |*value| value else return error.InvalidConsoleRecovery;
    try client.connection.header(intent.header);
    // Owned intent was validated on install/open and is immutable. Progress
    // checkpoints never hash or re-encode the full multi-megabyte command again.
    if (!std.meta.eql(self.record.operation, self.intent_commitment)) return error.InvalidConsoleRecovery;
    if (self.record.input) |input| if (input == 0 or input > p.max_counter or self.record.pending == null) return error.InvalidConsoleRecovery;
    if (self.record.pending) |pending| {
        if (self.record.complete and self.record.input == null) return error.InvalidConsoleRecovery;
        if (!std.meta.eql(pending.definition, g.current_definition)) return error.InvalidConsoleRecovery;
        try client.validate(pending);
        if (!try pending.matches(intent)) return error.InvalidConsoleRecovery;
    }
}
pub fn close(self: *Self) void {
    if (self.intent) |*intent| {
        std.crypto.secureZero(u8, intent.bytes);
        intent.deinit();
    }
    self.lock.close(self.io);
    std.crypto.secureZero(u8, std.mem.asBytes(&self.record));
    self.* = undefined;
}
pub fn unresolved(self: *const Self) bool {
    return self.record.operation != null and !self.record.complete;
}
fn write(self: *Self, path: []const u8, bytes: []const u8, replace: bool) !void {
    const parent = try std.Io.Dir.cwd().openDir(self.io, std.fs.path.dirname(path) orelse ".", .{ .iterate = true });
    defer parent.close(self.io);
    var file = try parent.createFileAtomic(self.io, std.fs.path.basename(path), .{ .replace = replace, .permissions = .fromMode(0o600) });
    defer file.deinit(self.io);
    try file.file.writeStreamingAll(self.io, bytes);
    try file.file.sync(self.io);
    if (replace) try file.replace(self.io) else try file.link(self.io);
    if (std.c.fsync(parent.handle) != 0) return error.ConsoleRecoverySyncFailed;
}
pub fn save(self: *Self, client: *c.TableClient) !void {
    if (self.failed) return error.ConsoleRecoveryWriteFailed;
    errdefer self.failed = true;
    try self.validate(client);
    const bytes = try std.json.Stringify.valueAlloc(self.allocator, self.record, .{});
    defer erase(self.allocator, bytes);
    if (bytes.len > max_record_bytes) return error.ConsoleRecoveryTooLarge;
    try self.write(self.path, bytes, true);
}
/// The caller keeps ownership of intent. Its canonical bytes are copied only
/// once when starting new work, never when advancing upload/input progress.
pub fn install(self: *Self, client: *c.TableClient, intent: *const c.TableIntent) !void {
    if (self.failed) return error.ConsoleRecoveryWriteFailed;
    if (self.unresolved()) return error.UnresolvedSubmission;
    try client.connection.header(intent.header);
    var owned = try c.TableIntent.restore(self.allocator, intent.bytes);
    var transferred = false;
    defer if (!transferred) owned.deinit();
    const file = commitment(owned.bytes);
    const intent_path = try self.intentPath(file);
    defer self.allocator.free(intent_path);
    // An orphan may come from a crash before the progress record was published.
    // Reuse only identical canonical content, never overwrite a saved intent.
    if (std.Io.Dir.cwd().readFileAlloc(self.io, intent_path, self.allocator, .limited(c.TableIntent.max_bytes))) |existing| {
        defer erase(self.allocator, existing);
        if (!std.mem.eql(u8, existing, owned.bytes)) return error.InvalidConsoleRecovery;
    } else |err| {
        if (err != error.FileNotFound) return err;
        self.write(intent_path, owned.bytes, false) catch |failure| {
            self.failed = true;
            return failure;
        };
    }
    const previous = self.record.operation;
    if (self.intent) |*old| {
        std.crypto.secureZero(u8, old.bytes);
        old.deinit();
    }
    self.intent = owned;
    self.intent_commitment = file;
    transferred = true;
    self.record.operation = file;
    self.record.pending = null;
    self.record.input = null;
    self.record.complete = false;
    self.record.cancelling = false;
    try self.save(client);
    if (previous) |old| if (!std.meta.eql(old, file)) try self.remove(old);
}
fn remove(self: *Self, file: IntentFile) !void {
    const path = try self.intentPath(file);
    defer self.allocator.free(path);
    std.Io.Dir.cwd().deleteFile(self.io, path) catch |err| {
        if (err != error.FileNotFound) return err;
    };
    // Unreferenced bytes are local recovery storage, not native Table cleanup.
    // A crash can leave an orphan; it cannot remove the new record's intent.
}
pub fn clearComplete(self: *Self, client: *c.TableClient) !void {
    if (self.failed) return error.ConsoleRecoveryWriteFailed;
    if (self.unresolved()) return error.UnresolvedSubmission;
    const previous = self.record.operation;
    if (self.intent) |*intent| {
        std.crypto.secureZero(u8, intent.bytes);
        intent.deinit();
    }
    self.intent = null;
    self.intent_commitment = null;
    self.record.operation = null;
    self.record.pending = null;
    self.record.input = null;
    self.record.complete = false;
    self.record.cancelling = false;
    try self.save(client);
    if (previous) |old| try self.remove(old);
}

const testing = struct {
    const t = std.testing;
    fn client() !c.TableClient {
        return .{ .transport = undefined, .connection = .{ .scope = .{ .realm = 46, .resource = 7, .catalog = std.math.maxInt(u64) }, .owner = 3, .principal = 1234 }, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(10)) };
    }
    fn intent(caller: *c.TableClient, operation: u64) !c.TableIntent {
        const large: [48000]u8 = @splat('a');
        const columns = [_]c.fuze.TableSchema.Column{.{ .id = 1, .name = "value", .type = .utf8, .default = .{ .value = .{ .atom = .{ .bytes = &large } } } }};
        const request: c.TableDdlRequest = .{ .principal = caller.connection.principal, .operation = operation, .object = operation, .expected_revision = 0, .name = try c.TableMetadata.Name.init("people"), .action = .{ .create = .{ .schema = .{ .object = operation, .revision = 1, .next_column = 2, .columns = &columns }, .if_not_exists = false } } };
        return c.TableIntent.create(t.allocator, try c.TableCommand.fromDdl(caller.connection.scope, caller.connection.owner, request, null), operation);
    }
    fn prepared(caller: *c.TableClient, work: *const c.TableIntent) !c.TableClient.Prepared {
        return .{ .version = 1, .definition = g.current_definition, .connection = caller.connection, .public_key = caller.key.public_key.toBytes(), .signed = try g.sign(.{ .realm = caller.connection.scope.realm, .principal = caller.connection.principal, .sequence = 3, .command = .{ .send = .{ .pid = caller.connection.owner, .value = try (c.station.Frame{ .kind = .cast, .payload = try (c.TableControl.Command{ .begin = .{ .header = try work.header.encode(), .namespace = work.namespace, .spec = work.spec } }).encode() }).encode() } } }, caller.key) };
    }
};
test "general Table recovery retains large intent and exact uncertain upload across close" {
    const t = std.testing;
    var directory = t.tmpDir(.{});
    defer directory.cleanup();
    const root = try directory.dir.realPathFileAlloc(t.io, ".", t.allocator);
    defer t.allocator.free(root);
    const path = try std.fs.path.join(t.allocator, &.{ root, "saved.json" });
    defer t.allocator.free(path);
    var caller = try testing.client();
    var work = try testing.intent(&caller, 101);
    defer work.deinit();
    const pending = try testing.prepared(&caller, &work);
    var file: IntentFile = undefined;
    {
        var saved = try open(t.io, t.allocator, path, &caller);
        defer saved.close();
        try saved.install(&caller, &work);
        file = saved.record.operation.?;
        try t.expect(work.bytes.len > max_record_bytes);
        saved.record.pending = pending;
        try saved.save(&caller);
        try t.expect(saved.unresolved());
        try t.expectError(error.ConsoleRecoveryInUse, open(t.io, t.allocator, path, &caller));
        const record = try std.Io.Dir.cwd().readFileAlloc(t.io, path, t.allocator, .limited(max_record_bytes));
        defer t.allocator.free(record);
        try t.expect(record.len < 8192);
        try t.expect(std.mem.indexOf(u8, record, "aaaaaaaaaaaa") == null);
    }
    {
        var saved = try open(t.io, t.allocator, path, &caller);
        defer saved.close();
        try t.expectEqualDeep(pending, saved.record.pending.?);
        try t.expect(saved.record.input == null);
        try t.expectEqualSlices(u8, work.bytes, saved.intent.?.bytes);
        try t.expectEqualDeep(file, saved.record.operation.?);
        try t.expectError(error.UnresolvedSubmission, saved.install(&caller, &work));
        try t.expectError(error.UnresolvedSubmission, saved.clearComplete(&caller));
        saved.record.input = 40;
        try saved.save(&caller);
        const immutable_path = try saved.intentPath(file);
        defer t.allocator.free(immutable_path);
        const bytes = try std.Io.Dir.cwd().readFileAlloc(t.io, immutable_path, t.allocator, .limited(c.TableIntent.max_bytes));
        defer t.allocator.free(bytes);
        try t.expectEqualSlices(u8, work.bytes, bytes);
        // Invalid successor progress cannot replace the last durable record.
        saved.record.input = 0;
        try t.expectError(error.InvalidConsoleRecovery, saved.save(&caller));
        try t.expect(saved.failed);
        try t.expectError(error.ConsoleRecoveryWriteFailed, saved.clearComplete(&caller));
    }
    {
        var saved = try open(t.io, t.allocator, path, &caller);
        defer saved.close();
        try t.expectEqual(@as(?u64, 40), saved.record.input);
        try t.expectEqualDeep(pending, saved.record.pending.?);
        saved.record.complete = true;
        try saved.save(&caller);
        try saved.clearComplete(&caller);
        try t.expect(!saved.unresolved() and saved.intent == null);
        const immutable_path = try saved.intentPath(file);
        defer t.allocator.free(immutable_path);
        try t.expectError(error.FileNotFound, std.Io.Dir.cwd().access(t.io, immutable_path, .{}));
    }
}
test "orphan intent is not adopted and corrupt referenced intent rejects offline" {
    const t = std.testing;
    var directory = t.tmpDir(.{});
    defer directory.cleanup();
    const root = try directory.dir.realPathFileAlloc(t.io, ".", t.allocator);
    defer t.allocator.free(root);
    const path = try std.fs.path.join(t.allocator, &.{ root, "saved.json" });
    defer t.allocator.free(path);
    var caller = try testing.client();
    var first = try testing.intent(&caller, 101);
    defer first.deinit();
    var second = try testing.intent(&caller, 102);
    defer second.deinit();
    {
        var saved = try open(t.io, t.allocator, path, &caller);
        defer saved.close();
        try saved.install(&caller, &first);
        const orphan = try saved.intentPath(commitment(second.bytes));
        defer t.allocator.free(orphan);
        try saved.write(orphan, second.bytes, false);
    }
    {
        var saved = try open(t.io, t.allocator, path, &caller);
        defer saved.close();
        try t.expectEqual(@as(u64, 101), saved.intent.?.header.operation);
        const original = try saved.intentPath(saved.record.operation.?);
        defer t.allocator.free(original);
        try saved.write(original, second.bytes, true);
    }
    try t.expectError(error.InvalidConsoleRecovery, open(t.io, t.allocator, path, &caller));
    caller.connection.scope.catalog -= 1;
    try t.expectError(error.ConsoleRecoveryIdentityMismatch, open(t.io, t.allocator, path, &caller));
}
test "saved compatibility fields and signed identities never acquire defaults" {
    const t = std.testing;
    var directory = t.tmpDir(.{});
    defer directory.cleanup();
    const root = try directory.dir.realPathFileAlloc(t.io, ".", t.allocator);
    defer t.allocator.free(root);
    const path = try std.fs.path.join(t.allocator, &.{ root, "saved.json" });
    defer t.allocator.free(path);
    var caller = try testing.client();
    var work = try testing.intent(&caller, 101);
    defer work.deinit();
    {
        var saved = try open(t.io, t.allocator, path, &caller);
        defer saved.close();
        try saved.install(&caller, &work);
        saved.record.pending = try testing.prepared(&caller, &work);
        try saved.save(&caller);
    }
    const original = try std.Io.Dir.cwd().readFileAlloc(t.io, path, t.allocator, .limited(max_record_bytes));
    defer t.allocator.free(original);
    for (0..6) |index| {
        var parsed = try std.json.parseFromSlice(std.json.Value, t.allocator, original, .{});
        defer parsed.deinit();
        const record = &parsed.value.object;
        const pending = &record.getPtr("pending").?.object;
        const request = &pending.getPtr("signed").?.object.getPtr("request").?.object;
        switch (index) {
            0 => try t.expect(record.swapRemove("definition")),
            1 => try t.expect(pending.swapRemove("definition")),
            2 => try t.expect(request.swapRemove("definition")),
            3 => record.getPtr("definition").?.* = .{ .string = "foreign-definition" },
            4 => request.getPtr("sequence").?.* = .{ .integer = 4 },
            5 => record.getPtr("complete").?.* = .{ .bool = true },
            else => unreachable,
        }
        const changed = try std.json.Stringify.valueAlloc(t.allocator, parsed.value, .{});
        defer t.allocator.free(changed);
        // Deliberately malformed disk data; no network transport is available.
        try @import("server/Files.zig").write(t.io, path, changed);
        if (open(t.io, t.allocator, path, &caller)) |opened| {
            var saved = opened;
            saved.close();
            return error.TestUnexpectedResult;
        } else |_| {}
    }
}
