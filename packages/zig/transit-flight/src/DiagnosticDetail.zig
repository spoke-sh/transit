//! Shared semantic evidence in an ordinary gRPC application binary trailer.
//! Never use grpc-status-details-bin: its upstream type is google.rpc.Status.
const std = @import("std");
const root = @import("root.zig");
const d = root.query.protocol.Diagnostic;
pub const header = "transit-diagnostic-bin";
pub const max_bytes = 4096;

/// Prefer full evidence. If it exceeds the metadata profile, shorten only
/// descriptive text/path values, marking truncation. Numeric identities,
/// measurements, commitments, original cause and recovery actions stay exact.
pub fn encode(original: d, output: *[max_bytes]u8) ![]const u8 {
    try original.validate();
    if (original.encode(output)) |bytes| return bytes else |_| {}
    var value = original;
    value.message = try d.Message.init("Diagnostic text was shortened to fit the Flight metadata budget. The original code, cause, outcome and numeric evidence are retained.");
    if (value.location) |*location| try shortLocation(location);
    for (&value.facts) |*slot| if (slot.*) |*fact| if (fact.value) |*item| switch (item.*) {
        .text => |text| if (text.slice().len > 64) {
            var end: usize = 64;
            while (!std.unicode.utf8ValidateSlice(text.slice()[0..end])) end -= 1;
            item.* = .{ .text = try d.Text.init(text.slice()[0..end]) };
            fact.availability = .truncated;
        },
        .location => |*location| try shortLocation(location),
        else => {},
    };
    if (value.encode(output)) |bytes| return bytes else |_| {}
    // Many large location facts can still exceed the transport's header bound.
    // Explicit unavailable facts preserve their field/origin instead of silently
    // inventing a short position, dropping counters, or changing the outcome.
    for (&value.facts) |*slot| if (slot.*) |*fact| if (fact.value) |item| switch (item) {
        .text, .location => {
            fact.value = null;
            fact.availability = .unavailable;
        },
        else => {},
    };
    value.message = try d.Message.init("Some diagnostic context is unavailable within the Flight metadata budget. The original code, cause, outcome and numeric evidence are retained.");
    return value.encode(output);
}
fn shortLocation(location: *d.Location) !void {
    const source = location.source orelse return;
    if (source.slice().len <= 64) return;
    var end: usize = 64;
    if (location.source_encoding == .escaped_bytes) {
        end = 0;
        while (end < source.slice().len) {
            const size: usize = if (source.slice()[end] == '\\') 4 else 1;
            if (end + size > 64) break;
            end += size;
        }
    } else while (!std.unicode.utf8ValidateSlice(source.slice()[0..end])) end -= 1;
    location.source = try d.Path.init(source.slice()[0..end]);
    location.source_truncated = true;
}

pub fn finish(response: *root.grpc.Server.Response, status: u8, message: []const u8, value: ?d) !void {
    if (value) |detail| {
        var buffer: [max_bytes]u8 = undefined;
        const bytes = encode(detail, &buffer) catch return response.finish(status, message);
        return response.finishBinary(status, message, header, bytes);
    }
    return response.finish(status, message);
}

test "metadata detail retains full normal evidence and bounds adversarial location/text expansion" {
    const t = std.testing;
    var value = try d.init("query.budget_exceeded", .limit, .execute, .rejected, .domain_status, "A budget was exceeded.");
    value.identity = .{ .domain = .query, .id = .init(std.math.maxInt(u64)) };
    try value.fact(.limit, .authority, .{ .unsigned = .init(std.math.maxInt(u64) - 1) });
    try value.fact(.required, .execution, .{ .unsigned = .init(std.math.maxInt(u64)) });
    try value.action(.inspect_status);
    var buffer: [max_bytes]u8 = undefined;
    const full = try d.decode(t.allocator, try encode(value, &buffer));
    try t.expectEqualDeep(value, full);
    var location: d.Location = .{ .offset = .init(std.math.maxInt(u64)), .length = .init(0), .line = .init(1), .byte_column = .init(1) };
    (try d.SourcePath.init(&@as([128]u8, @splat(255)))).apply(&location);
    value.location = location;
    for (0..14) |_| try value.fact(.parameter_use, .caller, .{ .location = location });
    const bounded = try d.decode(t.allocator, try encode(value, &buffer));
    try t.expectEqualStrings(value.code.slice(), bounded.code.slice());
    try t.expectEqualDeep(value.identity, bounded.identity);
    try t.expectEqualDeep(value.actions, bounded.actions);
    try t.expectEqualDeep(value.facts[0], bounded.facts[0]);
    try t.expectEqualDeep(value.facts[1], bounded.facts[1]);
    try t.expectEqual(.rejected, bounded.outcome);
    try t.expect(bounded.location.?.source_truncated);
    try t.expectEqual(@as(u64, std.math.maxInt(u64)), try bounded.location.?.offset.value());
}

/// The failed RPC alone establishes no outcome for earlier accepted work.
pub fn attempt(cause: anyerror, status: u8) !d {
    const info: struct { []const u8, d.Category, d.Stage, []const u8 } = switch (cause) {
        error.FlightUnauthenticated => .{ "flight.authentication_required", .access, .input, "Supply the configured Flight bearer credential. No protected source or saved result is disclosed." },
        error.FlightTicketScope => .{ "flight.ticket_scope", .access, .read, "The ticket does not belong to the current caller scope. Obtain a ticket through the authorized connection." },
        error.FlightTicketExpired => .{ "flight.ticket_expired", .lifecycle, .read, "The Flight ticket expired. Inspect the original query using its first request sequence; ticket expiry does not undo query execution." },
        error.FlightCallerCapacity => .{ "flight.caller_capacity", .limit, .admission, "Another call occupies this caller's bounded Flight capacity. Preserve any original statement and request sequence." },
        error.FlightSequenceConflict => .{ "flight.sequence_conflict", .conflict, .submit, "The supplied request sequence conflicts with recorded native history. Preserve the original statement and first sequence; do not choose a new sequence to bypass recovery." },
        error.InvalidFlightTicket => .{ "flight.invalid_ticket", .integrity, .read, "The Flight ticket is malformed or fails identity verification. Use the unmodified ticket issued for this connection." },
        error.InvalidQueryIdentity => .{ "flight.invalid_sequence", .binding, .input, "Provide a canonical positive native x-transit-request-sequence for GetFlightInfo. Preserve the original first sequence when recovering an earlier statement." },
        error.InvalidFlightCommand, error.InvalidFlightMetadata => .{ "flight.invalid_command", .binding, .input, "The request is not a supported Flight command or metadata shape. Inspect this connection's advertised SQL profile." },
        error.UnsupportedFlightCommand, error.UnsupportedFlightMetadata, error.UnsupportedFlightType, error.UnsupportedQuery => .{ "flight.unsupported_operation", .unsupported, .input, "This Flight interface supports finite read-only queries and its advertised metadata operations. Table writes require an authorized mutation interface." },
        error.DuplicateGrpcHeader => .{ "flight.duplicate_header", .syntax, .input, "An identity or framing header was supplied more than once. Supply each header exactly once." },
        error.Truncated, error.VarintOverflow, error.FieldNumberZero, error.FieldNumberOutOfRange, error.UnsupportedWireType, error.NonMinimalTag, error.DepthExceeded, error.InvalidUtf8, error.InvalidEnumValue, error.UnknownField => .{ "flight.invalid_encoding", .syntax, .decode, "The request violates the bounded protobuf command encoding. Check its declared message type and field encoding." },
        else => switch (status) {
            7 => .{ "flight.access_denied", .access, .read, "Current authorization does not permit this operation. Losing access does not establish the outcome of earlier work." },
            9 => .{ "flight.resource_unavailable", .lifecycle, .read, "The service or retained result is unavailable under its current lifecycle. Inspect its original identity; this read does not establish rollback or nonexistence." },
            8 => .{ "flight.capacity_exceeded", .limit, .admission, "The request exceeds bounded capacity or an allocation is unavailable. Preserve the original statement and request identity." },
            10 => .{ "flight.admission_conflict", .conflict, .admission, "Admission conflicts with current work. Preserve the original statement and request identity while inspecting its state." },
            14 => .{ "flight.unavailable", .unavailable, .read, "The RPC could not complete. Preserve the original statement and first request sequence; this failure does not establish its outcome." },
            else => .{ "flight.internal_failure", .internal, .read, "The Flight operation failed. Preserve original query identity and inspect its status; this failure does not establish its domain outcome." },
        },
    };
    var result = try d.init(info[0], info[1], info[2], .not_applicable, .none, info[3]);
    result.cause = try d.Code.init(@errorName(cause));
    if (info[1] == .access) try result.action(.inspect_scope) else if (info[1] == .internal or info[1] == .integrity) try result.action(.contact_operator);
    try result.validate();
    return result;
}

/// The fixed Flight request has not been sent. Report the first exceeding
/// dimension from the currently authorized policy, in stable field order.
pub fn budget(allowed: root.query.Bundle.Limits, requested: root.query.Bundle.Limits) !d {
    inline for (.{ "pages", "segments", "result_bytes" }) |field| if (@field(requested, field) > @field(allowed, field)) {
        var result = try d.init("query.budget_exceeded", .limit, .prepare, .not_submitted, .local_before_dispatch, "The Flight request budget exceeds the current source policy. Configure a permitted budget or use a query caller with explicit limits. No upload command was sent by this attempt.");
        result.cause = try d.Code.init("QueryBudgetExceeded");
        try result.text(.budget, .authority, field);
        try result.text(.unit, .authority, if (std.mem.eql(u8, field, "result_bytes")) "bytes" else field);
        try result.fact(.limit, .authority, .{ .unsigned = .init(@field(allowed, field)) });
        try result.fact(.required, .caller, .{ .unsigned = .init(@field(requested, field)) });
        try result.action(.inspect_scope);
        try result.validate();
        return result;
    };
    return error.InvalidDiagnosticBudget;
}

test "Flight policy budget retains exact first exceeding dimension without saved intent" {
    const limits: root.query.Bundle.Limits = .{ .pages = 4096, .segments = 63, .result_bytes = 240 * 1024 };
    inline for (.{ "pages", "segments", "result_bytes" }, 0..) |field, index| {
        var allowed = limits;
        @field(allowed, field) -= 1;
        const value = try budget(allowed, limits);
        try std.testing.expectEqualStrings(field, value.facts[0].?.value.?.text.slice());
        try std.testing.expectEqual(@field(allowed, field), try value.facts[2].?.value.?.unsigned.value());
        try std.testing.expectEqual(@field(limits, field), try value.facts[3].?.value.?.unsigned.value());
        try std.testing.expectEqual(.not_submitted, value.outcome);
        try std.testing.expectEqual(.local_before_dispatch, value.evidence);
        try std.testing.expectEqual(@as(?d.Identity, null), value.identity);
        _ = index;
    }
    try std.testing.expectError(error.InvalidDiagnosticBudget, budget(limits, limits));
}
