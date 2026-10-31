//! Complete, bounded single-source snapshots at one exact native current cut.
//! A concurrent source change refuses the whole result. No response claims a
//! retention pin or splices pages from different cuts.
const std = @import("std");
const Request = @import("BrowserRequest.zig");
const c = @import("transit_catalog");
const b = c.BrowserDeclarations;
const f = c.fuze;
pub const Cursor = struct { publication: b.Store.Revision, definition: c.protocol.DataLifecycle.Definition, watermark: u64 };
pub const Snapshot = struct { bytes: []u8, cursor: Cursor };

fn current(request: Request, publication: b.Publication, reader: c.DirectTableClient) !std.json.Parsed(c.DirectTableProtocol.Response) {
    return reader.call(.{ .observe = .{ .namespace = request.host.config.namespace, .interpretation = publication.source, .rows = null } }) catch |err| {
        if (request.wire.last_rejection == .TableDefinitionChanged) return error.TableDefinitionChanged;
        return err;
    };
}
fn sessionCredential(request: Request, audience: @FieldType(b.Publication, "audience"), cookie: ?[]const u8) !?b.Credential {
    var session = try request.session(cookie);
    defer if (session) |*value| value.deinit();
    if (audience == .public) return null;
    const identity = (session orelse return error.BindingRequired).value().identity;
    var binding = request.declaration(.binding, identity) catch |err| switch (err) {
        error.BrowserNotFound => return error.BindingRequired,
        else => return err,
    };
    defer binding.deinit();
    const value = binding.value().binding;
    if (!value.enabled or value.restricted) return error.IdentityRestricted;
    return try c.client.LocalEndpoint.clone(request.allocator, value.reader orelse return error.BindingRequired);
}
pub fn read(request: Request, name: []const u8, cookie: ?[]const u8, previous: ?Cursor) !?Snapshot {
    const allocator = request.allocator;
    var record = try request.declaration(.publication, b.Store.digest(name));
    defer record.deinit();
    const publication = record.value().publication;
    if (publication.descriptor.state != .published) return error.PublishedResourceWithdrawn;
    const credential = try sessionCredential(request, publication.audience, cookie);
    var publisher = try request.reader(publication.publisher);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&publisher.key));
    var caller = if (credential) |value| try request.reader(value) else publisher;
    defer std.crypto.secureZero(u8, std.mem.asBytes(&caller.key));
    const observed = try current(request, publication, caller);
    defer observed.deinit();
    // A bound caller and the publisher must each retain current native rights.
    if (credential != null) {
        const authorized = try current(request, publication, publisher);
        authorized.deinit();
    }
    const source = observed.value.result.observation.definition;
    const cursor: Cursor = .{ .publication = record.record.revision, .definition = publication.source, .watermark = source.changed_lsn };
    if (previous) |prior| {
        if (!std.meta.eql(prior.publication, cursor.publication) or !std.meta.eql(prior.definition, cursor.definition)) return error.PublishedResourceReset;
        if (prior.watermark == cursor.watermark) return null;
        if (prior.watermark > cursor.watermark) return error.PublishedResourceReset;
    }
    const schema_bytes = try source.schema.decode(allocator, f.TableSchema.max_bytes);
    defer allocator.free(schema_bytes);
    var schema = try f.TableSchema.decode(allocator, schema_bytes);
    defer schema.deinit();
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    var compiled = try f.TableSelect.compile(allocator, publication.descriptor.canonical_plan_or_sql, publication.source_name, try schema.schema.rowType(&fields), publication.source.digest, null);
    defer compiled.deinit();
    compiled.plan.collations = .fromTable(schema.schema);
    try compiled.plan.validate();
    if (compiled.plan.aggregate != .rows) return error.UnsupportedBrowserPublication;
    const output_type = try compiled.plan.outputSchema(&fields);
    if (output_type.structure.len != publication.descriptor.result_schema.columns.len) return error.PublicationSourceMismatch;
    for (output_type.structure, publication.descriptor.result_schema.columns) |actual, expected| {
        if (!std.mem.eql(u8, actual.name, expected.name) or !try actual.type.eql(expected.type) or actual.nullable != expected.nullable) return error.PublicationSourceMismatch;
    }
    const output_bytes = try allocator.alloc(u8, @min(publication.max_bytes, publication.descriptor.work_bound.max_bytes));
    var output_memory = std.heap.FixedBufferAllocator.init(output_bytes);
    const output_allocator = output_memory.allocator();
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(output_allocator);
    // Reserve the complete allowed response up front; no collection may exceed
    // it or hold borrowed row/scratch pointers across a native page boundary.
    try output.ensureTotalCapacityPrecise(output_allocator, output_bytes.len);
    try output.appendSlice(output_allocator, "{\"type\":\"snapshot\",\"view\":");
    const encoded_name = try c.protocol.Json.valueAlloc(allocator, name);
    defer allocator.free(encoded_name);
    try output.appendSlice(output_allocator, encoded_name);
    try output.appendSlice(output_allocator, ",\"columns\":");
    const columns = try allocator.alloc(c.BrowserContract.Column, publication.descriptor.result_schema.columns.len);
    for (columns, publication.descriptor.result_schema.columns) |*column, source_column| column.* = .{ .name = source_column.name, .type = source_column.type, .nullable = source_column.nullable };
    const encoded_schema = try c.protocol.Json.valueAlloc(allocator, columns);
    defer allocator.free(encoded_schema);
    try output.appendSlice(output_allocator, encoded_schema);
    try output.appendSlice(output_allocator, ",\"rows\":[");
    var scratch: std.heap.ArenaAllocator = .init(allocator);
    defer scratch.deinit();
    var after: ?f.TableRow.Identity = null;
    var counters: f.LogicalQuery.Counters = .{};
    var failure: ?f.LogicalQuery.Counters.FailureSite = null;
    var first = true;
    var pages: u64 = 0;
    const started = std.Io.Clock.awake.now(request.io);
    const max_rows = @min(publication.max_rows, publication.descriptor.work_bound.max_rows);
    while (true) {
        if (pages + 4 >= publication.descriptor.work_bound.max_iops or started.durationTo(std.Io.Clock.awake.now(request.io)).toMilliseconds() >= @min(publication.descriptor.work_bound.execution_timeout_ms, publication.descriptor.work_bound.max_cpu_micros / 1000)) return error.ResourceWorkBoundExceeded;
        _ = scratch.reset(.retain_capacity);
        const page = caller.call(.{ .read_current = .{ .namespace = request.host.config.namespace, .interpretation = publication.source, .expected = source.position, .selection = .{ .rows = .{ .after = after, .limits = .{ .rows = 8, .encoded_bytes = 65536 } } } } }) catch |err| {
            if (request.wire.last_rejection == .TableDefinitionChanged) return error.TableDefinitionChanged;
            if (request.wire.last_rejection == .Conflict) return error.PublishedSourceChanged;
            return err;
        };
        defer page.deinit();
        pages += 1;
        const rows = page.value.result.current_read.selection.rows;
        for (rows.rows) |encoded| {
            if (counters.scanned == max_rows) return error.ResourceWorkBoundExceeded;
            const bytes = try encoded.decode(scratch.allocator(), 65536);
            const row = try f.TableRow.decodeInto(scratch.allocator(), schema.schema, bytes);
            const cells = row.row().cells;
            if (try counters.observe(compiled.plan, cells, &failure)) {
                if (!first) try output.append(output_allocator, ',');
                first = false;
                try output.append(output_allocator, '[');
                for (compiled.plan.projection, 0..) |column, index| {
                    if (index != 0) try output.append(output_allocator, ',');
                    if (cells[column] == .missing) return error.MissingPublishedCell;
                    try c.PublishedProjection.appendPublishedCellJson(output_allocator, &output, cells[column]);
                    if (output.items.len > publication.max_bytes or output.items.len > publication.descriptor.work_bound.max_bytes) return error.ResourceWorkBoundExceeded;
                }
                try output.append(output_allocator, ']');
            }
            if (compiled.plan.limit) |limit| if (counters.selected >= limit) break;
        }
        if (compiled.plan.limit) |limit| if (counters.selected >= limit) break;
        after = rows.next;
        if (after == null) break;
    }
    const suffix = try std.fmt.allocPrint(allocator, "],\"attribution\":{{\"resource_object\":\"{d}\",\"publication_revision\":\"{d}\",\"source_object\":\"{d}\",\"source_revision\":\"{d}\",\"source_partition\":\"{d}\",\"source_next_lsn\":\"{d}\",\"watermark_lsn\":\"{d}\",\"row_count\":\"{d}\",\"retention\":\"current_cut_unpinned\",\"complete\":true}}}}", .{ publication.descriptor.resource_object, publication.descriptor.publication_revision, publication.source.object.object, publication.source.revision, source.position.partition, source.position.next_lsn, source.changed_lsn, counters.selected });
    defer allocator.free(suffix);
    try output.appendSlice(output_allocator, suffix);
    if (output.items.len > publication.max_bytes or output.items.len > publication.descriptor.work_bound.max_bytes) return error.ResourceWorkBoundExceeded;
    // Re-read declarations and session after buffering. Neither a cached key,
    // an old binding nor a completed scan substitutes for current rights.
    var latest = try request.declaration(.publication, b.Store.digest(name));
    defer latest.deinit();
    if (latest.value().publication.descriptor.state != .published) return error.PublishedResourceWithdrawn;
    if (!std.meta.eql(latest.record.revision, record.record.revision)) return error.PublishedResourceReset;
    const latest_credential = try sessionCredential(request, publication.audience, cookie);
    if (!sameCredential(credential, latest_credential)) return error.IdentityBindingChanged;
    // Resolve enabled secret references again too. Native checks independently
    // reject revoked keys/grants and changed source definitions.
    var final_caller = try request.reader(latest_credential orelse publication.publisher);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&final_caller.key));
    const final = try current(request, publication, final_caller);
    defer final.deinit();
    const final_source = final.value.result.observation.definition;
    if (!source.position.unchangedAt(final_source.position, final_source.changed_lsn)) return error.PublishedSourceChanged;
    if (latest_credential != null) {
        var final_publisher = try request.reader(publication.publisher);
        defer std.crypto.secureZero(u8, std.mem.asBytes(&final_publisher.key));
        const authorized = try current(request, publication, final_publisher);
        authorized.deinit();
    }
    // Exhaustion does not exempt the final page (or the final authority reads)
    // from the declared elapsed-work bound. Check authority first so a revoked
    // buffered result retains its policy refusal rather than a budget outcome.
    if (started.durationTo(std.Io.Clock.awake.now(request.io)).toMilliseconds() >= @min(publication.descriptor.work_bound.execution_timeout_ms, publication.descriptor.work_bound.max_cpu_micros / 1000)) return error.ResourceWorkBoundExceeded;
    return .{ .bytes = try output.toOwnedSlice(output_allocator), .cursor = cursor };
}

fn sameCredential(a: ?b.Credential, other: ?b.Credential) bool {
    const first = a orelse return other == null;
    const second = other orelse return false;
    return first.principal == second.principal and first.role == second.role and std.mem.eql(u8, first.secret, second.secret);
}
