//! Public offline declaration consumer. The ANTLR oracle lives in Python.
const std = @import("std");
const f = @import("transit_fuze");
const View = struct {
    definition: f.Declaration.Definition,
    pub fn jsonStringify(self: *const View, out: anytype) !void {
        try out.beginObject();
        try out.objectField("name");
        try out.write(self.definition.name.slice());
        try out.objectField("kind");
        try out.write(@tagName(self.definition.body));
        switch (self.definition.body) {
            .table => |columns| {
                try out.objectField("columns");
                try out.beginArray();
                for (columns) |slot| {
                    const column = slot orelse break;
                    try out.write(.{ .name = column.name.slice(), .type = column.type, .nullability = column.nullability });
                }
                try out.endArray();
            },
            .kv => |value| {
                try out.objectField("type");
                try out.write(value);
            },
            .document => {},
        }
        try out.endObject();
    }
};

pub fn main(init: std.process.Init) !void {
    const a = init.arena.allocator();
    const args = try init.minimal.args.toSlice(a);
    if (args.len != 2) return error.Usage;
    const cases = try std.json.parseFromSlice([]const []const u8, a, try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], a, .limited(1024 * 1024)), .{});
    var buffer: [8192]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    for (cases.value, 0..) |sql, index| {
        const parsed = f.Sql.parseDeclaration(sql) catch |err| {
            try std.json.Stringify.value(.{ .index = index, .parse_error = @errorName(err) }, .{}, &stdout.interface);
            try stdout.interface.writeByte('\n');
            continue;
        };
        const definition = parsed orelse return error.NotDeclaration;
        const view: View = .{ .definition = definition };
        definition.validate() catch |err| {
            try std.json.Stringify.value(.{ .index = index, .ast = view, .validation_error = @errorName(err) }, .{}, &stdout.interface);
            try stdout.interface.writeByte('\n');
            continue;
        };
        if (!std.meta.eql(definition, try f.Declaration.compile(sql))) return error.CompilerDrift;
        var output: [4096]u8 = undefined;
        const formatted = try definition.format(&output);
        if (!std.meta.eql(definition, try f.Declaration.compile(formatted))) return error.FormatRoundTrip;
        if (definition.tableSchema()) |schema| {
            try std.json.Stringify.value(.{ .index = index, .ast = view, .formatted = formatted, .schema = std.fmt.bytesToHex(try schema.fingerprint(), .lower) }, .{}, &stdout.interface);
        } else |err| {
            try std.json.Stringify.value(.{ .index = index, .ast = view, .formatted = formatted, .table_error = @errorName(err) }, .{}, &stdout.interface);
        }
        try stdout.interface.writeByte('\n');
    }
    try stdout.interface.flush();
}
