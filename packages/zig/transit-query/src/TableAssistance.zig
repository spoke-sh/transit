//! Bounded Table completion from production parsers and freshly authorized
//! catalog metadata. No SQL is executed and no persisted intent is prepared.
const std = @import("std");
const q = @import("root.zig");
const f = q.fuze;
const c = q.catalog;
const a = q.Assistance;
const Parser = f.SqlTyped;
const max_pages = 128;
const grammar = q.TableCompletionGrammar;

pub fn complete(allocator: std.mem.Allocator, client: *c.TableClient, request: a.Request) !a.Response {
    const span = try f.SqlInput.active(request.sql, request.cursor, request.mode == .console);
    var result = try completeStatement(allocator, client, .{ .sql = request.sql[span.start..span.end], .cursor = request.cursor - span.start, .generation = request.generation, .mode = request.mode });
    if (result.range) |*range| {
        range.start += span.start;
        range.end += span.start;
    }
    return result;
}
fn completeStatement(allocator: std.mem.Allocator, client: *c.TableClient, request: a.Request) !a.Response {
    var range = try f.SqlInput.replacement(request.sql, request.cursor);
    var advanced = false;
    var pages: usize = 0;
    const initial = try client.describe();
    var hash: std.crypto.hash.sha2.Sha256 = .init(.{});
    hash.update(&c.TableMetadata.definition());
    for ([_]u64{ client.connection.scope.realm, client.connection.scope.resource, client.connection.scope.catalog, client.connection.owner, client.connection.principal, initial.resource_revision, initial.authorization_revision }) |id| {
        var bytes: [8]u8 = undefined;
        std.mem.writeInt(u64, &bytes, id, .little);
        hash.update(&bytes);
    }
    var response: a.Response = .{ .generation = request.generation, .coverage = .complete, .status = if (range == null) .inside_text else .ready, .profile = .catalog_v1, .resource = client.connection.scope.resource, .contract = hash.finalResult(), .resource_revision = initial.resource_revision, .policy_revision = try std.fmt.allocPrint(allocator, "{d}", .{initial.authorization_revision}), .range = range, .items = &.{} };
    errdefer allocator.free(response.policy_revision);
    var arena: std.heap.ArenaAllocator = .init(allocator);
    defer arena.deinit();
    const command_end = std.mem.indexOfAny(u8, request.sql, " \t\r\n") orelse request.sql.len;
    const schema_command = request.mode == .console and request.cursor > command_end and std.mem.eql(u8, request.sql[0..command_end], ".schema");
    if (request.mode == .console and std.mem.startsWith(u8, request.sql, ".") and !schema_command) {
        const result = try a.meta(allocator, request);
        response.range = result.range;
        response.items = result.items;
        response.coverage = result.coverage;
        response.status = result.status;
    } else while (range) |selected| {
        var prefix = request.sql[selected.start..request.cursor];
        if (selected.quoted and prefix.len != 0) {
            prefix = prefix[1..];
            if (std.mem.endsWith(u8, prefix, "\"")) prefix = prefix[0 .. prefix.len - 1];
            prefix = try std.mem.replaceOwned(u8, arena.allocator(), prefix, "\"\"", "\"");
        }
        var builder: grammar.Builder = .{ .allocator = allocator, .prefix = prefix, .quoted = selected.quoted };
        errdefer builder.clear();
        const full = if (schema_command) "" else try grammar.statement(arena.allocator(), request.sql);
        const selected_text = if (schema_command) "DESCRIBE " else try grammar.statement(arena.allocator(), request.sql[0..selected.start]);
        const is_relational = f.RelationalSql.required(full) catch |err| blk: {
            try grammar.ignored(err);
            break :blk false;
        };
        const name = if (is_relational) null else grammar.target(arena.allocator(), full) catch |err| blk: {
            try grammar.ignored(err);
            break :blk null;
        };
        var definition: ?c.TableCatalog.Definition = if (name) |value| try client.lookup(arena.allocator(), try .init(value)) else null;
        defer if (definition) |*value| value.deinit();
        const source: ?grammar.Source = if (definition) |*value| .{ .name = value.metadata.name.slice(), .schema = value.schema.schema } else null;
        var editor = if (is_relational) try grammar.relationalExpectations(arena.allocator(), selected_text, &.{}) else try grammar.expectations(arena.allocator(), selected_text, source);
        const qualifier = if (definition) |*value| f.TableSelect.targetQualifier(arena.allocator(), full) catch value.metadata.name.slice() else null;
        if (is_relational) {
            var targets: [f.Relational.max_sources]f.RelationalSql.Target = undefined;
            const count = f.RelationalSql.discoverTargets(arena.allocator(), full, &targets) catch |err| blk: {
                try grammar.ignored(err);
                break :blk 0;
            };
            var declarations: [f.Relational.max_sources]grammar.RelationalSource = undefined;
            var definitions: [f.Relational.max_sources]?c.TableCatalog.Definition = @splat(null);
            defer for (&definitions) |*entry| if (entry.*) |*value| value.deinit();
            var found: usize = 0;
            for (targets[0..count], 0..) |input, i| {
                definitions[i] = try client.lookup(arena.allocator(), try .init(input.name));
                if (definitions[i]) |value| {
                    declarations[found] = .{ .alias = input.alias, .schema = value.schema.schema };
                    found += 1;
                }
            }
            editor = try grammar.relationalExpectations(arena.allocator(), selected_text, declarations[0..found]);
            try grammar.relationalSuggestions(&builder, editor, declarations[0..found]);
        } else try grammar.suggestions(&builder, editor, source, qualifier);
        if (editor.name_role == .source) {
            var cursor: ?c.TableCatalog.Cursor = null;
            var complete_names = false;
            while (pages < max_pages) {
                const page = try client.list(cursor);
                pages += 1;
                if (page.resource_revision != initial.resource_revision) return error.CatalogCursorChanged;
                for (page.entries) |entry| if (entry) |value| try builder.add(value.metadata.name.slice(), .source, "Authorized Table");
                cursor = page.next;
                if (cursor == null) {
                    complete_names = true;
                    break;
                }
            }
            if (!complete_names) builder.limited = true;
        }
        if (name != null and definition == null and editor.name_role != .source) {
            builder.clear();
            builder.count = 0;
            response.status = .unsupported;
        }
        response.coverage = if (builder.limited) .limited else .complete;
        if (editor.name_role == null and editor.value_type == null and editor.words[0] == null and editor.symbols[0] == null) response.status = .unsupported;
        if (!advanced) if (a.continuation(request, .{ .range = range, .coverage = response.coverage, .status = response.status, .items = builder.items[0..builder.count] })) |following| {
            builder.clear();
            range = following;
            response.range = following;
            advanced = true;
            continue;
        };
        response.items = try allocator.dupe(a.Item, builder.items[0..builder.count]);
        break;
    }
    errdefer (a.Completion{ .range = response.range, .items = response.items }).deinit(allocator);
    // Re-read current authorization and discard a mixed schema/policy response.
    // The terminal performs this same acquisition again before accepting a choice.
    const final = try client.describe();
    if (!std.meta.eql(initial, final)) return error.CatalogCursorChanged;
    return response;
}

