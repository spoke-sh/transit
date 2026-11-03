//! Offline oracle probe; the production package owns no process or I/O code.
const std = @import("std");
const profiles = @import("transit_document_profiles");

fn candidateBinding(descriptor: profiles.Profile.contract.Descriptor, part: profiles.Profile.contract.Part) !profiles.Profile.contract.Candidate.Binding {
    var manifest = try profiles.Profile.contract.Container.Commitment.init(descriptor.digest, 0);
    try manifest.addPart(part);
    // Synthetic offline attribution, never sent to or accepted by a data owner.
    return (profiles.Profile.contract.Candidate.Binding{
        .definition = descriptor.definition,
        .target = .{ .partition = .{ .definition = descriptor.definition, .interpretation = .{ .object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 4 }, .revision = 1, .digest = @splat(9) }, .partition = 0 }, .document = @splat(7) },
        .operation = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .principal = 8, .operation = 9 },
        .base = null,
        .interpretation = descriptor,
        .source = try manifest.finish(),
        .digest = undefined,
    }).sealed();
}

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
    const write_xml = std.mem.eql(u8, args[1], "xml-write");
    const write_json = std.mem.eql(u8, args[1], "json-write");
    const candidate_json = std.mem.eql(u8, args[1], "json-candidate");
    const candidate_xml = std.mem.eql(u8, args[1], "xml-candidate");
    const candidate_mime = std.mem.eql(u8, args[1], "mime-candidate");
    const use_candidate = candidate_json or candidate_xml or candidate_mime or write_json or write_xml;
    const format: profiles.Profile.contract.Format = if (write_json or candidate_json or std.mem.eql(u8, args[1], "json")) .json else if (write_xml or candidate_xml or std.mem.eql(u8, args[1], "xml")) .xml else if (candidate_mime or std.mem.eql(u8, args[1], "mime")) .mime else return error.InvalidArguments;
    const descriptor = try profiles.Profile.descriptor(format, limits);
    var json_frames: [32]profiles.Json.Frame = undefined;
    var xml_frames: [32]profiles.Xml.Frame = undefined;
    var names: [32 * 1024]u8 = undefined;
    var attributes: [32]profiles.Xml.Attribute = undefined;
    var decoded: [1024]u8 = undefined;
    const workspace: profiles.Reader.Workspace = switch (format) {
        .json => .{ .json = .{ .frames = &json_frames, .token = &token } },
        .xml => .{ .xml = .{ .frames = &xml_frames, .names = &names, .attributes = &attributes, .raw = &token, .decoded = &decoded } },
        .mime => .{ .mime = .{ .raw = &token, .unfolded = &decoded } },
        else => unreachable,
    };
    const source_part: profiles.Profile.contract.Part = .{
        .definition = descriptor.definition,
        .profile = descriptor.digest,
        .id = 1,
        .bytes = input.len,
        .sha256 = profiles.Profile.grammar(input).sha256,
        .coverage = .complete,
        .source = null,
    };
    var reader: profiles.Reader = undefined;
    var candidate: profiles.Candidate = undefined;
    if (use_candidate) {
        candidate = try profiles.Candidate.init(try candidateBinding(descriptor, source_part), source_part, workspace);
    } else reader = try profiles.Reader.init(descriptor, source_part, workspace);
    var writer_frames: [32]profiles.JsonWriter.Frame = undefined;
    var writer: profiles.JsonWriter = undefined;
    if (write_json) writer = try profiles.JsonWriter.init(descriptor, 2, &writer_frames);
    var xml_writer_frames: [32]profiles.XmlWriter.Frame = undefined;
    var xml_writer_names: [32 * 1024]u8 = undefined;
    var xml_writer_attributes: [32]profiles.XmlWriter.Attribute = undefined;
    var xml_writer_attribute_names: [1024]u8 = undefined;
    var xml_writer_encoded: [1025]u8 = undefined;
    var xml_writer: profiles.XmlWriter = undefined;
    if (write_xml) xml_writer = try profiles.XmlWriter.init(descriptor, 2, .{
        .frames = &xml_writer_frames,
        .names = &xml_writer_names,
        .attributes = &xml_writer_attributes,
        .attribute_names = &xml_writer_attribute_names,
        .encoded = &xml_writer_encoded,
    });
    var encoded: [23]u8 = undefined;
    var offset: usize = 0;
    var turns: usize = 0;
    while (turns < input.len * 4 + 100) : (turns += 1) {
        const end = @min(input.len, offset + chunk);
        var ticket: ?profiles.Candidate.Ticket = null;
        const step: profiles.Step = (if (use_candidate) candidate_step: {
            const next = candidate.next(input[offset..end], end == input.len, 7) catch |err| break :candidate_step err;
            const result: @FieldType(profiles.Step, "result") = switch (next.result) {
                .event => |pending| event: {
                    // A delayed consumer must see exactly the same event while
                    // all new input remains unconsumed, including zero-byte XML events.
                    const repeated = try candidate.next(input[offset..end], end == input.len, 1);
                    if (repeated.consumed != 0 or !std.meta.eql(pending.ticket, repeated.result.event.ticket)) return error.InvalidCandidateProgress;
                    ticket = pending.ticket;
                    break :event .{ .event = pending.event };
                },
                .need_input => .need_input,
                .yield => .yield,
                .verified => .complete,
            };
            break :candidate_step @as(anyerror!profiles.Step, .{ .consumed = next.consumed, .result = result });
        } else reader.next(input[offset..end], end == input.len, 7)) catch |err| {
            try out.print("error\t{s}\n", .{@errorName(err)});
            try out.flush();
            return;
        };
        offset += step.consumed;
        switch (step.result) {
            .event => |event| {
                if (write_json or write_xml) {
                    if (write_json) try writer.beginEvent(event) else try xml_writer.beginEvent(event);
                    while (if (write_json) writer.needsDrain() else xml_writer.needsDrain()) {
                        const count = if (write_json) try writer.drain(encoded[0..@min(encoded.len, chunk)], 5) else try xml_writer.drain(encoded[0..@min(encoded.len, chunk)], 5);
                        try out.writeAll("bytes\t");
                        for (encoded[0..count]) |byte| try out.print("{x:0>2}", .{byte});
                        try out.writeByte('\n');
                    }
                    try candidate.consume(ticket.?);
                    continue;
                }
                try out.print("{s}\t{d}\t{d}\t{d}\t", .{ @tagName(event.kind), event.span.byte_start, event.span.byte_end, event.depth });
                for (event.value) |byte| try out.print("{x:0>2}", .{byte});
                try out.writeByte('\t');
                for (event.detail) |byte| try out.print("{x:0>2}", .{byte});
                try out.writeByte('\n');
                if (ticket) |pending| try candidate.consume(pending);
            },
            .complete => {
                if (use_candidate) _ = try candidate.verifiedBinding() else _ = try reader.verifiedPart();
                if (write_json or write_xml) {
                    const part = if (write_json) try writer.finish() else try xml_writer.finish();
                    try out.print("complete\t{d}\t", .{part.bytes});
                    for (part.sha256) |byte| try out.print("{x:0>2}", .{byte});
                    try out.writeByte('\n');
                } else try out.writeAll("complete\n");
                try out.flush();
                return;
            },
            .need_input, .yield => {},
        }
    }
    return error.ParserDidNotFinish;
}
