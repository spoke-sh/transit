//! Incremental framing over caller-owned capacity. Headers are validated before
//! requesting body storage. No allocator, transport, clock or execution owner.
const std = @import("std");

/// Header supplies prefix_bytes, capacity() and frameSize(prefix). The caller
/// owns storage exclusively until release/abort, including every borrowed event.
pub fn Decoder(comptime Header: type) type {
    return struct {
        const Self = @This();
        pub const Shape = Header;
        pub const Event = union(enum) {
            input: []u8,
            capacity: usize,
            frame: []const u8,
        };
        header: Header,
        storage: []u8,
        maximum: usize,
        filled: usize = 0,
        total: ?usize = null,
        failed: bool = false,

        pub fn init(storage: []u8, header: Header) !Self {
            const maximum = try header.capacity();
            if (maximum < Header.prefix_bytes or storage.len < Header.prefix_bytes or storage.len > maximum)
                return error.InvalidFrameCapacity;
            return .{ .header = header, .storage = storage, .maximum = maximum };
        }
        /// Input slices end at the next framing boundary. A completed frame
        /// stops consumption, so coalesced trailing bytes stay with the caller.
        pub fn next(self: *Self) !Event {
            if (self.failed) return error.FrameInputClosed;
            const end = self.total orelse Header.prefix_bytes;
            if (end > self.storage.len) return .{ .capacity = end };
            if (self.total != null and self.filled == end) return .{ .frame = self.storage[0..end] };
            return .{ .input = self.storage[self.filled..end] };
        }
        /// Commit bytes written into the most recent input slice. A malformed
        /// header poisons this input; its body can never become another command.
        pub fn advance(self: *Self, count: usize) !void {
            errdefer self.failed = true;
            const event = try self.next();
            if (event != .input or count > event.input.len) return error.InvalidFrameAdvance;
            self.filled += count;
            if (self.total == null and self.filled == Header.prefix_bytes) {
                const total = try self.header.frameSize(self.storage[0..Header.prefix_bytes]);
                if (total < Header.prefix_bytes or total > self.maximum) return error.InvalidFrameSize;
                self.total = total;
            }
        }
        /// Only a capacity event permits replacement. The caller preserves the
        /// filled prefix (e.g. with realloc); no input/frame borrow may survive
        /// this call. The decoder never reads the previous storage here.
        pub fn supply(self: *Self, storage: []u8) !void {
            if (self.failed) return error.FrameInputClosed;
            const needed = self.total orelse return error.UnexpectedFrameCapacity;
            if (needed <= self.storage.len or storage.len < needed or storage.len > self.maximum)
                return error.InvalidFrameCapacity;
            self.storage = storage;
        }
        /// Copy as much as fits before a complete frame or capacity request.
        /// The consumed count lets a caller retain coalesced/fragmented input.
        pub fn feed(self: *Self, bytes: []const u8) !usize {
            var consumed: usize = 0;
            while (consumed < bytes.len) {
                const event = try self.next();
                if (event != .input) break;
                const n = @min(event.input.len, bytes.len - consumed);
                @memcpy(event.input[0..n], bytes[consumed..][0..n]);
                try self.advance(n);
                consumed += n;
            }
            return consumed;
        }
        /// End all frame borrows before reuse. Erase the used bytes; retain the
        /// admitted capacity. Incomplete or failed input cannot be recycled.
        pub fn release(self: *Self) !void {
            if ((try self.next()) != .frame) return error.FrameIncomplete;
            std.crypto.secureZero(u8, self.storage[0..self.filled]);
            self.filled = 0;
            self.total = null;
        }
        /// EOF, cancellation and host failures close the decoder permanently.
        /// The owner erases its full allocation before releasing it: a failed
        /// read may have written bytes without reporting their count.
        pub fn abort(self: *Self) void {
            self.failed = true;
        }
    };
}
