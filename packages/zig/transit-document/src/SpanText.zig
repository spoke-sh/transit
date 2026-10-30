//! Span-based collaborative UTF-8 text (`SpanText`) supporting arbitrary-length
//! contiguous UTF-8 insertions, interior span splitting, range tombstones,
//! deterministic convergence across all causal delivery permutations, and
//! step/byte-bounded sequence reads.
const std = @import("std");

pub const Error = error{
    InvalidSpanIdentity,
    InvalidUtf8Span,
    InvalidSpanBoundary,
    InvalidDeleteRange,
    MissingSpanDependency,
    SpanIdentityConflict,
    InvalidReadBudget,
    InvalidReadCursor,
    OutOfMemory,
};

pub const SpanKey = struct {
    counter: u64,
    replica: u64,

    pub fn validate(self: SpanKey) Error!void {
        if (self.counter == 0 or self.replica == 0) return error.InvalidSpanIdentity;
    }

    pub fn eql(self: SpanKey, other: SpanKey) bool {
        return self.counter == other.counter and self.replica == other.replica;
    }

    /// Descending priority order for concurrent siblings at the same anchor.
    pub fn higherPriorityThan(self: SpanKey, other: SpanKey) bool {
        if (self.counter != other.counter) return self.counter > other.counter;
        return self.replica > other.replica;
    }
};

/// Identifies a split/anchor position immediately after `byte_offset` bytes
/// within `span`. `byte_offset` must be positive and lie on a UTF-8 scalar boundary.
pub const Boundary = struct {
    span: SpanKey,
    byte_offset: u32,
};

pub const InsertOp = struct {
    span: SpanKey,
    after: ?Boundary,
    utf8: []const u8,
};

pub const DeleteOp = struct {
    span: SpanKey,
    start_byte: u32,
    end_byte: u32,
};

pub const Operation = union(enum) {
    insert: InsertOp,
    delete: DeleteOp,
};

pub const ApplyDisposition = enum {
    applied,
    duplicate,
};

pub const Piece = struct {
    span: SpanKey,
    start_byte: u32,
    end_byte: u32,
    deleted: bool,
    utf8: []const u8,
};

pub const ReadStepResult = struct {
    bytes_written: usize,
    steps_taken: u32,
    next_piece: usize,
    next_byte_in_piece: u32,
    complete: bool,
};

const StoredSpan = struct {
    key: SpanKey,
    after: ?Boundary,
    utf8: []u8,
};

const InternalPiece = struct {
    span_index: u32,
    start_byte: u32,
    end_byte: u32,
    deleted: bool,
};

pub const SpanText = struct {
    allocator: std.mem.Allocator,
    spans: std.ArrayListUnmanaged(StoredSpan) = .empty,
    pieces: std.ArrayListUnmanaged(InternalPiece) = .empty,
    visible_bytes: usize = 0,

    pub fn init(allocator: std.mem.Allocator) SpanText {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *SpanText) void {
        for (self.spans.items) |span| {
            self.allocator.free(span.utf8);
        }
        self.spans.deinit(self.allocator);
        self.pieces.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn visibleByteLen(self: *const SpanText) usize {
        return self.visible_bytes;
    }

    pub fn totalPieceCount(self: *const SpanText) usize {
        return self.pieces.items.len;
    }

    pub fn apply(self: *SpanText, op: Operation) Error!ApplyDisposition {
        return switch (op) {
            .insert => |ins| self.applyInsert(ins),
            .delete => |del| self.applyDelete(del),
        };
    }

    pub fn materializeAlloc(self: *const SpanText, allocator: std.mem.Allocator) Error![]u8 {
        const out = try allocator.alloc(u8, self.visible_bytes);
        var pos: usize = 0;
        for (self.pieces.items) |piece| {
            if (piece.deleted) continue;
            const span = self.spans.items[piece.span_index];
            const slice = span.utf8[piece.start_byte..piece.end_byte];
            @memcpy(out[pos .. pos + slice.len], slice);
            pos += slice.len;
        }
        std.debug.assert(pos == self.visible_bytes);
        return out;
    }

    /// Reads visible UTF-8 bytes starting from `(start_piece, start_byte_in_piece)`
    /// while bounding total piece steps (including tombstoned pieces) to `max_steps`
    /// and output bytes to `out.len`. Never splits a UTF-8 codepoint across `out`.
    pub fn readBounded(
        self: *const SpanText,
        start_piece: usize,
        start_byte_in_piece: u32,
        max_steps: u32,
        out: []u8,
    ) Error!ReadStepResult {
        if (max_steps == 0 or out.len < 4) return error.InvalidReadBudget;
        if (start_piece > self.pieces.items.len) return error.InvalidReadCursor;
        if (start_piece == self.pieces.items.len) {
            if (start_byte_in_piece != 0) return error.InvalidReadCursor;
            return .{
                .bytes_written = 0,
                .steps_taken = 0,
                .next_piece = start_piece,
                .next_byte_in_piece = 0,
                .complete = true,
            };
        }

        const first_piece = self.pieces.items[start_piece];
        const first_len = first_piece.end_byte - first_piece.start_byte;
        if (start_byte_in_piece >= first_len) return error.InvalidReadCursor;
        const first_span = self.spans.items[first_piece.span_index];
        if (!isUtf8ScalarBoundary(first_span.utf8, first_piece.start_byte + start_byte_in_piece)) {
            return error.InvalidReadCursor;
        }

        var piece_idx = start_piece;
        var byte_in_piece = start_byte_in_piece;
        var steps: u32 = 0;
        var written: usize = 0;

        while (piece_idx < self.pieces.items.len and steps < max_steps) {
            const piece = self.pieces.items[piece_idx];
            steps += 1;
            if (piece.deleted) {
                piece_idx += 1;
                byte_in_piece = 0;
                continue;
            }
            const span = self.spans.items[piece.span_index];
            const piece_slice = span.utf8[piece.start_byte + byte_in_piece .. piece.end_byte];
            const remaining_out = out.len - written;
            if (piece_slice.len <= remaining_out) {
                @memcpy(out[written .. written + piece_slice.len], piece_slice);
                written += piece_slice.len;
                piece_idx += 1;
                byte_in_piece = 0;
            } else {
                // Find the largest UTF-8 scalar boundary that fits in `remaining_out`.
                var cut = remaining_out;
                while (cut > 0 and (piece_slice[cut] & 0b1100_0000) == 0b1000_0000) {
                    cut -= 1;
                }
                if (cut == 0) break;
                @memcpy(out[written .. written + cut], piece_slice[0..cut]);
                written += cut;
                byte_in_piece += @intCast(cut);
                break;
            }
        }

        return .{
            .bytes_written = written,
            .steps_taken = steps,
            .next_piece = piece_idx,
            .next_byte_in_piece = byte_in_piece,
            .complete = piece_idx == self.pieces.items.len,
        };
    }

    fn applyInsert(self: *SpanText, ins: InsertOp) Error!ApplyDisposition {
        try ins.span.validate();
        if (ins.utf8.len == 0 or ins.utf8.len > std.math.maxInt(u32)) {
            return error.InvalidUtf8Span;
        }
        if (!std.unicode.utf8ValidateSlice(ins.utf8)) {
            return error.InvalidUtf8Span;
        }

        // Check for duplicate or conflicting span identity.
        for (self.spans.items) |existing| {
            if (existing.key.eql(ins.span)) {
                if ( sameBoundary(existing.after, ins.after) and
                    std.mem.eql(u8, existing.utf8, ins.utf8))
                {
                    return .duplicate;
                }
                return error.SpanIdentityConflict;
            }
        }

        // Verify causal anchor exists and lies on a UTF-8 scalar boundary.
        var anchor_piece_idx: ?usize = null;
        if (ins.after) |boundary| {
            try boundary.span.validate();
            if (boundary.byte_offset == 0) return error.InvalidSpanBoundary;
            const parent_span_idx = self.findSpanIndex(boundary.span) orelse return error.MissingSpanDependency;
            const parent_span = self.spans.items[parent_span_idx];
            if (boundary.byte_offset > parent_span.utf8.len or
                !isUtf8ScalarBoundary(parent_span.utf8, boundary.byte_offset))
            {
                return error.InvalidSpanBoundary;
            }
            anchor_piece_idx = try self.ensureSplitAt(parent_span_idx, boundary.byte_offset);
        }

        const owned_utf8 = try self.allocator.dupe(u8, ins.utf8);
        errdefer self.allocator.free(owned_utf8);
        const new_span_idx: u32 = @intCast(self.spans.items.len);
        try self.spans.append(self.allocator, .{
            .key = ins.span,
            .after = ins.after,
            .utf8 = owned_utf8,
        });
        errdefer _ = self.spans.pop();

        const insert_pos = self.findInsertionIndex(ins.span, ins.after, anchor_piece_idx);
        try self.pieces.insert(self.allocator, insert_pos, .{
            .span_index = new_span_idx,
            .start_byte = 0,
            .end_byte = @intCast(owned_utf8.len),
            .deleted = false,
        });
        self.visible_bytes += owned_utf8.len;
        return .applied;
    }

    fn applyDelete(self: *SpanText, del: DeleteOp) Error!ApplyDisposition {
        try del.span.validate();
        if (del.end_byte <= del.start_byte) return error.InvalidDeleteRange;
        const span_idx = self.findSpanIndex(del.span) orelse return error.MissingSpanDependency;
        const span = self.spans.items[span_idx];
        if (del.end_byte > span.utf8.len or
            !isUtf8ScalarBoundary(span.utf8, del.start_byte) or
            !isUtf8ScalarBoundary(span.utf8, del.end_byte))
        {
            return error.InvalidSpanBoundary;
        }

        if (del.start_byte > 0) {
            _ = try self.ensureSplitAt(span_idx, del.start_byte);
        }
        _ = try self.ensureSplitAt(span_idx, del.end_byte);

        var any_newly_deleted = false;
        for (self.pieces.items) |*piece| {
            if (piece.span_index == span_idx and
                piece.start_byte >= del.start_byte and
                piece.end_byte <= del.end_byte)
            {
                if (!piece.deleted) {
                    piece.deleted = true;
                    self.visible_bytes -= (piece.end_byte - piece.start_byte);
                    any_newly_deleted = true;
                }
            }
        }
        return if (any_newly_deleted) .applied else .duplicate;
    }

    fn findSpanIndex(self: *const SpanText, key: SpanKey) ?u32 {
        for (self.spans.items, 0..) |span, idx| {
            if (span.key.eql(key)) return @intCast(idx);
        }
        return null;
    }

    /// Ensures that the piece of `span_idx` containing `byte_offset` ends at
    /// `byte_offset` (splitting it into `[start..byte_offset)` and `[byte_offset..end)`
    /// if `byte_offset < end`). Returns the index of the piece whose `end_byte == byte_offset`.
    fn ensureSplitAt(self: *SpanText, span_idx: u32, byte_offset: u32) Error!usize {
        for (self.pieces.items, 0..) |piece, idx| {
            if (piece.span_index != span_idx) continue;
            if (piece.end_byte == byte_offset) return idx;
            if (piece.start_byte < byte_offset and byte_offset < piece.end_byte) {
                const right: InternalPiece = .{
                    .span_index = span_idx,
                    .start_byte = byte_offset,
                    .end_byte = piece.end_byte,
                    .deleted = piece.deleted,
                };
                self.pieces.items[idx].end_byte = byte_offset;
                // Where does `right` belong?
                // Any external insertions anchored at `(span.key, byte_offset)` must
                // precede `right`, which is only needed if such insertions already
                // exist; since causal order requires `span` to exist before any child
                // anchors at `(span.key, byte_offset)`, when `ensureSplitAt` splits an
                // unsplit piece, no external child is yet anchored at `byte_offset`, so
                // `idx + 1` is the exact canonical position for `right`!
                try self.pieces.insert(self.allocator, idx + 1, right);
                return idx;
            }
        }
        unreachable;
    }

    /// Computes the canonical piece-array index where a newly inserted span `new_key`
    /// with anchor `after` must be placed so that:
    /// 1. Sibling external insertions with the same `after` are ordered by descending `SpanKey`.
    /// 2. Each sibling's entire subtree (all pieces causally descending from that sibling
    ///    or continuing that sibling) precedes the next lower-priority sibling.
    /// 3. The continuation piece of the parent span `[after.byte_offset .. )` comes
    ///    AFTER all external insertions anchored at `after`.
    fn findInsertionIndex(
        self: *const SpanText,
        new_key: SpanKey,
        after: ?Boundary,
        anchor_piece_idx: ?usize,
    ) usize {
        var cursor: usize = if (anchor_piece_idx) |idx| idx + 1 else 0;
        while (cursor < self.pieces.items.len) {
            const candidate = self.pieces.items[cursor];
            const cand_span = self.spans.items[candidate.span_index];

            // If `candidate` is a continuation piece (`start_byte > 0`) of the anchor
            // span itself at `after.byte_offset`, the new external insertion must
            // come BEFORE that continuation piece!
            if (after) |boundary| {
                if (cand_span.key.eql(boundary.span) and candidate.start_byte == boundary.byte_offset) {
                    break;
                }
            }

            // Does `candidate` belong to the subtree of a sibling at `after` with
            // higher priority than `new_key`, or is it inside an ancestor's subtree
            // that started at/after `anchor_piece_idx + 1`?
            if (self.findSiblingRootAtAnchor(candidate.span_index, after)) |sibling_key| {
                if (sibling_key.higherPriorityThan(new_key)) {
                    cursor += 1;
                    continue;
                }
                break;
            } else {
                // `candidate` is not a descendant of `after` at all — we have reached
                // the end of the `after` anchor's external subtree!
                break;
            }
        }
        return cursor;
    }

    /// If `span_index` is (or causally descends from an external insertion that is)
    /// directly anchored at `target_after`, returns the `SpanKey` of that direct
    /// child of `target_after`. Otherwise returns `null`.
    fn findSiblingRootAtAnchor(
        self: *const SpanText,
        span_index: u32,
        target_after: ?Boundary,
    ) ?SpanKey {
        var current = self.spans.items[span_index];
        while (true) {
            if (sameBoundary(current.after, target_after)) {
                return current.key;
            }
            const parent_boundary = current.after orelse return null;
            const parent_idx = self.findSpanIndex(parent_boundary.span) orelse return null;
            current = self.spans.items[parent_idx];
        }
    }

    fn sameBoundary(a: ?Boundary, b: ?Boundary) bool {
        if (a == null and b == null) return true;
        if (a == null or b == null) return false;
        return a.?.span.eql(b.?.span) and a.?.byte_offset == b.?.byte_offset;
    }

    fn isUtf8ScalarBoundary(utf8: []const u8, offset: u32) bool {
        if (offset > utf8.len) return false;
        if (offset == 0 or offset == utf8.len) return true;
        return (utf8[offset] & 0b1100_0000) != 0b1000_0000;
    }
};
