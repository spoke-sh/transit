//! Immutable versioned Table Manifests (`"TMAN"` v1) committed to `TransitObjectStore`
//! via conditional CAS (`If-None-Match` on `manifest/<object_id>/v<N>.tman`).
const std = @import("std");
const definition = @import("transit_protocol").Growth.definition_bytes;
const TransitObjectStore = @import("TransitObjectStore.zig");

pub const max_encoded_bytes: usize = 512 * 1024;

pub const SegmentDescriptor = struct {
    segment_id: u64,
    tseg_key: []const u8,
    tseg_sha256: [32]u8,
    tseg_bytes: u32,
    tdel_key: ?[]const u8 = null,
    tdel_sha256: ?[32]u8 = null,
    tdel_bytes: u32 = 0,
    row_count: u32,
    deleted_count: u32 = 0,
    min_pk_sort_key: []const u8,
    max_pk_sort_key: []const u8,

    pub fn liveRows(self: SegmentDescriptor) u32 {
        return self.row_count -| self.deleted_count;
    }

    pub fn mayContainPk(self: SegmentDescriptor, pk_sort_key: []const u8) bool {
        if (self.liveRows() == 0) return false;
        return std.mem.order(u8, pk_sort_key, self.min_pk_sort_key) != .lt and
            std.mem.order(u8, pk_sort_key, self.max_pk_sort_key) != .gt;
    }

    pub fn overlapsPkRange(self: SegmentDescriptor, other: SegmentDescriptor) bool {
        if (self.liveRows() == 0 or other.liveRows() == 0) return false;
        return !(std.mem.order(u8, self.max_pk_sort_key, other.min_pk_sort_key) == .lt or
            std.mem.order(u8, other.max_pk_sort_key, self.min_pk_sort_key) == .lt);
    }
};

pub const Manifest = struct {
    catalog_id: u64,
    object_id: u64,
    manifest_version: u64,
    schema_revision: u64,
    layout_fingerprint: [32]u8,
    writer_epoch: u64,
    policy_epoch: u64,
    flushed_lsn: u64,
    live_row_count: u64,
    segments: []const SegmentDescriptor,

    pub fn validate(self: Manifest) !void {
        if (self.catalog_id == 0 or self.object_id == 0 or self.manifest_version == 0 or
            self.schema_revision == 0 or self.writer_epoch == 0 or self.policy_epoch == 0)
        {
            return error.InvalidTableManifest;
        }
        var computed_live: u64 = 0;
        for (self.segments) |seg| {
            if (seg.segment_id == 0 or seg.tseg_bytes == 0 or seg.deleted_count > seg.row_count) {
                return error.InvalidTableManifest;
            }
            try TransitObjectStore.validateKey(seg.tseg_key);
            if (seg.tdel_key) |dk| {
                try TransitObjectStore.validateKey(dk);
                if (seg.tdel_sha256 == null or seg.tdel_bytes == 0) return error.InvalidTableManifest;
            }
            computed_live += seg.liveRows();
        }
        if (computed_live != self.live_row_count) return error.InvalidTableManifest;
    }

    pub fn encode(self: Manifest, out: []u8) ![]const u8 {
        try self.validate();
        var writer: std.Io.Writer = .fixed(out[0..@min(out.len, max_encoded_bytes)]);
        try writer.writeAll("TMAN");
        try writer.writeByte(1); // version 1
        try writer.writeAll(&definition);
        try writer.writeInt(u64, self.catalog_id, .little);
        try writer.writeInt(u64, self.object_id, .little);
        try writer.writeInt(u64, self.manifest_version, .little);
        try writer.writeInt(u64, self.schema_revision, .little);
        try writer.writeAll(&self.layout_fingerprint);
        try writer.writeInt(u64, self.writer_epoch, .little);
        try writer.writeInt(u64, self.policy_epoch, .little);
        try writer.writeInt(u64, self.flushed_lsn, .little);
        try writer.writeInt(u64, self.live_row_count, .little);
        try writer.writeInt(u32, @intCast(self.segments.len), .little);

        for (self.segments) |seg| {
            try writer.writeInt(u64, seg.segment_id, .little);
            try writer.writeInt(u16, @intCast(seg.tseg_key.len), .little);
            try writer.writeAll(seg.tseg_key);
            try writer.writeAll(&seg.tseg_sha256);
            try writer.writeInt(u32, seg.tseg_bytes, .little);

            if (seg.tdel_key) |dk| {
                try writer.writeByte(1);
                try writer.writeInt(u16, @intCast(dk.len), .little);
                try writer.writeAll(dk);
                try writer.writeAll(&(seg.tdel_sha256.?));
                try writer.writeInt(u32, seg.tdel_bytes, .little);
            } else {
                try writer.writeByte(0);
            }

            try writer.writeInt(u32, seg.row_count, .little);
            try writer.writeInt(u32, seg.deleted_count, .little);
            try writer.writeInt(u16, @intCast(seg.min_pk_sort_key.len), .little);
            try writer.writeAll(seg.min_pk_sort_key);
            try writer.writeInt(u16, @intCast(seg.max_pk_sort_key.len), .little);
            try writer.writeAll(seg.max_pk_sort_key);
        }

        const body = writer.buffered();
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(body, &digest, .{});
        try writer.writeAll(&digest);
        return writer.buffered();
    }
};

pub const OwnedManifest = struct {
    arena: std.heap.ArenaAllocator,
    manifest: Manifest,
    pub fn deinit(self: *OwnedManifest) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !OwnedManifest {
    if (bytes.len < 4 + 1 + 32 + 64 + 32 + 4 + 32 or bytes.len > max_encoded_bytes) {
        return error.InvalidTableManifest;
    }
    if (!std.mem.eql(u8, bytes[0..4], "TMAN") or bytes[4] != 1) return error.InvalidTableManifest;
    if (!std.mem.eql(u8, bytes[5..37], &definition)) return error.IncompatibleDefinition;

    const body = bytes[0 .. bytes.len - 32];
    const expected_digest = bytes[bytes.len - 32 ..][0..32];
    var actual_digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(body, &actual_digest, .{});
    if (!std.mem.eql(u8, &actual_digest, expected_digest)) return error.CorruptTableManifest;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const a = arena.allocator();

    var reader: std.Io.Reader = .fixed(body[37..]);
    const catalog_id = try reader.takeInt(u64, .little);
    const object_id = try reader.takeInt(u64, .little);
    const manifest_version = try reader.takeInt(u64, .little);
    const schema_revision = try reader.takeInt(u64, .little);
    const layout_fp = (try reader.take(32))[0..32].*;
    const writer_epoch = try reader.takeInt(u64, .little);
    const policy_epoch = try reader.takeInt(u64, .little);
    const flushed_lsn = try reader.takeInt(u64, .little);
    const live_row_count = try reader.takeInt(u64, .little);
    const seg_count = try reader.takeInt(u32, .little);

    const segments = try a.alloc(SegmentDescriptor, seg_count);
    for (segments) |*seg| {
        const segment_id = try reader.takeInt(u64, .little);
        const tk_len = try reader.takeInt(u16, .little);
        const tk = try a.dupe(u8, try reader.take(tk_len));
        const ts_sha = (try reader.take(32))[0..32].*;
        const ts_bytes = try reader.takeInt(u32, .little);

        const has_tdel = try reader.takeByte();
        var dk: ?[]const u8 = null;
        var ds_sha: ?[32]u8 = null;
        var ds_bytes: u32 = 0;
        if (has_tdel == 1) {
            const dk_len = try reader.takeInt(u16, .little);
            dk = try a.dupe(u8, try reader.take(dk_len));
            ds_sha = (try reader.take(32))[0..32].*;
            ds_bytes = try reader.takeInt(u32, .little);
        } else if (has_tdel != 0) {
            return error.InvalidTableManifest;
        }

        const rc = try reader.takeInt(u32, .little);
        const dc = try reader.takeInt(u32, .little);
        const min_len = try reader.takeInt(u16, .little);
        const min_pk = try a.dupe(u8, try reader.take(min_len));
        const max_len = try reader.takeInt(u16, .little);
        const max_pk = try a.dupe(u8, try reader.take(max_len));

        seg.* = .{
            .segment_id = segment_id,
            .tseg_key = tk,
            .tseg_sha256 = ts_sha,
            .tseg_bytes = ts_bytes,
            .tdel_key = dk,
            .tdel_sha256 = ds_sha,
            .tdel_bytes = ds_bytes,
            .row_count = rc,
            .deleted_count = dc,
            .min_pk_sort_key = min_pk,
            .max_pk_sort_key = max_pk,
        };
    }
    if (reader.bufferedLen() != 0) return error.InvalidTableManifest;

    const manifest: Manifest = .{
        .catalog_id = catalog_id,
        .object_id = object_id,
        .manifest_version = manifest_version,
        .schema_revision = schema_revision,
        .layout_fingerprint = layout_fp,
        .writer_epoch = writer_epoch,
        .policy_epoch = policy_epoch,
        .flushed_lsn = flushed_lsn,
        .live_row_count = live_row_count,
        .segments = segments,
    };
    try manifest.validate();
    return .{ .arena = arena, .manifest = manifest };
}

pub fn manifestKey(object_id: u64, manifest_version: u64, buf: *[64]u8) ![]const u8 {
    return std.fmt.bufPrint(buf, "manifest/{d}/v{d}.tman", .{ object_id, manifest_version });
}

pub fn segmentKey(object_id: u64, segment_id: u64, buf: *[64]u8) ![]const u8 {
    return std.fmt.bufPrint(buf, "segments/{d}/seg-{d}.tseg", .{ object_id, segment_id });
}

pub fn deletionKey(object_id: u64, segment_id: u64, manifest_version: u64, buf: *[64]u8) ![]const u8 {
    return std.fmt.bufPrint(buf, "segments/{d}/seg-{d}-v{d}.tdel", .{ object_id, segment_id, manifest_version });
}
