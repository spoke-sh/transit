//! Scoped native secret callbacks. The trusted deployment supplies one private
//! mount for the exact namespace. Only verified file bytes enter the protected
//! host's private scratch; native metadata and read guards remain authoritative.
const std = @import("std");
const c = @import("transit_catalog");
const q = @import("transit_query_direct");
const S = c.DirectSecret;
const R = @import("ApplicationReservation.zig");
const Host = @import("ApplicationProtectedHost.zig");
const Self = @This();

client: c.DirectTableClient,
binding: S.Binding,
io: std.Io,
/// Borrowed trusted private mount, kept open until all request tasks join.
directory: std.Io.Dir,
reads: ?*q.ApplicationReadSet = null,

/// Borrowed for one expression evaluation with its current invocation and
/// transaction fences. The host erases its entire private arena on return.
pub fn callbacks(self: *Self) Host.Secrets {
    return .{ .context = self, .lookup = lookup, .current = current };
}
fn lookup(context: *anyopaque, private: std.mem.Allocator, name: []const u8) !R.Material {
    const self: *Self = @ptrCast(@alignCast(context));
    var metadata = std.heap.ArenaAllocator.init(self.client.allocator);
    defer metadata.deinit();
    const observed = try S.readObserved(&metadata, self.client, self.binding, name);
    try self.observe(observed);
    const found = observed.value orelse return error.SecretNotFound;
    const bytes = try load(self.io, self.directory, private, found.declaration);
    errdefer std.crypto.secureZero(u8, bytes);
    const revision = try found.revision.encode(private);
    return .{ .secret = .{ .bytes = bytes, .revision = revision, .origin = .named, .revision_kind = .native } };
}
fn current(context: *anyopaque, bytes: []const u8) !bool {
    const self: *Self = @ptrCast(@alignCast(context));
    return self.isCurrent(bytes);
}
/// Also used by the native reservation verifier before redeeming cached
/// material. A revision cannot redirect the verifier to another namespace.
pub fn isCurrent(self: Self, bytes: []const u8) !bool {
    var revision = try S.Revision.decode(self.client.allocator, bytes);
    defer revision.deinit();
    if (!std.meta.eql(self.binding, revision.value.binding)) return error.InvalidSecretReference;
    var output: std.heap.ArenaAllocator = .init(self.client.allocator);
    defer output.deinit();
    const observed = try S.readObserved(&output, self.client, self.binding, revision.value.name);
    try self.observe(observed);
    const found = observed.value orelse return false;
    return found.declaration.enabled and std.meta.eql(found.revision.row, revision.value.row);
}
fn observe(self: Self, observed: S.Observed) !void {
    if (self.reads) |reads| {
        if (observed.workspace != null or self.client.transaction != null) return error.InvalidTransactionGuard;
        try reads.add(.{ .current_state = .{ .namespace = self.binding.namespace, .kind = .kv, .guard = observed.guard } }, observed.policy_revision);
    }
}

/// The allocator must be the protected host's private scratch. The complete
/// allocation is erased on a failed read; the host erases successful material
/// after retaining it in the bounded reservation. Mount operators own symlinks;
/// resolve_beneath additionally restricts their resolution where supported.
fn load(io: std.Io, directory: std.Io.Dir, private: std.mem.Allocator, declaration: S.Declaration) ![]u8 {
    try declaration.validate();
    if (!declaration.enabled) return error.SecretDisabled;
    const file = directory.openFile(io, declaration.file, .{ .allow_directory = false, .resolve_beneath = true }) catch |err| return if (err == error.Canceled) err else error.SecretUnavailable;
    defer file.close(io);
    const stat = file.stat(io) catch |err| return if (err == error.Canceled) err else error.SecretUnavailable;
    if (stat.kind != .file or stat.size == 0 or stat.size > S.max_secret_bytes) return error.InvalidSecretContent;
    // One extra byte detects growth without an unbounded allocation/read.
    const memory = try private.alloc(u8, @as(usize, @intCast(stat.size)) + 1);
    @memset(memory, 0);
    errdefer std.crypto.secureZero(u8, memory);
    var reader = file.reader(io, &.{});
    const count = reader.interface.readSliceShort(memory) catch {
        const cause = reader.err orelse error.ReadFailed;
        return if (cause == error.Canceled) cause else error.SecretUnavailable;
    };
    if (count != stat.size) return error.SecretContentChanged;
    const bytes = memory[0..count];
    try declaration.verifyContent(bytes);
    return bytes;
}

test "application secret files preserve exact bytes and erase failed private reads" {
    const t = std.testing;
    var directory = t.tmpDir(.{});
    defer directory.cleanup();
    const content = "mounted-private-bytes\n";
    try directory.dir.writeFile(t.io, .{ .sub_path = "key-1", .data = content });
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(content, &digest, .{});
    var declaration: S.Declaration = .{ .name = "browser.cookie_key", .file = "key-1", .content_sha256 = digest, .enabled = true };
    var memory: [256]u8 = @splat(0x5a);
    defer std.crypto.secureZero(u8, &memory);
    var private = std.heap.FixedBufferAllocator.init(&memory);
    try t.expectEqualStrings(content, try load(t.io, directory.dir, private.allocator(), declaration));
    std.crypto.secureZero(u8, &memory);
    private.reset();
    try directory.dir.writeFile(t.io, .{ .sub_path = "key-1", .data = "different-private-bytes" });
    @memset(&memory, 0x5a);
    try t.expectError(error.SecretContentChanged, load(t.io, directory.dir, private.allocator(), declaration));
    try t.expect(private.end_index > 0);
    try t.expect(std.mem.allEqual(u8, memory[0..private.end_index], 0));
    private.reset();
    declaration.enabled = false;
    try t.expectError(error.SecretDisabled, load(t.io, directory.dir, private.allocator(), declaration));
    try t.expectEqual(0, private.end_index);
    declaration.enabled = true;
    declaration.file = "../key-1";
    try t.expectError(error.InvalidSecretReference, load(t.io, directory.dir, private.allocator(), declaration));
    declaration.file = "missing-key";
    try t.expectError(error.SecretUnavailable, load(t.io, directory.dir, private.allocator(), declaration));
}

test "application secret files bound empty oversized and allocation failures" {
    const t = std.testing;
    var directory = t.tmpDir(.{});
    defer directory.cleanup();
    var content: [S.max_secret_bytes + 1]u8 = @splat('x');
    var declaration: S.Declaration = .{ .name = "cookie_key", .file = "key", .content_sha256 = undefined, .enabled = true };
    std.crypto.hash.sha2.Sha256.hash(content[0..S.max_secret_bytes], &declaration.content_sha256, .{});
    var memory: [S.max_secret_bytes + 1]u8 = undefined;
    defer std.crypto.secureZero(u8, &memory);
    var private = std.heap.FixedBufferAllocator.init(&memory);
    try directory.dir.writeFile(t.io, .{ .sub_path = "key", .data = "" });
    try t.expectError(error.InvalidSecretContent, load(t.io, directory.dir, private.allocator(), declaration));
    try directory.dir.writeFile(t.io, .{ .sub_path = "key", .data = &content });
    try t.expectError(error.InvalidSecretContent, load(t.io, directory.dir, private.allocator(), declaration));
    try t.expectEqual(0, private.end_index);
    try directory.dir.writeFile(t.io, .{ .sub_path = "key", .data = content[0..S.max_secret_bytes] });
    try t.expectEqualSlices(u8, content[0..S.max_secret_bytes], try load(t.io, directory.dir, private.allocator(), declaration));
    var tiny = std.heap.FixedBufferAllocator.init(memory[0..8]);
    try t.expectError(error.OutOfMemory, load(t.io, directory.dir, tiny.allocator(), declaration));
}

test "application secret callbacks reject a revision from another native binding before IO" {
    const t = std.testing;
    const binding: S.Binding = .{ .namespace = 1, .interpretation = .{ .object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 4 }, .revision = 1, .digest = @splat(3) } };
    var self: Self = .{ .client = .{ .allocator = t.allocator, .authority = undefined, .service = undefined, .connection = undefined, .key = undefined }, .binding = binding, .io = t.io, .directory = undefined };
    var revision: S.Revision = .{ .definition = c.protocol.Growth.current_definition, .binding = binding, .name = "cookie_key", .row = .{ .origin = 2, .operation = 3, .ordinal = 0 } };
    revision.binding.namespace = 2;
    const bytes = try revision.encode(t.allocator);
    defer t.allocator.free(bytes);
    const host = self.callbacks();
    try t.expectError(error.InvalidSecretReference, host.current(host.context, bytes));
}
