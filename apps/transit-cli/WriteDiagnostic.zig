//! Owned caller-facing write evidence. Rendering never reads or retries work.
const std = @import("std");
const q = @import("transit_query");
const c = @import("transit_catalog");
const Self = @This();
envelope: q.protocol.Diagnostic,
heading: []const u8,
code: []const u8,
message: [8192]u8 = @splat(0),
length: usize = 0,
next: ?[]const u8 = null,

pub fn tableInput(value: c.TableControl.Disposition, active: bool) !Self {
    const detail = try c.TableDiagnostic.input(value);
    if (detail.outcome != .input_rejected) return error.InvalidConsoleRecovery;
    var result: Self = .{ .envelope = detail, .heading = if (detail.category == .access) "Authorization Error" else "Table Input Error", .code = @tagName(value.outcome) };
    var out: std.Io.Writer = .fixed(&result.message);
    try out.writeAll(detail.message.slice());
    if (active) try out.writeAll("\nThe original operation is still active.");
    result.length = out.end;
    result.next = "Use .status to inspect the original outcome and .resume to reconcile exact saved work. Repeating SQL creates another operation.";
    return result;
}
pub fn tableOutcome(allocator: std.mem.Allocator, intent: *const c.TableIntent, outcome: c.TableClient.Outcome) !?Self {
    const detail = try c.TableDiagnostic.status(intent, outcome);
    if (detail.outcome != .rejected) return null;
    var result: Self = .{ .envelope = detail, .heading = if (detail.category == .constraint) "Constraint Error" else "Table Error", .code = "table_rejected" };
    var out: std.Io.Writer = .fixed(&result.message);
    const key = fact(detail, .key);
    const column = fact(detail, .column);
    if (key != null and key.?.value != null and key.?.value.? == .text and column != null and column.?.value != null and column.?.value.? == .text) {
        try out.writeAll("Duplicate key ");
        var bytes: [512]u8 = undefined;
        const label = try std.fmt.bufPrint(&bytes, "{s}: {s}", .{ column.?.value.?.text.slice(), key.?.value.?.text.slice() });
        try quoted(&out, label);
        if (key.?.availability == .truncated or column.?.availability == .truncated) try out.writeAll(" [truncated]");
        try out.writeAll(" violates the primary key constraint. The statement published no row changes.");
    } else try out.writeAll(detail.message.slice());
    // The name comes from the original immutable caller intent, never from a
    // fresh lookup that could bind a replacement Table after DROP/CREATE.
    var original = try intent.command(allocator);
    defer original.deinit();
    const name = switch (original.body.request) {
        .ddl => |value| value.name.slice(),
        .dml => |value| value.plan.name,
    };
    try out.writeAll("\nTable: ");
    try quoted(&out, name);
    if (key == null) if (column) |entry| if (entry.value) |value| if (value == .text) {
        try out.writeAll("; column: ");
        try quoted(&out, value.text.slice());
    };
    inline for (.{ .{ q.protocol.Diagnostic.Field.input_row, "Input row" }, .{ q.protocol.Diagnostic.Field.source_row, "Source row identity" }, .{ q.protocol.Diagnostic.Field.supplied_value, "Value" }, .{ q.protocol.Diagnostic.Field.expected_type, "Expected type" }, .{ q.protocol.Diagnostic.Field.limit, "Limit (Unicode scalars)" } }) |entry| {
        if (fact(detail, entry[0])) |evidence| {
            if (evidence.value) |value| {
                try out.print("\n{s}: ", .{entry[1]});
                switch (value) {
                    .text => |text| try out.writeAll(text.slice()),
                    .unsigned => |number| try out.writeAll(number.text.slice()),
                    else => return error.InvalidConsoleRecovery,
                }
                if (evidence.availability == .truncated) try out.writeAll(" [truncated]");
            } else if (evidence.availability == .withheld) try out.print("\n{s}: withheld by current read policy", .{entry[1]});
        }
    }
    if (key) |entry| if (entry.availability == .withheld) try out.writeAll("\nConflicting key: withheld by current read policy");
    result.length = out.end;
    return result;
}

fn fact(detail: q.protocol.Diagnostic, field: q.protocol.Diagnostic.Field) ?q.protocol.Diagnostic.Fact {
    for (detail.facts) |entry| if (entry) |value| {
        if (value.field == field) return value;
    };
    return null;
}

fn quoted(out: *std.Io.Writer, value: []const u8) !void {
    try out.writeByte('"');
    for (value) |byte| switch (byte) {
        '"', '\\' => {
            try out.writeByte('\\');
            try out.writeByte(byte);
        },
        0x20...0x21, 0x23...0x5b, 0x5d...0x7e => try out.writeByte(byte),
        else => try out.print("\\x{x:0>2}", .{byte}),
    };
    try out.writeByte('"');
}

pub fn render(self: Self, out: *std.Io.Writer, style: @import("Style.zig")) !void {
    try style.text(out, .failure, self.heading);
    try out.writeAll(":\n");
    try out.writeAll(self.message[0..self.length]);
    try out.writeByte('\n');
    if (self.next) |next| {
        try out.writeByte('\n');
        try style.hint(out, next);
        try out.writeByte('\n');
    }
}
