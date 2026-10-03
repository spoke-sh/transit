//! Owned offline declaration context. Never includes option values or credentials.
const std = @import("std");
const d = @import("root.zig").protocol.Diagnostic;
const Self = @This();
format: enum { human, json } = .human,
file: ?d.SourcePath = null,
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

pub fn reset(self: *Self, stage: @FieldType(Self, "stage")) void {
    self.* = .{ .stage = stage, .format = self.format, .file = self.file };
}

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
        error.InterfaceProgramTooLarge => "The canonical declaration exceeds the 65536-byte program limit.",
        error.SyntaxError, error.UnexpectedEndOfInput, error.UnexpectedToken => "The input is not valid declaration JSON.",
        error.UnknownField => "The JSON contains a field outside the declaration schema.",
        error.DuplicateField => "The JSON repeats a declaration field.",
        error.MissingField => "The JSON omits a required declaration field.",
        error.InvalidCharacter, error.InvalidNumber, error.Overflow => "A JSON value has an invalid canonical representation or is outside its declared range.",
        error.InvalidJsonShape => "A JSON field has the wrong structural type or an unsupported enum value.",
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

pub fn structured(self: Self, cause: anyerror) !d {
    const stage: d.Stage = switch (self.stage) {
        .command => .input,
        .input => .read,
        .parse => .parse,
        .validate => .bind,
        .output => .output,
    };
    const info = classification(cause);
    var result = if (self.sql) |nested| try nested.structured() else try d.init(info.code, info.category, stage, .not_submitted, .local_before_dispatch, if (info.category == .internal) "The offline compiler could not complete this operation. Preserve its cause and input context for inspection. No application was published." else explanation(cause));
    if (self.sql == null) result.cause = try d.Code.init(@errorName(cause));
    // Nested SELECT offsets belong to that decoded SQL string, not to the
    // enclosing declaration (whose quoting can change byte lengths).
    if (self.sql != null) {
        if (result.location) |location| try result.fact(.expression, .caller, .{ .location = location });
        result.location = null;
    }
    if (self.offset) |offset| {
        result.location = .{ .offset = .init(offset), .length = .init(0), .line = .init(self.line), .byte_column = .init(self.column) };
        if (self.file) |file| file.apply(&result.location.?);
    } else if (self.file) |file| {
        var length: usize = @min(file.path.slice().len, 256);
        if (file.encoding == .escaped_bytes) {
            var index: usize = 0;
            while (index < length) {
                const size: usize = if (file.path.slice()[index] == '\\') 4 else 1;
                if (index + size > length) {
                    length = index;
                    break;
                }
                index += size;
            }
        }
        const path = if (file.encoding == .utf8) try d.Text.truncate(file.path.slice()) else try d.Text.init(file.path.slice()[0..length]);
        try result.add(.{ .field = .object, .origin = .caller, .availability = if (file.truncated or path.slice().len != file.path.slice().len) .truncated else .provided, .value = .{ .text = path } });
        try result.text(.source_kind, .caller, if (file.encoding == .escaped_bytes) "file/escaped_bytes" else "file/utf8");
    }
    if (self.member_len != 0) try result.text(.name, .caller, self.member[0..self.member_len]);
    if (self.option_len != 0) try result.text(.option, .caller, self.option[0..self.option_len]);
    if (self.reference_len != 0) try result.text(.scope, .caller, self.reference[0..self.reference_len]);
    if (self.expected) |expected| try result.text(.expected_type, .schema, expected);
    if (self.stage == .output) try result.fact(.completion, .execution, .{ .boolean = false });
    if (result.actions[0] == null) try result.action(switch (info.category) {
        .internal, .integrity => .contact_operator,
        .access => .inspect_scope,
        else => .correct_input,
    });
    try result.validate();
    return result;
}
const Classification = struct { code: []const u8, category: d.Category };
fn classification(cause: anyerror) Classification {
    return switch (cause) {
        error.MissingInterfaceOption => .{ .code = "application.missing_interface_option", .category = .binding },
        error.DuplicateInterfaceOption => .{ .code = "application.duplicate_interface_option", .category = .binding },
        error.UnknownInterfaceOption => .{ .code = "application.unknown_interface_option", .category = .binding },
        error.InvalidInterfaceOption => .{ .code = "application.invalid_interface_option", .category = .binding },
        error.UnsupportedInterfaceOption => .{ .code = "application.unsupported_interface_option", .category = .unsupported },
        error.MissingInterfaceReference => .{ .code = "application.missing_interface_reference", .category = .binding },
        error.ForeignInterfaceDeclaration => .{ .code = "application.foreign_interface_declaration", .category = .binding },
        error.DuplicateInterfaceName => .{ .code = "application.duplicate_interface_name", .category = .binding },
        error.DuplicateInterfacePath => .{ .code = "application.duplicate_interface_path", .category = .binding },
        error.IncompatibleRenderer => .{ .code = "application.incompatible_renderer", .category = .binding },
        error.IncompatibleAction => .{ .code = "application.incompatible_action", .category = .binding },
        error.UnsupportedInterfaceWatch => .{ .code = "application.unsupported_interface_watch", .category = .unsupported },
        error.InvalidQueryBudget => .{ .code = "application.invalid_query_budget", .category = .binding },
        error.UnsupportedInspectionBudget => .{ .code = "application.unsupported_inspection_budget", .category = .unsupported },
        error.UnsupportedInterfaceVersion => .{ .code = "application.unsupported_interface_version", .category = .unsupported },
        error.InterfaceCapacity => .{ .code = "application.interface_capacity", .category = .limit },
        error.InterfaceOptionCapacity => .{ .code = "application.interface_option_capacity", .category = .limit },
        error.InterfaceLiteralTooLarge => .{ .code = "application.interface_literal_too_large", .category = .limit },
        error.InterfaceCommentDepth => .{ .code = "application.interface_comment_depth", .category = .limit },
        error.UnterminatedInterfaceComment => .{ .code = "application.unterminated_interface_comment", .category = .syntax },
        error.UnterminatedInterfaceLiteral => .{ .code = "application.unterminated_interface_literal", .category = .syntax },
        error.UnsupportedInterfaceStatement => .{ .code = "application.unsupported_interface_statement", .category = .unsupported },
        error.InvalidInterfaceSyntax => .{ .code = "application.invalid_interface_syntax", .category = .syntax },
        error.InvalidInterfaceName => .{ .code = "application.invalid_interface_name", .category = .binding },
        error.InvalidInterfaceSchema => .{ .code = "application.invalid_interface_schema", .category = .binding },
        error.InvalidInterfaceIdentity => .{ .code = "application.invalid_interface_identity", .category = .binding },
        error.InvalidInterfaceRevision => .{ .code = "application.invalid_interface_revision", .category = .binding },
        error.InvalidInterfacePath => .{ .code = "application.invalid_interface_path", .category = .binding },
        error.ReservedInterfacePath => .{ .code = "application.reserved_interface_path", .category = .unsupported },
        error.InvalidInterfaceText => .{ .code = "application.invalid_interface_text", .category = .binding },
        error.InvalidInterfaceCommand => .{ .code = "application.invalid_interface_command", .category = .binding },
        error.UsageExpectedParseOrFormatAndFile => .{ .code = "application.usage_expected_parse_or_format_and_file", .category = .syntax },
        error.UnknownApplicationCommand => .{ .code = "application.unknown_application_command", .category = .syntax },
        error.FileNotFound => .{ .code = "application.file_not_found", .category = .unavailable },
        error.AccessDenied => .{ .code = "application.access_denied", .category = .access },
        error.StreamTooLong => .{ .code = "application.stream_too_long", .category = .limit },
        error.OutOfMemory => .{ .code = "application.out_of_memory", .category = .unavailable },
        error.WriteFailed => .{ .code = "application.write_failed", .category = .unavailable },
        error.BrokenPipe => .{ .code = "application.broken_pipe", .category = .unavailable },
        error.InterfaceProgramTooLarge => .{ .code = "application.program_too_large", .category = .limit },
        error.SyntaxError, error.UnexpectedEndOfInput, error.UnexpectedToken => .{ .code = "application.invalid_json", .category = .syntax },
        error.UnknownField => .{ .code = "application.unknown_json_field", .category = .binding },
        error.DuplicateField => .{ .code = "application.duplicate_json_field", .category = .syntax },
        error.MissingField => .{ .code = "application.missing_json_field", .category = .binding },
        error.InvalidCharacter, error.InvalidNumber, error.Overflow => .{ .code = "application.invalid_json_value", .category = .binding },
        error.InvalidJsonShape => .{ .code = "application.invalid_json_shape", .category = .binding },
        else => .{ .code = "application.internal_failure", .category = .internal },
    };
}
