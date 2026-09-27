//! Canonical finite request bytes; borrowed plan/source arrays die with their
//! input and bounded arena. Publication is immutable transport, not admission.
const std = @import("std");
const q = @import("root.zig");
const m = q.fuze.Unified;
const Self = @This();
pub const max_bytes = 16384;
pub const format: u32 = 0x32425155; // UQB2
source: q.SourceDefinition,
plan: m.Plan,
limits: Limits,
pub const Limits = struct {
    pages: u64,
    segments: u64,
    result_bytes: u64,
    pub fn validate(self: Limits) !void {
        if (self.pages == 0 or self.segments == 0 or self.result_bytes == 0) return error.InvalidQueryBudget;
    }
    pub fn permits(self: Limits, requested: Limits) bool {
        return requested.pages <= self.pages and requested.segments <= self.segments and requested.result_bytes <= self.result_bytes;
    }
};
pub fn validate(self: Self) !void {
    try self.limits.validate();
    var columns: [m.max_columns]m.Column = undefined;
    try self.plan.validate(try self.source.schema(&columns));
}
pub fn encode(self: Self, output: []u8) ![]const u8 {
    try self.validate();
    var source_bytes: [q.SourceDefinition.max_bytes]u8 = undefined;
    var plan_bytes: [m.Codec.max_plan_bytes]u8 = undefined;
    const source = try self.source.encode(&source_bytes);
    const plan = try m.Codec.encode(self.plan, &plan_bytes);
    if (32 + source.len + plan.len > max_bytes) return error.QueryBundleTooLarge;
    var writer: std.Io.Writer = .fixed(output);
    try writer.writeAll("UQB2");
    try writer.writeInt(u16, @intCast(source.len), .little);
    try writer.writeInt(u16, @intCast(plan.len), .little);
    inline for (.{ "pages", "segments", "result_bytes" }) |name| try writer.writeInt(u64, @field(self.limits, name), .little);
    try writer.writeAll(source);
    try writer.writeAll(plan);
    return writer.buffered();
}
pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !Self {
    if (bytes.len > max_bytes) return error.QueryBundleTooLarge;
    var reader: std.Io.Reader = .fixed(bytes);
    if (!std.mem.eql(u8, try reader.take(4), "UQB2")) return error.InvalidQueryBundle;
    const source_length = try reader.takeInt(u16, .little);
    const plan_length = try reader.takeInt(u16, .little);
    const limits: Limits = .{ .pages = try reader.takeInt(u64, .little), .segments = try reader.takeInt(u64, .little), .result_bytes = try reader.takeInt(u64, .little) };
    const result: Self = .{
        .limits = limits,
        .source = try q.SourceDefinition.decode(allocator, try reader.take(source_length)),
        .plan = try m.Codec.decode(try reader.take(plan_length)),
    };
    if (reader.bufferedLen() != 0) return error.InvalidQueryBundle;
    try result.validate();
    return result;
}
pub fn reference(self: Self, resource: u64, namespace: u64) !q.station.PublicationReference {
    var buffer: [max_bytes]u8 = undefined;
    const result: q.station.PublicationReference = .{ .resource = resource, .namespace = namespace, .record = 1, .spec = try q.station.Publication.Digest.of(format, try self.encode(&buffer)) };
    try checkReference(result);
    return result;
}
pub fn checkReference(ref: q.station.PublicationReference) !void {
    try ref.validate();
    if (ref.record != 1 or ref.spec.format != format or ref.spec.length < 32 or ref.spec.length > max_bytes) return error.InvalidQueryBundle;
}
/// A policy-bound request resource is still not a substitute for its publisher.
pub fn checkPublisher(ref: q.station.PublicationReference, source: anytype, peer: u64) !void {
    try checkReference(ref);
    var reader = try source.open(ref.resource);
    const descriptor = try ref.publication().inspect(&reader, ref.record);
    if (descriptor.state != .published or !std.meta.eql(descriptor.spec, ref.spec) or descriptor.publisher != peer) return error.UnexpectedQueryPublisher;
}
/// The declaration permits changing only the accepted Document revision. Epoch,
/// type, format, paths and decoders remain fenced by the durable source policy.
pub fn declaration(source: q.SourceDefinition) ![32]u8 {
    var normalized = source;
    if (normalized.source == .document) normalized.source.document.reference.revision = 1;
    return normalized.fingerprint();
}
