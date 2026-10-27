//! General typed DML compiler consumer. Python supplies independent SQL/schema
//! expectations and canonical payload bytes; this is not native admission.
const std = @import("std");
const f = @import("transit_station").fuze;
const Case = struct { sql: []const u8, basis: []const u8 };
fn hex(allocator: std.mem.Allocator, bytes: []const u8) ![]const u8 {
    const result = try allocator.alloc(u8, bytes.len * 2);
    const alphabet = "0123456789abcdef";
    for (bytes, 0..) |byte, i| {
        result[i * 2] = alphabet[byte >> 4];
        result[i * 2 + 1] = alphabet[byte & 15];
    }
    return result;
}
fn emit(init: std.process.Init, out: *std.Io.Writer, case: Case, index: usize) !void {
    var declaration = try f.TableDdl.compile(init.gpa, case.basis, null, null);
    defer declaration.deinit();
    const table = declaration.statement.create;
    const schema = try table.bind(7);
    var compiled = try f.TableDml.compile(init.gpa, case.sql, table.name, schema, null);
    defer compiled.deinit();
    const buffer = try init.gpa.alloc(u8, f.TableDmlCodec.max_bytes);
    defer init.gpa.free(buffer);
    const encoded = try f.TableDmlCodec.encode(init.gpa, compiled.plan, buffer);
    var decoded = try f.TableDmlCodec.decode(init.gpa, schema, encoded);
    defer decoded.deinit();
    if (!std.mem.eql(u8, &try compiled.plan.fingerprint(init.gpa), &try decoded.plan.fingerprint(init.gpa))) return error.IntentRoundTripChanged;
    try std.json.Stringify.value(.{ .index = index, .bytes = try hex(init.arena.allocator(), encoded) }, .{}, out);
}
pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);
    if (args.len != 2) return error.Usage;
    const cases = try std.json.parseFromSlice([]const Case, allocator, try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], allocator, .limited(4 * 1024 * 1024)), .{});
    var buffer: [8192]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    for (cases.value, 0..) |case, index| {
        emit(init, &stdout.interface, case, index) catch |err| {
            try std.json.Stringify.value(.{ .index = index, .err = @errorName(err) }, .{}, &stdout.interface);
        };
        try stdout.interface.writeByte('\n');
    }
    try stdout.interface.flush();
}
