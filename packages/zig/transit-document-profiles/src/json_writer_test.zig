const std = @import("std");
const t = std.testing;
const Profile = @import("Profile.zig");
const Writer = @import("JsonWriter.zig");
const Json = @import("Json.zig");
const limits = @import("json_test.zig").limits;

fn collect(writer: *Writer, output: []u8, used: *usize, window: usize) !void {
    while (writer.needsDrain()) {
        const end = @min(output.len, used.* + window);
        used.* += try writer.drain(output[used.*..end], 3);
    }
}

test "JSON construction preserves duplicate ordering exact numbers and UTF-8" {
    const tokens = [_]Writer.Token{ .object_start, .{ .key = "a" }, .array_start, .{ .number = "1.2300e+021" }, .{ .number = "9007199254740993" }, .{ .number = "-0" }, .array_end, .{ .key = "a" }, .{ .string = "a\x00\n\"\\é🙂" }, .{ .key = "z" }, .{ .boolean = false }, .object_end };
    const expected = "{\"a\":[1.2300e+021,9007199254740993,-0],\"a\":\"a\\u0000\\u000a\\\"\\\\é🙂\",\"z\":false}";
    for (1..10) |window| {
        var frames: [32]Writer.Frame = undefined;
        var writer = try Writer.init(try Profile.descriptor(.json, limits), 9, &frames);
        var output: [512]u8 = undefined;
        var used: usize = 0;
        for (tokens) |token| {
            try writer.begin(token);
            try collect(&writer, &output, &used, window);
        }
        const part = try writer.finish();
        try part.requireExact();
        try t.expectEqualStrings(expected, output[0..used]);
        try t.expectEqual(@as(u64, expected.len), part.bytes);
        try t.expectEqual(Profile.grammar(expected).sha256, part.sha256);
        try t.expectEqualDeep(part, try writer.finish());
        try t.expectError(error.DocumentWriterComplete, writer.begin(.null_value));
    }
}

test "JSON event re-encoding drains borrowed parser data before advancing" {
    const input = " { \"é\": [true, null, \"\\ud834\\udd1e\", \"x\\t\\b\\f\\r\"], \"é\": -0.00E-9999 } ";
    const expected = "{\"é\":[true,null,\"𝄞\",\"x\\u0009\\u0008\\u000c\\u000d\"],\"é\":-0.00E-9999}";
    for (1..input.len + 1) |chunk| {
        var parser_frames: [32]Json.Frame = undefined;
        var token: [256]u8 = undefined;
        var writer_frames: [32]Writer.Frame = undefined;
        const descriptor = try Profile.descriptor(.json, limits);
        var parser = try Json.init(descriptor, 1, &parser_frames, &token);
        var writer = try Writer.init(descriptor, 2, &writer_frames);
        var output: [512]u8 = undefined;
        var used: usize = 0;
        var offset: usize = 0;
        while (true) {
            const end = @min(input.len, offset + chunk);
            const step = try parser.next(input[offset..end], end == input.len, 7);
            offset += step.consumed;
            switch (step.result) {
                .event => |event| {
                    try writer.beginEvent(event);
                    try collect(&writer, &output, &used, 1);
                },
                .complete => break,
                else => {},
            }
        }
        _ = try writer.finish();
        try t.expectEqualStrings(expected, output[0..used]);
    }
}

test "JSON construction refuses invalid tokens structure and incomplete roots" {
    var frames: [32]Writer.Frame = undefined;
    const descriptor = try Profile.descriptor(.json, limits);
    for ([_][]const u8{ "", "+1", "01", "1.", "1e+", "NaN", "Infinity", "1 2", "--1" }) |number| {
        var writer = try Writer.init(descriptor, 1, &frames);
        try t.expectError(error.InvalidJsonNumber, writer.begin(.{ .number = number }));
        try t.expectError(error.DocumentWriterFailed, writer.finish());
    }
    for ([_][]const u8{ "\xc0\x80", "\xed\xa0\x80", "\xf4\x90\x80\x80", "\xc2" }) |invalid| {
        var writer = try Writer.init(descriptor, 1, &frames);
        try t.expectError(error.InvalidDocumentUtf8, writer.begin(.{ .string = invalid }));
    }
    for ([_]Writer.Token{ .object_end, .array_end, .{ .key = "a" } }) |invalid| {
        var writer = try Writer.init(descriptor, 1, &frames);
        try t.expectError(error.InvalidJsonSyntax, writer.begin(invalid));
    }
    var output: [100]u8 = undefined;
    var writer = try Writer.init(descriptor, 1, &frames);
    try writer.begin(.object_start);
    _ = try writer.drain(&output, 100);
    try writer.begin(.{ .key = "a" });
    _ = try writer.drain(&output, 100);
    try t.expectError(error.InvalidJsonSyntax, writer.begin(.object_end));
    writer = try Writer.init(descriptor, 1, &frames);
    try writer.begin(.array_start);
    _ = try writer.drain(&output, 100);
    try t.expectError(error.InvalidJsonSyntax, writer.begin(.object_end));
    writer = try Writer.init(descriptor, 1, &frames);
    try t.expectError(error.IncompleteDocumentFrame, writer.finish());
    writer = try Writer.init(descriptor, 1, &frames);
    try writer.begin(.null_value);
    _ = try writer.drain(&output, 100);
    try t.expectError(error.TrailingDocumentBytes, writer.begin(.null_value));
}

test "JSON output ownership busy errors and each resource bound" {
    var frames: [32]Writer.Frame = undefined;
    var writer = try Writer.init(try Profile.descriptor(.json, limits), 1, &frames);
    var token: [2]u8 = .{ 'a', 'b' };
    try writer.begin(.{ .string = &token });
    try t.expectError(error.DocumentWriterBusy, writer.begin(.null_value));
    try t.expectError(error.DocumentWriterBusy, writer.finish());
    try t.expectError(error.InvalidDocumentWorkBudget, writer.drain(&.{}, 1));
    var output: [100]u8 = undefined;
    var used: usize = 0;
    try collect(&writer, &output, &used, 1);
    @memset(&token, 'x');
    try t.expectEqualStrings("\"ab\"", output[0..used]);
    try t.expectEqual(Profile.grammar("\"ab\"").sha256, (try writer.finish()).sha256);
    const Case = struct { field: []const u8, value: u64, expected: anyerror };
    inline for (.{
        Case{ .field = "token_bytes", .value = 1, .expected = error.DocumentTokenLimitExceeded },
        Case{ .field = "expanded_bytes", .value = 1, .expected = error.DocumentExpansionLimitExceeded },
        Case{ .field = "input_bytes", .value = 3, .expected = error.DocumentInputLimitExceeded },
        Case{ .field = "work", .value = 2, .expected = error.DocumentWorkLimitExceeded },
    }) |case| {
        var bounded = limits;
        @field(bounded, case.field) = @intCast(case.value);
        writer = try Writer.init(try Profile.descriptor(.json, bounded), 1, &frames);
        try t.expectError(case.expected, writer.begin(.{ .string = "ab" }));
        try t.expectError(error.DocumentWriterFailed, writer.finish());
    }
    var bounded = limits;
    bounded.depth = 1;
    writer = try Writer.init(try Profile.descriptor(.json, bounded), 1, &frames);
    try writer.begin(.array_start);
    _ = try writer.drain(&output, 10);
    try t.expectError(error.DocumentDepthLimitExceeded, writer.begin(.array_start));
    bounded = limits;
    bounded.nodes = 1;
    writer = try Writer.init(try Profile.descriptor(.json, bounded), 1, &frames);
    try writer.begin(.array_start);
    _ = try writer.drain(&output, 10);
    try t.expectError(error.DocumentNodeLimitExceeded, writer.begin(.null_value));
    bounded = limits;
    bounded.work = 5;
    writer = try Writer.init(try Profile.descriptor(.json, bounded), 1, &frames);
    try writer.begin(.null_value);
    try t.expectError(error.DocumentWorkLimitExceeded, writer.drain(&output, 10));
}

test "JSON construction streams large arrays with fixed depth workspace" {
    var frames: [32]Writer.Frame = undefined;
    var writer = try Writer.init(try Profile.descriptor(.json, limits), 1, &frames);
    var output: [7]u8 = undefined;
    var bytes: u64 = 0;
    try writer.begin(.array_start);
    bytes += try writer.drain(&output, 1);
    for (0..100_000) |_| {
        try writer.begin(.{ .number = "123" });
        while (writer.needsDrain()) bytes += try writer.drain(&output, 2);
    }
    try writer.begin(.array_end);
    bytes += try writer.drain(&output, 1);
    try t.expectEqual(@as(u64, 400_001), bytes);
    try t.expectEqual(bytes, (try writer.finish()).bytes);
}
