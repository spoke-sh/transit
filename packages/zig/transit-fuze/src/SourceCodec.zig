//! Frozen discovery bindings. Restore requires already acquired matching source
//! handles and rechecks current authority; it never opens a path or refetches.
const std = @import("std");
const types = @import("Types.zig");
const source = @import("FileSource.zig");
pub const max_bytes = 32768;
pub fn encode(binding: *const source.Binding, output: []u8) ![]const u8 {
    var writer: std.Io.Writer = .fixed(output[0..@min(output.len, max_bytes)]);
    try binding.validateMetadata();
    try writer.writeAll("FSB1");
    try writer.writeByte(source.definition.len);
    try writer.writeAll(source.definition);
    const o = binding.options;
    try writer.writeAll(&.{ @intFromBool(o.format == .jsonl), @backingInt(o.mode), @backingInt(o.mismatch), o.dialect.delimiter, o.dialect.quote, @intFromBool(o.dialect.header) });
    for ([_]u64{ o.sample_records, o.sample_bytes, o.max_scan_bytes, o.max_records, o.max_record_bytes, o.max_fields }) |number| try writer.writeInt(u64, number, .little);
    try writer.writeByte(@intCast(o.dialect.null_tokens.len));
    for (o.dialect.null_tokens) |token| {
        try writer.writeInt(u16, @intCast(token.len), .little);
        try writer.writeAll(token);
    }
    var descriptor: [types.max_encoding_bytes]u8 = undefined;
    const schema = try binding.schema.type.encode(&descriptor);
    try writer.writeInt(u16, @intCast(schema.len), .little);
    try writer.writeAll(schema);
    try writer.writeInt(u64, binding.evidence.records, .little);
    try writer.writeInt(u64, binding.evidence.sampled_bytes, .little);
    try writer.writeByte(@intFromBool(binding.evidence.complete));
    try writer.writeByte(@intCast(binding.schema.type.structure.len));
    for (binding.origins[0..binding.schema.type.structure.len]) |origin| try writer.writeByte(@backingInt(origin));
    try writer.writeAll(&binding.sources_digest);
    try writer.writeAll(&binding.digest);
    return writer.buffered();
}
pub fn decode(allocator: std.mem.Allocator, bytes: []const u8, sources: []const source.Source) !source.Binding {
    if (bytes.len > max_bytes) return error.SourceBudgetExceeded;
    var reader: std.Io.Reader = .fixed(bytes);
    if (!std.mem.eql(u8, try reader.take(4), "FSB1")) return error.InvalidSourceEncoding;
    if (!std.mem.eql(u8, try reader.take(try reader.takeByte()), source.definition)) return error.IncompatibleDefinition;
    const format: @import("FileFraming.zig").Format = switch (try reader.takeByte()) {
        0 => .csv,
        1 => .jsonl,
        else => return error.InvalidSourceEncoding,
    };
    const mode = std.enums.fromInt(source.Mode, try reader.takeByte()) orelse return error.InvalidSourceEncoding;
    const mismatch = std.enums.fromInt(source.Mismatch, try reader.takeByte()) orelse return error.InvalidSourceEncoding;
    const delimiter = try reader.takeByte();
    const quote = try reader.takeByte();
    const header = try boolean(&reader);
    var o: source.Options = .{
        .format = format,
        .mode = mode,
        .mismatch = mismatch,
        .dialect = .{ .delimiter = delimiter, .quote = quote, .header = header },
        .sample_records = try reader.takeInt(u64, .little),
        .sample_bytes = try reader.takeInt(u64, .little),
        .max_scan_bytes = try reader.takeInt(u64, .little),
        .max_records = try reader.takeInt(u64, .little),
        .max_record_bytes = std.math.cast(u32, try reader.takeInt(u64, .little)) orelse return error.InvalidSourceBudget,
        .max_fields = std.math.cast(u16, try reader.takeInt(u64, .little)) orelse return error.InvalidSourceBudget,
    };
    var tokens: [16][]const u8 = undefined;
    const count = try reader.takeByte();
    if (count > tokens.len) return error.InvalidDialect;
    for (tokens[0..count]) |*token| token.* = try reader.take(try reader.takeInt(u16, .little));
    o.dialect.null_tokens = tokens[0..count];
    try o.validate();
    var schema = try types.decode(allocator, try reader.take(try reader.takeInt(u16, .little)));
    errdefer schema.deinit();
    if (schema.type != .structure or schema.type.structure.len > o.max_fields) return error.InvalidExplicitSchema;
    const evidence: source.Evidence = .{ .records = try reader.takeInt(u64, .little), .sampled_bytes = try reader.takeInt(u64, .little), .complete = try boolean(&reader) };
    if (evidence.records > o.max_records or evidence.sampled_bytes > o.max_scan_bytes or
        (o.mode == .sampled and (evidence.records > o.sample_records or evidence.sampled_bytes > o.sample_bytes))) return error.InvalidSourceEncoding;
    const origin_count = try reader.takeByte();
    if (origin_count != schema.type.structure.len) return error.InvalidSourceEncoding;
    var origins: [128]source.Origin = @splat(.raw);
    for (origins[0..origin_count]) |*origin| origin.* = std.enums.fromInt(source.Origin, try reader.takeByte()) orelse return error.InvalidSourceEncoding;
    const source_digest = (try reader.take(32))[0..32].*;
    const digest = (try reader.take(32))[0..32].*;
    if (reader.bufferedLen() != 0) return error.InvalidSourceEncoding;
    const owned_tokens = try schema.arena.allocator().alloc([]const u8, count);
    for (tokens[0..count], owned_tokens) |token, *owned| owned.* = try schema.arena.allocator().dupe(u8, token);
    o.dialect.null_tokens = owned_tokens;
    var binding: source.Binding = .{
        .schema = schema,
        .options = o,
        .options_digest = try o.fingerprint(),
        .sources_digest = source_digest,
        .digest = digest,
        .evidence = evidence,
        .origins = origins,
    };
    try binding.validate(sources);
    return binding;
}
fn boolean(reader: *std.Io.Reader) !bool {
    return switch (try reader.takeByte()) {
        0 => false,
        1 => true,
        else => error.InvalidSourceEncoding,
    };
}
