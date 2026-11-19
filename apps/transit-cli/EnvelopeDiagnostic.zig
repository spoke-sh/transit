//! Human projection of typed evidence. All owner/caller text is terminal inert.
const std = @import("std");
const d = @import("transit_query").protocol.Diagnostic;

pub fn escaped(out: *std.Io.Writer, bytes: []const u8) !void {
    for (bytes) |byte| switch (byte) {
        0x20...0x7e => try out.writeByte(byte),
        else => try out.print("\\x{x:0>2}", .{byte}),
    };
}
pub fn render(value: d, out: *std.Io.Writer) !void {
    return renderFor(value, out, false);
}
pub fn renderConsole(value: d, out: *std.Io.Writer) !void {
    return renderFor(value, out, true);
}
fn renderFor(value: d, out: *std.Io.Writer, console: bool) !void {
    try value.validate();
    const source_failure = std.mem.startsWith(u8, value.code.slice(), "application.source.");
    if (source_failure) if (value.location) |at| {
        try location(out, at);
        try out.writeAll(": ");
    };
    try out.writeAll("error: ");
    try escaped(out, value.message.slice());
    if (console) try out.print("\nCode: {s}.\n", .{value.code.slice()}) else try out.print("\nCode: {s}; stage: {s}.\n", .{ value.code.slice(), @tagName(value.stage) });
    if (!source_failure) if (value.location) |at| {
        try out.writeAll("Location: ");
        try location(out, at);
        try out.writeByte('\n');
    };
    if (value.cause) |cause| try out.print("Cause: {s}.\n", .{cause.slice()});
    if (!console) if (value.identity) |identity| try out.print("{s} {d}: {s}.\n", .{ @tagName(identity.domain), try identity.id.value(), @tagName(value.outcome) });
    for (value.facts) |slot| if (slot) |fact| {
        if (console) switch (fact.field) {
            .operation, .source_basis, .dependency_owner, .emitted_segments => continue,
            else => {},
        };
        try out.print("{s}: ", .{switch (fact.field) {
            .source_row => "Scan row",
            .source_key => "Source key",
            .column => "Column",
            .operation => "Operation",
            .expression => "Predicate instruction (zero-based)",
            .source_basis => "Frozen plan/source fingerprint",
            .source_kind => "Source kind",
            .object => "Resource",
            .expected_revision => "Source revision",
            .expected_type => "Expected type",
            .actual_type => "Actual type",
            .actual_source => if (source_failure) "Path (escaped bytes)" else "Actual source",
            .first_occurrence => "Related location",
            .completion => "Complete result",
            .budget => "Budget",
            .limit => "Limit",
            .required => "Required",
            .emitted_rows => "Rows already emitted",
            .emitted_segments => "Segments already emitted",
            .dependency => "Blocking dependency",
            .dependency_kind => "Dependency kind",
            .dependency_owner => "Dependency owner PID",
            else => @tagName(fact.field),
        }});
        if (fact.value) |item| switch (item) {
            .text => |text| try escaped(out, text.slice()),
            .signed => |number| try out.print("{d}", .{try number.value()}),
            .unsigned => |number| try out.print("{d}", .{try number.value()}),
            .boolean => |boolean| try out.writeAll(if (boolean) "yes" else "no"),
            .digest => |digest| try out.print("{x}", .{&digest}),
            .location => |at| try location(out, at),
        } else try out.writeAll(@tagName(fact.availability));
        if (fact.availability == .truncated) try out.writeAll(" [truncated]");
        try out.writeByte('\n');
    };
    for (value.actions) |slot| if (slot) |action| {
        // Source owners supply a correction in their family-specific message.
        if (source_failure and action.kind == .correct_input) continue;
        if (console) switch (action.kind) {
            .inspect_status, .resume_exact, .cancel_wait, .cancel_mutation, .reconcile_effect, .contact_operator => continue,
            else => {},
        };
        switch (action.kind) {
            .correct_input => try out.writeAll("Correct the reported input or source problem before starting new work.\n"),
            .inspect_scope => try out.writeAll("Inspect the current permissions and declaration of the named target.\n"),
            .inspect_status => try out.writeAll("Inspect the recorded outcome through its owning interface.\n"),
            .recompile => try out.writeAll("Prepare the statement again against the current source declaration.\n"),
            .resume_exact => try out.writeAll("Reconcile the saved operation with its original identity and bytes.\n"),
            .cancel_wait => try out.writeAll("Cancel the saved wait through its owning query interface; already disclosed results remain disclosed.\n"),
            .cancel_mutation => try out.writeAll("Request cancellation through the mutation's owning interface; inspect the resulting outcome.\n"),
            .reconcile_effect => try out.writeAll("Use the connector's reconciliation policy for the saved effect; its remote outcome is not established.\n"),
            .refresh => try out.writeAll("Refresh the authorized source metadata.\n"),
            .retry_read => try out.writeAll("Retry the read under current permissions.\n"),
            .contact_operator => try out.writeAll("Preserve the operation evidence and ask the operator to inspect this failure.\n"),
        }
    };
    if (source_failure and value.outcome == .not_submitted) try out.writeAll("No SQL was submitted.\n");
}
pub fn location(out: *std.Io.Writer, at: d.Location) !void {
    if (at.source) |source| {
        try escaped(out, source.slice());
        if (at.source_truncated) try out.writeAll(" [truncated]");
        if (at.source_encoding == .escaped_bytes) try out.writeAll(" [escaped bytes]");
        try out.print(":{d}:{d}", .{ try at.line.value(), try at.byte_column.value() });
    } else try out.print("line {d}, byte column {d}", .{ try at.line.value(), try at.byte_column.value() });
}
test "source diagnostics show primary and related filenames with safe terminal text" {
    var value = try d.init("application.source.type", .binding, .bind, .not_submitted, .local_before_dispatch, "Use the declared operand type.");
    value.location = .{ .source = try d.Path.init("modules/rows.transit"), .offset = .init(19), .length = .init(1), .line = .init(2), .byte_column = .init(5) };
    var call = value.location.?;
    call.source = try d.Path.init("build\x1b.transit");
    try value.fact(.first_occurrence, .caller, .{ .location = call });
    try value.action(.correct_input);
    var out: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer out.deinit();
    try render(value, &out.writer);
    const text = out.written();
    try std.testing.expect(std.mem.indexOf(u8, text, "modules/rows.transit:2:5: error:") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "build\\x1b.transit:2:5") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "Correct the reported") == null);
    try std.testing.expect(std.mem.indexOfScalar(u8, text, 0x1b) == null);
}
