//! Exclusive local log owner. Disk cardinality is independent of the partition
//! cache; recovery and reads retain at most one frame plus a bounded result page.
//! Callers serialize access. An uncertain disk mutation poisons this open owner.
const std = @import("std");
const p = @import("transit_protocol");
const log = @import("TransitLog.zig");
const Self = @This();

pub const cache_slots = 8;
pub const Options = struct {
    segment_bytes: u64 = 64 * 1024 * 1024,
    batch_bytes: usize = 8 * 1024 * 1024,
    batch_frames: usize = 1024,
};
const State = struct {
    partition: u64,
    writer: u64 = 1,
    policy: u64 = 1,
    floor: u64 = 0,
    next: u64 = 0,
    segment: u64 = 0,
    offset: u64 = 0,
    /// Derived verified frame coordinates; never persisted or authoritative.
    latest: ?Cursor = null,
    read_start: ?Cursor = null,
    read_next: ?Cursor = null,
};
const Segment = struct { first: u64, bytes: u64 };
const Cursor = struct { lsn: u64, segment: u64, offset: u64 };

allocator: std.mem.Allocator,
io: std.Io,
dir: std.Io.Dir,
lock: std.Io.File,
options: Options,
cache: [cache_slots]?State = @splat(null),
replace: usize = 0,
poisoned: bool = false,
syncs: u64 = 0,
recovered_frames: u64 = 0,
truncated_tail_bytes: u64 = 0,
read_frames: u64 = 0,
read_bytes: u64 = 0,
directory_scans: u64 = 0,

fn definition() [32]u8 {
    var bytes: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, @tagName(p.Growth.current_definition)) catch unreachable;
    return bytes;
}

/// Opens a child directory, holding its process lock until deinit. A populated
/// directory without its mandatory definition marker is never initialized.
pub fn open(allocator: std.mem.Allocator, io: std.Io, parent: std.Io.Dir, path: []const u8, options: Options) !Self {
    if (options.segment_bytes < log.alignedFrameSize(1) or options.batch_bytes < log.alignedFrameSize(log.max_payload_bytes) or options.batch_frames == 0) return error.InvalidWalLimits;
    try parent.createDirPath(io, path);
    // Persist newly created directory entries as well as their later contents.
    // `parent` itself is supplied by the installation owner.
    var ancestor = std.fs.path.dirname(path);
    while (ancestor) |name| {
        const directory = try parent.openDir(io, name, .{});
        defer directory.close(io);
        try syncDir(io, directory);
        const next = std.fs.path.dirname(name);
        if (next != null and std.mem.eql(u8, name, next.?)) break;
        ancestor = next;
    }
    try syncDir(io, parent);
    const dir = try parent.openDir(io, path, .{ .iterate = true });
    errdefer dir.close(io);
    const lock = try dir.createFile(io, ".lock", .{ .read = true, .truncate = false, .permissions = .fromMode(0o600) });
    errdefer lock.close(io);
    if (!try lock.tryLock(io, .exclusive)) return error.WalInUse;
    var self: Self = .{ .allocator = allocator, .io = io, .dir = dir, .lock = lock, .options = options };
    const marker = dir.openFile(io, ".definition", .{ .follow_symlinks = false }) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    defer if (marker) |file| file.close(io);
    if (marker) |file| {
        var bytes: [32]u8 = undefined;
        if (try file.length(io) != bytes.len or try file.readPositionalAll(io, &bytes, 0) != bytes.len or !std.mem.eql(u8, &bytes, &definition())) return error.IncompatibleDefinition;
    } else {
        var it = dir.iterate();
        while (try it.next(io)) |entry| if (!std.mem.eql(u8, entry.name, ".lock")) return error.IncompatibleDefinition;
        try self.atomic(".definition", &definition());
    }
    // Validate all retained partitions without retaining their entire directory.
    // Recovery performs its own scans. Iterators on the same directory handle
    // share a filesystem offset, so the outer walk needs an independent handle
    // or a nested scan can silently skip later directory pages.
    const listing = try dir.openDir(io, ".", .{ .iterate = true });
    defer listing.close(io);
    var it = listing.iterate();
    while (try it.next(io)) |entry| {
        if (std.mem.eql(u8, entry.name, ".lock") or std.mem.eql(u8, entry.name, ".definition")) continue;
        if (entry.kind != .file) return error.InvalidWalDirectory;
        if (parseMeta(entry.name)) |id| {
            var name: [64]u8 = undefined;
            if (!std.mem.eql(u8, entry.name, metaName(id, &name))) return error.InvalidWalDirectory;
            _ = try self.load(id);
        } else if (parseSegment(entry.name)) |id| {
            var name: [96]u8 = undefined;
            if (!std.mem.eql(u8, entry.name, segmentName(id.partition, id.first, &name))) return error.InvalidWalDirectory;
            if (try self.metadata(id.partition) == null) return error.WalMetadataMissing;
        } else if (entry.name.len != 16 or (std.fmt.parseInt(u64, entry.name, 16) catch null) == null) {
            return error.InvalidWalDirectory;
        }
        // Atomic-file temporaries are unreachable. Keep them on uncertain
        // recovery; they cannot supply metadata or accepted log entries.
    }
    return self;
}

pub fn deinit(self: *Self) void {
    self.lock.close(self.io);
    self.dir.close(self.io);
    self.* = undefined;
}

fn usable(self: *Self) !void {
    if (self.poisoned) return error.WalRecoveryRequired;
}

fn syncDirectory(self: *Self) !void {
    try syncDir(self.io, self.dir);
    self.syncs += 1;
}

fn syncDir(io: std.Io, dir: std.Io.Dir) !void {
    // A supplied Dir may be O_PATH or AT_FDCWD. Reopen for actual I/O before
    // fsync, and close only the Dir owner of the descriptor.
    const current = try dir.openDir(io, ".", .{ .iterate = true });
    defer current.close(io);
    const file: std.Io.File = .{ .handle = current.handle, .flags = .{ .nonblocking = false } };
    try file.sync(io);
}

fn atomic(self: *Self, name: []const u8, bytes: []const u8) !void {
    errdefer self.poisoned = true;
    var pending = try self.dir.createFileAtomic(self.io, name, .{ .replace = true, .permissions = .fromMode(0o600) });
    defer pending.deinit(self.io);
    try pending.file.writeStreamingAll(self.io, bytes);
    try pending.file.sync(self.io);
    self.syncs += 1;
    try pending.replace(self.io);
    try self.syncDirectory();
}

fn metaName(id: u64, bytes: *[64]u8) []const u8 {
    return std.fmt.bufPrint(bytes, "part-{d}.meta", .{id}) catch unreachable;
}
fn segmentName(id: u64, first: u64, bytes: *[96]u8) []const u8 {
    return std.fmt.bufPrint(bytes, "part-{d}-{d}.twal", .{ id, first }) catch unreachable;
}
fn parseMeta(name: []const u8) ?u64 {
    if (!std.mem.startsWith(u8, name, "part-") or !std.mem.endsWith(u8, name, ".meta")) return null;
    return std.fmt.parseInt(u64, name[5 .. name.len - 5], 10) catch null;
}
fn parseSegment(name: []const u8) ?struct { partition: u64, first: u64 } {
    if (!std.mem.startsWith(u8, name, "part-") or !std.mem.endsWith(u8, name, ".twal")) return null;
    const values = name[5 .. name.len - 5];
    const dash = std.mem.indexOfScalar(u8, values, '-') orelse return null;
    return .{ .partition = std.fmt.parseInt(u64, values[0..dash], 10) catch return null, .first = std.fmt.parseInt(u64, values[dash + 1 ..], 10) catch return null };
}

fn save(self: *Self, state: State) !void {
    var bytes: [128]u8 = @splat(0);
    bytes[0..8].* = "LWMT\x01\x00\x00\x00".*;
    bytes[8..40].* = definition();
    inline for (.{ "partition", "writer", "policy", "floor", "next" }, 0..) |field, i| std.mem.writeInt(u64, bytes[40 + i * 8 ..][0..8], @field(state, field), .little);
    std.crypto.hash.sha2.Sha256.hash(bytes[0..96], bytes[96..128], .{});
    var name: [64]u8 = undefined;
    try self.atomic(metaName(state.partition, &name), &bytes);
}

fn metadata(self: *Self, id: u64) !?State {
    var name: [64]u8 = undefined;
    const file = self.dir.openFile(self.io, metaName(id, &name), .{ .follow_symlinks = false }) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    defer file.close(self.io);
    var bytes: [128]u8 = undefined;
    if (try file.length(self.io) != bytes.len or try file.readPositionalAll(self.io, &bytes, 0) != bytes.len) return error.CorruptWalMetadata;
    if (!std.mem.eql(u8, bytes[8..40], &definition())) return error.IncompatibleDefinition;
    if (!std.mem.eql(u8, bytes[0..8], "LWMT\x01\x00\x00\x00")) return error.CorruptWalMetadata;
    for (bytes[80..96]) |byte| if (byte != 0) return error.CorruptWalMetadata;
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes[0..96], &digest, .{});
    if (!std.mem.eql(u8, &digest, bytes[96..128])) return error.CorruptWalMetadata;
    var state: State = .{ .partition = id };
    inline for (.{ "partition", "writer", "policy", "floor", "next" }, 0..) |field, i| @field(state, field) = std.mem.readInt(u64, bytes[40 + i * 8 ..][0..8], .little);
    if (state.partition != id or state.writer == 0 or state.policy == 0 or state.floor > state.next) return error.CorruptWalMetadata;
    return state;
}

/// Ordered directory selection uses constant resident memory, including after
/// cache eviction. The filename identifies the first LSN, not an array offset.
fn nextSegment(self: *Self, id: u64, after: ?u64) !?Segment {
    self.directory_scans +|= 1;
    var found: ?Segment = null;
    var it = self.dir.iterate();
    while (try it.next(self.io)) |entry| {
        const parsed = parseSegment(entry.name) orelse continue;
        if (parsed.partition != id or (after != null and parsed.first <= after.?)) continue;
        if (found != null and parsed.first >= found.?.first) continue;
        const file = try self.dir.openFile(self.io, entry.name, .{ .follow_symlinks = false });
        defer file.close(self.io);
        found = .{ .first = parsed.first, .bytes = try file.length(self.io) };
    }
    return found;
}

/// Locate the newest segment that can contain a requested LSN in one bounded
/// directory pass. Full continuity/integrity validation still belongs to recover.
fn segmentAt(self: *Self, id: u64, lsn: u64) !?Segment {
    self.directory_scans +|= 1;
    var first: ?u64 = null;
    var it = self.dir.iterate();
    while (try it.next(self.io)) |entry| {
        const parsed = parseSegment(entry.name) orelse continue;
        if (parsed.partition == id and parsed.first <= lsn and (first == null or parsed.first > first.?)) first = parsed.first;
    }
    return if (first) |value| try self.segmentInfo(id, value) else null;
}

fn segmentInfo(self: *Self, id: u64, first: u64) !Segment {
    var name: [96]u8 = undefined;
    const file = try self.dir.openFile(self.io, segmentName(id, first, &name), .{ .follow_symlinks = false });
    defer file.close(self.io);
    return .{ .first = first, .bytes = try file.length(self.io) };
}

/// Read one frame without allocating from an unchecked header length.
fn frame(self: *Self, file: std.Io.File, offset: u64, allocator: std.mem.Allocator) ![]u8 {
    var header: [log.header_bytes]u8 = undefined;
    const acquired = try file.readPositionalAll(self.io, &header, offset);
    try log.validateHeader(header[0..acquired]);
    const length = std.mem.readInt(u32, header[48..52], .little);
    if (length > log.max_payload_bytes) return error.InvalidWalHeader;
    const bytes = try allocator.alloc(u8, log.alignedFrameSize(length));
    errdefer allocator.free(bytes);
    @memcpy(bytes[0..header.len], &header);
    if (try file.readPositionalAll(self.io, bytes[header.len..], offset + header.len) != bytes.len - header.len) return error.TruncatedWalFrame;
    _ = try log.decodeFrame(bytes);
    return bytes;
}

fn recover(self: *Self, state: *State) !void {
    const durable_next = state.next;
    var previous: ?u64 = null;
    var expected: ?u64 = null;
    while (try self.nextSegment(state.partition, previous)) |segment| {
        const following = try self.nextSegment(state.partition, segment.first);
        var name: [96]u8 = undefined;
        const file = try self.dir.openFile(self.io, segmentName(state.partition, segment.first, &name), .{ .mode = .read_write, .follow_symlinks = false });
        defer file.close(self.io);
        if (expected) |value| {
            if (segment.first != value) return error.CorruptWalFrame;
        } else if (segment.first > state.floor) return error.WalHistoryMissing;
        expected = segment.first;
        var offset: u64 = 0;
        while (offset < segment.bytes) {
            const bytes = self.frame(file, offset, self.allocator) catch |err| switch (err) {
                error.TruncatedWalFrame => {
                    if (following != null or expected.? < durable_next) return error.WalHistoryMissing;
                    errdefer self.poisoned = true;
                    try file.setLength(self.io, offset);
                    try file.sync(self.io);
                    self.syncs += 1;
                    self.truncated_tail_bytes += segment.bytes - offset;
                    break;
                },
                else => return err,
            };
            defer self.allocator.free(bytes);
            const decoded = try log.decodeFrame(bytes);
            if (decoded.frame.header.partition_id != state.partition or decoded.frame.header.lsn != expected.?) return error.CorruptWalFrame;
            state.latest = .{ .lsn = expected.?, .segment = segment.first, .offset = offset };
            expected = std.math.add(u64, expected.?, 1) catch return error.WalLsnExhausted;
            state.writer = @max(state.writer, decoded.frame.header.writer_epoch);
            state.policy = @max(state.policy, decoded.frame.header.policy_epoch);
            offset += bytes.len;
            self.recovered_frames += 1;
        }
        state.segment = segment.first;
        state.offset = offset;
        previous = segment.first;
    }
    if (expected) |value| {
        if (value < durable_next) return error.WalHistoryMissing;
        state.next = value;
    } else {
        if (state.floor != state.next) return error.WalHistoryMissing;
        state.segment = state.next;
    }
}

fn load(self: *Self, id: u64) !*State {
    try self.usable();
    for (&self.cache) |*slot| if (slot.*) |*state| if (state.partition == id) return state;
    return self.loadCold(id) catch |err| {
        // An interrupted observation publishes no descriptor or disk change.
        // Recovery's truncation path separately poisons an uncertain mutation.
        // Keep corruption and other storage failures fail-closed as before.
        if (err != error.Canceled) self.poisoned = true;
        return err;
    };
}

fn loadCold(self: *Self, id: u64) !*State {
    var state = (try self.metadata(id)) orelse blk: {
        if (try self.nextSegment(id, null) != null) return error.WalMetadataMissing;
        break :blk State{ .partition = id };
    };
    try self.recover(&state);
    const index = self.replace;
    self.replace = (index + 1) % self.cache.len;
    self.cache[index] = state;
    return &self.cache[index].?;
}

pub fn tail(self: *Self, id: u64) !u64 {
    return (try self.load(id)).next;
}

pub fn append(self: *Self, id: u64, expected_lsn: ?u64, writer: u64, policy: u64, kind: log.FrameKind, payload: []const u8) !log.AppendReceipt {
    if (writer == 0 or policy == 0) return error.InvalidWalEpoch;
    if (payload.len > log.max_payload_bytes) return error.WalPayloadTooLarge;
    const state = try self.load(id);
    if (writer < state.writer) return error.StaleWriterEpoch;
    if (policy < state.policy) return error.StalePolicyEpoch;
    if (expected_lsn) |expected| if (expected != state.next) return error.WalLsnConflict;
    const successor = std.math.add(u64, state.next, 1) catch return error.WalLsnExhausted;
    const bytes = try self.allocator.alloc(u8, log.alignedFrameSize(payload.len));
    defer self.allocator.free(bytes);
    _ = try log.encodeFrame(id, writer, policy, state.next, 0, kind, payload, bytes);
    if (try self.metadata(id) == null) try self.save(state.*);
    // After the first possible disk change, an error is an uncertain outcome.
    // Do not reuse this owner's cached frontier or roll back an attempted write.
    errdefer self.poisoned = true;
    var next = state.*;
    if (next.offset != 0 and (next.offset > self.options.segment_bytes or bytes.len > self.options.segment_bytes - next.offset)) {
        next.segment = state.next;
        next.offset = 0;
    }
    var name: [96]u8 = undefined;
    const filename = segmentName(id, next.segment, &name);
    const file = if (next.offset == 0)
        try self.dir.createFile(self.io, filename, .{ .read = true, .truncate = false, .permissions = .fromMode(0o600) })
    else
        try self.dir.openFile(self.io, filename, .{ .mode = .read_write, .follow_symlinks = false });
    defer file.close(self.io);
    if (try file.length(self.io) != next.offset) return error.WalRecoveryRequired;
    try file.writePositionalAll(self.io, bytes, next.offset);
    try file.sync(self.io);
    self.syncs += 1;
    if (next.offset == 0) try self.syncDirectory();
    next.offset += bytes.len;
    next.next = successor;
    next.writer = writer;
    next.policy = policy;
    // The durable frontier detects missing acknowledged tail files on restart,
    // including the last segment. Complete unacknowledged frames may also be
    // recovered; callers must reconcile their original operation identity.
    try self.save(next);
    next.latest = .{ .lsn = state.next, .segment = next.segment, .offset = next.offset - bytes.len };
    state.* = next;
    return .{ .partition_id = id, .lsn = successor - 1, .next_lsn = successor, .writer_epoch = writer, .policy_epoch = policy, .frame_bytes = bytes.len };
}

pub fn read(self: *Self, allocator: std.mem.Allocator, id: u64, from: u64, requested: usize) !log.Log.OwnedBatch {
    const cached = try self.load(id);
    const state = cached.*;
    if (from < state.floor) return error.WalHistoryTrimmed;
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    var frames: std.ArrayList(log.Frame) = .empty;
    if (from >= state.next or requested == 0) return .{ .arena = arena, .frames = &.{} };
    const count = @min(requested, self.options.batch_frames);
    var used: usize = 0;
    var expected = from;
    var hint: ?Cursor = null;
    for ([_]?Cursor{ state.latest, state.read_start, state.read_next }) |candidate| if (candidate) |cursor| {
        if (cursor.lsn >= state.floor and cursor.lsn <= from and (hint == null or cursor.lsn > hint.?.lsn)) hint = cursor;
    };
    var current = if (hint) |cursor| try self.segmentInfo(id, cursor.segment) else try self.segmentAt(id, from);
    var offset: u64 = if (hint) |cursor| cursor.offset else 0;
    while (current) |segment| {
        var name: [96]u8 = undefined;
        const file = try self.dir.openFile(self.io, segmentName(id, segment.first, &name), .{ .follow_symlinks = false });
        defer file.close(self.io);
        if (offset > segment.bytes) return error.WalHistoryMissing;
        while (offset < segment.bytes) {
            const frame_offset = offset;
            const bytes = try self.frame(file, offset, self.allocator);
            defer self.allocator.free(bytes);
            self.read_frames +|= 1;
            self.read_bytes +|= bytes.len;
            offset += bytes.len;
            const decoded = try log.decodeFrame(bytes);
            if (decoded.frame.header.partition_id != id) return error.CorruptWalFrame;
            if (decoded.frame.header.lsn < from) continue;
            if (decoded.frame.header.lsn != expected) return error.WalHistoryMissing;
            if (bytes.len > self.options.batch_bytes - used) return .{ .arena = arena, .frames = frames.items };
            var item = decoded.frame;
            item.payload = try arena.allocator().dupe(u8, item.payload);
            try frames.append(arena.allocator(), item);
            if (frames.items.len == 1) cached.read_start = .{ .lsn = from, .segment = segment.first, .offset = frame_offset };
            used += bytes.len;
            expected += 1;
            cached.read_next = .{ .lsn = expected, .segment = segment.first, .offset = offset };
            if (expected == state.next or frames.items.len == count) return .{ .arena = arena, .frames = frames.items };
        }
        current = try self.nextSegment(id, segment.first);
        offset = 0;
    }
    return error.WalHistoryMissing;
}

pub fn fence(self: *Self, id: u64, writer: u64, policy: u64) !void {
    if (writer == 0 or policy == 0) return error.InvalidWalEpoch;
    const state = try self.load(id);
    if (writer < state.writer or policy < state.policy) return error.WalEpochRegression;
    var next = state.*;
    next.writer = writer;
    next.policy = policy;
    try self.save(next);
    state.* = next;
}

/// Physical trim is called only by the retention authority after it has retained
/// checkpoints, pins, logical history and receipts elsewhere. This backend does
/// not infer that authority from disk pressure or checkpoint existence.
pub fn trim(self: *Self, id: u64, before: u64) !void {
    const state = try self.load(id);
    if (before > state.next) return error.InvalidWalTrimBoundary;
    if (before < state.floor) return;
    var next = state.*;
    next.floor = before;
    next.latest = null;
    next.read_start = null;
    next.read_next = null;
    // A crash can leave the floor published with only some prefix segments
    // removed. Repeating that authorized floor must finish physical cleanup.
    if (before > state.floor) try self.save(next);
    state.* = next;
    errdefer self.poisoned = true;
    var previous: ?u64 = null;
    while (try self.nextSegment(id, previous)) |segment| {
        const following = try self.nextSegment(id, segment.first);
        const end = if (following) |value| value.first else next.next;
        previous = segment.first;
        if (end > before) break;
        var name: [96]u8 = undefined;
        try self.dir.deleteFile(self.io, segmentName(id, segment.first, &name));
    }
    try self.syncDirectory();
    if (before == next.next) {
        state.segment = next.next;
        state.offset = 0;
    }
}
