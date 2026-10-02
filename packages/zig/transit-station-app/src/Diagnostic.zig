//! Owned offline declaration context. Never includes option values or credentials.
const std = @import("std");
const Self = @This();
stage: enum { command, input, parse, validate, output } = .command,
offset: ?usize = null,
line: usize = 1,
column: usize = 1,
kind: []const u8 = "interface",
member: [64]u8 = @splat(0),
member_len: usize = 0,
option: [64]u8 = @splat(0),
option_len: usize = 0,
expected: ?[]const u8 = null,
sql: ?@import("root.zig").serving.query.fuze.SqlDiagnostic = null,
reference: [64]u8 = @splat(0),
reference_len: usize = 0,

pub fn subject(self: ?*Self, kind: []const u8, name: []const u8) void {
    const detail = self orelse return;
    // Kind may be a parsed token: keep only known static vocabulary.
    detail.kind = if (std.mem.eql(u8, kind, "screen")) "screen" else if (std.mem.eql(u8, kind, "binding")) "binding" else if (std.mem.eql(u8, kind, "action")) "action" else if (std.mem.eql(u8, kind, "theme")) "theme" else "interface";
    detail.member_len = @min(name.len, detail.member.len);
    @memcpy(detail.member[0..detail.member_len], name[0..detail.member_len]);
    detail.option_len = 0;
    detail.offset = null;
    detail.expected = null;
    detail.reference_len = 0;
    detail.sql = null;
}
pub fn target(self: ?*Self, value: []const u8) void {
    const detail = self orelse return;
    detail.reference_len = @min(value.len, detail.reference.len);
    @memcpy(detail.reference[0..detail.reference_len], value[0..detail.reference_len]);
}
pub fn field(self: ?*Self, name: []const u8, offset: ?usize) void {
    const detail = self orelse return;
    detail.option_len = @min(name.len, detail.option.len);
    @memcpy(detail.option[0..detail.option_len], name[0..detail.option_len]);
    detail.offset = offset;
    detail.expected = null;
}
pub fn locate(self: *Self, source: []const u8) void {
    const offset = self.offset orelse return;
    self.line = 1;
    self.column = 1;
    for (source[0..@min(offset, source.len)]) |byte| {
        if (byte == '\n') {
            self.line += 1;
            self.column = 1;
        } else self.column += 1;
    }
}
pub fn render(self: Self, out: *std.Io.Writer, cause: anyerror) !void {
    try out.print("Application Declaration Error:\n{s} ({s})\nStage: {s}", .{ explanation(cause), @errorName(cause), @tagName(self.stage) });
    if (self.member_len != 0) {
        try out.print("; {s}: ", .{self.kind});
        try quoted(out, self.member[0..self.member_len]);
    }
    if (self.option_len != 0) {
        try out.writeAll("; option: ");
        try quoted(out, self.option[0..self.option_len]);
    }
    if (self.offset != null) try out.print("; line {d}, byte column {d}", .{ self.line, self.column });
    try out.writeAll(".\n");
    if (self.reference_len != 0) {
        try out.writeAll("Referenced name: ");
        try quoted(out, self.reference[0..self.reference_len]);
        try out.writeAll(".\n");
    }
    if (self.expected) |expected| try out.print("Expected {s}.\n", .{expected});
    if (self.sql) |nested| {
        try out.writeAll("Embedded SELECT (coordinates within the binding SQL):\n");
        try nested.render(out);
    }
    try out.writeAll("No application was published. ");
    try out.writeAll(switch (self.stage) {
        .command => "Usage: transit-app parse|format|module FILE, or transit-app schema.\n",
        .input => "Check the input file and its access permissions.\n",
        .parse, .validate => "Correct the declaration and compile it again.\n",
        .output => "Any emitted output is incomplete; correct the output failure before compiling again.\n",
    });
}
fn explanation(cause: anyerror) []const u8 {
    return switch (cause) {
        error.MissingInterfaceOption => "A required declaration option is missing.",
        error.DuplicateInterfaceOption => "The declaration repeats an option.",
        error.UnknownInterfaceOption => "This declaration does not accept that option.",
        error.InvalidInterfaceOption => "The option has the wrong type or is outside its numeric range.",
        error.UnsupportedInterfaceOption => "The option value is unsupported for this declaration.",
        error.MissingInterfaceReference => "A referenced theme, screen or binding is not declared.",
        error.ForeignInterfaceDeclaration => "The member belongs to a different interface.",
        error.DuplicateInterfaceName => "Two declarations use the same member name.",
        error.DuplicateInterfacePath => "Two screens use the same path.",
        error.IncompatibleRenderer => "The screen renderer is incompatible with its binding.",
        error.IncompatibleAction => "The action requires a different binding or screen kind.",
        error.UnsupportedInterfaceWatch => "Follow queries require the unified_v1 Table query profile.",
        error.InvalidQueryBudget => "Query starts must be 1 through 8; snapshot refresh requires exactly 1.",
        error.UnsupportedInspectionBudget => "Inspection bindings require a page budget of 1.",
        error.UnsupportedInterfaceVersion => "The declaration requires version 1 and components 1.",
        error.InterfaceCapacity => "The interface requires 1–2 themes, 1–16 screens, and at most 16 bindings and actions.",
        error.InterfaceOptionCapacity => "A declaration accepts at most 16 options.",
        error.InterfaceLiteralTooLarge => "A declaration literal exceeds 4096 bytes.",
        error.InterfaceCommentDepth => "A declaration comment exceeds 16 nesting levels.",
        error.UnterminatedInterfaceComment => "A block comment is missing its closing delimiter.",
        error.UnterminatedInterfaceLiteral => "A quoted literal is missing its closing quote.",
        error.UnsupportedInterfaceStatement => "The offline compiler expects CREATE INTERFACE and its supported member declarations.",
        error.InvalidInterfaceSyntax => "A required declaration delimiter is missing.",
        error.InvalidInterfaceName => "A name must start with an ASCII letter or underscore and contain only letters, digits or underscores (at most 64 bytes).",
        error.InvalidInterfaceSchema => "The schema digest must contain exactly 64 hexadecimal digits.",
        error.InvalidInterfaceIdentity => "A realm, resource, service, target or command revision must be between 1 and 9007199254740991.",
        error.InvalidInterfaceRevision => "The interface revision must be greater than zero.",
        error.InvalidInterfacePath => "A screen path must start with '/', contain only ASCII letters, digits, '/', '-' or '_', and contain no empty or parent segments.",
        error.ReservedInterfacePath => "This path is reserved for an application host endpoint.",
        error.InvalidInterfaceText => "Text must be nonempty, valid UTF-8, contain no NUL and fit the field's byte limit.",
        error.InvalidInterfaceCommand => "A command binding requires a nonzero codec.",
        error.UsageExpectedParseOrFormatAndFile, error.UnknownApplicationCommand => "The offline compiler command or arguments are invalid.",
        error.FileNotFound => "The input file does not exist.",
        error.AccessDenied => "Access to the input or output was denied.",
        error.StreamTooLong => "The input exceeds the 65536-byte declaration limit.",
        error.OutOfMemory => "The compiler could not allocate memory.",
        error.WriteFailed, error.BrokenPipe => "The compiler could not complete its output.",
        else => "The declaration failed validation; inspect its cause and member context.",
    };
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
