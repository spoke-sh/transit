//! Owned caller-facing write evidence. Rendering never reads or retries work.
const std = @import("std");
const q = @import("transit_query");
const c = @import("transit_catalog");
const Self = @This();
heading: []const u8,
code: []const u8,
message: [512]u8 = @splat(0),
length: usize = 0,
next: ?[]const u8 = null,

pub fn mutation(name: q.fuze.model.Name, request: q.TableMutationRequest, status: q.TableMutationRecords.Status) !Self {
    try status.validate();
    if (status.phase != .rejected or status.table != request.table or !std.meta.eql(status.reference, try request.reference(status.reference.namespace))) return error.InvalidConsoleRecovery;
    var self: Self = .{ .heading = "Mutation Error", .code = @tagName(status.reason) };
    var out: std.Io.Writer = .fixed(&self.message);
    switch (status.reason) {
        .row_exists => {
            const conflict = status.conflict.?;
            if (request.plan.operation != .insert) return error.InvalidConsoleRecovery;
            const row = request.plan.operation.insert[conflict.row - 1] orelse return error.InvalidConsoleRecovery;
            if (row.key != conflict.key) return error.InvalidConsoleRecovery;
            self.heading = "Constraint Error";
            try out.writeAll("Duplicate key ");
            var key_buffer: [64]u8 = undefined;
            try quoted(&out, try std.fmt.bufPrint(&key_buffer, "{s}: {d}", .{ request.plan.schema.names[0].slice(), conflict.key }));
            try out.writeAll(" violates the primary key constraint on ");
            try quoted(&out, name.slice());
            try out.print(".\nInput row: {d}. No rows were inserted.", .{conflict.row});
        },
        .source_changed => {
            try out.writeAll("The target Table definition changed before the mutation could apply. No rows were changed.");
            self.next = "Use .schema writer to inspect its current definition before preparing a new statement.";
        },
        .invalid_request => {
            try out.writeAll("The writer rejected the immutable mutation request as invalid. No rows were changed.");
            self.next = "Preserve the saved request and check that the caller and writer use the same contract definition.";
        },
        .denied => {
            self.heading = "Authorization Error";
            try out.writeAll("The writer's current mutation policy does not permit this request. No rows were changed.");
            self.next = "Check the Table writer's policy and revision for this principal. Query read access does not grant writes.";
        },
        .budget => {
            self.heading = "Limit Error";
            try out.writeAll("The writer could not fit the mutation and its outcome within the turn's mutation budget. No rows were changed.");
            self.next = "Check the writer's turn composition. Splitting one atomic statement changes its semantics.";
        },
        .none => return error.InvalidConsoleRecovery,
    }
    self.length = out.end;
    return self;
}

pub fn input(reason: q.TableMutationWriter.Rejection, active: bool) Self {
    var self: Self = .{ .heading = "Mutation Input Error", .code = @tagName(reason) };
    var out: std.Io.Writer = .fixed(&self.message);
    out.writeAll(switch (reason) {
        .invalid_command => "The writer could not decode this mutation command.",
        .denied => "The current principal or mutation policy does not permit this command.",
        .identity_conflict => "This command conflicts with the recorded mutation identity.",
        .busy => "The writer already has an active mutation upload.",
        .not_found => "The referenced mutation has no recorded upload.",
        .not_active => "The referenced mutation is not the writer's active upload.",
        .upload_closed => "The mutation upload is closed to additional parts.",
        .not_sealed => "The mutation upload has not been sealed for application.",
        .invalid_part => "An upload part conflicts with the immutable request or its bounds.",
        .incomplete_upload => "The upload is missing required request bytes.",
        .source_changed => "The target Table definition no longer matches this command.",
        .stale_policy => "The command's expected mutation policy revision is stale.",
    }) catch unreachable;
    out.writeAll(if (active) "\nThis input was rejected; the saved mutation is still active." else "\nThis input was rejected. It does not replace an existing terminal mutation outcome.") catch unreachable;
    self.length = out.end;
    self.next = if (active) "Use .status to inspect the saved mutation and .cancel to request closure. Preserve the original recovery file; repeating the SQL creates new work." else "Use .status to inspect the recorded input and any original terminal mutation outcome.";
    return self;
}

pub fn creation(request: c.Model.CreateTable, outcome: c.Model.Outcome) !Self {
    var self: Self = .{ .heading = "Catalog Error", .code = @tagName(outcome) };
    var out: std.Io.Writer = .fixed(&self.message);
    switch (outcome) {
        .name_conflict => {
            try out.writeAll("The name ");
            try quoted(&out, request.name.slice());
            try out.writeAll(" is already bound in the configured catalog.");
            self.next = "Use SHOW TABLES to inspect that catalog and choose a different name for a new declaration.";
        },
        .object_conflict => try out.print("Object identity {d} is already occupied in the configured catalog.", .{request.object}),
        .table_conflict => try out.print("Table identity {d} is already occupied in the target resource.", .{request.table}),
        .applied => return error.InvalidConsoleRecovery,
    }
    try out.writeAll("\nThis CREATE TABLE did not create a Table.");
    self.length = out.end;
    return self;
}

pub fn catalogInput(outcome: @FieldType(c.Model.Disposition, "outcome")) !Self {
    var self: Self = .{ .heading = "Catalog Input Error", .code = @tagName(outcome) };
    var out: std.Io.Writer = .fixed(&self.message);
    try out.writeAll(switch (outcome) {
        .invalid_command => "The catalog could not decode the creation command.",
        .denied => "The current principal or catalog policy does not permit this command.",
        .identity_conflict => "This command conflicts with the recorded catalog operation identity.",
        .stale_policy => "The command's expected catalog policy revision is stale.",
        .initialized, .policy_applied => return error.InvalidConsoleRecovery,
    });
    try out.writeAll("\nThis input was rejected; it did not create a Table.");
    self.length = out.end;
    self.next = "Use .status to inspect the saved input. Preserve its original operation identity; CREATE TABLE cannot be cancelled.";
    return self;
}

fn quoted(out: *std.Io.Writer, value: []const u8) !void {
    try out.writeByte('"');
    for (value) |byte| switch (byte) {
        '"', '\\' => {
            try out.writeByte('\\');
            try out.writeByte(byte);
        },
        0x20...0x21, 0x23...0x5b, 0x5d...0x7e => try out.writeByte(byte),
        else => try out.print("\\x{x:0>2}", .{byte}),
    };
    try out.writeByte('"');
}

pub fn render(self: Self, out: *std.Io.Writer, style: @import("Style.zig")) !void {
    try style.text(out, .failure, self.heading);
    try out.writeAll(":\n");
    try out.writeAll(self.message[0..self.length]);
    try out.writeByte('\n');
    if (self.next) |next| {
        try out.writeByte('\n');
        try style.hint(out, next);
        try out.writeByte('\n');
    }
}
