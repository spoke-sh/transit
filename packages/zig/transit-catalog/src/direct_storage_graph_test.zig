const std = @import("std");
const t = std.testing;
const c = @import("root.zig");
const s = c.storage;
const d = c.protocol.DataLifecycle;
const Graph = c.DirectStorageGraph;
const P = s.TablePartition;

test "direct graph retains physical and ADD interpretations without receipt or history roots" {
    const Fixture = struct {
        fn acquire(_: *anyopaque) !P.Guard.Fence {
            return .{ .writer_epoch = 1, .policy_epoch = 1 };
        }
        fn release(_: *anyopaque) void {}
        fn binding(table: *P, id: u64, action: d.Action) d.Binding {
            return .{ .definition = c.protocol.Growth.current_definition, .identity = .{ .scope = table.root.interpretation.object.scope, .principal = 4, .operation = id }, .target = table.root.interpretation.object, .action = action, .expected_definition = if (action == .create) null else table.root.interpretation, .expected_data = null, .intent = @splat(1) };
        }
        const Workspace = struct {
            jobs: std.ArrayList(Graph.Work) = .empty,
            marks: std.StringHashMap(void) = .init(t.allocator),
            fn deinit(self: *@This()) void {
                var keys = self.marks.keyIterator();
                while (keys.next()) |key| t.allocator.free(key.*);
                self.marks.deinit();
                self.jobs.deinit(t.allocator);
            }
            pub fn enqueue(self: *@This(), work: Graph.Work) !void {
                try self.jobs.append(t.allocator, work);
            }
            pub fn mark(self: *@This(), key: []const u8, _: s.TransitObjectStore.ObjectMeta) !void {
                if (self.marks.contains(key)) return;
                const owned = try t.allocator.dupe(u8, key);
                errdefer t.allocator.free(owned);
                try self.marks.put(owned, {});
            }
            pub fn visited(_: *@This(), _: [32]u8) !bool {
                return false;
            }
        };
    };
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    const object: d.Object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 7 };
    var table = try P.init(t.allocator, 17, .{ .object = object, .revision = 1, .schema = .{ .object = 7, .revision = 1, .next_column = 2, .columns = &.{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }}, .primary_key = &.{1} }, .properties = "graph" }, wal.log(), objects.objectStore(), .{ .resident_pages = 1 });
    defer table.deinit();
    try table.recover();
    var context: u8 = 0;
    const guard: P.Guard = .{ .context = &context, .acquire = Fixture.acquire, .release = Fixture.release };
    _ = try table.apply(Fixture.binding(&table, 1, .create), &.{.{ .put = .{ .row = .{ .identity = .{ .origin = 7, .operation = 1, .ordinal = 0 }, .cells = &.{.{ .value = .{ .atom = .{ .signed = 1 } } }} } } }}, .point, guard);
    const physical = table.root.declared();
    _ = try table.changeDefinition(Fixture.binding(&table, 2, .alter), .{ .alter = .{ .change = .{ .add = .{ .name = "score", .type = .int64, .nullable = false, .default = .{ .value = .{ .atom = .{ .signed = 7 } } } } }, .properties = "graph" } }, guard);
    const origin = table.root.declared();
    _ = try table.changeDefinition(Fixture.binding(&table, 3, .alter), .{ .alter = .{ .change = .{ .default = .{ .column = 2, .value = .{ .value = .{ .atom = .{ .signed = 9 } } } } }, .properties = "graph" } }, guard);
    // A snapshot root owns rows and their interpretation, without retaining the
    // historical records or receipts that could accidentally mask a missed edge.
    var workspace: Fixture.Workspace = .{};
    defer workspace.deinit();
    try workspace.enqueue(.{ .table_root = .{ .root = table.root, .archive = table.root.archive, .role = .snapshot } });
    var at: usize = 0;
    var steps: usize = 0;
    while (at < workspace.jobs.items.len) {
        var work = workspace.jobs.items[at];
        while (!try Graph.step(t.allocator, &table.index, wal.log(), &work, &workspace)) {
            steps += 1;
            if (steps == 1000) return error.FixtureBudget;
        }
        at += 1;
    }
    var name: [96]u8 = undefined;
    for ([_]s.TableDeclaration.Stored{ physical, origin, table.root.declared() }) |stored| try t.expect(workspace.marks.contains(try s.TableDeclaration.key(stored.content, &name)));
    // Receipt pages are intentionally absent from this isolated source graph.
    try t.expect(!workspace.marks.contains(try s.TreeStore.key(table.root.receipts.?.location, &name)));
}
