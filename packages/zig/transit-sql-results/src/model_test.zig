const std = @import("std");
const r = @import("root.zig");
const t = std.testing;
const identity: r.Identity = .{ .result = @splat(1), .schema = @splat(2), .observation = @splat(3) };

test "logical result projection is independent of chunk boundaries and terminal framing" {
    // Independent oracle: the relation is a sequence of occurrences, including
    // duplicate values. Enumeration covers every partition of up to eight rows.
    for (0..9) |length| {
        const partitions = @as(usize, 1) << @intCast(length);
        for (0..partitions) |cuts| for ([_]bool{ false, true }) |empty_terminal| {
            var state: r.Progress = .{ .identity = identity };
            var emitted: usize = 0;
            var pending: usize = 0;
            for (0..length) |index| {
                pending += 1;
                if (index + 1 == length or cuts & (@as(usize, 1) << @intCast(index)) != 0) {
                    try state.receive(identity, pending);
                    // A replay is erased by the communication adapter. No
                    // second semantic receive event exists for the same chunk.
                    if (index + 1 == length and !empty_terminal) try state.finish(identity, .{ .rows = length });
                    for (0..pending) |_| {
                        try state.deliver(1);
                        emitted += 1;
                        try t.expectEqual(emitted, state.delivered);
                    }
                    pending = 0;
                }
            }
            if (empty_terminal or length == 0) try state.finish(identity, .{ .rows = length });
            try t.expectEqual(length, emitted);
            try t.expectEqual(r.Completion{ .rows = length }, state.completion().?);
            try t.expectEqual(.exhausted, state.consumption);
            state.release();
            state.release();
            try t.expectEqual(length, state.completion().?.rows);
        };
    }
}
test "incomplete prefixes, identity changes and incorrect terminal counts reject" {
    var state: r.Progress = .{ .identity = identity };
    try state.receive(identity, 2);
    try state.deliver(1);
    var other = identity;
    other.schema[0] ^= 1;
    try t.expectError(error.ResultIdentityChanged, state.receive(other, 1));
    try t.expectError(error.InvalidResultCount, state.finish(identity, .{ .rows = 1 }));
    try t.expectError(error.InvalidResultTransition, state.deliver(2));
    state.release();
    try t.expect(state.completion() == null);
    try t.expectError(error.InvalidResultTransition, state.finish(identity, .{ .rows = 2 }));
    try t.expectEqual(1, state.delivered);
    for ([_]bool{ false, true }) |cancelled| {
        var failed: r.Progress = .{ .identity = identity };
        try failed.receive(identity, 1);
        try failed.deliver(1);
        failed.fail(cancelled);
        try t.expect(failed.completion() == null);
        try t.expectError(error.InvalidResultTransition, failed.finish(identity, .{ .rows = 1 }));
    }
}
test "progress guards reject duplicate delivery and preserve received terminal evidence" {
    var state: r.Progress = .{ .identity = identity };
    try state.receive(identity, 1);
    try state.finish(identity, .{ .rows = 1 });
    try t.expectEqual(.reading, state.consumption);
    try state.deliver(1);
    try t.expectError(error.InvalidResultTransition, state.deliver(1));
    try t.expectError(error.InvalidResultTransition, state.receive(identity, 1));
    var overflow: r.Progress = .{ .identity = identity, .received = std.math.maxInt(u64) };
    try t.expectError(error.ResultCountOverflow, overflow.receive(identity, 1));
    try t.expectEqual(std.math.maxInt(u64), overflow.received);
}
test "bounded logical copies own nested scratch-backed values" {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    var scratch = "hello".*;
    const nested = [_]r.Types.Field{.{ .name = "text", .type = .utf8 }};
    const fields = [_]r.Types.Field{.{ .name = "nested", .type = .{ .structure = &nested } }};
    const children = [_]r.Types.Values.Cell{.{ .value = .{ .atom = .{ .bytes = &scratch } } }};
    const row = [_]r.Types.Values.Cell{.{ .value = .{ .structure = &children } }};
    const copied = try r.copyRow(arena.allocator(), &fields, &row);
    @memset(&scratch, 'x');
    try t.expectEqualStrings("hello", copied[0].value.structure[0].value.atom.bytes);
}
test "published resource observation binds attribution and halts mid-stream on withdrawal or revocation" {
    const pub_obs: r.Observation.PublishedResourceObservation = .{
        .resource_object = 500,
        .definition_id = 9001,
        .publication_revision = 1,
        .definition_digest = @splat(0x11),
        .disclosure_mode = .derived_publication,
        .audience_policy_hash = @splat(0x22),
        .verified_policy_epoch = 5,
        .investigation_id = 700,
        .basis_revision = 1,
        .is_globally_atomic = false,
        .basis_digest = @splat(0x33),
        .attribution_receipt_digest = @splat(0x44),
    };
    try pub_obs.validate();
    try pub_obs.validateBatchDisclosure(5, false, false);
    try t.expectError(error.PublishedResourceWithdrawn, pub_obs.validateBatchDisclosure(6, true, false));
    try t.expectError(error.AuthorizationRevokedMidStream, pub_obs.validateBatchDisclosure(6, false, true));
}
