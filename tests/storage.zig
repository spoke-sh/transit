const std = @import("std");
const adapter = @import("transit_ursula");
const ursula = adapter.ursula;
const check = std.testing;

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.ExpectedUrlAndPhase;
    var client = try ursula.Client.init(init.gpa, init.io, .{ .base_url = args[1] });
    defer client.deinit();
    const journal: adapter.Journal = .{ .client = &client, .stream = .{ .bucket = "transit-proof", .name = "journal" } };
    if (std.mem.eql(u8, args[2], "write")) {
        try journal.create();
        const first = try journal.tail();
        try check.expectEqual(@as(u64, 0), first);
        // Two proposals derive from the same prefix; only one may become visible.
        try check.expect(try journal.append(first, "{\"winner\":1}"));
        try check.expect(!try journal.append(first, "{\"winner\":2}"));
        // Discard the successful receipt, then retry as if its ack were lost.
        _ = try journal.append(1, "{\"uncertain\":true}");
        try check.expect(!try journal.append(1, "{\"uncertain\":true}"));
        for (2..40) |i| {
            const body = try init.gpa.print("{{\"n\":{d}}}", .{i});
            defer init.gpa.free(body);
            try check.expect(try journal.append(i, body));
        }
    } else if (std.mem.eql(u8, args[2], "recover") or std.mem.eql(u8, args[2], "checkpoint") or std.mem.eql(u8, args[2], "trim_recover")) {
        try check.expectEqual(@as(u64, 40), try journal.tail());
        try check.expect(!try journal.append(0, "{\"stale\":true}"));
        var at: u64 = 0;
        while (at < 40) {
            var batch = try journal.read(at);
            defer batch.deinit();
            const next = (try batch.head.metadata()).record_next.?;
            try check.expect(next > at);
            if (at == 0) {
                try check.expect(std.mem.startsWith(u8, batch.body, "{\"winner\":1}\n{\"uncertain\":true}\n"));
                try check.expect(std.mem.indexOf(u8, batch.body, "winner\":2") == null);
            }
            at = next;
        }
        try check.expectEqual(@as(u64, 40), at);
    } else return error.UnknownPhase;
    std.debug.print("storage {s}: passed\n", .{args[2]});
}
