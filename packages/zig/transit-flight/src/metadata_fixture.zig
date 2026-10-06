//! Independent clients consume bytes produced by the real metadata builder.
const std = @import("std");
const flight = @import("transit_flight");
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 4) return error.ExpectedCommandInputOutput;
    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, args[2], init.gpa, .limited(1024));
    defer init.gpa.free(input);
    const workspace = try init.gpa.alloc(u8, flight.Metadata.working_bytes);
    defer init.gpa.free(workspace);
    var output: [16384]u8 = undefined;
    const type_url = try std.fmt.allocPrint(init.gpa, "{s}{s}", .{ flight.command_prefix, args[1] });
    defer init.gpa.free(type_url);
    const f = flight.query.fuze;
    const bytes = bytes: {
        if (std.mem.eql(u8, args[1], "WideQuerySchema")) {
            var fields: [128]f.Types.Field = undefined;
            var names: [128][32]u8 = undefined;
            for (&fields, &names, 0..) |*field, *name, i| field.* = .{
                .name = try std.fmt.bufPrint(name, "column_{d}", .{i}),
                .type = .int64,
                .nullable = i % 3 == 0,
            };
            break :bytes try flight.Metadata.querySchema("people", .{ .structure = &fields }, input, &output, workspace);
        }
        if (std.mem.eql(u8, args[1], "MixedQuerySchema")) {
            const schema: f.Types.Type = .{ .structure = &.{
                .{ .name = "id", .type = .int64, .nullable = true },
                .{ .name = "full name", .type = .utf8 },
                .{ .name = "value", .type = .int64 },
            } };
            break :bytes try flight.Metadata.querySchema("東京\"people", schema, input, &output, workspace);
        }
        const encoded = try flight.Metadata.encode(.{ .type_url = type_url, .value = input }, "counter", .{ .structure = &.{ .{ .name = "id", .type = .int64 }, .{ .name = "count", .type = .int64, .nullable = true } } }, &output, workspace);
        _ = try flight.Ipc.parts(encoded, workspace);
        break :bytes encoded;
    };
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = args[3], .data = bytes });
}
