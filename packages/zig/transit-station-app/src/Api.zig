//! The public declaration schema is reflected from the owning Zig types.
const std = @import("std");
const root = @import("root.zig");
const m = root.Model;
pub fn schema(writer: *std.Io.Writer) !void {
    var out: std.json.Stringify = .{ .writer = writer, .options = .{ .whitespace = .indent_2 } };
    try out.beginObject();
    try root.protocol.Schema.field(&out, "$schema", "https://json-schema.org/draft/2020-12/schema");
    try root.protocol.Schema.field(&out, "$id", "urn:transit:application:v1");
    try root.protocol.Schema.field(&out, "$ref", "#/$defs/Definition");
    try out.objectField("$defs");
    try out.beginObject();
    inline for (.{ "Definition", "Theme", "Screen", "Binding", "Action" }) |name| {
        try out.objectField(name);
        try root.protocol.Schema.write(@field(m, name), &out, .{ .safe_integers = true, .sequence_max_length = m.max_members });
    }
    inline for (.{ "Configuration", "Policy", "Proposal", "Receipt", "Head" }) |name| {
        try out.objectField(name);
        try root.protocol.Schema.write(@field(root.Publication, name), &out, .{ .safe_integers = true });
    }
    try out.objectField("Command");
    try root.protocol.Schema.write(root.Request.Command, &out, .{ .safe_integers = true });
    inline for (.{ "Scope", "Prepared", "Signed", "PreparedRead", "SignedRead", "Observation" }) |name| {
        try out.objectField(name);
        try root.protocol.Schema.write(@field(root.Native, name), &out, .{ .safe_integers = true });
    }
    inline for (.{ "Request", "Response", "Compiled" }) |name| {
        try out.objectField(if (std.mem.eql(u8, name, "Compiled")) name else "Host" ++ name);
        try root.protocol.Schema.write(@field(root.Host, name), &out, .{ .safe_integers = true, .sequence_max_length = m.max_members });
    }
    try out.endObject();
    try out.endObject();
    try writer.writeByte('\n');
}

/// Validate the whole definition and its canonical encoded size before exposure.
/// Caller owns both the parsed model and the bounded output buffer.
pub fn canonical(definition: m.Definition, buffer: *[m.max_program_bytes]u8) ![]const u8 {
    var out: std.Io.Writer = .fixed(buffer);
    root.Sql.format(definition, &out) catch |err| switch (err) {
        error.WriteFailed => return error.InterfaceProgramTooLarge,
        else => return err,
    };
    return out.buffered();
}
