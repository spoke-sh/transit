//! Component-owned file diagnostic projections; no file or authority reads.
const std = @import("std");
const owner = @import("FileDiagnostic.zig");
const d = @import("transit_query").protocol.Diagnostic;
const base: owner = .{ .stage = .execute, .path = null, .location = .{}, .output_started = false, .limited = false, .max_record_bytes = 65536, .max_records = 100, .max_scan_bytes = 1000000 };
fn emit(out: *std.Io.Writer, family: []const u8, variant: []const u8, scenario: []const u8, detail: d) !void {
    try detail.validate();
    const Fact = struct { field: d.Field, origin: d.Origin, availability: d.Availability };
    var facts: [16]?Fact = @splat(null);
    for (detail.facts, 0..) |slot, index| if (slot) |fact| {
        facts[index] = .{ .field = fact.field, .origin = fact.origin, .availability = fact.availability };
    };
    try std.json.Stringify.value(.{ .family = family, .variant = variant, .scenario = scenario, .code = detail.code.slice(), .category = detail.category, .stage = detail.stage, .outcome = detail.outcome, .evidence = detail.evidence, .identity = detail.identity, .facts = facts, .actions = detail.actions }, .{}, out);
    try out.writeByte('\n');
}
pub fn main(init: std.process.Init) !void {
    var buffer: [8192]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    for (owner.codes.entries) |entry| {
        try emit(&stdout.interface, "file.caller", @errorName(entry.cause), "execute", try base.structured(entry.cause));
        var schema = base;
        schema.stage = .schema;
        schema.schema_file = true;
        try emit(&stdout.interface, "file.caller", @errorName(entry.cause), "schema_file", try schema.structured(entry.cause));
    }
    try stdout.interface.flush();
}

test "file registry projects every known cause without fabricating completion or saved work" {
    for (owner.codes.entries, 0..) |entry, index| {
        for (owner.codes.entries[0..index]) |earlier| try std.testing.expect(earlier.cause != entry.cause);
        inline for (comptime std.meta.tags(owner.Stage)) |stage| {
            var context = base;
            context.stage = stage;
            context.output_started = true;
            const detail = try context.structured(entry.cause);
            try detail.validate();
            try std.testing.expectEqual(.not_applicable, detail.outcome);
            try std.testing.expect(detail.identity == null);
            try std.testing.expectEqual(false, detail.facts[0].?.value.?.boolean);
            for (detail.actions) |slot| if (slot) |action| try std.testing.expect(action.kind != .resume_exact and action.kind != .cancel_wait and action.kind != .cancel_mutation);
            var bytes: [8192]u8 = undefined;
            var writer: std.Io.Writer = .fixed(&bytes);
            try context.render(&writer, entry.cause, .{});
            try std.testing.expect(std.mem.indexOf(u8, writer.buffered(), "Any emitted output is incomplete") != null);
        }
    }
}

test "file unknown callbacks and storage context preserve original failure and incomplete output" {
    const shape = try base.structured(error.InvalidColumnCount);
    try std.testing.expectEqualStrings("file.invalid_row_shape", shape.code.slice());
    try std.testing.expectEqual(.integrity, shape.category);
    try std.testing.expectEqual(false, shape.facts[0].?.value.?.boolean);
    try std.testing.expectEqual(.contact_operator, shape.actions[0].?.kind);
    const unknown = try base.structured(error.UnregisteredCallbackFailure);
    try std.testing.expectEqualStrings("file.internal_failure", unknown.code.slice());
    try std.testing.expectEqual(.internal, unknown.category);
    try std.testing.expectEqualStrings("UnregisteredCallbackFailure", unknown.cause.?.slice());
    try std.testing.expectEqual(.contact_operator, unknown.actions[0].?.kind);
    var capture = base;
    capture.stage = .capture;
    capture.capture_failure = .{ .phase = .capture_write, .directory = "/private-test" };
    const unavailable = try capture.structured(error.UnregisteredCallbackFailure);
    try std.testing.expectEqualStrings("file.capture_storage_unavailable", unavailable.code.slice());
    try std.testing.expectEqual(.unavailable, unavailable.category);
    try std.testing.expectEqual(.not_applicable, unavailable.outcome);
    try std.testing.expectEqualStrings("file.memory_unavailable", (try capture.structured(error.OutOfMemory)).code.slice());
    try std.testing.expectEqualStrings("file.interrupted", (try capture.structured(error.FileQueryInterrupted)).code.slice());
    var scalar = base;
    scalar.location.conversion = .init(.{}, .int64, .{ .number_string = "9223372036854775808" });
    const overflow = try scalar.structured(error.Overflow);
    try std.testing.expectEqualStrings("file.scalar_out_of_range", overflow.code.slice());
    try std.testing.expectEqual(.decode, overflow.stage);
    try std.testing.expectEqualStrings("file.arithmetic_overflow", (try base.structured(error.Overflow)).code.slice());
}

test "file I/O context retains OS causes and distinguishes schema reads and gzip framing" {
    const t = std.testing;
    var context = base;
    context.stage = .capture;
    context.capture_failure = .{ .phase = .source_open, .system_errno = @backingInt(std.c.E.ACCES) };
    const denied = try context.structured(error.SourceOpenFailed);
    try t.expectEqualStrings("file.source_unavailable", denied.code.slice());
    try t.expectEqualStrings("ACCES", denied.cause.?.slice());
    var bytes: [4096]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    try context.render(&writer, error.SourceOpenFailed, .{});
    try t.expect(std.mem.indexOf(u8, writer.buffered(), "Local filesystem permissions denied access") != null);
    context.capture_failure = .{ .phase = .decompress };
    try t.expectEqualStrings("file.invalid_gzip", (try context.structured(error.EndOfStream)).code.slice());
    try t.expectEqualStrings("file.truncated_input", (try base.structured(error.EndOfStream)).code.slice());
    context.capture_failure = null;
    context.schema_read_failure = true;
    const schema = try context.structured(error.UnregisteredCallbackFailure);
    try t.expectEqualStrings("file.schema_read_unavailable", schema.code.slice());
    try t.expectEqual(.input, schema.stage);
    try t.expectEqual(.unavailable, schema.category);
    try t.expectEqualStrings("UnregisteredCallbackFailure", schema.cause.?.slice());
    try t.expectEqual(.retry_read, schema.actions[0].?.kind);
    try t.expect(schema.identity == null);
}
