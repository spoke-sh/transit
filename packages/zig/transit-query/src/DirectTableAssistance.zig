//! Completion over current direct metadata, without a data snapshot or query.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const f = q.fuze;
const a = q.Assistance;
const grammar = q.TableAssistance;
const w = c.DirectTableProtocol;
pub const Response = a.Response;
const Metadata = struct { binding: c.DirectTableBinding, schema: f.TableSchema.Owned };
fn lookup(allocator: std.mem.Allocator, client: c.DirectTableClient, namespace: u64, name: []const u8) !?Metadata {
    const response = try client.call(.{ .lookup = .{ .namespace = namespace, .name = name } });
    defer response.deinit();
    const value = response.value.result.lookup orelse return null;
    const bytes = try value.schema.decode(allocator, f.TableSchema.max_bytes);
    defer allocator.free(bytes);
    return .{ .binding = try c.DirectTableBinding.init(client.connection, value), .schema = try f.TableSchema.decode(allocator, bytes) };
}
pub fn complete(allocator: std.mem.Allocator, client: c.DirectTableClient, namespace: u64, request: a.Request) !Response {
    const span = try f.SqlInput.active(request.sql, request.cursor, request.mode == .console);
    var result = try completeStatement(allocator, client, namespace, .{ .sql = request.sql[span.start..span.end], .cursor = request.cursor - span.start, .generation = request.generation, .mode = request.mode });
    if (result.range) |*range| {
        range.start += span.start;
        range.end += span.start;
    }
    return result;
}
fn completeStatement(allocator: std.mem.Allocator, client: c.DirectTableClient, namespace: u64, request: a.Request) !Response {
    _ = try client.require(.{ .namespace = namespace, .target = null, .access = .schema });
    const range = try f.SqlInput.replacement(request.sql, request.cursor);
    var arena: std.heap.ArenaAllocator = .init(allocator);
    defer arena.deinit();
    const temporary = arena.allocator();
    var checks: [1 + f.Relational.max_sources + a.max_items]w.ReadCheck = undefined;
    checks[0] = .{ .access = .{ .namespace = namespace, .target = null, .access = .schema } };
    var count: usize = 1;
    var result: Response = .{ .generation = request.generation, .coverage = .complete, .status = if (range == null) .inside_text else .ready, .profile = .direct_table_v1, .resource = client.connection.scope.resource, .resource_revision = null, .contract = undefined, .policy_revision = undefined, .range = range, .items = &.{} };
    const command_end = std.mem.indexOfAny(u8, request.sql, " \t\r\n") orelse request.sql.len;
    const schema_command = request.mode == .console and request.cursor > command_end and std.mem.eql(u8, request.sql[0..command_end], ".schema");
    if (request.mode == .console and std.mem.startsWith(u8, request.sql, ".") and !schema_command) {
        const meta = try a.meta(allocator, request);
        result.range = meta.range;
        result.items = meta.items;
        result.coverage = meta.coverage;
        result.status = meta.status;
    } else if (range) |selected| {
        var prefix = request.sql[selected.start..request.cursor];
        if (selected.quoted and prefix.len != 0) {
            prefix = prefix[1..];
            if (std.mem.endsWith(u8, prefix, "\"")) prefix = prefix[0 .. prefix.len - 1];
            prefix = try std.mem.replaceOwned(u8, temporary, prefix, "\"\"", "\"");
        }
        var builder: grammar.Builder = .{ .allocator = allocator, .prefix = prefix, .quoted = selected.quoted };
        errdefer builder.clear();
        const full = if (schema_command) "" else try grammar.statement(temporary, request.sql);
        const text = if (schema_command) "DESCRIBE " else try grammar.statement(temporary, request.sql[0..selected.start]);
        const relational = f.RelationalSql.required(full) catch |err| blk: {
            try grammar.ignored(err);
            break :blk false;
        };
        var editor: f.SqlTyped.Editor = undefined;
        if (relational) {
            var targets: [f.Relational.max_sources]f.RelationalSql.Target = undefined;
            const discovered = f.RelationalSql.discoverTargets(temporary, full, &targets) catch |err| blk: {
                try grammar.ignored(err);
                break :blk 0;
            };
            var definitions: [f.Relational.max_sources]?Metadata = @splat(null);
            defer for (&definitions) |*slot| if (slot.*) |*value| value.schema.deinit();
            var declarations: [f.Relational.max_sources]grammar.RelationalSource = undefined;
            var found: usize = 0;
            for (targets[0..discovered], 0..) |input, i| {
                definitions[i] = try lookup(temporary, client, namespace, input.name);
                if (definitions[i]) |value| {
                    declarations[found] = .{ .alias = input.alias, .schema = value.schema.schema };
                    found += 1;
                    checks[count] = .{ .access = .{ .namespace = namespace, .target = value.binding.interpretation.interpretation, .access = .inspect } };
                    count += 1;
                }
            }
            editor = try grammar.relationalExpectations(temporary, text, declarations[0..found]);
            try grammar.relationalSuggestions(&builder, editor, declarations[0..found]);
        } else {
            const name = grammar.target(temporary, full) catch |err| blk: {
                try grammar.ignored(err);
                break :blk null;
            };
            var definition = if (name) |value| try lookup(temporary, client, namespace, value) else null;
            defer if (definition) |*value| value.schema.deinit();
            const source: ?grammar.Source = if (definition) |*value| .{ .name = value.binding.name.slice(), .schema = value.schema.schema } else null;
            if (definition) |value| {
                checks[count] = .{ .access = .{ .namespace = namespace, .target = value.binding.interpretation.interpretation, .access = .inspect } };
                count += 1;
            }
            editor = try grammar.expectations(temporary, text, source);
            const qualifier = if (definition) |*value| f.TableSelect.targetQualifier(temporary, full) catch value.binding.name.slice() else null;
            try grammar.suggestions(&builder, editor, source, qualifier);
            if (name != null and definition == null and editor.name_role != .source) {
                builder.clear();
                builder.count = 0;
                result.status = .unsupported;
            }
        }
        if (editor.name_role == .source) {
            var names: Names = .{};
            var cursor: ?u64 = null;
            for (0..128) |_| {
                const response = try client.call(.{ .list = .{ .namespace = namespace, .after = cursor } });
                defer response.deinit();
                const page = response.value.result.list;
                for (page.entries) |slot| if (slot) |entry| {
                    try names.offer(&builder, entry);
                };
                cursor = page.next;
                if (cursor == null) break;
            }
            if (cursor != null) builder.limited = true;
            for (names.retained) |slot| if (slot) |entry| {
                checks[count] = .{ .access = .{ .namespace = namespace, .target = entry.interpretation, .access = .inspect } };
                count += 1;
            };
        }
        result.coverage = if (builder.limited) .limited else .complete;
        if (editor.name_role == null and editor.value_type == null and editor.words[0] == null and editor.symbols[0] == null) result.status = .unsupported;
        result.items = try allocator.dupe(a.Item, builder.items[0..builder.count]);
    }
    errdefer (a.Completion{ .range = result.range, .items = result.items }).deinit(allocator);
    // One current policy revision and exact interpretation checks cover every
    // disclosed name/column. No native resource revision is invented for this
    // independent metadata vector.
    const checked = try client.call(.{ .check_set = checks[0..count] });
    defer checked.deinit();
    const bytes = try c.protocol.Json.valueAlloc(temporary, .{ .definition = c.protocol.Growth.current_definition, .connection = client.connection, .checks = checks[0..count] });
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.table.direct.assistance.v1\x00");
    hash.update(bytes);
    result.contract = hash.finalResult();
    result.policy_revision = try std.fmt.allocPrint(allocator, "{d}", .{checked.value.policy_revision});
    return result;
}

/// Ranking can replace an earlier candidate after the shortlist fills. Retain
/// the exact definition of every displayed name for the final authority check.
const Names = struct {
    retained: [a.max_items]?c.DirectCatalog.Listed = @splat(null),

    fn offer(self: *Names, builder: *grammar.Builder, entry: c.DirectCatalog.Listed) !void {
        try builder.add(entry.name.slice(), .source, "Authorized Table");
        const items = builder.items[0..builder.count];
        for (&self.retained) |*slot| if (slot.*) |prior| {
            if (!contains(items, prior.name.slice())) slot.* = null;
        };
        if (!contains(items, entry.name.slice())) return;
        for (self.retained) |slot| if (slot) |prior| {
            if (std.meta.eql(prior.name, entry.name)) {
                if (!std.meta.eql(prior.interpretation, entry.interpretation)) return error.CatalogCursorChanged;
                return;
            }
        };
        for (&self.retained) |*slot| if (slot.* == null) {
            slot.* = entry;
            return;
        };
        unreachable; // There are at most max_items distinct displayed names.
    }
    fn contains(items: []const a.Item, name: []const u8) bool {
        for (items) |item| {
            if (item.kind != .source) continue;
            var offset: usize = 1;
            const matches = for (name) |byte| {
                if (offset >= item.text.len or item.text[offset] != byte) break false;
                offset += 1;
                if (byte == '"') {
                    if (offset >= item.text.len or item.text[offset] != '"') break false;
                    offset += 1;
                }
            } else true;
            if (matches and offset + 1 == item.text.len and item.text[0] == '"' and item.text[offset] == '"') return true;
        }
        return false;
    }
};

test "ranked direct names keep only their exact disclosed definitions" {
    const t = std.testing;
    var builder: grammar.Builder = .{ .allocator = t.allocator, .prefix = "", .quoted = false };
    defer builder.clear();
    var names: Names = .{};
    for ([_][]const u8{ "z", "y", "x", "w", "v", "u", "t", "s", "a\"b" }, 1..) |name, id| {
        try names.offer(&builder, .{ .name = try .init(name), .namespace = 1, .interpretation = .{ .object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = id }, .revision = 1, .digest = @splat(0) }, .position = .{ .partition = 1, .next_lsn = 1 }, .changed_lsn = 0 });
    }
    try t.expect(builder.limited);
    try t.expectEqualStrings("\"a\"\"b\"", builder.items[0].text);
    var count: usize = 0;
    var replaced = false;
    for (names.retained) |slot| if (slot) |entry| {
        count += 1;
        try t.expect(entry.interpretation.object.object != 1);
        if (entry.interpretation.object.object == 9) replaced = true;
    };
    try t.expectEqual(a.max_items, count);
    try t.expect(replaced);
    var changed = names.retained[0].?;
    changed.interpretation.revision += 1;
    try t.expectError(error.CatalogCursorChanged, names.offer(&builder, changed));
}
