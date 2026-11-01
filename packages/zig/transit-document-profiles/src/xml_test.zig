const std = @import("std");
const t = std.testing;
const Xml = @import("Xml.zig");
const Profile = @import("Profile.zig");
const Event = @import("Event.zig").Event;
const limits = @import("json_test.zig").limits;

const Storage = struct {
    frames: [32]Xml.Frame = undefined,
    names: [32 * 256]u8 = undefined,
    attributes: [16]Xml.Attribute = undefined,
    raw: [256]u8 = undefined,
    decoded: [256]u8 = undefined,
    fn workspace(self: *Storage) Xml.Workspace {
        return .{ .frames = &self.frames, .names = &self.names, .attributes = &self.attributes, .raw = &self.raw, .decoded = &self.decoded };
    }
};
const Expected = struct {
    kind: @FieldType(Event, "kind"),
    value: []const u8 = "",
    detail: []const u8 = "",
    depth: u32,
    raw: []const u8,
};

fn expectParse(input: []const u8, split: usize, expected: []const Expected) !void {
    var storage: Storage = .{};
    var parser = try Xml.init(try Profile.descriptor(.xml, limits), 19, storage.workspace());
    var offset: usize = 0;
    var events: usize = 0;
    var first = true;
    var turns: usize = 0;
    while (turns < input.len * 3 + 10) : (turns += 1) {
        const end = if (first) split else input.len;
        const step = try parser.next(input[offset..end], !first, 2);
        offset += step.consumed;
        switch (step.result) {
            .event => |event| {
                try t.expect(events < expected.len);
                const wanted = expected[events];
                try t.expectEqual(wanted.kind, event.kind);
                try t.expectEqualStrings(wanted.value, event.value);
                try t.expectEqualStrings(wanted.detail, event.detail);
                try t.expectEqualStrings(wanted.raw, input[@intCast(event.span.byte_start)..@intCast(event.span.byte_end)]);
                try t.expectEqual(wanted.depth, event.depth);
                try t.expectEqual(@as(u64, 19), event.span.part_id);
                events += 1;
            },
            .need_input => {
                try t.expect(first);
                try t.expectEqual(split, offset);
                first = false;
            },
            .yield => try t.expect(step.consumed > 0),
            .complete => {
                try t.expect(!first);
                try t.expectEqual(input.len, offset);
                try t.expectEqual(expected.len, events);
                try t.expectEqual(.complete, (try parser.next("", true, 1)).result);
                try t.expectError(error.DocumentParserComplete, parser.next("<r/>", true, 1));
                return;
            },
        }
    }
    return error.ParserDidNotComplete;
}

test "XML exact spans ordered attributes and mixed content survive every split" {
    const input = "<?xml version='1.0' encoding='UTF-8' standalone='yes'?>\n<r a='x&amp;&#10;\r\n' b=\"é\">hi\r\n<e/><!--c--><![CDATA[<x>&]]><?p data?></r> ";
    const expected = [_]Expected{
        .{ .kind = .element_start, .value = "r", .depth = 0, .raw = "<r a='x&amp;&#10;\r\n' b=\"é\">" },
        .{ .kind = .attribute, .value = "a", .detail = "x&\n ", .depth = 1, .raw = "a='x&amp;&#10;\r\n'" },
        .{ .kind = .attribute, .value = "b", .detail = "é", .depth = 1, .raw = "b=\"é\"" },
        .{ .kind = .text, .value = "hi\n", .depth = 1, .raw = "hi\r\n" },
        .{ .kind = .element_start, .value = "e", .depth = 1, .raw = "<e/>" },
        .{ .kind = .element_end, .value = "e", .depth = 1, .raw = "<e/>" },
        .{ .kind = .comment, .value = "c", .depth = 1, .raw = "<!--c-->" },
        .{ .kind = .text, .value = "<x>&", .depth = 1, .raw = "<![CDATA[<x>&]]>" },
        .{ .kind = .processing_instruction, .value = "p", .detail = "data", .depth = 1, .raw = "<?p data?>" },
        .{ .kind = .element_end, .value = "r", .depth = 0, .raw = "</r>" },
    };
    for (0..input.len + 1) |split| try expectParse(input, split, &expected);
}

test "XML predefined numeric entities and empty attributes" {
    const input = "<r a=''/>&#32;";
    var storage: Storage = .{};
    var parser = try Xml.init(try Profile.descriptor(.xml, limits), 1, storage.workspace());
    try t.expectError(error.InvalidXmlSyntax, finish(&parser, input, 1));
    const valid = "<r a=''>&lt;&gt;&amp;&apos;&quot;&#x1F642;&#13;</r>";
    const expected = [_]Expected{
        .{ .kind = .element_start, .value = "r", .depth = 0, .raw = "<r a=''>" },
        .{ .kind = .attribute, .value = "a", .depth = 1, .raw = "a=''" },
        .{ .kind = .text, .value = "<>&'\"🙂\r", .depth = 1, .raw = "&lt;&gt;&amp;&apos;&quot;&#x1F642;&#13;" },
        .{ .kind = .element_end, .value = "r", .depth = 0, .raw = "</r>" },
    };
    for (0..valid.len + 1) |split| try expectParse(valid, split, &expected);
}

fn finish(parser: *Xml, input: []const u8, chunk: usize) !void {
    var offset: usize = 0;
    var turns: usize = 0;
    while (turns < input.len * 3 + 10) : (turns += 1) {
        const end = @min(input.len, offset + chunk);
        const step = try parser.next(input[offset..end], end == input.len, 5);
        offset += step.consumed;
        if (step.result == .complete) return;
    }
    return error.ParserDidNotComplete;
}

test "XML malformed and unsupported documents never certify completion" {
    const invalid = [_][]const u8{
        "",                                            " ",                                       "<r>",                                         "<r",                                                          "<r></s>",                        "<r/><s/>",                  "</r>",                       "<r>text",                   "text<r/>",
        "<r a=1/>",                                    "<r a='x' a='y'/>",                        "<r a='x'b='y'/>",                             "<r a='<'/>",                                                  "<r/ >",                          "<r></r x>",                 "<r>&unknown;</r>",           "<r>&#0;</r>",               "<r>&#xD800;</r>",
        "<r>&#x110000;</r>",                           "<r>&#99999999999999999999;</r>",          "<r>&#;</r>",                                  "<r>&#x;</r>",                                                 "<r>&#X20;</r>",                  "<r>&#-1;</r>",              "<r>&amp</r>",                "<r>]]></r>",                "<r>\x01</r>",
        "<r>\xc0\x80</r>",                             "<r>\xef\xbf\xbe</r>",                     "<r>\xc2&#128;</r>",                           "<r>\xc2</r>",                                                 "<!--bad--comment--><r/>",        "<!--bad---><r/>",           "<!--<r/>",                   "<![CDATA[x]]><r/>",         "<!DOCTYPE r><r/>",
        "<!ENTITY x SYSTEM 'file:///private'><r/>",    "<r xmlns='u'/>",                          "<x:r/>",                                      "<r x:a='v'/>",                                                "<?xml?><r/>",                    "<?XML version='1.0'?><r/>", " <?xml version='1.0'?><r/>", "<?xml version='1.1'?><r/>", "<?xml encoding='UTF-8' version='1.0'?><r/>",
        "<?xml version='1.0' encoding='latin1'?><r/>", "<?xml version='1.0' version='1.0'?><r/>", "<?xml version='1.0' standalone='true'?><r/>", "<?xml version='1.0' standalone='yes' encoding='UTF-8'?><r/>", "<?p?><r/><?xml version='1.0'?>", "\xef\xbb\xbf<r/>",
        "<é/>",
        "<r><!bogus></r>",                             "<r a='unterminated>",                     "<?p data><r/>",
    };
    for (invalid) |input| for ([_]usize{ 1, 2, 64 }) |chunk| {
        var storage: Storage = .{};
        var parser = try Xml.init(try Profile.descriptor(.xml, limits), 1, storage.workspace());
        if (finish(&parser, input, chunk)) |_| {
            std.debug.print("accepted XML: {s}\n", .{input});
            return error.InvalidInputAccepted;
        } else |err| {
            try t.expect(err != error.ParserDidNotComplete);
            try t.expect(parser.failure_offset != null);
            try t.expectError(error.DocumentParserFailed, parser.next("<r/>", true, 1));
        }
    };
}

test "XML workspace and processing budgets refuse without allocation" {
    const Case = struct { field: []const u8, value: u32, input: []const u8, expected: anyerror };
    inline for (.{
        Case{ .field = "input_bytes", .value = 1, .input = "<r/>", .expected = error.DocumentInputLimitExceeded },
        Case{ .field = "expanded_bytes", .value = 1, .input = "<rr/>", .expected = error.DocumentExpansionLimitExceeded },
        Case{ .field = "nodes", .value = 1, .input = "<r><e/></r>", .expected = error.DocumentNodeLimitExceeded },
        Case{ .field = "depth", .value = 1, .input = "<r><e/></r>", .expected = error.DocumentDepthLimitExceeded },
        Case{ .field = "token_bytes", .value = 3, .input = "<r/>", .expected = error.DocumentTokenLimitExceeded },
        Case{ .field = "attributes", .value = 1, .input = "<r a='' b=''/>", .expected = error.DocumentAttributeLimitExceeded },
        Case{ .field = "work", .value = 4, .input = "<r/>", .expected = error.DocumentWorkLimitExceeded },
    }) |case| {
        var storage: Storage = .{};
        var bounded = limits;
        @field(bounded, case.field) = case.value;
        var parser = try Xml.init(try Profile.descriptor(.xml, bounded), 1, storage.workspace());
        try t.expectError(case.expected, finish(&parser, case.input, 1));
        try t.expect(parser.failed);
    }
    var storage: Storage = .{};
    var workspace = storage.workspace();
    workspace.names = workspace.names[0..1];
    try t.expectError(error.DocumentWorkspaceTooSmall, Xml.init(try Profile.descriptor(.xml, limits), 1, workspace));
}

test "XML input cardinality does not grow retained workspace" {
    var storage: Storage = .{};
    var parser = try Xml.init(try Profile.descriptor(.xml, limits), 1, storage.workspace());
    _ = try parser.next("<r>", false, 10);
    for (0..100_000) |_| {
        _ = try parser.next("<e/>", false, 10);
        _ = try parser.next("", false, 10);
    }
    try finish(&parser, "</r>", 1);
    try t.expectEqual(@as(u64, 100_001), parser.budget.nodes);
}
