const std = @import("std");
const t = std.testing;
const profiles = @import("root.zig");
const ordered = @import("transit_document").OrderedChange;
const limits = @import("json_test.zig").limits;

test "verified profile candidates preserve duplicate keys numbers XML mixed content and reject late failure" {
    var json_frames: [32]profiles.Json.Frame = undefined;
    var xml_frames: [32]profiles.Xml.Frame = undefined;
    var token: [256]u8 = undefined;
    var names: [32 * 256]u8 = undefined;
    var attributes: [16]profiles.Xml.Attribute = undefined;
    var decoded: [256]u8 = undefined;
    var name: [256]u8 = undefined;
    var ends: [32]usize = undefined;
    var output: [8192]u8 = undefined;
    const fixtures = [_]struct { format: profiles.Profile.contract.Format, input: []const u8, nodes: []const ordered.Node }{
        .{ .format = .json, .input = "{\"dup\":[123456789012345678901234567890,true,null],\"dup\":\"é\"}", .nodes = &.{
            .{ .depth = 0, .kind = .map },
            .{ .depth = 1, .kind = .list, .name = "dup" },
            .{ .depth = 2, .kind = .number, .value = "123456789012345678901234567890" },
            .{ .depth = 2, .kind = .boolean, .value = "\x01" },
            .{ .depth = 2, .kind = .null_value },
            .{ .depth = 1, .kind = .string, .name = "dup", .value = "é" },
        } },
        .{ .format = .xml, .input = "<!--before--><r a='x&amp;y'>text<e/>tail<?p data?></r><!--after-->", .nodes = &.{
            .{ .depth = 0, .kind = .list },
            .{ .depth = 1, .kind = .comment, .value = "before" },
            .{ .depth = 1, .kind = .element, .name = "r" },
            .{ .depth = 2, .kind = .attribute, .name = "a", .value = "x&y" },
            .{ .depth = 2, .kind = .text, .value = "text" },
            .{ .depth = 2, .kind = .element, .name = "e" },
            .{ .depth = 2, .kind = .text, .value = "tail" },
            .{ .depth = 2, .kind = .processing_instruction, .name = "p", .value = "data" },
            .{ .depth = 1, .kind = .comment, .value = "after" },
        } },
    };
    for (fixtures) |fixture| {
        const descriptor = try profiles.Profile.descriptor(fixture.format, limits);
        const part: profiles.Profile.contract.Part = .{ .definition = descriptor.definition, .profile = descriptor.digest, .id = 19, .bytes = fixture.input.len, .sha256 = profiles.Profile.grammar(fixture.input).sha256, .coverage = .complete, .source = null };
        const workspace: profiles.OrderedInput.Workspace = .{ .reader = if (fixture.format == .json) .{ .json = .{ .frames = &json_frames, .token = &token } } else .{ .xml = .{ .frames = &xml_frames, .names = &names, .attributes = &attributes, .raw = &token, .decoded = &decoded } }, .name = &name, .ends = &ends };
        const request: profiles.OrderedInput.Request = .{ .document = @splat(0x81), .epoch = 1, .expected_revision = 0 };
        const candidate = try profiles.OrderedInput.encode(descriptor, part, request, fixture.input, workspace, &output);
        try t.expectEqualDeep(part, candidate.verified_part);
        var reader = try ordered.Decoder.init(candidate.bytes);
        try t.expectEqual(fixture.nodes.len, reader.header.nodes);
        try t.expectEqualStrings(fixture.input, (try reader.nextPart()).?.bytes);
        var frames: [33]ordered.Frame = undefined;
        var validator: ordered.Validator = .{ .frames = &frames };
        for (fixture.nodes, 0..) |expected, i| {
            const actual = (try reader.next()).?;
            try validator.push(actual);
            try t.expectEqual(expected.kind, actual.kind);
            try t.expectEqual(expected.depth, actual.depth);
            try t.expectEqualStrings(expected.name, actual.name);
            try t.expectEqualStrings(expected.value, actual.value);
            try t.expectEqual(@as(u64, 19), actual.span.?.part);
            try t.expect(actual.span.?.end <= fixture.input.len);
            if (i == 0) try t.expectEqual(fixture.input.len, actual.span.?.end);
        }
        try validator.finish();
        try t.expect((try reader.next()) == null);
        // A valid root followed by garbage cannot become a usable candidate.
        var bad: [1024]u8 = undefined;
        @memcpy(bad[0..fixture.input.len], fixture.input);
        bad[fixture.input.len] = '!';
        const invalid = bad[0 .. fixture.input.len + 1];
        var invalid_part = part;
        invalid_part.bytes = invalid.len;
        invalid_part.sha256 = profiles.Profile.grammar(invalid).sha256;
        if (profiles.OrderedInput.encode(descriptor, invalid_part, request, invalid, workspace, &output)) |_| return error.AcceptedInvalidProfile else |_| {}
        try t.expectError(error.InvalidOrderedChange, ordered.Decoder.init(&output));
        var wrong_part = part;
        wrong_part.sha256[0] ^= 1;
        try t.expectError(error.InvalidOrderedPart, profiles.OrderedInput.encode(descriptor, wrong_part, request, fixture.input, workspace, &output));
        try t.expectError(error.DocumentEncodingCapacity, profiles.OrderedInput.encode(descriptor, part, request, fixture.input, workspace, output[0..128]));
    }
}
