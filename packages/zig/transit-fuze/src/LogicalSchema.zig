//! Reflected structural JSON Schemas for recursive logical documents. Semantic
//! ranges/traits and global budgets remain checked by the shared logical codec.
const std = @import("std");
const json = @import("LogicalJson.zig");
const types = @import("Types.zig");
const Graph = struct {
    nodes: [128]type = @splat(void),
    count: usize = 0,
    fn add(self: *Graph, comptime T: type) void {
        for (self.nodes[0..self.count]) |node| if (node == T) return;
        if (self.count == self.nodes.len) @compileError("Logical schema type graph exceeded its explicit bound");
        self.nodes[self.count] = T;
        self.count += 1;
        switch (@typeInfo(T)) {
            .@"struct" => |info| for (info.field_types) |F| self.add(F),
            .@"union" => |info| for (info.field_types) |F| self.add(F),
            .pointer => |info| if (info.size == .one or info.child != u8) self.add(info.child),
            .optional, .array => |info| self.add(info.child),
            else => {},
        }
    }
    fn index(comptime self: Graph, comptime T: type) usize {
        inline for (self.nodes[0..self.count], 0..) |node, i| if (node == T) return i;
        @compileError("Logical schema reference is missing");
    }
};
fn field(out: *std.json.Stringify, name: []const u8, value: anytype) !void {
    try out.objectField(name);
    try out.write(value);
}
fn reference(comptime graph: Graph, comptime T: type, out: *std.json.Stringify) !void {
    try out.beginObject();
    try field(out, "$ref", std.fmt.comptimePrint("#/$defs/T{d}", .{comptime graph.index(T)}));
    try out.endObject();
}
pub fn write(comptime T: type, out: *std.json.Stringify) !void {
    @setEvalBranchQuota(500000);
    const graph = comptime blk: {
        var graph: Graph = .{};
        graph.add(T);
        break :blk graph;
    };
    try out.beginObject();
    try field(out, "$ref", "#/$defs/T0");
    try out.objectField("$defs");
    try out.beginObject();
    inline for (graph.nodes[0..graph.count], 0..) |Node, index| {
        try out.objectField(std.fmt.comptimePrint("T{d}", .{index}));
        try writeNode(graph, Node, out);
    }
    try out.endObject();
    try out.endObject();
}
fn writeNode(comptime graph: Graph, comptime T: type, out: *std.json.Stringify) anyerror!void {
    try out.beginObject();
    switch (@typeInfo(T)) {
        .@"struct" => |info| {
            try field(out, "type", "object");
            try field(out, "additionalProperties", false);
            try out.objectField("properties");
            try out.beginObject();
            inline for (info.field_names, info.field_types) |name, F| {
                try out.objectField(name);
                if (comptime (T == json.TypeEnvelope or T == json.Envelope) and std.mem.eql(u8, name, "definition")) {
                    try out.beginObject();
                    try field(out, "const", types.definition);
                    try out.endObject();
                } else try reference(graph, F, out);
            }
            try out.endObject();
            try out.objectField("required");
            try out.beginArray();
            inline for (info.field_names, info.field_types, info.field_attrs) |name, F, attrs| if (comptime attrs.defaultValue(F) == null) try out.write(name);
            try out.endArray();
        },
        .@"union" => |info| {
            try out.objectField("oneOf");
            try out.beginArray();
            inline for (info.field_names, info.field_types) |name, F| {
                try out.beginObject();
                try field(out, "type", "object");
                try field(out, "additionalProperties", false);
                try field(out, "required", &[_][]const u8{name});
                try out.objectField("properties");
                try out.beginObject();
                try out.objectField(name);
                try reference(graph, F, out);
                try out.endObject();
                try out.endObject();
            }
            try out.endArray();
        },
        .@"enum" => |info| {
            try field(out, "type", "string");
            try field(out, "enum", info.field_names);
        },
        .void => {
            try field(out, "type", "object");
            try field(out, "maxProperties", 0);
        },
        .bool => try field(out, "type", "boolean"),
        .int => {
            try field(out, "type", "integer");
            try field(out, "minimum", std.math.minInt(T));
            try field(out, "maximum", std.math.maxInt(T));
        },
        .pointer => |info| {
            if (info.size == .one) {
                try field(out, "$ref", std.fmt.comptimePrint("#/$defs/T{d}", .{comptime graph.index(info.child)}));
            } else if (info.size == .slice and info.child == u8) {
                try field(out, "type", "string");
                try field(out, "maxLength", json.max_input_bytes);
            } else if (info.size == .slice) {
                try field(out, "type", "array");
                try field(out, "maxItems", 65536);
                try out.objectField("items");
                try reference(graph, info.child, out);
            } else @compileError("Unsupported logical JSON pointer");
        },
        .optional => |info| {
            try out.objectField("anyOf");
            try out.beginArray();
            try reference(graph, info.child, out);
            try out.write(.{ .type = "null" });
            try out.endArray();
        },
        .array => |info| {
            try field(out, "type", "array");
            try field(out, "minItems", info.len);
            try field(out, "maxItems", info.len);
            try out.objectField("items");
            try reference(graph, info.child, out);
        },
        else => @compileError("Unsupported logical JSON schema node"),
    }
    try out.endObject();
}
