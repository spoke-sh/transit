//! Bounded schema evidence. The mutable tree consumes a fixed metadata budget,
//! independently of row count. Freeze allocates one owned logical descriptor.
const std = @import("std");
const types = @import("Types.zig");
const sem = types.Semantics;
pub const max_nodes = 256;
pub const max_names = 4096;
pub const Node = struct {
    kind: ?types.Tag = null,
    name_offset: u16 = 0,
    name_length: u8 = 0,
    next: ?u16 = null,
    first: ?u16 = null,
    element: ?u16 = null,
    nullable: bool = false,
    optional: bool = false,
    present: u64 = 0,
    objects: u64 = 0,
    whole_digits: u8 = 0,
    scale: u8 = 0,
};
pub const Builder = struct {
    failure: ?*?types.Diagnostic = null,
    nodes: [max_nodes]Node = @splat(.{}),
    count: u16 = 1,
    names: [max_names]u8 = undefined,
    name_bytes: u16 = 0,
    pub fn init() Builder {
        var result: Builder = .{};
        result.nodes[0].kind = .structure;
        return result;
    }
    fn reject(self: *Builder, path: types.Diagnostic.Path, kind: types.Diagnostic.Kind, actual: ?usize, limit: ?usize, supplied: []const u8, err: anyerror) anyerror {
        if (self.failure) |failure| if (failure.* == null) {
            var detail: types.Diagnostic = .{ .path = path, .kind = kind, .actual = actual, .limit = limit };
            detail.capture(supplied);
            failure.* = detail;
        };
        return err;
    }
    fn allocate(self: *Builder, path: types.Diagnostic.Path) !u16 {
        if (self.count == max_nodes) return self.reject(path, .nodes, @as(usize, self.count) + 1, max_nodes, "", error.InferenceNodeBudgetExceeded);
        const index = self.count;
        self.count += 1;
        return index;
    }
    pub fn name(self: *const Builder, index: u16) []const u8 {
        const node = self.nodes[index];
        return self.names[node.name_offset..][0..node.name_length];
    }
    pub fn ensureField(self: *Builder, parent: u16, text: []const u8) !u16 {
        return self.ensureFieldAt(parent, text, (types.Diagnostic.Path{}).field(text));
    }
    fn ensureFieldAt(self: *Builder, parent: u16, text: []const u8, path: types.Diagnostic.Path) !u16 {
        if (text.len == 0) return self.reject(path, .name_empty, 0, null, text, error.InvalidFieldName);
        if (text.len > 255) return self.reject(path, .name_length, text.len, 255, text, error.InvalidFieldName);
        if (!std.unicode.utf8ValidateSlice(text)) return self.reject(path, .name_utf8, null, null, text, error.InvalidFieldName);
        if (std.mem.indexOfScalar(u8, text, 0) != null) return self.reject(path, .name_nul, null, null, text, error.InvalidFieldName);
        var cursor = self.nodes[parent].first;
        var previous: ?u16 = null;
        while (cursor) |index| {
            switch (std.mem.order(u8, self.name(index), text)) {
                .eq => return index,
                .gt => break,
                .lt => {
                    previous = index;
                    cursor = self.nodes[index].next;
                },
            }
        }
        if (text.len > max_names - self.name_bytes) return self.reject(path, .name_bytes, @as(usize, self.name_bytes) + text.len, max_names, text, error.InferenceNameBudgetExceeded);
        const index = try self.allocate(path);
        self.nodes[index].name_offset = self.name_bytes;
        self.nodes[index].name_length = @intCast(text.len);
        @memcpy(self.names[self.name_bytes..][0..text.len], text);
        self.name_bytes += @intCast(text.len);
        self.nodes[index].next = cursor;
        if (previous) |p| self.nodes[p].next = index else self.nodes[parent].first = index;
        return index;
    }
    fn increment(self: *Builder, counter: *u64, path: types.Diagnostic.Path) !void {
        counter.* = std.math.add(u64, counter.*, 1) catch return self.reject(path, .observation_count, @intCast(counter.*), std.math.maxInt(u64), "", error.InferenceWorkExceeded);
    }
    pub fn csvRow(self: *Builder, names: []const []const u8, cells: []const @import("FileFraming.zig").CsvField, raw: bool) !void {
        if (names.len != cells.len) return error.RaggedCsvRow;
        try self.increment(&self.nodes[0].objects, .{});
        for (names, cells) |text, cell| {
            const index = try self.ensureField(0, text);
            const node = &self.nodes[index];
            try self.increment(&node.present, (types.Diagnostic.Path{}).field(text));
            if (cell.is_null) {
                node.nullable = true;
                continue;
            }
            const inferred: types.Type = if (raw) .utf8 else sem.inferText(cell.text);
            if (node.kind) |kind| node.kind = sem.unifyText(typeForTag(kind), inferred).tag() else node.kind = inferred.tag();
        }
    }
    pub fn jsonRow(self: *Builder, value: std.json.Value) !void {
        if (value != .object) return error.JsonObjectRequired;
        try self.observe(0, value, 0, .{});
    }
    fn observe(self: *Builder, index: u16, value: std.json.Value, depth: usize, path: types.Diagnostic.Path) anyerror!void {
        if (depth >= 16) return self.reject(path, .depth, depth + 1, 16, "", error.InferenceDepthExceeded);
        const node = &self.nodes[index];
        try self.increment(&node.present, path);
        if (value == .null) {
            node.nullable = true;
            return;
        }
        if (node.kind == .json) return;
        const kind: types.Tag = switch (value) {
            .bool => .boolean,
            .string => .utf8,
            .object => .structure,
            .array => .list,
            .number_string => return self.number(node, value.number_string),
            else => return error.InvalidInferenceValue,
        };
        if (node.kind != null and node.kind.? != kind) {
            node.kind = .json;
            return;
        }
        node.kind = kind;
        switch (value) {
            .object => |object| {
                try self.increment(&node.objects, path);
                var iterator = object.iterator();
                while (iterator.next()) |entry| {
                    const child_path = path.field(entry.key_ptr.*);
                    const child = try self.ensureFieldAt(index, entry.key_ptr.*, child_path);
                    try self.observe(child, entry.value_ptr.*, depth + 1, child_path);
                }
            },
            .array => |array| {
                if (node.element == null) node.element = try self.allocate(path);
                for (array.items, 0..) |child, ordinal| try self.observe(node.element.?, child, depth + 1, path.index(ordinal));
            },
            else => {},
        }
    }
    fn number(_: *Builder, node: *Node, text: []const u8) !void {
        const exact = sem.exact(text) catch {
            node.kind = .json;
            return;
        };
        // Keep signed zero and numbers outside decimal128 as lossless raw JSON.
        if (exact.coefficient == 0 and text[0] == '-') {
            node.kind = .json;
            return;
        }
        var abs = @abs(exact.coefficient);
        var digits: u8 = 1;
        while (abs >= 10) : (digits += 1) abs /= 10;
        const precision = @max(digits, exact.scale);
        const whole = precision - exact.scale;
        var inferred = sem.inferText(text);
        if (inferred == .utf8) {
            if (precision > 38) {
                node.kind = .json;
                return;
            }
            inferred = .{ .decimal = .{ .precision = @max(precision, 1), .scale = exact.scale } };
        }
        if (node.kind) |prior| {
            const old = typeForTag(prior);
            if (sem.integer(old) == null and prior != .decimal) {
                node.kind = .json;
                return;
            }
            if (prior == .decimal or inferred == .decimal) {
                const combined_whole = @max(node.whole_digits, whole);
                const combined_scale = @max(node.scale, exact.scale);
                if (@as(u16, combined_whole) + combined_scale > 38) {
                    node.kind = .json;
                    return;
                }
                node.kind = .decimal;
            } else node.kind = (sem.promote(old, inferred) catch {
                node.kind = .json;
                return;
            }).tag();
        } else node.kind = inferred.tag();
        node.whole_digits = @max(node.whole_digits, whole);
        node.scale = @max(node.scale, exact.scale);
    }
    /// Names are sorted by decoded UTF-8 bytes, making discovery independent of
    /// object/header order. Overrides are borrowed until the owned freeze ends.
    pub fn freeze(self: *const Builder, allocator: std.mem.Allocator, csv: bool, overrides: []const types.Field) !types.Decoded {
        return self.freezeDiagnostic(allocator, csv, overrides, null);
    }
    pub fn freezeDiagnostic(self: *const Builder, allocator: std.mem.Allocator, csv: bool, overrides: []const types.Field, failure: ?*?types.Diagnostic) !types.Decoded {
        var arena: std.heap.ArenaAllocator = .init(allocator);
        errdefer arena.deinit();
        var result = try self.resolve(arena.allocator(), 0, csv);
        if (result != .structure) {
            if (overrides.len == 0) return error.UnresolvedSchema;
            result = .{ .structure = &.{} };
        }
        // The resolved tree owns its storage; overrides are deep-copied through
        // the canonical codec so caller descriptors cannot mutate a binding.
        var fields: std.ArrayList(types.Field) = .empty;
        for (result.structure) |field| try fields.append(arena.allocator(), field);
        for (overrides, 0..) |override, i| {
            for (overrides[0..i]) |earlier| if (std.mem.eql(u8, earlier.name, override.name)) return error.DuplicateField;
            try override.type.validate(.{});
            var found = false;
            for (fields.items) |*field| if (std.mem.eql(u8, field.name, override.name)) {
                field.* = override;
                found = true;
                break;
            };
            if (!found) try fields.append(arena.allocator(), override);
        }
        std.mem.sort(types.Field, fields.items, {}, struct {
            fn less(_: void, a: types.Field, b: types.Field) bool {
                return std.mem.order(u8, a.name, b.name) == .lt;
            }
        }.less);
        result = .{ .structure = fields.items };
        try result.validateDiagnostic(.{}, failure);
        var bytes: [types.max_encoding_bytes]u8 = undefined;
        const encoded = try result.encode(&bytes);
        var owned = try types.decode(allocator, encoded);
        errdefer owned.deinit();
        arena.deinit();
        return owned;
    }
    fn resolve(self: *const Builder, allocator: std.mem.Allocator, index: u16, csv: bool) anyerror!types.Type {
        const node = self.nodes[index];
        const kind = node.kind orelse return if (csv) .utf8 else .json;
        return switch (kind) {
            .structure => blk: {
                var fields: std.ArrayList(types.Field) = .empty;
                var cursor = node.first;
                while (cursor) |child| : (cursor = self.nodes[child].next) {
                    const field_node = self.nodes[child];
                    try fields.append(allocator, .{
                        .name = self.name(child),
                        .type = try self.resolve(allocator, child, csv),
                        .nullable = field_node.nullable,
                        .optional = field_node.optional or field_node.present < node.objects,
                    });
                }
                // An empty object has a lossless raw representation; no invented
                // column is implied. The file-source owner supplies raw mode.
                if (fields.items.len == 0) return .json;
                break :blk .{ .structure = fields.items };
            },
            .list => blk: {
                const child = try allocator.create(types.Type);
                child.* = if (node.element) |element| try self.resolve(allocator, element, csv) else .json;
                break :blk .{ .list = .{ .type = child, .nullable = if (node.element) |element| self.nodes[element].nullable else false } };
            },
            .decimal => .{ .decimal = .{ .precision = @max(1, node.whole_digits + node.scale), .scale = node.scale } },
            else => typeForTag(kind),
        };
    }
};
fn typeForTag(tag: types.Tag) types.Type {
    return switch (tag) {
        .decimal => .{ .decimal = .{ .precision = 38, .scale = 0 } },
        .structure, .list, .array, .map, .tagged_union, .timestamp => .json,
        inline else => |kind| @unionInit(types.Type, @tagName(kind), {}),
    };
}
test "JSON discovery is lossless recursive sparse and independent of field order" {
    const t = std.testing;
    const texts = [_][]const u8{
        "{\"id\":9007199254740993,\"nested\":{\"a\":1},\"items\":[1,null,2],\"n\":1.25}",
        "{\"n\":2,\"items\":[3],\"nested\":{\"b\":true},\"id\":18446744073709551615}",
    };
    var builder = Builder.init();
    for (texts) |text| {
        var json = try types.Json.parse(t.allocator, text, .{});
        defer json.deinit();
        try builder.jsonRow(json.value);
    }
    var schema = try builder.freeze(t.allocator, false, &.{});
    defer schema.deinit();
    const fields = schema.type.structure;
    try t.expectEqualStrings("id", fields[0].name);
    try t.expectEqual(types.Tag.int128, fields[0].type.tag());
    try t.expect(fields[1].type.list.nullable);
    try t.expectEqual(@as(u8, 2), fields[2].type.decimal.scale);
    try t.expectEqual(@as(u8, 3), fields[2].type.decimal.precision);
    try t.expect(fields[3].type.structure[0].optional);
    try t.expect(fields[3].type.structure[1].optional);
    var reversed = Builder.init();
    for (0..texts.len) |i| {
        var json = try types.Json.parse(t.allocator, texts[texts.len - i - 1], .{});
        defer json.deinit();
        try reversed.jsonRow(json.value);
    }
    var other = try reversed.freeze(t.allocator, false, &.{});
    defer other.deinit();
    try t.expect(try schema.type.eql(other.type));
}
test "heterogeneous JSON uses raw values and null alone never invents numeric type" {
    const t = std.testing;
    var builder = Builder.init();
    for ([_][]const u8{ "{\"x\":1,\"empty\":null}", "{\"x\":\"001\",\"empty\":null}" }) |text| {
        var json = try types.Json.parse(t.allocator, text, .{});
        defer json.deinit();
        try builder.jsonRow(json.value);
    }
    var schema = try builder.freeze(t.allocator, false, &.{});
    defer schema.deinit();
    try t.expect(schema.type.structure[0].nullable);
    try t.expectEqual(types.Tag.json, schema.type.structure[0].type.tag());
    try t.expectEqual(types.Tag.json, schema.type.structure[1].type.tag());
}

test "discovery keeps original nested field paths after input release" {
    const t = std.testing;
    var builder = Builder.init();
    var failure: ?types.Diagnostic = null;
    builder.failure = &failure;
    {
        var input = try types.Json.parse(t.allocator, "{\"outer/~\":[{}, {\"\":1}]}", .{});
        defer input.deinit();
        try t.expectError(error.InvalidFieldName, builder.jsonRow(input.value));
    }
    try t.expectEqualStrings("/outer~1~0/1/", failure.?.path.slice());
    try t.expectEqual(types.Diagnostic.Kind.name_empty, failure.?.kind);
    // A later check cannot replace the original failing position.
    try t.expectError(error.InvalidFieldName, builder.ensureField(0, "bad\x00name"));
    try t.expectEqualStrings("/outer~1~0/1/", failure.?.path.slice());
}

test "discovery count overflow and metadata capacity retain exact stopping values" {
    const t = std.testing;
    var builder = Builder.init();
    var failure: ?types.Diagnostic = null;
    builder.failure = &failure;
    const index = try builder.ensureField(0, "id");
    builder.nodes[index].present = std.math.maxInt(u64);
    var input = try types.Json.parse(t.allocator, "{\"id\":1}", .{});
    defer input.deinit();
    try t.expectError(error.InferenceWorkExceeded, builder.jsonRow(input.value));
    try t.expectEqualStrings("/id", failure.?.path.slice());
    try t.expectEqual(types.Diagnostic.Kind.observation_count, failure.?.kind);
    try t.expectEqual(@as(?usize, std.math.maxInt(u64)), failure.?.actual);
    try t.expectEqual(std.math.maxInt(u64), builder.nodes[index].present);
    failure = null;
    builder.count = max_nodes;
    try t.expectError(error.InferenceNodeBudgetExceeded, builder.ensureField(0, "next"));
    try t.expectEqual(@as(?usize, 257), failure.?.actual);
    try t.expectEqualStrings("/next", failure.?.path.slice());
}

test "resolved schema witnesses describe combined overrides without a fabricated row" {
    const t = std.testing;
    var builder = Builder.init();
    var input = try types.Json.parse(t.allocator, "{\"observed\":1}", .{});
    defer input.deinit();
    try builder.jsonRow(input.value);
    const overrides = [_]types.Field{.{ .name = "extra", .type = .{ .array = .{ .length = 0, .element = .{ .type = &.int64 } } } }};
    // Individual invalid overrides fail their own admission validation.
    try t.expectError(error.InvalidArrayLength, builder.freeze(t.allocator, false, &overrides));
    var names: [255][2]u8 = undefined;
    var fields: [255]types.Field = undefined;
    for (&fields, 0..) |*field, i| {
        names[i] = std.fmt.bytesToHex(&[_]u8{@intCast(i)}, .lower);
        field.* = .{ .name = &names[i], .type = .int64 };
    }
    var failure: ?types.Diagnostic = null;
    try t.expectError(error.InvalidFieldCount, builder.freezeDiagnostic(t.allocator, false, &fields, &failure));
    try t.expectEqualStrings("/type/structure", failure.?.path.slice());
    try t.expectEqual(@as(?usize, 256), failure.?.actual);
    try t.expectEqual(@as(?usize, 255), failure.?.limit);
}
