//! Offline oracle probe; the production package owns no process or I/O code.
const std = @import("std");
const profiles = @import("transit_document_profiles");

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 4) return error.InvalidArguments;
    const chunk = try std.fmt.parseInt(usize, args[2], 10);
    if (chunk == 0) return error.InvalidArguments;
    var input_storage: [8192]u8 = undefined;
    const input = try std.fmt.hexToBytes(&input_storage, args[3]);
    var output_storage: [8192]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &output_storage);
    const out = &output.interface;
    const limits: profiles.Profile.contract.Limits = .{
        .input_bytes = input_storage.len,
        .expanded_bytes = input_storage.len,
        .expansion_ratio = 1,
        .parts = 1,
        .nodes = 8192,
        .depth = 32,
        .token_bytes = 1024,
        .attributes = 32,
        .diagnostics = 1,
        .work = 256 * 1024,
    };
    var token: [1024]u8 = undefined;
    const format: profiles.Profile.contract.Format = if (std.mem.eql(u8, args[1], "json")) .json else if (std.mem.eql(u8, args[1], "xml")) .xml else return error.InvalidArguments;
    const descriptor = try profiles.Profile.descriptor(format, limits);
    var json_frames: [32]profiles.Json.Frame = undefined;
    var xml_frames: [32]profiles.Xml.Frame = undefined;
    var names: [32 * 1024]u8 = undefined;
    var attributes: [32]profiles.Xml.Attribute = undefined;
    var decoded: [1024]u8 = undefined;
    const workspace: profiles.Reader.Workspace = switch (format) {
        .json => .{ .json = .{ .frames = &json_frames, .token = &token } },
        .xml => .{ .xml = .{ .frames = &xml_frames, .names = &names, .attributes = &attributes, .raw = &token, .decoded = &decoded } },
        else => unreachable,
    };
    var reader = try profiles.Reader.init(descriptor, .{
        .definition = descriptor.definition,
        .profile = descriptor.digest,
        .id = 1,
        .bytes = input.len,
        .sha256 = profiles.Profile.grammar(input).sha256,
        .coverage = .complete,
        .source = null,
    }, workspace);
    var offset: usize = 0;
    var turns: usize = 0;
    while (turns < input.len * 4 + 100) : (turns += 1) {
        const end = @min(input.len, offset + chunk);
        const step = reader.next(input[offset..end], end == input.len, 7) catch |err| {
            try out.print("error\t{s}\n", .{@errorName(err)});
            try out.flush();
            return;
        };
        offset += step.consumed;
        switch (step.result) {
            .event => |event| {
                try out.print("{s}\t{d}\t{d}\t{d}\t", .{ @tagName(event.kind), event.span.byte_start, event.span.byte_end, event.depth });
                for (event.value) |byte| try out.print("{x:0>2}", .{byte});
                try out.writeByte('\t');
                for (event.detail) |byte| try out.print("{x:0>2}", .{byte});
                try out.writeByte('\n');
            },
            .complete => {
                _ = try reader.verifiedPart();
                try out.writeAll("complete\n");
                try out.flush();
                return;
            },
            .need_input, .yield => {},
        }
    }
    return error.ParserDidNotFinish;
}
