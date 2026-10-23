//! Human projection of typed evidence. All owner/caller text is terminal inert.
const std = @import("std");
const d = @import("transit_query").protocol.Diagnostic;

fn escaped(out: *std.Io.Writer, bytes: []const u8) !void {
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
    try out.writeAll("error: ");
    try escaped(out, value.message.slice());
    if (console) try out.print("\nCode: {s}.\n", .{value.code.slice()}) else try out.print("\nCode: {s}; stage: {s}.\n", .{ value.code.slice(), @tagName(value.stage) });
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
            .location => |location| try out.print("line {d}, byte column {d}", .{ try location.line.value(), try location.byte_column.value() }),
        } else try out.writeAll(@tagName(fact.availability));
        if (fact.availability == .truncated) try out.writeAll(" [truncated]");
        try out.writeByte('\n');
    };
    for (value.actions) |slot| if (slot) |action| {
        if (console) switch (action.kind) {
            .inspect_status, .resume_exact, .cancel_wait, .cancel_mutation, .reconcile_effect, .contact_operator => continue,
            else => {},
        };
        switch (action.kind) {
            .correct_input => try out.writeAll("Correct the reported input or source problem before starting new work.\n"),
            .inspect_scope => try out.writeAll("Inspect the current permissions and declaration of the named target.\n"),
            .inspect_status => try out.writeAll(if (value.identity != null and switch (value.identity.?.domain) {
                .query, .mutation, .catalog => true,
                else => false,
            }) "Use .status to inspect the recorded outcome for this exact operation.\n" else "Inspect the recorded outcome through its owning interface.\n"),
            .recompile => try out.writeAll("Prepare the statement again against the current source declaration.\n"),
            .resume_exact => try out.writeAll(if (value.identity != null and (value.identity.?.domain == .query or value.identity.?.domain == .mutation or value.identity.?.domain == .catalog)) "Use .resume to reconcile the saved operation with its original identity and bytes.\n" else "Reconcile the saved operation with its original identity and bytes.\n"),
            .cancel_wait => try out.writeAll("Cancel the saved wait through its owning query interface; already disclosed results remain disclosed.\n"),
            .cancel_mutation => try out.writeAll("Use .cancel to request cancellation of the saved mutation; inspect the resulting outcome.\n"),
            .reconcile_effect => try out.writeAll("Use the connector's reconciliation policy for the saved effect; its remote outcome is not established.\n"),
            .refresh => try out.writeAll("Refresh the authorized source metadata.\n"),
            .retry_read => try out.writeAll("Retry the read under current permissions.\n"),
            .contact_operator => try out.writeAll("Preserve the operation evidence and ask the operator to inspect this failure.\n"),
        }
    };
}
