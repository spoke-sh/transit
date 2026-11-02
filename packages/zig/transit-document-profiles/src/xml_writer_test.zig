const std = @import("std");
const t = std.testing;
const Profile = @import("Profile.zig");
const Writer = @import("XmlWriter.zig");
const limits = @import("json_test.zig").limits;
const Workspace = struct {
    frames: [32]Writer.Frame = undefined,
    names: [32 * 256]u8 = undefined,
    attributes: [16]Writer.Attribute = undefined,
    attribute_names: [256]u8 = undefined,
    encoded: [257]u8 = undefined,
    fn get(self: *Workspace) Writer.Workspace {
        return .{ .frames = &self.frames, .names = &self.names, .attributes = &self.attributes, .attribute_names = &self.attribute_names, .encoded = &self.encoded };
    }
};
fn collect(writer: *Writer, output: []u8, used: *usize, chunk: usize) !void {
    while (writer.needsDrain()) used.* += try writer.drain(output[used.*..@min(output.len, used.* + chunk)], 3);
}
fn discard(writer: *Writer) !void {
    var bytes: [7]u8 = undefined;
    while (writer.needsDrain()) _ = try writer.drain(&bytes, 3);
}

test "XML construction preserves ordered attributes mixed text and escaped whitespace" {
    const tokens = [_]Writer.Token{
        .{ .comment = "before" },  .{ .processing_instruction = .{ .name = "step", .body = "data" } },
        .{ .element_start = "r" },
        .{ .attribute = .{ .name = "a", .value = "\t\n\r<&\"é🙂" } },
        .{ .text = "left\r]]>" },  .{ .element_start = "child" },
        .element_end,              .{ .text = "right" },
        .element_end,              .{ .comment = "after" },
    };
    const expected = "<!--before--><?step data?><r a=\"&#9;&#10;&#13;&lt;&amp;&quot;é🙂\">left&#13;]]&gt;<child/>right</r><!--after-->";
    for (1..12) |chunk| {
        var workspace: Workspace = .{};
        var writer = try Writer.init(try Profile.descriptor(.xml, limits), 2, workspace.get());
        var output: [512]u8 = undefined;
        var used: usize = 0;
        for (tokens) |token| {
            try writer.begin(token);
            try collect(&writer, &output, &used, chunk);
        }
        const part = try writer.finish();
        try t.expectEqualStrings(expected, output[0..used]);
        try t.expectEqual(Profile.grammar(expected).sha256, part.sha256);
        try t.expectEqual(@as(u64, expected.len), part.bytes);
        try t.expectEqualDeep(part, try writer.finish());
        try t.expectError(error.DocumentWriterComplete, writer.begin(.element_end));
    }
}

test "XML rejects invalid names scalars comments instructions and duplicate attributes" {
    var workspace: Workspace = .{};
    const descriptor = try Profile.descriptor(.xml, limits);
    const Case = struct { token: Writer.Token, expected: anyerror };
    for ([_]Case{
        .{ .token = .{ .element_start = "p:r" }, .expected = error.UnsupportedXmlNamespace },
        .{ .token = .{ .element_start = "r x" }, .expected = error.InvalidXmlName },
        .{ .token = .{ .element_start = "é" }, .expected = error.InvalidXmlName },
        .{ .token = .{ .comment = "--" }, .expected = error.InvalidXmlComment },
        .{ .token = .{ .comment = "x-" }, .expected = error.InvalidXmlComment },
        .{ .token = .{ .comment = "\r" }, .expected = error.InvalidXmlComment },
        .{ .token = .{ .comment = "\x00" }, .expected = error.InvalidXmlCharacter },
        .{ .token = .{ .comment = "\xef\xbf\xbe" }, .expected = error.InvalidXmlCharacter },
        .{ .token = .{ .comment = "\xc0\x80" }, .expected = error.InvalidDocumentUtf8 },
        .{ .token = .{ .processing_instruction = .{ .name = "XML", .body = "" } }, .expected = error.UnsupportedXmlDeclaration },
        .{ .token = .{ .processing_instruction = .{ .name = "p", .body = " x" } }, .expected = error.InvalidXmlSyntax },
        .{ .token = .{ .processing_instruction = .{ .name = "p", .body = "?>" } }, .expected = error.InvalidXmlSyntax },
        .{ .token = .element_end, .expected = error.InvalidXmlSyntax },
        .{ .token = .{ .text = "outside" }, .expected = error.InvalidXmlSyntax },
    }) |case| {
        var writer = try Writer.init(descriptor, 1, workspace.get());
        try t.expectError(case.expected, writer.begin(case.token));
        try t.expectError(error.DocumentWriterFailed, writer.finish());
    }
    var writer = try Writer.init(descriptor, 1, workspace.get());
    try writer.begin(.{ .element_start = "r" });
    try discard(&writer);
    try writer.begin(.{ .attribute = .{ .name = "a", .value = "1" } });
    try discard(&writer);
    try t.expectError(error.DuplicateXmlAttribute, writer.begin(.{ .attribute = .{ .name = "a", .value = "2" } }));
    writer = try Writer.init(descriptor, 1, workspace.get());
    try writer.begin(.{ .element_start = "r" });
    try discard(&writer);
    try t.expectError(error.UnsupportedXmlNamespace, writer.begin(.{ .attribute = .{ .name = "xmlns", .value = "x" } }));
}

test "XML construction copies input and enforces token and cumulative markup bounds" {
    var workspace: Workspace = .{};
    var writer = try Writer.init(try Profile.descriptor(.xml, limits), 1, workspace.get());
    var name: [1]u8 = .{'r'};
    try writer.begin(.{ .element_start = &name });
    name[0] = 'x';
    try t.expectError(error.DocumentWriterBusy, writer.begin(.element_end));
    try t.expectError(error.DocumentWriterBusy, writer.finish());
    var output: [512]u8 = undefined;
    var used: usize = 0;
    try collect(&writer, &output, &used, 1);
    try writer.begin(.element_end);
    try collect(&writer, &output, &used, 1);
    _ = try writer.finish();
    try t.expectEqualStrings("<r/>", output[0..used]);
    var bounded = limits;
    bounded.token_bytes = 12;
    writer = try Writer.init(try Profile.descriptor(.xml, bounded), 1, workspace.get());
    try writer.begin(.{ .element_start = "r" });
    try discard(&writer);
    try writer.begin(.{ .attribute = .{ .name = "a", .value = "1" } });
    try discard(&writer);
    try t.expectError(error.DocumentTokenLimitExceeded, writer.begin(.{ .attribute = .{ .name = "b", .value = "2" } }));
    writer = try Writer.init(try Profile.descriptor(.xml, bounded), 1, workspace.get());
    try writer.begin(.{ .element_start = "r" });
    try discard(&writer);
    try writer.begin(.{ .text = "1234567" });
    try discard(&writer);
    try t.expectError(error.DocumentTokenLimitExceeded, writer.begin(.{ .text = "1234567" }));
    bounded = limits;
    bounded.attributes = 1;
    writer = try Writer.init(try Profile.descriptor(.xml, bounded), 1, workspace.get());
    try writer.begin(.{ .element_start = "r" });
    try discard(&writer);
    try writer.begin(.{ .attribute = .{ .name = "a", .value = "1" } });
    try discard(&writer);
    try t.expectError(error.DocumentAttributeLimitExceeded, writer.begin(.{ .attribute = .{ .name = "b", .value = "2" } }));
}

test "XML construction streams growing sibling counts in fixed workspace" {
    var workspace: Workspace = .{};
    var writer = try Writer.init(try Profile.descriptor(.xml, limits), 1, workspace.get());
    try writer.begin(.{ .element_start = "r" });
    try discard(&writer);
    for (0..100_000) |_| {
        try writer.begin(.{ .element_start = "s" });
        try discard(&writer);
        try writer.begin(.element_end);
        try discard(&writer);
    }
    try writer.begin(.element_end);
    try discard(&writer);
    try t.expectEqual(@as(u64, 400_007), (try writer.finish()).bytes);
}

test "XML construction meters depth nodes bytes expansion and work without completing prefixes" {
    var workspace: Workspace = .{};
    const Case = struct { field: []const u8, value: u64, expected: anyerror };
    inline for ([_]Case{
        .{ .field = "depth", .value = 1, .expected = error.DocumentDepthLimitExceeded },
        .{ .field = "nodes", .value = 1, .expected = error.DocumentNodeLimitExceeded },
        .{ .field = "input_bytes", .value = 3, .expected = error.DocumentInputLimitExceeded },
        .{ .field = "expanded_bytes", .value = 1, .expected = error.DocumentExpansionLimitExceeded },
        .{ .field = "work", .value = 6, .expected = error.DocumentWorkLimitExceeded },
    }) |case| {
        var bounded = limits;
        @field(bounded, case.field) = @intCast(case.value);
        var writer = try Writer.init(try Profile.descriptor(.xml, bounded), 1, workspace.get());
        try writer.begin(.{ .element_start = "r" });
        try discard(&writer);
        try t.expectError(case.expected, writer.begin(.{ .element_start = "c" }));
        try t.expectError(error.DocumentWriterFailed, writer.finish());
    }
    var bounded = limits;
    bounded.work = 5;
    var writer = try Writer.init(try Profile.descriptor(.xml, bounded), 1, workspace.get());
    try writer.begin(.{ .element_start = "r" });
    var output: [2]u8 = undefined;
    try t.expectError(error.DocumentWorkLimitExceeded, writer.drain(&output, 2));
    try t.expectError(error.DocumentWriterFailed, writer.finish());

    bounded = limits;
    bounded.expanded_bytes = 2;
    writer = try Writer.init(try Profile.descriptor(.xml, bounded), 1, workspace.get());
    try writer.begin(.{ .element_start = "r" });
    try discard(&writer);
    try writer.begin(.{ .text = "x" });
    try discard(&writer);
    try t.expectError(error.DocumentExpansionLimitExceeded, writer.begin(.element_end));
    try t.expectError(error.DocumentWriterFailed, writer.finish());
}

test "XML construction requires complete nesting and exact event depth and end names" {
    var workspace: Workspace = .{};
    const descriptor = try Profile.descriptor(.xml, limits);
    var writer = try Writer.init(descriptor, 1, workspace.get());
    try t.expectError(error.IncompleteDocumentFrame, writer.finish());
    try t.expectError(error.DocumentWriterFailed, writer.finish());
    writer = try Writer.init(descriptor, 1, workspace.get());
    try writer.begin(.{ .element_start = "r" });
    var output: [4]u8 = undefined;
    try t.expectError(error.InvalidDocumentWorkBudget, writer.drain(&output, 0));
    try t.expectError(error.InvalidDocumentWorkBudget, writer.drain(output[0..0], 1));
    try discard(&writer);
    try t.expectError(error.IncompleteDocumentFrame, writer.finish());
    try t.expectError(error.DocumentWriterFailed, writer.begin(.element_end));
    inline for (.{ .{ "r", @as(u32, 1) }, .{ "wrong", @as(u32, 0) } }) |case| {
        writer = try Writer.init(descriptor, 1, workspace.get());
        try writer.begin(.{ .element_start = "r" });
        try discard(&writer);
        try t.expectError(error.InvalidDocumentEvent, writer.beginEvent(.{
            .kind = .element_end,
            .depth = case[1],
            .value = case[0],
            .detail = "",
            .span = .{ .part_id = 1, .space = .raw, .byte_start = 0, .byte_end = 0 },
        }));
        try t.expectError(error.DocumentWriterFailed, writer.finish());
    }
}
