//! Completion over current direct metadata, without a data snapshot or query.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const f = q.fuze;
const a = q.Assistance;
const grammar = q.TableAssistance;
const w = c.DirectTableProtocol;
pub const Response = struct { resource: u64, contract: [32]u8, policy_revision: []const u8, range: ?f.SqlInput.Range, items: []const a.Item };
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
    _ = try client.require(.{ .namespace = namespace, .target = null, .access = .schema });
    const range = try f.SqlInput.replacement(request.sql, request.cursor);
    var arena: std.heap.ArenaAllocator = .init(allocator);
    defer arena.deinit();
    const temporary = arena.allocator();
    var checks: [1 + f.Relational.max_sources + a.max_items]w.ReadCheck = undefined;
    checks[0] = .{ .access = .{ .namespace = namespace, .target = null, .access = .schema } };
    var count: usize = 1;
    var result: Response = .{ .resource = client.connection.scope.resource, .contract = undefined, .policy_revision = undefined, .range = range, .items = &.{} };
    const schema_command = request.mode == .console and request.cursor >= 8 and std.mem.startsWith(u8, request.sql, ".schema ");
    if (request.mode == .console and std.mem.startsWith(u8, request.sql, ".") and !schema_command) {
        const meta = try a.meta(allocator, request);
        result.range = meta.range;
        result.items = meta.items;
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
        }
        if (editor.name_role == .source) {
            var cursor: ?u64 = null;
            for (0..128) |_| {
                const response = try client.call(.{ .list = .{ .namespace = namespace, .after = cursor } });
                defer response.deinit();
                const page = response.value.result.list;
                for (page.entries) |slot| if (slot) |entry| {
                    const before = builder.count;
                    try builder.add(entry.name.slice(), .source, "Authorized Table");
                    if (builder.count != before) {
                        checks[count] = .{ .access = .{ .namespace = namespace, .target = entry.interpretation, .access = .inspect } };
                        count += 1;
                    }
                };
                cursor = page.next;
                if (cursor == null or builder.count == builder.items.len) break;
            }
        }
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
