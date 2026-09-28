//! Bounded declaration grammar; embedded SELECT remains Fuze's responsibility.
const std = @import("std");
const m = @import("Model.zig");
pub const Parsed = struct {
    arena: std.heap.ArenaAllocator,
    definition: m.Definition,
    pub fn deinit(self: *Parsed) void {
        self.arena.deinit();
        self.* = undefined;
    }
};
pub fn parse(gpa: std.mem.Allocator, source: []const u8) !Parsed {
    try m.text(source, m.max_program_bytes);
    var arena = std.heap.ArenaAllocator.init(gpa);
    errdefer arena.deinit();
    var parser: Parser = .{ .allocator = arena.allocator(), .source = source };
    const definition = try parser.program();
    try definition.validate();
    return .{ .arena = arena, .definition = definition };
}
const Value = struct { text: []const u8, integer: bool };
const Option = struct { name: []const u8, value: Value, used: bool = false };
const Options = struct {
    values: [16]Option = undefined,
    length: usize = 0,
    fn take(self: *Options, key: []const u8) !Value {
        for (self.values[0..self.length]) |*item| if (std.mem.eql(u8, item.name, key)) {
            item.used = true;
            return item.value;
        };
        return error.MissingInterfaceOption;
    }
    fn string(self: *Options, key: []const u8) ![]const u8 {
        const value = try self.take(key);
        if (value.integer) return error.InvalidInterfaceOption;
        return value.text;
    }
    fn number(self: *Options, key: []const u8, comptime T: type) !T {
        const value = try self.take(key);
        if (!value.integer or (value.text.len > 1 and value.text[0] == '0')) return error.InvalidInterfaceOption;
        return std.fmt.parseInt(T, value.text, 10) catch error.InvalidInterfaceOption;
    }
    fn enumeration(self: *Options, key: []const u8, comptime T: type) !T {
        return std.meta.stringToEnum(T, try self.string(key)) orelse error.UnsupportedInterfaceOption;
    }
    fn finish(self: *Options) !void {
        for (self.values[0..self.length]) |item| if (!item.used) return error.UnknownInterfaceOption;
    }
};
const Parser = struct {
    allocator: std.mem.Allocator,
    source: []const u8,
    index: usize = 0,
    fn space(self: *Parser) !void {
        while (self.index < self.source.len) {
            if (std.ascii.isWhitespace(self.source[self.index])) {
                self.index += 1;
            } else if (std.mem.startsWith(u8, self.source[self.index..], "--")) {
                while (self.index < self.source.len and self.source[self.index] != '\n') self.index += 1;
            } else if (std.mem.startsWith(u8, self.source[self.index..], "/*")) {
                self.index += 2;
                var depth: usize = 1;
                while (depth > 0) {
                    if (self.index >= self.source.len) return error.UnterminatedInterfaceComment;
                    if (std.mem.startsWith(u8, self.source[self.index..], "/*")) {
                        depth += 1;
                        if (depth > 16) return error.InterfaceCommentDepth;
                        self.index += 2;
                    } else if (std.mem.startsWith(u8, self.source[self.index..], "*/")) {
                        depth -= 1;
                        self.index += 2;
                    } else self.index += 1;
                }
            } else return;
        }
    }
    fn take(self: *Parser, byte: u8) !bool {
        try self.space();
        if (self.index == self.source.len or self.source[self.index] != byte) return false;
        self.index += 1;
        return true;
    }
    fn require(self: *Parser, byte: u8) !void {
        if (!try self.take(byte)) return error.InvalidInterfaceSyntax;
    }
    fn quoted(self: *Parser, quote: u8) ![]const u8 {
        try self.require(quote);
        var result: std.ArrayList(u8) = .empty;
        while (self.index < self.source.len) {
            const byte = self.source[self.index];
            self.index += 1;
            if (byte == quote) {
                if (self.index < self.source.len and self.source[self.index] == quote) self.index += 1 else return result.toOwnedSlice(self.allocator);
            }
            if (result.items.len == 4096) return error.InterfaceLiteralTooLarge;
            try result.append(self.allocator, byte);
        }
        return error.UnterminatedInterfaceLiteral;
    }
    fn name(self: *Parser) ![]const u8 {
        try self.space();
        if (self.index < self.source.len and self.source[self.index] == '"') {
            const value = try self.quoted('"');
            try m.identifier(value);
            return value;
        }
        const start = self.index;
        while (self.index < self.source.len and (std.ascii.isAlphanumeric(self.source[self.index]) or self.source[self.index] == '_')) self.index += 1;
        const value = try self.allocator.dupe(u8, self.source[start..self.index]);
        try m.identifier(value);
        for (value) |*byte| byte.* = std.ascii.toLower(byte.*);
        return value;
    }
    fn word(self: *Parser, expected: []const u8) !void {
        try self.space();
        if (self.index < self.source.len and self.source[self.index] == '"') return error.UnsupportedInterfaceStatement;
        if (!std.ascii.eqlIgnoreCase(try self.name(), expected)) return error.UnsupportedInterfaceStatement;
    }
    fn options(self: *Parser) !Options {
        try self.word("with");
        try self.require('(');
        var result: Options = .{};
        while (true) {
            if (result.length == result.values.len) return error.InterfaceOptionCapacity;
            const key = try self.name();
            for (result.values[0..result.length]) |item| if (std.mem.eql(u8, item.name, key)) return error.DuplicateInterfaceOption;
            try self.require('=');
            try self.space();
            var value: Value = undefined;
            if (self.index < self.source.len and self.source[self.index] == '\'') {
                value = .{ .text = try self.quoted('\''), .integer = false };
            } else {
                const start = self.index;
                while (self.index < self.source.len and std.ascii.isDigit(self.source[self.index])) self.index += 1;
                if (self.index == start) return error.InvalidInterfaceOption;
                value = .{ .text = try self.allocator.dupe(u8, self.source[start..self.index]), .integer = true };
            }
            result.values[result.length] = .{ .name = key, .value = value };
            result.length += 1;
            if (!try self.take(',')) break;
        }
        try self.require(')');
        try self.require(';');
        return result;
    }
    fn program(self: *Parser) !m.Definition {
        try self.word("create");
        try self.word("interface");
        const interface_name = try self.name();
        var initial = try self.options();
        var definition: m.Definition = .{ .name = interface_name, .realm = try initial.number("realm", u64), .revision = .{ .value = try initial.number("revision", u64) }, .components = try initial.number("components", u16), .entry = try initial.string("entry"), .theme = try initial.string("theme"), .themes = &.{}, .screens = &.{}, .bindings = &.{}, .actions = &.{} };
        try initial.finish();
        var themes: std.ArrayList(m.Theme) = .empty;
        var screens: std.ArrayList(m.Screen) = .empty;
        var bindings: std.ArrayList(m.Binding) = .empty;
        var actions: std.ArrayList(m.Action) = .empty;
        while (true) {
            try self.space();
            if (self.index == self.source.len) break;
            try self.word("create");
            if (try self.take('"')) return error.UnsupportedInterfaceStatement;
            const kind = try self.name();
            if (!std.mem.eql(u8, try self.name(), interface_name)) return error.ForeignInterfaceDeclaration;
            try self.require('.');
            const name_value = try self.name();
            var fields = try self.options();
            if (std.mem.eql(u8, kind, "theme")) {
                if (themes.items.len == 2) return error.InterfaceCapacity;
                try themes.append(self.allocator, .{ .name = name_value, .density = try fields.enumeration("density", @FieldType(m.Theme, "density")) });
            } else if (std.mem.eql(u8, kind, "screen")) {
                if (screens.items.len == m.max_members) return error.InterfaceCapacity;
                try screens.append(self.allocator, .{ .name = name_value, .path = try fields.string("path"), .label = try fields.string("label"), .area = try fields.enumeration("area", m.Area), .renderer = try fields.enumeration("renderer", m.Renderer), .binding = try fields.string("binding") });
            } else if (std.mem.eql(u8, kind, "binding")) {
                if (bindings.items.len == m.max_members) return error.InterfaceCapacity;
                const tag = try fields.enumeration("kind", std.meta.Tag(@FieldType(m.Binding, "source")));
                var source: @FieldType(m.Binding, "source") = undefined;
                switch (tag) {
                    .inspection => source = .{ .inspection = .{ .projection = try fields.enumeration("projection", m.Inspection), .page_budget = try fields.number("page_budget", u8) } },
                    .query => {
                        const schema = try fields.string("schema");
                        var digest: [32]u8 = undefined;
                        if (schema.len != 64) return error.InvalidInterfaceSchema;
                        _ = std.fmt.hexToBytes(&digest, schema) catch return error.InvalidInterfaceSchema;
                        const Q = @FieldType(@FieldType(m.Binding, "source"), "query");
                        source = .{ .query = .{ .resource = try fields.number("resource", u64), .name = try fields.string("source"), .schema = digest, .profile = try fields.enumeration("profile", @FieldType(Q, "profile")), .sql = try fields.string("query"), .refresh = try fields.enumeration("refresh", m.Refresh), .starts = try fields.number("starts", u8) } };
                    },
                    .command => source = .{ .command = .{ .service = try fields.number("service", u64), .target = try fields.number("target", u64), .revision = try fields.number("revision", u64), .codec = try fields.number("codec", u16) } },
                }
                try bindings.append(self.allocator, .{ .name = name_value, .source = source });
            } else if (std.mem.eql(u8, kind, "action")) {
                if (actions.items.len == m.max_members) return error.InterfaceCapacity;
                const tag = try fields.enumeration("kind", std.meta.Tag(@FieldType(m.Action, "target")));
                const target = try fields.string("target");
                const selected: @FieldType(m.Action, "target") = switch (tag) {
                    .navigate => .{ .navigate = target },
                    .command => .{ .command = target },
                    .follow => .{ .follow = target },
                };
                try actions.append(self.allocator, .{ .name = name_value, .label = try fields.string("label"), .target = selected });
            } else return error.UnsupportedInterfaceStatement;
            try fields.finish();
        }
        definition.themes = try themes.toOwnedSlice(self.allocator);
        definition.screens = try screens.toOwnedSlice(self.allocator);
        definition.bindings = try bindings.toOwnedSlice(self.allocator);
        definition.actions = try actions.toOwnedSlice(self.allocator);
        return definition;
    }
};
fn quoted(out: *std.Io.Writer, value: []const u8, quote: u8) !void {
    try out.writeByte(quote);
    for (value) |byte| {
        try out.writeByte(byte);
        if (byte == quote) try out.writeByte(byte);
    }
    try out.writeByte(quote);
}
fn prefix(out: *std.Io.Writer, kind: []const u8, application: []const u8, name: []const u8) !void {
    try out.print("CREATE {s} ", .{kind});
    try quoted(out, application, '"');
    try out.writeByte('.');
    try quoted(out, name, '"');
    try out.writeAll(" WITH (");
}
fn option(out: *std.Io.Writer, name: []const u8, value: []const u8) !void {
    try out.print("{s} = ", .{name});
    try quoted(out, value, '\'');
}
pub fn format(value: m.Definition, out: *std.Io.Writer) !void {
    try value.validate();
    try out.writeAll("CREATE INTERFACE ");
    try quoted(out, value.name, '"');
    try out.print(" WITH (realm = {d}, revision = {d}, components = {d}, ", .{ value.realm, value.revision.value, value.components });
    try option(out, "entry", value.entry);
    try out.writeAll(", ");
    try option(out, "theme", value.theme);
    try out.writeAll(");\n");
    for (value.themes) |item| {
        try prefix(out, "THEME", value.name, item.name);
        try option(out, "density", @tagName(item.density));
        try out.writeAll(");\n");
    }
    for (value.bindings) |item| {
        try prefix(out, "BINDING", value.name, item.name);
        try option(out, "kind", @tagName(item.source));
        try out.writeAll(", ");
        switch (item.source) {
            .inspection => |binding| {
                try option(out, "projection", @tagName(binding.projection));
                try out.print(", page_budget = {d}", .{binding.page_budget});
            },
            .query => |binding| {
                try out.print("resource = {d}, ", .{binding.resource});
                try option(out, "source", binding.name);
                try out.writeAll(", ");
                try option(out, "schema", &std.fmt.bytesToHex(binding.schema, .lower));
                try out.writeAll(", ");
                try option(out, "profile", @tagName(binding.profile));
                try out.writeAll(", ");
                try option(out, "query", binding.sql);
                try out.writeAll(", ");
                try option(out, "refresh", @tagName(binding.refresh));
                try out.print(", starts = {d}", .{binding.starts});
            },
            .command => |binding| try out.print("service = {d}, target = {d}, revision = {d}, codec = {d}", .{ binding.service, binding.target, binding.revision, binding.codec }),
        }
        try out.writeAll(");\n");
    }
    for (value.screens) |item| {
        try prefix(out, "SCREEN", value.name, item.name);
        try option(out, "path", item.path);
        try out.writeAll(", ");
        try option(out, "label", item.label);
        try out.writeAll(", ");
        try option(out, "area", @tagName(item.area));
        try out.writeAll(", ");
        try option(out, "renderer", @tagName(item.renderer));
        try out.writeAll(", ");
        try option(out, "binding", item.binding);
        try out.writeAll(");\n");
    }
    for (value.actions) |item| {
        try prefix(out, "ACTION", value.name, item.name);
        try option(out, "label", item.label);
        try out.writeAll(", ");
        try option(out, "kind", @tagName(item.target));
        try out.writeAll(", ");
        switch (item.target) {
            inline else => |target| try option(out, "target", target),
        }
        try out.writeAll(");\n");
    }
}
