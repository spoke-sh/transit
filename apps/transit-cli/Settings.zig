//! Bounded configuration input. YAML is a data-only mapping/sequence subset.
const std = @import("std");
const Diagnostic = @import("Diagnostic.zig");
pub const Value = std.json.Value;
pub const max_bytes = 65536;

pub fn readTyped(comptime T: type, init: std.process.Init, name: []const u8, diagnostic: *Diagnostic) !T {
    if (std.mem.endsWith(u8, name, ".json")) return diagnostic.readJson(T, init, name, max_bytes);
    const value = try read(init, name, diagnostic);
    // Use the same token decoder as JSON so native custom codecs (for example
    // initialization frames encoded as hex strings) retain their exact contract.
    const bytes = try std.json.Stringify.valueAlloc(init.arena.allocator(), value, .{});
    return std.json.parseFromSliceLeaky(T, init.arena.allocator(), bytes, .{ .allocate = .alloc_always }) catch |err|
        diagnostic.invalidFieldCause(err, "configuration", "contains an invalid or missing field", null);
}

/// Human configuration defaults to YAML; explicit .json exports stay compatible.
pub fn write(init: std.process.Init, name: []const u8, value: anytype) !void {
    const Files = @import("server/Files.zig");
    if (std.mem.endsWith(u8, name, ".json")) return Files.json(init.io, init.gpa, name, value);
    var arena: std.heap.ArenaAllocator = .init(init.gpa);
    defer arena.deinit();
    const allocator = arena.allocator();
    const encoded = try std.json.Stringify.valueAlloc(allocator, value, .{});
    if (encoded.len > max_bytes) return error.ConfigurationTooLarge;
    const tree = try jsonValue(allocator, encoded);
    const buffer = try allocator.alloc(u8, max_bytes);
    var output: std.Io.Writer = .fixed(buffer);
    try yaml(&output, tree, 0);
    try Files.write(init.io, name, output.buffered());
}
fn yaml(out: *std.Io.Writer, value: Value, indent: usize) anyerror!void {
    if (value == .object and value.object.count() > 0) {
        var iterator = value.object.iterator();
        while (iterator.next()) |entry| {
            for (entry.key_ptr.*) |c| if (!std.ascii.isAlphanumeric(c) and c != '_') return error.YamlInvalidKey;
            try out.splatByteAll(' ', indent);
            try out.print("{s}:", .{entry.key_ptr.*});
            if (entry.value_ptr.* == .object and entry.value_ptr.object.count() > 0) {
                try out.writeByte('\n');
                try yaml(out, entry.value_ptr.*, indent + 2);
            } else {
                try out.writeByte(' ');
                try std.json.Stringify.value(entry.value_ptr.*, .{ .escape_unicode = true }, out);
                try out.writeByte('\n');
            }
        }
    } else {
        try std.json.Stringify.value(value, .{ .escape_unicode = true }, out);
        try out.writeByte('\n');
    }
}

pub fn object(allocator: std.mem.Allocator) Value {
    _ = allocator;
    return .{ .object = .{} };
}
pub fn merge(allocator: std.mem.Allocator, into: *Value, overlay: Value) !void {
    if (into.* == .object and overlay == .object) {
        var it = overlay.object.iterator();
        while (it.next()) |entry| {
            if (into.object.getPtr(entry.key_ptr.*)) |existing| try merge(allocator, existing, entry.value_ptr.*) else try into.object.put(allocator, entry.key_ptr.*, entry.value_ptr.*);
        }
    } else into.* = overlay;
}
pub fn shape(comptime T: type, allocator: std.mem.Allocator, value: Value, comptime prefix: []const u8, diagnostic: *Diagnostic) anyerror!void {
    switch (@typeInfo(T)) {
        .optional => |info| {
            if (value == .null) return;
            return shape(info.child, allocator, value, prefix, diagnostic);
        },
        .@"struct" => |info| {
            if (value != .object) return diagnostic.invalidField(prefix, "must be an object", null);
            var it = value.object.iterator();
            while (it.next()) |entry| {
                var found = false;
                inline for (info.field_names, info.field_types) |name, field_type| {
                    if (std.mem.eql(u8, name, entry.key_ptr.*)) {
                        found = true;
                        try shape(field_type, allocator, entry.value_ptr.*, if (prefix.len == 0) name else prefix ++ "." ++ name, diagnostic);
                    }
                }
                if (!found) return diagnostic.invalidField(prefix, "contains an unknown field", null);
            }
        },
        else => {
            _ = std.json.parseFromValueLeaky(T, allocator, value, .{}) catch |err| return diagnostic.invalidFieldCause(err, prefix, "has an invalid value", null);
        },
    }
}
pub fn discover(init: std.process.Init, local: []const u8, personal: []const u8, system: []const u8, diagnostic: *Diagnostic) !?[]const u8 {
    const allocator = init.arena.allocator();
    const home = init.environ_map.get("HOME");
    const paths = [_]?[]const u8{ local, if (home) |dir| if (dir.len > 0) try std.fs.path.join(allocator, &.{ dir, personal }) else null else null, system };
    for (paths) |maybe| if (maybe) |name| {
        const file = std.Io.Dir.cwd().openFile(init.io, name, .{}) catch |err| {
            if (err == error.FileNotFound) continue;
            diagnostic.atFile(name);
            return err;
        };
        file.close(init.io);
        return name;
    };
    return null;
}
pub fn read(init: std.process.Init, name: []const u8, diagnostic: *Diagnostic) !Value {
    diagnostic.atFile(name);
    const allocator = init.arena.allocator();
    const bytes = std.Io.Dir.cwd().readFileAlloc(init.io, name, allocator, .limited(max_bytes)) catch |err| {
        diagnostic.configurationFailure(err);
        return error.InvalidConfiguration;
    };
    if (std.mem.endsWith(u8, name, ".json")) {
        boundJson(allocator, bytes) catch |err| switch (err) {
            error.ConfigurationTooDeep, error.ConfigurationTooLarge => return diagnostic.invalidField("configuration", "exceeds the nesting or node limit", null),
            else => {}, // The normal decoder supplies syntax coordinates.
        };
        return diagnostic.readJson(Value, init, name, max_bytes);
    }
    var parser: Yaml = .{ .allocator = allocator, .bytes = bytes };
    return parser.parse() catch |err| {
        diagnostic.line = parser.line;
        diagnostic.column = 1;
        return diagnostic.fail(error.InvalidConfiguration, "invalid or unsupported YAML configuration", @errorName(err));
    };
}

/// Supports block mappings, scalar sequences and JSON flow values. Rejects
/// anchors, tags, merge keys and multiline scalars rather than interpreting them.
pub const Yaml = struct {
    allocator: std.mem.Allocator,
    bytes: []const u8,
    offset: usize = 0,
    line: u64 = 0,
    nodes: usize = 0,
    pending: ?Line = null,
    const Line = struct { indent: usize, text: []const u8 };
    fn next(self: *Yaml) !?Line {
        if (self.pending) |value| {
            self.pending = null;
            return value;
        }
        while (self.offset < self.bytes.len) {
            const start = self.offset;
            self.offset = if (std.mem.indexOfScalarPos(u8, self.bytes, start, '\n')) |end| end + 1 else self.bytes.len;
            self.line += 1;
            const raw = std.mem.trimEnd(u8, self.bytes[start..self.offset], " \r\n");
            const text = std.mem.trimStart(u8, raw, " ");
            if (std.mem.indexOfScalar(u8, text, '\t') != null) return error.YamlTab;
            if (text.len == 0 or text[0] == '#') continue;
            return .{ .indent = raw.len - text.len, .text = text };
        }
        return null;
    }
    pub fn parse(self: *Yaml) !Value {
        if (self.bytes.len > max_bytes) return error.ConfigurationTooLarge;
        const trimmed = std.mem.trim(u8, self.bytes, " \r\n\t");
        if (trimmed.len > 0 and trimmed[0] == '{') return try jsonValue(self.allocator, trimmed);
        const first = try self.next() orelse return object(self.allocator);
        if (first.indent != 0) return error.YamlIndentation;
        self.pending = first;
        const result = try self.block(0, 0);
        if (try self.next() != null) return error.YamlIndentation;
        var nodes: usize = 0;
        try boundedValue(result, 0, &nodes);
        return result;
    }
    fn block(self: *Yaml, indent: usize, depth: usize) anyerror!Value {
        if (depth > 16) return error.ConfigurationTooDeep;
        var result = object(self.allocator);
        var started = false;
        while (try self.next()) |line| {
            if (line.indent < indent) {
                self.pending = line;
                break;
            }
            if (line.indent != indent) return error.YamlIndentation;
            self.nodes += 1;
            if (self.nodes > 2048) return error.ConfigurationTooLarge;
            const sequence = std.mem.startsWith(u8, line.text, "- ") or std.mem.eql(u8, line.text, "-");
            if (!started and sequence) result = .{ .array = std.array_list.Managed(Value).init(self.allocator) };
            started = true;
            if (sequence != (result == .array)) return error.YamlMixedCollection;
            if (sequence) {
                try result.array.append(try self.scalar(std.mem.trim(u8, line.text[1..], " ")));
                continue;
            }
            const colon = std.mem.indexOfScalar(u8, line.text, ':') orelse return error.YamlMappingExpected;
            const key = std.mem.trim(u8, line.text[0..colon], " ");
            if (key.len == 0 or key.len > 128) return error.YamlInvalidKey;
            for (key) |c| if (!std.ascii.isAlphanumeric(c) and c != '_') return error.YamlInvalidKey;
            if (result.object.contains(key)) return error.DuplicateField;
            const tail = std.mem.trim(u8, line.text[colon + 1 ..], " ");
            const value = if (tail.len == 0 or tail[0] == '#') blk: {
                const following = try self.next() orelse break :blk Value.null;
                self.pending = following;
                break :blk if (following.indent > indent) try self.block(following.indent, depth + 1) else Value.null;
            } else try self.scalar(tail);
            try result.object.put(self.allocator, try self.allocator.dupe(u8, key), value);
        }
        return result;
    }
    fn scalar(self: *Yaml, raw: []const u8) !Value {
        if (raw.len == 0) return .null;
        if (raw[0] == '"' or raw[0] == '[' or raw[0] == '{') {
            return try jsonValue(self.allocator, raw);
        }
        if (raw[0] == '\'') {
            var out: std.Io.Writer.Allocating = .init(self.allocator);
            var i: usize = 1;
            while (i < raw.len) : (i += 1) {
                if (raw[i] == '\'') {
                    if (i + 1 < raw.len and raw[i + 1] == '\'') {
                        try out.writer.writeByte('\'');
                        i += 1;
                        continue;
                    }
                    const rest = std.mem.trim(u8, raw[i + 1 ..], " ");
                    if (rest.len > 0 and rest[0] != '#') return error.YamlInvalidScalar;
                    return .{ .string = try out.toOwnedSlice() };
                }
                try out.writer.writeByte(raw[i]);
            }
            return error.YamlInvalidScalar;
        }
        const text = std.mem.trimEnd(u8, if (std.mem.indexOf(u8, raw, " #")) |at| raw[0..at] else raw, " ");
        if (std.mem.indexOfScalar(u8, "&*!|>@`%", text[0]) != null or std.mem.indexOf(u8, text, ": ") != null) return error.YamlUnsupportedScalar;
        if (std.mem.eql(u8, text, "null") or std.mem.eql(u8, text, "~")) return .null;
        if (std.mem.eql(u8, text, "true")) return .{ .bool = true };
        if (std.mem.eql(u8, text, "false")) return .{ .bool = false };
        if (std.fmt.parseInt(i64, text, 10)) |number| return .{ .integer = number } else |_| {}
        return .{ .string = try self.allocator.dupe(u8, text) };
    }
};

pub fn environment(comptime T: type, init: std.process.Init, value: *Value, diagnostic: *Diagnostic) !void {
    const allocator = init.arena.allocator();
    // Whole objects first, then increasingly specific leaves. Enumeration order
    // never decides whether PORTS or PORTS__GATEWAY wins.
    var used: usize = 0;
    var iterator = init.environ_map.iterator();
    while (iterator.next()) |entry| {
        const key = entry.key_ptr.*;
        if (!std.mem.startsWith(u8, key, "TRANSIT_") or std.mem.eql(u8, key, "TRANSIT_CONSOLE_CONFIG")) continue;
        used += key.len + entry.value_ptr.len;
        if (used > max_bytes or key.len > 128) return diagnostic.invalidField("environment", "exceeds the configuration limit", null);
        for (key) |c| if (!(c >= 'A' and c <= 'Z') and !std.ascii.isDigit(c) and c != '_') return diagnostic.invalidField("environment", "contains an invalid TRANSIT_ setting name", null);
        if (std.mem.count(u8, key, "__") > 16) return diagnostic.invalidField("environment", "is nested too deeply", null);
    }
    for (0..17) |depth| {
        iterator = init.environ_map.iterator();
        while (iterator.next()) |entry| {
            const key = entry.key_ptr.*;
            if (!std.mem.startsWith(u8, key, "TRANSIT_") or std.mem.eql(u8, key, "TRANSIT_CONSOLE_CONFIG") or std.mem.count(u8, key, "__") != depth) continue;
            applyEnv(T, allocator, value, key[8..], entry.value_ptr.*) catch |err| {
                return diagnostic.invalidFieldCause(err, key, "is not a valid server setting", null);
            };
        }
    }
}
fn applyEnv(comptime T: type, allocator: std.mem.Allocator, value: *Value, key: []const u8, raw: []const u8) anyerror!void {
    switch (@typeInfo(T)) {
        .optional => |info| return applyEnv(info.child, allocator, value, key, raw),
        .@"struct" => |info| {
            const split = std.mem.indexOf(u8, key, "__");
            const head = key[0 .. split orelse key.len];
            inline for (info.field_names, info.field_types) |name, field_type| {
                const upper = comptime blk: {
                    var bytes: [name.len]u8 = undefined;
                    for (name, 0..) |c, i| bytes[i] = std.ascii.toUpper(c);
                    break :blk bytes;
                };
                if (std.mem.eql(u8, head, &upper)) {
                    if (value.* == .null) value.* = object(allocator);
                    if (value.* != .object) return error.InvalidEnvironmentObject;
                    if (split) |at| {
                        if (!value.object.contains(name)) try value.object.put(allocator, name, .null);
                        return applyEnv(field_type, allocator, value.object.getPtr(name).?, key[at + 2 ..], raw);
                    }
                    const parsed = try envValue(field_type, allocator, raw);
                    if (value.object.getPtr(name)) |existing| try merge(allocator, existing, parsed) else try value.object.put(allocator, name, parsed);
                    return;
                }
            }
            return error.UnknownEnvironmentSetting;
        },
        else => return error.UnknownEnvironmentSetting,
    }
}
fn envValue(comptime T: type, allocator: std.mem.Allocator, raw: []const u8) !Value {
    switch (@typeInfo(T)) {
        .optional => |info| {
            if (std.mem.eql(u8, raw, "null") and info.child != []const u8) return .null;
            return envValue(info.child, allocator, raw);
        },
        .pointer => |info| if (info.child == u8) {
            return .{ .string = raw };
        },
        .@"enum" => return .{ .string = raw },
        else => {},
    }
    return jsonValue(allocator, raw);
}

test "bounded YAML merges partial maps and refuses duplicate and active syntax" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var parser: Yaml = .{ .allocator = arena.allocator(), .bytes = "ports:\n  gateway: 10000\ngateway_allowed_hosts:\n  - localhost:10000\n" };
    const result = try parser.parse();
    try std.testing.expectEqual(@as(i64, 10000), result.object.get("ports").?.object.get("gateway").?.integer);
    try std.testing.expectEqualStrings("localhost:10000", result.object.get("gateway_allowed_hosts").?.array.items[0].string);
    for ([_][]const u8{ "a: 1\na: 2\n", "a: &anchor 1\n", "a: !tag value\n" }) |bytes| {
        parser = .{ .allocator = arena.allocator(), .bytes = bytes };
        if (parser.parse()) |_| return error.ExpectedInvalidConfiguration else |_| {}
    }
}

fn boundJson(allocator: std.mem.Allocator, bytes: []const u8) !void {
    var scanner = std.json.Scanner.initCompleteInput(allocator, bytes);
    defer scanner.deinit();
    var depth: usize = 0;
    var nodes: usize = 0;
    while (true) {
        const token = try scanner.next();
        switch (token) {
            .end_of_document => return,
            .object_begin, .array_begin => {
                depth += 1;
                if (depth > 16) return error.ConfigurationTooDeep;
            },
            .object_end, .array_end => {
                if (depth > 0) depth -= 1;
            },
            else => {},
        }
        nodes += 1;
        if (nodes > 2048) return error.ConfigurationTooLarge;
    }
}
fn jsonValue(allocator: std.mem.Allocator, bytes: []const u8) !Value {
    try boundJson(allocator, bytes);
    return (try std.json.parseFromSlice(Value, allocator, bytes, .{ .allocate = .alloc_always })).value;
}

/// Attribute semantic field failures to the most specific environment override.
/// Values are never included, and coordinates come only from the schema.
pub fn environmentOrigin(init: std.process.Init, diagnostic: *Diagnostic) void {
    const field = diagnostic.field orelse return;
    if (std.mem.startsWith(u8, field, "TRANSIT_")) {
        diagnostic.file = null;
        return;
    }
    var parts = std.mem.tokenizeAny(u8, field, " / ");
    while (parts.next()) |part| {
        var prefix = part;
        while (prefix.len > 0) {
            var storage: [128]u8 = undefined;
            var writer: std.Io.Writer = .fixed(&storage);
            writer.writeAll("TRANSIT_") catch return;
            for (prefix) |c| {
                if (c == '.') writer.writeAll("__") catch return else writer.writeByte(std.ascii.toUpper(c)) catch return;
            }
            const key = writer.buffered();
            if (init.environ_map.get(key) != null) {
                diagnostic.field = std.fmt.allocPrint(init.arena.allocator(), "{s} ({s})", .{ key, field }) catch field;
                diagnostic.file = null;
                return;
            }
            prefix = prefix[0 .. std.mem.lastIndexOfScalar(u8, prefix, '.') orelse 0];
        }
    }
}

fn boundedValue(value: Value, depth: usize, nodes: *usize) anyerror!void {
    if (depth > 16) return error.ConfigurationTooDeep;
    nodes.* += 1;
    if (nodes.* > 2048) return error.ConfigurationTooLarge;
    switch (value) {
        .object => |map| {
            for (map.values()) |child| try boundedValue(child, depth + 1, nodes);
        },
        .array => |list| {
            for (list.items) |child| try boundedValue(child, depth + 1, nodes);
        },
        else => {},
    }
}
