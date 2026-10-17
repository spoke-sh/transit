//! Domain-owned setting descriptions and deterministic value validation.
const std = @import("std");
const Input = @import("Input.zig");
const Value = Input.Value;
const Allocator = std.mem.Allocator;
const Self = @This();

pub const Change = enum { initialization, restart, reload, new_session, session, read_only };
pub const Scope = enum { installation, component, session };
pub const Kind = enum { boolean, unsigned, string, strings, object, duration, bytes, enumeration };
pub const Source = enum { defaults, file, environment, invocation, session, derived };
pub const Origin = struct {
    source: Source,
    name: ?[]const u8 = null,
    line: ?u64 = null,
    column: ?u64 = null,
};
pub const Descriptor = struct {
    name: []const u8,
    description: []const u8,
    owner: []const u8,
    kind: Kind,
    scope: Scope = .component,
    change: Change,
    nullable: bool = false,
    sensitive: bool = false,
    minimum: u64 = 0,
    maximum: u64 = std.math.maxInt(u64),
    values: []const []const u8 = &.{},

    pub fn normalize(self: Descriptor, allocator: Allocator, value: Value) !Value {
        if (value == .null) {
            if (!self.nullable) return error.InvalidSettingNull;
            return .null;
        }
        switch (self.kind) {
            .boolean => if (value != .bool) return error.InvalidSettingType,
            .string => if (value != .string) return error.InvalidSettingType,
            .strings => {
                if (value != .array) return error.InvalidSettingType;
                for (value.array.items) |item| if (item != .string) return error.InvalidSettingType;
            },
            .object => if (value != .object) return error.InvalidSettingType,
            .enumeration => {
                if (value != .string) return error.InvalidSettingType;
                for (self.values) |allowed| if (std.mem.eql(u8, allowed, value.string)) return value;
                return error.InvalidSettingValue;
            },
            .unsigned, .duration, .bytes => {
                const number: u64 = switch (value) {
                    .integer => |n| std.math.cast(u64, n) orelse return error.InvalidSettingValue,
                    .number_string => |s| std.fmt.parseInt(u64, s, 10) catch return error.InvalidSettingValue,
                    .string => |s| if (self.kind == .unsigned) return error.InvalidSettingType else try quantity(s, self.kind),
                    else => return error.InvalidSettingType,
                };
                if (number < self.minimum or number > self.maximum) return error.SettingOutOfRange;
                if (std.math.cast(i64, number)) |n| return .{ .integer = n };
                return .{ .number_string = try std.fmt.allocPrint(allocator, "{d}", .{number}) };
            },
        }
        return value;
    }

    pub fn unit(self: Descriptor) ?[]const u8 {
        return switch (self.kind) {
            .duration => "ms",
            .bytes => "B",
            else => null,
        };
    }

    /// Values are never rendered before sensitivity is checked.
    pub fn display(self: Descriptor, allocator: Allocator, value: ?Value) !?[]const u8 {
        if (self.sensitive) return null;
        const present = value orelse return null;
        return if (present == .string) try allocator.dupe(u8, present.string) else try std.json.Stringify.valueAlloc(allocator, present, .{});
    }
};

descriptors: []const Descriptor,

pub fn lookup(self: Self, name: []const u8) !Descriptor {
    for (self.descriptors) |descriptor| if (std.mem.eql(u8, descriptor.name, name)) return descriptor;
    return error.UnknownSetting;
}

/// Registry size is the finite schema, never retained user-data cardinality.
pub fn validate(self: Self) !void {
    for (self.descriptors, 0..) |descriptor, i| {
        try validateName(descriptor.name);
        if (descriptor.description.len == 0 or descriptor.owner.len == 0 or descriptor.minimum > descriptor.maximum) return error.InvalidSettingDescriptor;
        if ((descriptor.kind == .enumeration) != (descriptor.values.len != 0)) return error.InvalidSettingDescriptor;
        for (self.descriptors[0..i]) |earlier| if (std.mem.eql(u8, earlier.name, descriptor.name)) return error.DuplicateSetting;
    }
}

pub fn validateName(name: []const u8) !void {
    if (name.len == 0 or name.len > 128) return error.InvalidSettingName;
    var start = true;
    for (name) |c| {
        if (c == '.') {
            if (start) return error.InvalidSettingName;
            start = true;
        } else {
            if (!(c >= 'a' and c <= 'z') and c != '_' and (!std.ascii.isDigit(c) or start)) return error.InvalidSettingName;
            start = false;
        }
    }
    if (start) return error.InvalidSettingName;
}

pub fn environmentName(allocator: Allocator, name: []const u8) ![]const u8 {
    try validateName(name);
    var output: std.Io.Writer.Allocating = .init(allocator);
    defer output.deinit();
    try output.writer.writeAll("TRANSIT_");
    for (name) |c| if (c == '.') try output.writer.writeAll("__") else try output.writer.writeByte(std.ascii.toUpper(c));
    return output.toOwnedSlice();
}

pub fn environment(self: Self, init: std.process.Init, root: *Value, diagnostic: anytype) !void {
    const allocator = init.arena.allocator();
    var used: usize = 0;
    var iterator = init.environ_map.iterator();
    while (iterator.next()) |entry| {
        const name = entry.key_ptr.*;
        if (!std.mem.startsWith(u8, name, "TRANSIT_") or Input.reservedEnvironment(name)) continue;
        used += name.len + entry.value_ptr.len;
        if (used > Input.max_bytes or name.len > 128 or std.mem.count(u8, name, "__") > 16) return diagnostic.invalidField("environment", "exceeds the configuration limit", null);
        for (name) |c| if (!(c >= 'A' and c <= 'Z') and !std.ascii.isDigit(c) and c != '_') return diagnostic.invalidField("environment", "contains an invalid TRANSIT_ setting name", null);
    }
    for (0..17) |depth| {
        iterator = init.environ_map.iterator();
        while (iterator.next()) |entry| {
            const key = entry.key_ptr.*;
            if (!std.mem.startsWith(u8, key, "TRANSIT_") or Input.reservedEnvironment(key) or std.mem.count(u8, key, "__") != depth) continue;
            var path: std.Io.Writer.Allocating = .init(allocator);
            defer path.deinit();
            var parts = std.mem.splitSequence(u8, key[8..], "__");
            var first = true;
            while (parts.next()) |part| {
                if (!first) try path.writer.writeByte('.');
                first = false;
                for (part) |c| try path.writer.writeByte(std.ascii.toLower(c));
            }
            var field: ?[]const u8 = null;
            self.override(allocator, root, path.written(), entry.value_ptr.*, &field) catch |err| {
                const label = if (field) |known| try std.fmt.allocPrint(allocator, "{s} ({s})", .{ key, known }) else key;
                diagnostic.file = null;
                return diagnostic.invalidFieldCause(err, label, "is not a valid server setting", null);
            };
        }
    }
}

pub fn override(self: Self, allocator: Allocator, root: *Value, name: []const u8, raw: []const u8, field: *?[]const u8) !void {
    try validateName(name);
    const descriptor = self.lookup(name) catch null;
    field.* = if (descriptor) |item| item.name else null;
    const value: Value = if (descriptor) |item| switch (item.kind) {
        .string, .enumeration => .{ .string = try allocator.dupe(u8, raw) },
        .duration, .bytes => Input.jsonValue(allocator, raw) catch .{ .string = try allocator.dupe(u8, raw) },
        else => try Input.jsonValue(allocator, raw),
    } else try Input.jsonValue(allocator, raw);
    var overlay = Input.object(allocator);
    try set(allocator, &overlay, name, value);
    try self.normalizeInput(allocator, &overlay, field);
    try Input.merge(allocator, root, overlay);
}

pub fn get(root: Value, path: []const u8) ?Value {
    var parts = std.mem.splitScalar(u8, path, '.');
    var value = root;
    while (parts.next()) |part| {
        if (value != .object) return null;
        value = value.object.get(part) orelse return null;
    }
    return value;
}

pub fn set(allocator: Allocator, root: *Value, path: []const u8, value: Value) !void {
    try validateName(path);
    const split = std.mem.indexOfScalar(u8, path, '.');
    const name = path[0 .. split orelse path.len];
    if (root.* == .null) root.* = Input.object(allocator);
    if (root.* != .object) return error.InvalidSettingType;
    if (split) |at| {
        if (!root.object.contains(name)) try root.object.put(allocator, try allocator.dupe(u8, name), .null);
        try set(allocator, root.object.getPtr(name).?, path[at + 1 ..], value);
    } else try root.object.put(allocator, try allocator.dupe(u8, name), value);
}

/// Check and normalize only supplied keys. The owner validates required fields
/// and cross-field constraints after default/environment resolution.
pub fn normalize(self: Self, allocator: Allocator, root: *Value, field: *?[]const u8) !void {
    return self.walk(allocator, root, "", field, 0, true);
}
/// Shadowed values still have known names/types; bounds apply to the final value.
pub fn normalizeInput(self: Self, allocator: Allocator, root: *Value, field: *?[]const u8) !void {
    return self.walk(allocator, root, "", field, 0, false);
}
fn walk(self: Self, allocator: Allocator, value: *Value, prefix: []const u8, field: *?[]const u8, depth: usize, bounds: bool) anyerror!void {
    if (depth > Input.max_depth) return error.ConfigurationTooDeep;
    if (prefix.len != 0) {
        field.* = prefix;
        if (self.lookup(prefix)) |descriptor| {
            var validation = descriptor;
            if (!bounds) {
                validation.minimum = 0;
                validation.maximum = std.math.maxInt(u64);
                if (validation.kind == .enumeration) validation.kind = .string;
            }
            value.* = try validation.normalize(allocator, value.*);
            if (descriptor.kind != .object or value.* == .null) return;
        } else |_| {
            var namespace = false;
            for (self.descriptors) |descriptor| if (std.mem.startsWith(u8, descriptor.name, prefix) and descriptor.name.len > prefix.len and descriptor.name[prefix.len] == '.') {
                namespace = true;
                break;
            };
            if (!namespace) {
                // Unknown input names are untrusted values, not schema labels.
                field.* = if (std.mem.lastIndexOfScalar(u8, prefix, '.')) |at| prefix[0..at] else null;
                return error.UnknownSetting;
            }
        }
    }
    if (value.* != .object) return error.InvalidSettingType;
    var iterator = value.object.iterator();
    while (iterator.next()) |entry| {
        const path = if (prefix.len == 0) try allocator.dupe(u8, entry.key_ptr.*) else try std.fmt.allocPrint(allocator, "{s}.{s}", .{ prefix, entry.key_ptr.* });
        try self.walk(allocator, entry.value_ptr, path, field, depth + 1, bounds);
    }
    field.* = null;
}

pub fn quantity(raw: []const u8, kind: Kind) !u64 {
    const input = std.mem.trim(u8, raw, " ");
    var end: usize = 0;
    while (end < input.len and std.ascii.isDigit(input[end])) : (end += 1) {}
    if (end == 0) return error.InvalidSettingValue;
    const base = std.fmt.parseInt(u64, input[0..end], 10) catch return error.InvalidSettingValue;
    const suffix = std.mem.trim(u8, input[end..], " ");
    const scale: u64 = switch (kind) {
        .duration => blk: {
            inline for (.{ .{ "ms", 1 }, .{ "s", 1000 }, .{ "min", 60000 }, .{ "h", 3600000 } }) |pair| if (std.mem.eql(u8, suffix, pair[0])) break :blk pair[1];
            return error.InvalidSettingUnit;
        },
        .bytes => blk: {
            inline for (.{ .{ "B", 1 }, .{ "KiB", 1024 }, .{ "MiB", 1048576 }, .{ "GiB", 1073741824 }, .{ "kB", 1000 }, .{ "MB", 1000000 }, .{ "GB", 1000000000 } }) |pair| if (std.mem.eql(u8, suffix, pair[0])) break :blk pair[1];
            return error.InvalidSettingUnit;
        },
        else => return error.InvalidSettingType,
    };
    return std.math.mul(u64, base, scale) catch error.SettingOutOfRange;
}

test "unit parsing remains exact and refuses ambiguity and overflow" {
    const t = std.testing;
    try t.expectEqual(@as(u64, 5000), try quantity("5s", .duration));
    try t.expectEqual(@as(u64, 256 * 1048576), try quantity("256 MiB", .bytes));
    try t.expectEqual(@as(u64, 256000000), try quantity("256MB", .bytes));
    for ([_][]const u8{ "5", "5m", "-1s", "1.5s", "infinity", "1s trailing" }) |invalid| {
        if (quantity(invalid, .duration)) |_| return error.ExpectedRejection else |_| {}
    }
    try t.expectError(error.SettingOutOfRange, quantity("18446744073709551615h", .duration));
}

test "registry validates unknown input and normalizes nested values without disclosure" {
    const t = std.testing;
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const registry: Self = .{ .descriptors = &.{
        .{ .name = "query.statement_timeout", .description = "Statement wait bound", .owner = "query", .kind = .duration, .change = .session, .minimum = 1, .maximum = 60000 },
        .{ .name = "tls.key_file", .description = "Private key reference", .owner = "gateway", .kind = .string, .change = .restart, .sensitive = true },
    } };
    try registry.validate();
    var tree = try Input.jsonValue(allocator, "{\"query\":{\"statement_timeout\":\"5s\"}}");
    var field: ?[]const u8 = null;
    try registry.normalize(allocator, &tree, &field);
    try t.expectEqual(@as(i64, 5000), get(tree, "query.statement_timeout").?.integer);
    try set(allocator, &tree, "query.typo", .{ .integer = 1 });
    try t.expectError(error.UnknownSetting, registry.normalize(allocator, &tree, &field));
    try t.expectEqualStrings("query", field.?);
    const secret = try registry.lookup("tls.key_file");
    try t.expectEqual(@as(?[]const u8, null), try secret.display(allocator, .{ .string = "private" }));
    try t.expectEqualStrings("TRANSIT_QUERY__STATEMENT_TIMEOUT", try environmentName(allocator, "query.statement_timeout"));
    const integer: Descriptor = .{ .name = "size", .description = "size", .owner = "test", .kind = .unsigned, .change = .restart };
    try t.expectError(error.InvalidSettingType, integer.normalize(allocator, .{ .string = "42" }));
}
