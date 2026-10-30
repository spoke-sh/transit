//! Succinct $2N$-bit Balanced Parentheses (`BP`) tree representation with
//! two-level rank/select and excess summaries.
//!
//! Each node $v \in [0, N)$ in preorder has an opening parenthesis (`1` bit)
//! at `openBit(v)` and a matching closing parenthesis (`0` bit) at `closeBit(v)`.
//! Navigation primitives (`parent`, `firstChild`, `nextSibling`, `subtreeSize`,
//! `depth`, `isAncestor`, `within`, `lca`) perform zero heap allocations.
const std = @import("std");

pub const magic = "SBPT0001";
pub const max_nodes: u32 = 1 << 24;
const block_words: usize = 4; // 256 bits per summary block

pub const Error = error{
    EmptySuccinctTree,
    InvalidSuccinctTree,
    NodeOutOfBounds,
    OutOfMemory,
    TreeTooLarge,
};

pub const BlockSummary = struct {
    cum_ones: u32,
    cum_excess: i32,
    min_excess: i32,
    max_excess: i32,
};

pub const SuccinctTree = struct {
    node_count: u32,
    bit_len: u32,
    words: []u64,
    summaries: []BlockSummary,

    pub const Edge = struct {
        parent: ?u32,
    };

    pub fn deinit(self: *SuccinctTree, allocator: std.mem.Allocator) void {
        allocator.free(self.words);
        allocator.free(self.summaries);
        self.* = undefined;
    }

    /// Builds a `SuccinctTree` from a preorder parent array where `parents[0] == null`
    /// and `parents[i] < i` for `i > 0`. Uses `scratch` for temporary traversal state
    /// and `output` solely for the retained `words` and `summaries` slices.
    pub fn fromParentSlice(
        output: std.mem.Allocator,
        scratch: std.mem.Allocator,
        parents: []const ?u32,
    ) Error!SuccinctTree {
        if (parents.len == 0) return error.EmptySuccinctTree;
        if (parents.len > max_nodes) return error.TreeTooLarge;
        if (parents[0] != null) return error.InvalidSuccinctTree;

        const n: u32 = @intCast(parents.len);
        const first_child = try scratch.alloc(?u32, n);
        const next_sibling = try scratch.alloc(?u32, n);
        const last_child = try scratch.alloc(?u32, n);
        @memset(first_child, null);
        @memset(next_sibling, null);
        @memset(last_child, null);

        for (parents[1..], 1..) |maybe_p, idx| {
            const p = maybe_p orelse return error.InvalidSuccinctTree;
            const u: u32 = @intCast(idx);
            if (p >= u) return error.InvalidSuccinctTree;
            if (last_child[p]) |prev| {
                next_sibling[prev] = u;
            } else {
                first_child[p] = u;
            }
            last_child[p] = u;
        }

        const bit_len: u32 = n * 2;
        const word_count = (@as(usize, bit_len) + 63) / 64;
        const words = try output.alloc(u64, word_count);
        errdefer output.free(words);
        @memset(words, 0);

        const Frame = struct {
            node: u32,
            next_child: ?u32,
        };
        const stack = try scratch.alloc(Frame, n);
        var sp: usize = 0;
        var bit_pos: u32 = 0;
        var visited: u32 = 0;

        setBit(words, bit_pos);
        bit_pos += 1;
        visited += 1;
        stack[0] = .{ .node = 0, .next_child = first_child[0] };
        sp = 1;

        while (sp > 0) {
            const top = &stack[sp - 1];
            if (top.next_child) |child| {
                if (child != visited) return error.InvalidSuccinctTree;
                top.next_child = next_sibling[child];
                setBit(words, bit_pos);
                bit_pos += 1;
                visited += 1;
                stack[sp] = .{ .node = child, .next_child = first_child[child] };
                sp += 1;
            } else {
                // Closing parenthesis is a 0 bit (already zeroed).
                bit_pos += 1;
                sp -= 1;
            }
        }

        if (visited != n or bit_pos != bit_len) return error.InvalidSuccinctTree;
        const summaries = try buildSummaries(output, words, bit_len);
        return .{
            .node_count = n,
            .bit_len = bit_len,
            .words = words,
            .summaries = summaries,
        };
    }

    pub fn nodeCount(self: SuccinctTree) u32 {
        return self.node_count;
    }

    pub fn openBit(self: SuccinctTree, preorder: u32) Error!u32 {
        if (preorder >= self.node_count) return error.NodeOutOfBounds;
        return self.select1(preorder + 1);
    }

    pub fn closeBit(self: SuccinctTree, preorder: u32) Error!u32 {
        const open = try self.openBit(preorder);
        return self.findClose(open);
    }

    pub fn subtreeSize(self: SuccinctTree, preorder: u32) Error!u32 {
        const open = try self.openBit(preorder);
        const close = try self.findClose(open);
        return (close - open + 1) / 2;
    }

    pub fn depth(self: SuccinctTree, preorder: u32) Error!u32 {
        const open = try self.openBit(preorder);
        const ex = self.excessAt(open);
        if (ex <= 0) return error.InvalidSuccinctTree;
        return @intCast(ex - 1);
    }

    pub fn firstChild(self: SuccinctTree, preorder: u32) Error!?u32 {
        const open = try self.openBit(preorder);
        if (open + 1 >= self.bit_len) return null;
        if (self.getBit(open + 1) == 1) return preorder + 1;
        return null;
    }

    pub fn nextSibling(self: SuccinctTree, preorder: u32) Error!?u32 {
        const open = try self.openBit(preorder);
        const close = try self.findClose(open);
        if (close + 1 >= self.bit_len) return null;
        if (self.getBit(close + 1) == 1) {
            const sub_size = (close - open + 1) / 2;
            return preorder + sub_size;
        }
        return null;
    }

    pub fn parent(self: SuccinctTree, preorder: u32) Error!?u32 {
        if (preorder >= self.node_count) return error.NodeOutOfBounds;
        if (preorder == 0) return null;
        const open = try self.openBit(preorder);
        const target_excess = self.excessAt(open) - 1;
        if (target_excess <= 0) return null;
        var pos = open;
        while (pos > 0) {
            pos -= 1;
            if (self.getBit(pos) == 1 and self.excessAt(pos) == target_excess) {
                return self.rank1(pos) - 1;
            }
        }
        return error.InvalidSuccinctTree;
    }

    pub fn isAncestor(self: SuccinctTree, ancestor: u32, descendant: u32) Error!bool {
        if (ancestor >= self.node_count or descendant >= self.node_count) {
            return error.NodeOutOfBounds;
        }
        if (ancestor > descendant) return false;
        if (ancestor == descendant) return true;
        const size = try self.subtreeSize(ancestor);
        return descendant < ancestor + size;
    }

    pub fn within(self: SuccinctTree, inner: u32, outer: u32) Error!bool {
        return self.isAncestor(outer, inner);
    }

    pub fn lca(self: SuccinctTree, u: u32, v: u32) Error!u32 {
        if (try self.isAncestor(u, v)) return u;
        if (try self.isAncestor(v, u)) return v;
        const first = @min(u, v);
        const second = @max(u, v);
        const left = try self.closeBit(first);
        const right = try self.openBit(second);
        var min_ex: i32 = std.math.maxInt(i32);
        var pos = left;
        while (pos <= right) : (pos += 1) {
            const ex = self.excessAt(pos);
            if (ex < min_ex) min_ex = ex;
        }
        // The LCA's opening parenthesis is the last '1' before `left` whose excess equals `min_ex`.
        var scan = left;
        while (scan > 0) {
            scan -= 1;
            if (self.getBit(scan) == 1 and self.excessAt(scan) == min_ex) {
                return self.rank1(scan) - 1;
            }
        }
        return 0;
    }

    pub fn encode(self: SuccinctTree, allocator: std.mem.Allocator) Error![]u8 {
        const byte_len = 8 + 4 + 4 + self.words.len * 8;
        const buf = try allocator.alloc(u8, byte_len);
        @memcpy(buf[0..8], magic);
        std.mem.writeInt(u32, buf[8..12], self.node_count, .little);
        std.mem.writeInt(u32, buf[12..16], self.bit_len, .little);
        var offset: usize = 16;
        for (self.words) |w| {
            std.mem.writeInt(u64, buf[offset..][0..8], w, .little);
            offset += 8;
        }
        return buf;
    }

    pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) Error!SuccinctTree {
        if (bytes.len < 16 or !std.mem.eql(u8, bytes[0..8], magic)) {
            return error.InvalidSuccinctTree;
        }
        const n = std.mem.readInt(u32, bytes[8..12], .little);
        const bit_len = std.mem.readInt(u32, bytes[12..16], .little);
        if (n == 0 or n > max_nodes or bit_len != n * 2) {
            return error.InvalidSuccinctTree;
        }
        const word_count = (@as(usize, bit_len) + 63) / 64;
        if (bytes.len != 16 + word_count * 8) return error.InvalidSuccinctTree;
        const words = try allocator.alloc(u64, word_count);
        errdefer allocator.free(words);
        var offset: usize = 16;
        for (words) |*w| {
            w.* = std.mem.readInt(u64, bytes[offset..][0..8], .little);
            offset += 8;
        }
        const summaries = try buildSummaries(allocator, words, bit_len);
        errdefer allocator.free(summaries);
        if (summaries.len == 0) return error.InvalidSuccinctTree;
        const last = summaries[summaries.len - 1];
        if (last.cum_ones != n or last.cum_excess != 0 or last.min_excess < 0) {
            return error.InvalidSuccinctTree;
        }
        return .{
            .node_count = n,
            .bit_len = bit_len,
            .words = words,
            .summaries = summaries,
        };
    }

    fn setBit(words: []u64, bit_pos: u32) void {
        const word_idx = @as(usize, bit_pos) / 64;
        const bit_idx: u6 = @intCast(bit_pos % 64);
        words[word_idx] |= (@as(u64, 1) << bit_idx);
    }

    fn getBit(self: SuccinctTree, bit_pos: u32) u1 {
        const word_idx = @as(usize, bit_pos) / 64;
        const bit_idx: u6 = @intCast(bit_pos % 64);
        return @intCast((self.words[word_idx] >> bit_idx) & 1);
    }

    /// Number of 1 bits in `[0 .. bit_pos]` inclusive.
    pub fn rank1(self: SuccinctTree, bit_pos: u32) u32 {
        const word_idx = @as(usize, bit_pos) / 64;
        const block_idx = word_idx / block_words;
        var ones: u32 = if (block_idx > 0) self.summaries[block_idx - 1].cum_ones else 0;
        const start_word = block_idx * block_words;
        for (self.words[start_word..word_idx]) |w| {
            ones += @popCount(w);
        }
        const bit_idx: u6 = @intCast(bit_pos % 64);
        const mask: u64 = if (bit_idx == 63) std.math.maxInt(u64) else (@as(u64, 1) << (bit_idx + 1)) - 1;
        ones += @popCount(self.words[word_idx] & mask);
        return ones;
    }

    /// Excess (`#1 - #0`) in `[0 .. bit_pos]` inclusive.
    pub fn excessAt(self: SuccinctTree, bit_pos: u32) i32 {
        const ones: i32 = @intCast(self.rank1(bit_pos));
        const total: i32 = @intCast(bit_pos + 1);
        return 2 * ones - total;
    }

    /// Bit position of the `k`-th `1` bit (`1`-indexed).
    fn select1(self: SuccinctTree, k: u32) Error!u32 {
        if (k == 0 or k > self.node_count) return error.NodeOutOfBounds;
        var lo: usize = 0;
        var hi: usize = self.summaries.len;
        while (lo < hi) {
            const mid = lo + (hi - lo) / 2;
            if (self.summaries[mid].cum_ones < k) {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }
        const block_idx = lo;
        var remaining: u32 = k - (if (block_idx > 0) self.summaries[block_idx - 1].cum_ones else 0);
        const start_word = block_idx * block_words;
        const end_word = @min(start_word + block_words, self.words.len);
        for (start_word..end_word) |w_idx| {
            const w = self.words[w_idx];
            const c: u32 = @popCount(w);
            if (remaining <= c) {
                var word = w;
                var b: u32 = 0;
                while (word != 0) : (b += 1) {
                    if ((word & 1) != 0) {
                        remaining -= 1;
                        if (remaining == 0) {
                            return @intCast(w_idx * 64 + b);
                        }
                    }
                    word >>= 1;
                }
            }
            remaining -= c;
        }
        return error.InvalidSuccinctTree;
    }

    fn findClose(self: SuccinctTree, open_pos: u32) Error!u32 {
        if (self.getBit(open_pos) != 1) return error.InvalidSuccinctTree;
        const target_excess = self.excessAt(open_pos) - 1;
        var pos = open_pos + 1;
        while (pos < self.bit_len) : (pos += 1) {
            if (self.excessAt(pos) == target_excess) return pos;
        }
        return error.InvalidSuccinctTree;
    }

    fn buildSummaries(
        allocator: std.mem.Allocator,
        words: []const u64,
        bit_len: u32,
    ) Error![]BlockSummary {
        const block_count = (words.len + block_words - 1) / block_words;
        const summaries = try allocator.alloc(BlockSummary, block_count);
        var cum_ones: u32 = 0;
        var cum_excess: i32 = 0;
        var bit_cursor: u32 = 0;

        for (summaries, 0..) |*summary, b_idx| {
            const start_w = b_idx * block_words;
            const end_w = @min(start_w + block_words, words.len);
            var block_min: i32 = std.math.maxInt(i32);
            var block_max: i32 = std.math.minInt(i32);

            for (words[start_w..end_w]) |w| {
                var b: u7 = 0;
                while (b < 64 and bit_cursor < bit_len) : ({
                    b += 1;
                    bit_cursor += 1;
                }) {
                    const bit: u1 = @intCast((w >> @as(u6, @intCast(b))) & 1);
                    if (bit == 1) {
                        cum_ones += 1;
                        cum_excess += 1;
                    } else {
                        cum_excess -= 1;
                    }
                    if (cum_excess < block_min) block_min = cum_excess;
                    if (cum_excess > block_max) block_max = cum_excess;
                }
            }
            summary.* = .{
                .cum_ones = cum_ones,
                .cum_excess = cum_excess,
                .min_excess = block_min,
                .max_excess = block_max,
            };
        }
        return summaries;
    }
};
