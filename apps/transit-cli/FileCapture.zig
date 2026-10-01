//! Local acquisition boundary: explicit paths/stdin, quota-limited unlinked disk
//! captures, checked gzip, and cancellation. No network or durable acceptance.
const std = @import("std");
const f = @import("transit_query").fuze;
const Signals = @import("Signals.zig");
const Self = @This();
io: std.Io,
file: std.Io.File,
length: u64 = 0,
digest: [32]u8 = undefined,

pub fn close(self: *Self) void {
    self.file.close(self.io);
    self.* = undefined;
}
pub fn check(_: *anyopaque) !void {
    if (Signals.interrupted()) return error.FileQueryInterrupted;
}
fn read(context: *anyopaque, offset: u64, output: []u8) !usize {
    const self: *Self = @ptrCast(@alignCast(context));
    try check(context);
    return self.file.readPositional(self.io, &.{output}, offset);
}
pub fn source(self: *Self) f.FileSource.Source {
    return .{ .context = self, .read = read, .check = check, .length = self.length, .digest = self.digest };
}
fn temporary(init: std.process.Init) !Self {
    var directory = try std.Io.Dir.cwd().openDir(init.io, init.environ_map.get("TMPDIR") orelse "/tmp", .{});
    defer directory.close(init.io);
    var random: [16]u8 = undefined;
    init.io.random(&random);
    var name_buffer: [80]u8 = undefined;
    const name = try std.fmt.bufPrint(&name_buffer, "transit-file-{x}", .{random});
    const file = try directory.createFile(init.io, name, .{ .read = true, .exclusive = true, .permissions = .fromMode(0o600) });
    errdefer file.close(init.io);
    // The open descriptor keeps bytes alive. Normal cleanup and process death
    // both release storage without leaving a named capture to replay by mistake.
    try directory.deleteFile(init.io, name);
    return .{ .io = init.io, .file = file };
}
pub fn acquire(init: std.process.Init, path: []const u8, encoded_remaining: *u64, expanded_remaining: *u64, gzip: bool) !Self {
    try check(undefined);
    const stdin = std.mem.eql(u8, path, "-");
    const input: std.Io.File = if (stdin) .stdin() else blk: {
        const name = try init.gpa.dupeSentinel(u8, path, 0);
        defer init.gpa.free(name);
        const fd = std.c.open(name, .{ .ACCMODE = .RDONLY, .CLOEXEC = true, .NONBLOCK = true });
        if (fd < 0) return error.SourceOpenFailed;
        break :blk .{ .handle = fd, .flags = .{ .nonblocking = true } };
    };
    defer if (!stdin) input.close(init.io);
    const before = try input.stat(init.io);
    if (!stdin and before.kind != .file) return error.NonRegularSourcePath;
    var captured = try temporary(init);
    errdefer captured.close();
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    var bytes: [65536]u8 = undefined;
    while (true) {
        try check(undefined);
        if (stdin) {
            var poll: [1]std.c.pollfd = .{.{ .fd = input.handle, .events = std.c.POLL.IN, .revents = 0 }};
            const ready = std.c.poll(&poll, 1, 100);
            if (ready == 0) continue;
            if (ready < 0) {
                if (std.c._errno().* == @backingInt(std.c.E.INTR)) continue;
                return error.SourceReadFailed;
            }
        }
        const count = std.c.read(input.handle, &bytes, bytes.len);
        if (count < 0) {
            if (std.c._errno().* == @backingInt(std.c.E.INTR)) continue;
            return error.SourceReadFailed;
        }
        if (count == 0) break;
        const length: usize = @intCast(count);
        if (length > encoded_remaining.* or (!gzip and length > expanded_remaining.*)) return error.CaptureQuotaExceeded;
        encoded_remaining.* -= length;
        if (!gzip) expanded_remaining.* -= length;
        try captured.file.writeStreamingAll(init.io, bytes[0..length]);
        hash.update(bytes[0..length]);
        captured.length += length;
    }
    if (before.kind == .file) {
        const after = try input.stat(init.io);
        if (before.inode != after.inode or before.size != after.size or
            !std.meta.eql(before.mtime, after.mtime) or !std.meta.eql(before.ctime, after.ctime) or
            (!stdin and captured.length != before.size)) return error.SourceChanged;
    }
    captured.digest = hash.finalResult();
    if (!gzip) return captured;
    const expanded = try expand(init, &captured, expanded_remaining);
    captured.close();
    return expanded;
}
const CheckedReader = struct {
    capture: *Self,
    offset: u64 = 0,
    cause: ?anyerror = null,
    reader: std.Io.Reader,
    fn stream(reader: *std.Io.Reader, writer: *std.Io.Writer, limit: std.Io.Limit) std.Io.Reader.StreamError!usize {
        const self: *@This() = @alignCast(@fieldParentPtr("reader", reader));
        var bytes: [8192]u8 = undefined;
        const count = read(self.capture, self.offset, bytes[0..limit.minInt(bytes.len)]) catch |err| {
            self.cause = err;
            return error.ReadFailed;
        };
        if (count == 0) return error.EndOfStream;
        const written = try writer.write(bytes[0..count]);
        self.offset += written;
        return written;
    }
};
// Validate the entire bounded gzip header, including optional header CRC. The
// standard raw inflater owns DEFLATE; this host verifies CRC/ISIZE and exact EOF.
fn gzipHeader(reader: *std.Io.Reader) !void {
    const fixed = try reader.takeArray(10);
    if (fixed[0] != 0x1f or fixed[1] != 0x8b or fixed[2] != 8 or fixed[3] & 0xe0 != 0) return error.InvalidGzipHeader;
    const flags = fixed[3];
    var crc: std.hash.Crc32 = .init();
    crc.update(fixed);
    var remaining: usize = 65536 - 10;
    if (flags & 4 != 0) {
        const size = try reader.takeArray(2);
        crc.update(size);
        remaining -= 2;
        const count = std.mem.readInt(u16, size, .little);
        if (count > remaining) return error.GzipHeaderTooLarge;
        for (0..count) |_| {
            const byte = try reader.takeByte();
            crc.update(&.{byte});
        }
        remaining -= count;
    }
    for ([_]u8{ 8, 16 }) |flag| if (flags & flag != 0) {
        while (true) {
            if (remaining == 0) return error.GzipHeaderTooLarge;
            remaining -= 1;
            const byte = try reader.takeByte();
            crc.update(&.{byte});
            if (byte == 0) break;
        }
    };
    if (flags & 2 != 0) {
        if (remaining < 2) return error.GzipHeaderTooLarge;
        if (try reader.takeInt(u16, .little) != @as(u16, @truncate(crc.final()))) return error.InvalidGzipHeaderCrc;
    }
}
fn expand(init: std.process.Init, encoded: *Self, remaining: *u64) !Self {
    var buffer: [8192]u8 = undefined;
    var input: CheckedReader = .{ .capture = encoded, .reader = .{ .buffer = &buffer, .seek = 0, .end = 0, .vtable = &.{ .stream = CheckedReader.stream } } };
    var output = try temporary(init);
    errdefer output.close();
    expandInner(init, &input, &output, remaining) catch |err| return input.cause orelse err;
    return output;
}
fn expandInner(init: std.process.Init, input: *CheckedReader, output: *Self, remaining: *u64) !void {
    try gzipHeader(&input.reader);
    var window: [std.compress.flate.max_window_len]u8 = undefined;
    var inflater: std.compress.flate.Decompress = .init(&input.reader, .raw, &window);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    var crc: std.hash.Crc32 = .init();
    var bytes: [65536]u8 = undefined;
    while (true) {
        try check(undefined);
        const count = inflater.reader.readSliceShort(&bytes) catch |err| return inflater.err orelse err;
        if (count == 0) break;
        if (count > remaining.*) return error.CaptureQuotaExceeded;
        remaining.* -= count;
        try output.file.writeStreamingAll(init.io, bytes[0..count]);
        output.length += count;
        hash.update(bytes[0..count]);
        crc.update(bytes[0..count]);
    }
    const checksum = try input.reader.takeInt(u32, .little);
    const size = try input.reader.takeInt(u32, .little);
    if (checksum != crc.final() or size != @as(u32, @truncate(output.length))) return error.InvalidGzipChecksum;
    if (input.reader.takeByte()) |_| return error.GzipTrailingData else |err| if (err != error.EndOfStream) return err;
    output.digest = hash.finalResult();
}
