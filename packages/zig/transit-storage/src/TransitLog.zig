//! `TransitLog` (`TWAL1` v1): The sequenced Write-Ahead Log and live Data-Activation Bus.
//! Provides a 64-byte-aligned binary frame format with CRC32C + SHA-256 integrity,
//! partition-scoped monotonic LSN sequencing, and `(writer_epoch, policy_epoch)` fencing.
const std = @import("std");
const definition = @import("transit_protocol").Growth.definition_bytes;

pub const header_bytes: usize = 128;
pub const frame_alignment: usize = 64;
pub const max_payload_bytes: u32 = 4 * 1024 * 1024;

pub const FrameKind = enum(u8) {
    genesis = 1,
    policy_control = 2,
    row_delta = 3,
    catalog_ddl = 4,
    process_turn = 5,
    manifest_checkpoint = 6,
};

pub const Header = struct {
    partition_id: u64,
    writer_epoch: u64,
    policy_epoch: u64,
    lsn: u64,
    timestamp_ms: u64,
    kind: FrameKind,
    payload_len: u32,
    crc32c: u32,
    sha256_prefix: [8]u8,
};

pub const Frame = struct {
    header: Header,
    payload: []const u8,
};

pub const AppendReceipt = struct {
    partition_id: u64,
    lsn: u64,
    next_lsn: u64,
    writer_epoch: u64,
    policy_epoch: u64,
    frame_bytes: usize,
};

pub fn alignedFrameSize(payload_len: usize) usize {
    return std.mem.alignForward(usize, header_bytes + payload_len, frame_alignment);
}

fn computeCrc32c(header_prefix_52: *const [52]u8, payload: []const u8) u32 {
    var crc = std.hash.crc.@"CRC-32/ISCSI".init();
    crc.update(header_prefix_52);
    crc.update(payload);
    return crc.final();
}

fn computeSha256Prefix(payload: []const u8) [8]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(payload, &digest, .{});
    return digest[0..8].*;
}

/// Encode a `TWAL1` frame (128-byte header + payload + 64-byte alignment padding).
pub fn encodeFrame(
    partition_id: u64,
    writer_epoch: u64,
    policy_epoch: u64,
    lsn: u64,
    timestamp_ms: u64,
    kind: FrameKind,
    payload: []const u8,
    out: []u8,
) ![]const u8 {
    if (writer_epoch == 0 or policy_epoch == 0) return error.InvalidWalEpoch;
    if (payload.len > max_payload_bytes) return error.WalPayloadTooLarge;
    const total_bytes = alignedFrameSize(payload.len);
    if (out.len < total_bytes) return error.BufferTooSmall;

    @memset(out[0..total_bytes], 0);
    out[0..4].* = "TWAL".*;
    out[4] = 1; // version 1
    out[5] = @backingInt(kind);
    std.mem.writeInt(u16, out[6..8], header_bytes, .little);
    std.mem.writeInt(u64, out[8..16], partition_id, .little);
    std.mem.writeInt(u64, out[16..24], writer_epoch, .little);
    std.mem.writeInt(u64, out[24..32], policy_epoch, .little);
    std.mem.writeInt(u64, out[32..40], lsn, .little);
    std.mem.writeInt(u64, out[40..48], timestamp_ms, .little);
    std.mem.writeInt(u32, out[48..52], @intCast(payload.len), .little);

    const crc = computeCrc32c(out[0..52], payload);
    const sha_prefix = computeSha256Prefix(payload);
    std.mem.writeInt(u32, out[52..56], crc, .little);
    out[56..64].* = sha_prefix;
    out[64..96].* = definition;

    @memcpy(out[header_bytes .. header_bytes + payload.len], payload);
    return out[0..total_bytes];
}

pub const DecodedFrame = struct {
    frame: Frame,
    consumed_bytes: usize,
};

/// Decode and verify one 64-byte-aligned `TWAL1` frame from the beginning of `bytes`.
/// Returns `error.TruncatedWalFrame` if `bytes` has an incomplete trailing frame (used by
/// crash recovery to distinguish a torn tail write from mid-log corruption).
pub fn decodeFrame(bytes: []const u8) !DecodedFrame {
    try validateHeader(bytes);
    const kind = std.enums.fromInt(FrameKind, bytes[5]) orelse return error.InvalidWalHeader;
    const partition_id = std.mem.readInt(u64, bytes[8..16], .little);
    const writer_epoch = std.mem.readInt(u64, bytes[16..24], .little);
    const policy_epoch = std.mem.readInt(u64, bytes[24..32], .little);
    const lsn = std.mem.readInt(u64, bytes[32..40], .little);
    const timestamp_ms = std.mem.readInt(u64, bytes[40..48], .little);
    const payload_len = std.mem.readInt(u32, bytes[48..52], .little);
    const expected_crc = std.mem.readInt(u32, bytes[52..56], .little);
    const expected_sha = bytes[56..64].*;

    if (writer_epoch == 0 or policy_epoch == 0 or payload_len > max_payload_bytes) {
        return error.InvalidWalHeader;
    }
    const total_bytes = alignedFrameSize(payload_len);
    if (bytes.len < total_bytes) return error.TruncatedWalFrame;

    const payload = bytes[header_bytes .. header_bytes + payload_len];
    const actual_crc = computeCrc32c(bytes[0..52], payload);
    const actual_sha = computeSha256Prefix(payload);
    if (actual_crc != expected_crc or !std.mem.eql(u8, &actual_sha, &expected_sha)) {
        return error.CorruptWalFrame;
    }
    for (bytes[header_bytes + payload_len .. total_bytes]) |pad_byte| {
        if (pad_byte != 0) return error.CorruptWalFrame;
    }

    return .{
        .frame = .{
            .header = .{
                .partition_id = partition_id,
                .writer_epoch = writer_epoch,
                .policy_epoch = policy_epoch,
                .lsn = lsn,
                .timestamp_ms = timestamp_ms,
                .kind = kind,
                .payload_len = payload_len,
                .crc32c = expected_crc,
                .sha256_prefix = expected_sha,
            },
            .payload = payload,
        },
        .consumed_bytes = total_bytes,
    };
}

/// Check the discriminator before deciding whether a short tail is torn. An
/// older complete header is incompatible history, never disposable tail bytes.
pub fn validateHeader(bytes: []const u8) !void {
    if (bytes.len < 8) return error.TruncatedWalFrame;
    if (!std.mem.eql(u8, bytes[0..4], "TWAL") or bytes[4] != 1) return error.InvalidWalMagic;
    if (std.mem.readInt(u16, bytes[6..8], .little) != header_bytes) return error.IncompatibleDefinition;
    if (bytes.len < header_bytes) return error.TruncatedWalFrame;
    if (!std.mem.eql(u8, bytes[64..96], &definition)) return error.IncompatibleDefinition;
    if (!std.mem.allEqual(u8, bytes[96..header_bytes], 0)) return error.InvalidWalHeader;
}

/// Pluggable `TransitLog` backend interface (`LocalWal`, `UrsulaWal`, `KafkaWal`, `PulsarWal`).
pub const Log = struct {
    context: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        append: *const fn (
            ctx: *anyopaque,
            partition_id: u64,
            expected_lsn: ?u64,
            writer_epoch: u64,
            policy_epoch: u64,
            kind: FrameKind,
            payload: []const u8,
        ) anyerror!AppendReceipt,
        read: *const fn (
            ctx: *anyopaque,
            allocator: std.mem.Allocator,
            partition_id: u64,
            from_lsn: u64,
            max_frames: usize,
        ) anyerror!OwnedBatch,
        tail: *const fn (ctx: *anyopaque, partition_id: u64) anyerror!u64,
        trim: *const fn (ctx: *anyopaque, partition_id: u64, up_to_lsn: u64) anyerror!void,
        fence: *const fn (ctx: *anyopaque, partition_id: u64, min_writer_epoch: u64, min_policy_epoch: u64) anyerror!void,
    };

    pub const OwnedBatch = struct {
        arena: std.heap.ArenaAllocator,
        frames: []const Frame,
        pub fn deinit(self: *OwnedBatch) void {
            self.arena.deinit();
            self.* = undefined;
        }
    };

    pub fn append(
        self: Log,
        partition_id: u64,
        expected_lsn: ?u64,
        writer_epoch: u64,
        policy_epoch: u64,
        kind: FrameKind,
        payload: []const u8,
    ) !AppendReceipt {
        return self.vtable.append(self.context, partition_id, expected_lsn, writer_epoch, policy_epoch, kind, payload);
    }

    pub fn read(self: Log, allocator: std.mem.Allocator, partition_id: u64, from_lsn: u64, max_frames: usize) !OwnedBatch {
        return self.vtable.read(self.context, allocator, partition_id, from_lsn, max_frames);
    }

    pub fn tail(self: Log, partition_id: u64) !u64 {
        return self.vtable.tail(self.context, partition_id);
    }

    pub fn trim(self: Log, partition_id: u64, up_to_lsn: u64) !void {
        return self.vtable.trim(self.context, partition_id, up_to_lsn);
    }

    pub fn fence(self: Log, partition_id: u64, min_writer_epoch: u64, min_policy_epoch: u64) !void {
        return self.vtable.fence(self.context, partition_id, min_writer_epoch, min_policy_epoch);
    }
};
