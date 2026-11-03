//! M16 verified-reader to M7 disk acceptance handoff, without Station.
const std = @import("std");
const t = std.testing;
const p = @import("transit_protocol");
const s = @import("transit_storage");
const profiles = @import("transit_document_profiles");
const d = p.DataLifecycle;
fn acquire(_: *anyopaque) !s.PublicationGuard.Fence {
    return .{ .writer_epoch = 1, .policy_epoch = 1 };
}
fn release(_: *anyopaque) void {}
fn op(id: u64) d.Operation {
    return .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .principal = 7, .operation = id };
}

test "verified workbook XML and MIME candidates publish complete ordered revisions on disk" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var prepared = try s.DocumentDeclaration.prepare(t.allocator, .{
        .object = .{ .scope = op(1).scope, .branch = 1, .object = 505 },
        .revision = 1,
        .schema = .{ .object = 505, .revision = 1, .next_column = 2, .columns = &.{.{ .id = 1, .name = "key", .type = .utf8, .nullable = false, .collation = .utf8_binary }} },
        .configuration = .{ .partitioning = .{ .count = 1, .key_column = null, .hash = .sha256_64 }, .profile = .versioned, .shredding = .{ .frequent_path_threshold = 64, .max_shredded_columns = 32, .default_collation = .utf8_binary }, .retention = .{ .max_age_ms = null, .merge_window_revisions = null } },
        .limits = .{ .change_bytes = 16384, .operations_per_change = 1, .path_depth = 32, .read_steps = 4096, .read_bytes = 16384, .unresolved_conflicts = 16 },
        .properties = "",
    });
    defer prepared.deinit();
    const declared = try s.DocumentDeclaration.stage(objects.objectStore(), &prepared);
    const initial: s.DocumentInitialization.Request = .{ .definition = p.Growth.current_definition, .declared = declared, .operation = op(1), .ordinal = 0, .partition = 113 };
    var context: u8 = 0;
    const guard: s.PublicationGuard = .{ .context = &context, .acquire = acquire, .release = release };
    _ = try s.DocumentInitialization.initialize(t.allocator, wal.log(), objects.objectStore(), initial, guard);
    var owner = try s.DocumentPartition.open(t.allocator, wal.log(), objects.objectStore(), initial, guard, .{ .read_secret = @splat(7), .logical = .{ .pending_records = 8, .resident_pages = 1 } });
    defer owner.deinit();
    const mime_prefix = "X-A: one\r\n\t two \r\nx-a:\r\nbody: header\r\n\r\n";
    const mime_body = comptime blk: {
        @setEvalBranchQuota(2000);
        var bytes: [1500]u8 = undefined;
        for (&bytes, 0..) |*byte, i| byte.* = "\x00\xff\r\n."[i % 5];
        break :blk bytes;
    };
    const mime_source = mime_prefix ++ mime_body;
    const mime_nodes = [_]struct { kind: []const u8, depth: u32, name: []const u8, value: []const u8, start: u64, end: u64 }{
        .{ .kind = "map", .depth = 0, .name = "", .value = "", .start = 0, .end = mime_source.len },
        .{ .kind = "list", .depth = 1, .name = "headers", .value = "", .start = 0, .end = mime_prefix.len },
        .{ .kind = "binary", .depth = 2, .name = "X-A", .value = " one\t two ", .start = 0, .end = 16 },
        .{ .kind = "binary", .depth = 2, .name = "x-a", .value = "", .start = 18, .end = 22 },
        .{ .kind = "binary", .depth = 2, .name = "body", .value = " header", .start = 24, .end = 36 },
        .{ .kind = "binary", .depth = 1, .name = "body", .value = &mime_body, .start = mime_prefix.len, .end = mime_source.len },
    };
    const fixtures = [_]struct { format: profiles.Profile.contract.Format, input: []const u8, nodes: u32 }{
        .{ .format = .json, .input = "{\"cells\":[{\"kind\":\"sql\",\"source\":\"SELECT 1\"},{\"kind\":\"text\",\"source\":\"notes é\"}],\"preferences\":{\"theme\":\"dark\"}}", .nodes = 10 },
        .{ .format = .xml, .input = "<!--before--><r a='x&amp;y'>text<e/>tail<?p data?></r><!--after-->", .nodes = 9 },
        .{ .format = .mime, .input = mime_source, .nodes = mime_nodes.len },
    };
    var json_frames: [32]profiles.Json.Frame = undefined;
    var xml_frames: [32]profiles.Xml.Frame = undefined;
    var token: [256]u8 = undefined;
    var names: [32 * 256]u8 = undefined;
    var attributes: [16]profiles.Xml.Attribute = undefined;
    var decoded: [256]u8 = undefined;
    var name: [256]u8 = undefined;
    var ends: [32]usize = undefined;
    var output: [8192]u8 = undefined;
    for (fixtures, 0..) |fixture, i| {
        const descriptor = try profiles.Profile.descriptor(fixture.format, .{ .input_bytes = 8192, .expanded_bytes = 8192, .expansion_ratio = 1, .parts = 1, .nodes = 1024, .depth = 32, .token_bytes = 256, .attributes = 16, .diagnostics = 1, .work = 32768 });
        const part: profiles.Profile.contract.Part = .{ .definition = descriptor.definition, .profile = descriptor.digest, .id = 19, .bytes = fixture.input.len, .sha256 = profiles.Profile.grammar(fixture.input).sha256, .coverage = .complete, .source = null };
        const workspace: profiles.OrderedInput.Workspace = .{ .reader = switch (fixture.format) {
            .json => .{ .json = .{ .frames = &json_frames, .token = &token } },
            .xml => .{ .xml = .{ .frames = &xml_frames, .names = &names, .attributes = &attributes, .raw = &token, .decoded = &decoded } },
            .mime => .{ .mime = .{ .raw = &token, .unfolded = &decoded } },
            else => unreachable,
        }, .name = &name, .ends = &ends };
        const request: profiles.OrderedInput.Request = .{ .document = @splat(@as(u8, @intCast(i + 1))), .epoch = 1, .expected_revision = 0 };
        const candidate = try profiles.OrderedInput.encode(descriptor, part, request, fixture.input, workspace, &output);
        const target: p.DocumentOperation.Target = .{ .partition = initial.target(), .document = request.document };
        const mutation: p.DocumentOperation.Mutation = .{ .target = target, .operation = op(i * 10 + 2), .lineage = .{ .profile = .versioned, .merge_epoch = 1, .base_revision = 0, .replica = null, .parent_revision = null, .raw_span = null }, .operations = 1, .payload = profiles.Profile.grammar(candidate.bytes) };
        const accepted = try owner.applyOrdered(mutation, candidate.bytes, guard);
        @memset(&token, 0xcc);
        @memset(&decoded, 0xcc);
        owner.deinit();
        owner = try s.DocumentPartition.open(t.allocator, wal.log(), objects.objectStore(), initial, guard, .{ .read_secret = @splat(7) });
        const replay_appends = wal.appends;
        try t.expectEqualDeep(accepted, try owner.applyOrdered(mutation, candidate.bytes, guard));
        try t.expectEqual(replay_appends, wal.appends);
        const read = try owner.beginRead(.{ .target = target, .operation = op(i * 10 + 3), .from_revision = 1, .through_revision = 1, .max_steps = 4096, .max_bytes = 8192 }, guard);
        var cursor = try owner.orderedCursor(read, .{ .kind = .tree }, guard);
        var count: usize = 0;
        var saw_source = false;
        var saw_text = false;
        var mime_value_offset: usize = 0;
        while (try owner.readOrderedPage(cursor, guard)) |page| {
            if (page.section == .node) {
                if (fixture.format == .mime) {
                    if (count != 0) try t.expectEqual(mime_nodes[count - 1].value.len, mime_value_offset);
                    mime_value_offset = 0;
                    const expected = mime_nodes[count];
                    try t.expectEqualStrings(expected.kind, @tagName(page.node.?.kind));
                    try t.expectEqual(expected.depth, page.node.?.depth);
                    try t.expectEqual(expected.name.len, page.node.?.name_bytes);
                    try t.expectEqual(expected.value.len, page.node.?.value_bytes);
                    try t.expectEqual(expected.start, page.node.?.span.?.start);
                    try t.expectEqual(expected.end, page.node.?.span.?.end);
                }
                count += 1;
                try t.expectEqual(@as(u64, 19), page.node.?.span.?.part);
            }
            if (fixture.format == .mime and page.section == .name) try t.expectEqualStrings(mime_nodes[count - 1].name, page.data.slice());
            if (fixture.format == .mime and page.section == .value) {
                try t.expectEqualSlices(u8, mime_nodes[count - 1].value[mime_value_offset..][0..page.data.len], page.data.slice());
                mime_value_offset += page.data.len;
            }
            if (page.section == .name and std.mem.eql(u8, page.data.slice(), "source")) saw_source = true;
            if (page.section == .value and std.mem.eql(u8, page.data.slice(), if (fixture.format == .json) "notes é" else "tail")) saw_text = true;
            cursor = page.cursor;
        }
        try t.expectEqual(fixture.nodes, count);
        if (fixture.format == .json) try t.expect(saw_source);
        if (fixture.format == .mime) {
            try t.expectEqual(mime_body.len, mime_value_offset);
            const navigation = try owner.inspectOrderedNode(read, 1, guard);
            try t.expectEqual(@as(?u64, 2), navigation.node.first_child);
            try t.expectEqual(@as(?u64, 5), navigation.node.next_sibling);
            try t.expectEqual(@as(u64, 5), navigation.node.subtree_end);
        } else try t.expect(saw_text);
        var raw_cursor = try owner.orderedCursor(read, .{ .kind = .part, .part = 19 }, guard);
        var raw_offset: usize = 0;
        while (try owner.readOrderedPage(raw_cursor, guard)) |raw| {
            try t.expectEqualSlices(u8, fixture.input[raw_offset..][0..raw.data.len], raw.data.slice());
            raw_offset += raw.data.len;
            raw_cursor = raw.cursor;
        }
        try t.expectEqual(fixture.input.len, raw_offset);
        try t.expect(raw_cursor.complete);
        const before = wal.appends;
        var invalid_storage: [2048]u8 = undefined;
        @memcpy(invalid_storage[0..fixture.input.len], fixture.input);
        invalid_storage[fixture.input.len] = '!';
        // Appending bytes is valid for a MIME body. Break the second header
        // after the first field has already been copied into private output.
        if (fixture.format == .mime) invalid_storage[21] = '\n';
        const invalid = invalid_storage[0 .. fixture.input.len + 1];
        var bad_part = part;
        bad_part.bytes = invalid.len;
        bad_part.sha256 = profiles.Profile.grammar(invalid).sha256;
        if (profiles.OrderedInput.encode(descriptor, bad_part, request, invalid, workspace, &output)) |_| return error.AcceptedInvalidProfile else |_| {}
        try t.expectEqual(before, wal.appends);
        try t.expect((try owner.readOrderedPage(cursor, guard)) == null);
    }
}
