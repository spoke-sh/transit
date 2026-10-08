//! Finite compile-time reflection graph for recursive host contracts. Native
//! framing and runtime domain budgets are unchanged by schema generation.
const std = @import("std");
const p = @import("root.zig");
const s = @import("Schema.zig");
const Options = s.Options;
const Node = struct { T: type, options: Options };
fn custom(comptime T: type) bool {
    if (T == p.Value) return true;
    return switch (@typeInfo(T)) {
        .@"struct" => @hasDecl(T, "jsonSchema") or @hasDecl(T, "json_schema_type"),
        else => false,
    };
}
const Graph = struct {
    // This bounds contract reflection, not collections in a running system.
    nodes: [1024]Node = @splat(.{ .T = void, .options = .{} }),
    count: usize = 0,
    fn add(self: *Graph, comptime T: type, comptime options: Options) void {
        for (self.nodes[0..self.count]) |node| if (node.T == T and std.meta.eql(node.options, options)) return;
        if (self.count == self.nodes.len) @compileError("Host schema reflection exceeded its explicit type graph bound");
        self.nodes[self.count] = .{ .T = T, .options = options };
        self.count += 1;
        if (comptime custom(T) or (T == p.Diagnostic and options.diagnostic_reference != null)) return;
        switch (@typeInfo(T)) {
            inline .@"struct", .@"union" => |info| {
                for (info.field_names, info.field_types) |name, F| {
                    if (@hasDecl(T, "json_schema_fields") and @hasField(@TypeOf(T.json_schema_fields), name)) continue;
                    self.add(F, s.fieldOptions(T, name, options));
                }
            },
            .pointer => |info| if (info.size == .one or info.child != u8) self.add(info.child, if (info.size == .slice) s.sequenceItems(options) else options),
            .optional => |info| self.add(info.child, options),
            .array => |info| self.add(info.child, options),
            else => {},
        }
    }
    fn index(comptime self: Graph, comptime T: type, comptime options: Options) usize {
        inline for (self.nodes[0..self.count], 0..) |node, i| if (node.T == T and std.meta.eql(node.options, options)) return i;
        @compileError("Missing host schema graph reference");
    }
};
fn reference(comptime base: []const u8, comptime graph: Graph, comptime T: type, out: *std.json.Stringify, comptime options: Options) std.Io.Writer.Error!void {
    try out.write(.{ .@"$ref" = std.fmt.comptimePrint("#{s}/$defs/T{d}", .{ base, comptime graph.index(T, options) }) });
}
pub fn write(comptime T: type, out: *std.json.Stringify, comptime options: Options) std.Io.Writer.Error!void {
    return writeAt(T, out, options, "");
}
/// base is the JSON pointer of this schema within the enclosing document.
pub fn writeAt(comptime T: type, out: *std.json.Stringify, comptime options: Options, comptime base: []const u8) std.Io.Writer.Error!void {
    @setEvalBranchQuota(5000000);
    const graph = comptime blk: {
        var value: Graph = .{};
        value.add(T, options);
        break :blk value;
    };
    try out.beginObject();
    try s.field(out, "$ref", "#" ++ base ++ "/$defs/T0");
    try out.objectField("$defs");
    try out.beginObject();
    inline for (graph.nodes[0..graph.count], 0..) |node, i| {
        try out.objectField(std.fmt.comptimePrint("T{d}", .{i}));
        try writeNode(base, graph, node.T, out, node.options);
    }
    try out.endObject();
    try out.endObject();
}
fn writeNode(comptime base: []const u8, comptime graph: Graph, comptime T: type, out: *std.json.Stringify, comptime options: Options) std.Io.Writer.Error!void {
    if (comptime custom(T) or (T == p.Diagnostic and options.diagnostic_reference != null)) return s.write(T, out, options);
    switch (@typeInfo(T)) {
        .@"struct" => |info| {
            try out.beginObject();
            try s.field(out, "type", "object");
            try s.field(out, "additionalProperties", false);
            try s.field(out, "x-transit-field-order", info.field_names);
            try out.objectField("properties");
            try out.beginObject();
            inline for (info.field_names, info.field_types) |name, F| {
                try out.objectField(name);
                if (comptime @hasDecl(T, "json_schema_fields") and @hasField(@TypeOf(T.json_schema_fields), name)) {
                    try out.write(@field(T.json_schema_fields, name));
                } else try reference(base, graph, F, out, s.fieldOptions(T, name, options));
            }
            try out.endObject();
            try out.objectField("required");
            try out.beginArray();
            inline for (info.field_names, info.field_types, info.field_attrs) |name, F, attrs| {
                if (comptime T == p.Runtime.Binding and std.mem.eql(u8, name, "upgrade_from")) continue;
                if (comptime options.output or attrs.defaultValue(F) == null) try out.write(name);
            }
            try out.endArray();
            try out.objectField("x-transit-defaults");
            try out.beginObject();
            inline for (info.field_names, info.field_types, info.field_attrs) |name, F, attrs| {
                if (comptime attrs.defaultValue(F)) |value| try s.field(out, name, value);
            }
            try out.endObject();
            try out.endObject();
        },
        .@"union" => |info| {
            try out.beginObject();
            try out.objectField("oneOf");
            try out.beginArray();
            inline for (info.field_names, info.field_types) |name, F| {
                try out.beginObject();
                try s.field(out, "type", "object");
                try s.field(out, "additionalProperties", false);
                try s.field(out, "required", &[_][]const u8{name});
                try out.objectField("properties");
                try out.beginObject();
                try out.objectField(name);
                if (comptime @hasDecl(T, "json_schema_fields") and @hasField(@TypeOf(T.json_schema_fields), name)) {
                    try out.write(@field(T.json_schema_fields, name));
                } else try reference(base, graph, F, out, s.fieldOptions(T, name, options));
                try out.endObject();
                try out.endObject();
            }
            try out.endArray();
            try out.endObject();
        },
        .optional => |info| {
            try out.beginObject();
            try out.objectField("anyOf");
            try out.beginArray();
            try reference(base, graph, info.child, out, options);
            try out.write(.{ .type = "null" });
            try out.endArray();
            try out.endObject();
        },
        .pointer => |info| {
            if (info.size == .one) return reference(base, graph, info.child, out, options);
            if (info.size != .slice) @compileError("Public host pointers must be single values or bounded slices");
            if (info.child == u8) return s.write(T, out, options);
            try out.beginObject();
            try s.field(out, "type", "array");
            try s.field(out, "maxItems", options.sequence_outer_max_length orelse (options.sequence_max_length orelse @compileError("Public sequences require an explicit finite profile bound")));
            try out.objectField("items");
            try reference(base, graph, info.child, out, s.sequenceItems(options));
            try out.endObject();
        },
        .array => |info| {
            try out.beginObject();
            try s.field(out, "type", "array");
            try s.field(out, "minItems", info.len);
            try s.field(out, "maxItems", info.len);
            try out.objectField("items");
            try reference(base, graph, info.child, out, options);
            try out.endObject();
        },
        else => try s.write(T, out, options),
    }
}

test "recursive schemas retain scalar codecs safe integers and per-field sequence bounds" {
    const t = std.testing;
    const Recursive = struct {
        pub const json_schema_sequence_bounds = .{ .children = 3, .matrix = 5 };
        pub const json_schema_outer_sequence_bounds = .{ .matrix = 2 };
        pub const json_schema_text_bounds = .{ .bounded = 29 };
        pub const json_schema_fields = .{ .label = .{ .type = "string", .maxLength = 17 } };
        value: u64,
        label: []const u8,
        bounded: []const u8,
        children: []const @This(),
        matrix: []const []const u32,
        parent: ?*const @This(),
        opaque_value: p.Value,
        exact: p.Diagnostic.Unsigned,
        enabled: bool = true,
    };
    var output: std.Io.Writer.Allocating = .init(t.allocator);
    defer output.deinit();
    var out: std.json.Stringify = .{ .writer = &output.writer };
    try write(Recursive, &out, .{ .safe_integers = true, .sequence_max_length = 8 });
    const parsed = try std.json.parseFromSlice(std.json.Value, t.allocator, output.written(), .{});
    defer parsed.deinit();
    const defs = parsed.value.object.get("$defs").?.object;
    const root = defs.get("T0").?.object;
    const props = root.get("properties").?.object;
    const Resolve = struct {
        fn get(definitions: std.json.ObjectMap, value: std.json.Value) std.json.Value {
            if (value.object.get("$ref")) |ref| return get(definitions, definitions.get(ref.string[8..]).?);
            return value;
        }
    };
    try t.expectEqual(@as(i64, 3), Resolve.get(defs, props.get("children").?).object.get("maxItems").?.integer);
    const matrix = Resolve.get(defs, props.get("matrix").?).object;
    try t.expectEqual(@as(i64, 2), matrix.get("maxItems").?.integer);
    try t.expectEqual(@as(i64, 5), Resolve.get(defs, matrix.get("items").?).object.get("maxItems").?.integer);
    try t.expectEqual(@as(i64, p.max_counter), Resolve.get(defs, props.get("value").?).object.get("maximum").?.integer);
    try t.expectEqualStrings("string", Resolve.get(defs, props.get("opaque_value").?).object.get("type").?.string);
    try t.expectEqualStrings("string", Resolve.get(defs, props.get("exact").?).object.get("type").?.string);
    try t.expectEqual(@as(i64, 17), props.get("label").?.object.get("maxLength").?.integer);
    try t.expectEqual(@as(i64, 29), Resolve.get(defs, props.get("bounded").?).object.get("maxLength").?.integer);
    try t.expectEqual(@as(usize, 8), root.get("required").?.array.items.len);
    try t.expect(root.get("x-transit-defaults").?.object.get("enabled").?.bool);
    try t.expect(defs.count() < 30);
}

test "embedded recursive schema references resolve in their enclosing document" {
    const t = std.testing;
    const NodeType = struct { children: []const @This(), value: u8 };
    var output: std.Io.Writer.Allocating = .init(t.allocator);
    defer output.deinit();
    var out: std.json.Stringify = .{ .writer = &output.writer };
    try out.beginObject();
    try out.objectField("request");
    try writeAt(NodeType, &out, .{ .sequence_max_length = 8 }, "/request");
    try out.endObject();
    const parsed = try std.json.parseFromSlice(std.json.Value, t.allocator, output.written(), .{});
    defer parsed.deinit();
    const Check = struct {
        fn walk(root: std.json.Value, value: std.json.Value) anyerror!void {
            switch (value) {
                .object => |fields| {
                    if (fields.get("$ref")) |ref| {
                        try t.expect(std.mem.startsWith(u8, ref.string, "#/request/$defs/"));
                        var target = root;
                        var parts = std.mem.splitScalar(u8, ref.string[2..], '/');
                        while (parts.next()) |part| target = target.object.get(part) orelse return error.MissingSchemaReference;
                    }
                    for (fields.values()) |child| try walk(root, child);
                },
                .array => |items| for (items.items) |child| try walk(root, child),
                else => {},
            }
        }
    };
    try Check.walk(parsed.value, parsed.value);
}
