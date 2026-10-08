//! Reference-safe cleanup of rejected/cancelled Table reservations. This owner
//! never collects applied work or changes terminal outcomes, ID floors or heads.
const std = @import("std");
const p = @import("transit_client").protocol;
const Turn = @import("Turn.zig");
const Write = @import("TableWrite.zig");
const Head = @import("TableHead.zig");
const Pages = @import("TablePages.zig");
pub const Cursor = struct {
    digest: [32]u8,
    first: u64,
    end: u64,
    next: u64,
    phase: enum(u8) { inline_pages = 1, publications = 2, complete = 3 } = .inline_pages,
    pub fn key(reference: Write.Reference) p.Value {
        var result = reference.key();
        result.data[1] = 'X';
        return result;
    }
    fn validate(self: Cursor) !void {
        if (self.first == 0 or self.end < self.first or self.next < self.first or self.next > self.end or (self.phase == .complete and self.next != self.end)) return error.InvalidTableCleanup;
    }
    pub fn encode(self: Cursor) !p.Value {
        try self.validate();
        var bytes: [93]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try writer.writeAll("STX1");
        try writer.writeAll(&definition());
        try writer.writeAll(&self.digest);
        try writer.writeInt(u64, self.first, .little);
        try writer.writeInt(u64, self.end, .little);
        try writer.writeInt(u64, self.next, .little);
        try writer.writeByte(@backingInt(self.phase));
        return p.Value.init(writer.buffered());
    }
    pub fn decode(value: p.Value) !Cursor {
        try value.validate();
        if (value.len != 93 or !std.mem.eql(u8, value.data[0..4], "STX1")) return error.InvalidTableCleanup;
        if (!std.mem.eql(u8, value.data[4..36], &definition())) return error.IncompatibleTableStorage;
        const result: Cursor = .{
            .digest = value.data[36..68].*,
            .first = std.mem.readInt(u64, value.data[68..76], .little),
            .end = std.mem.readInt(u64, value.data[76..84], .little),
            .next = std.mem.readInt(u64, value.data[84..92], .little),
            .phase = std.enums.fromInt(@FieldType(Cursor, "phase"), value.data[92]) orelse return error.InvalidTableCleanup,
        };
        try result.validate();
        return result;
    }
};
fn definition() [32]u8 {
    var bytes: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, @tagName(p.Growth.current_definition)) catch unreachable;
    return bytes;
}
fn inRange(id: u64, result: Write.Status) bool {
    return id >= result.first_record and id < result.end_record;
}
fn writeCount(turn: *const Turn) usize {
    var count: usize = 0;
    for (turn.decision.mutations) |slot| count += @intFromBool(slot != null);
    return count;
}
/// Call after current cleanup authority and receipt disclosure checks. A closed
/// exclusive interval cannot enter any accepted successor: publication/cancel
/// fencing and the nonreused ID floor establish this, not a guessed root scan.
pub fn step(turn: *Turn, reference: Write.Reference) !bool {
    const before = turn.decision;
    errdefer turn.decision = before;
    const result = (try Write.status(turn, reference)) orelse return error.TableWriteNotFound;
    if (result.state != .rejected and result.state != .cancelled) return error.TableCleanupNotClosed;
    const head = try Head.load(turn, reference.object);
    if (head.next_record < result.end_record or inRange(head.schema.id, result) or
        (head.pending != 0 and inRange(head.pending, result))) return error.InvalidTableCleanup;
    if (head.index.root) |root| if (inRange(root.id, result)) return error.InvalidTableCleanup;
    var cursor = if (try turn.read(Cursor.key(reference))) |value| try Cursor.decode(value) else Cursor{
        .digest = reference.digest,
        .first = result.first_record,
        .end = result.end_record,
        .next = result.first_record,
    };
    if (!std.mem.eql(u8, &cursor.digest, &reference.digest) or cursor.first != result.first_record or cursor.end != result.end_record) return error.InvalidTableCleanup;
    if (cursor.phase == .complete) return true;
    const pages: Pages = .{ .resource = reference.resource, .object = reference.object };
    if (try pages.nextRecord(turn, cursor.phase == .publications, cursor.next, cursor.end)) |id| {
        const before_count = writeCount(turn);
        if (try pages.collect(turn, id, cursor.phase == .publications) == .progress) return false;
        cursor.next = id + 1; // id < exclusive end, so this cannot overflow.
        turn.write(Cursor.key(reference), try cursor.encode()) catch |err| {
            if (err != error.MutationBudgetExceeded or writeCount(turn) == before_count) return err;
            // A full four-write Publication collection commits first; the next
            // step sees its permanent closed descriptor and advances the cursor.
            return false;
        };
    } else {
        cursor.phase = if (cursor.phase == .inline_pages) .publications else .complete;
        cursor.next = if (cursor.phase == .complete) cursor.end else cursor.first;
        try turn.write(Cursor.key(reference), try cursor.encode());
    }
    return cursor.phase == .complete;
}
