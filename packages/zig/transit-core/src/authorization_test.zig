const std = @import("std");
const t = std.testing;
const core = @import("root.zig");
const a = core.protocol.Authorization;
const reference: a.ObjectRef = .{ .kind = .domain, .id = 42 };
const policy_revision = 100;

const Store = struct {
    role_records: []const a.Role,
    membership_records: []const a.Membership = &.{},
    grant_records: []const a.Grant = &.{},
    object_record: ?a.Object = .{ .reference = reference, .owner = 0, .registrar = 0, .actions = 3, .revision = 1 },
    corrupt_page: bool = false,

    pub fn role(self: *Store, id: u64) !?a.Role {
        for (self.role_records) |value| if (value.id == id) return value;
        return null;
    }
    pub fn object(self: *Store, ref: a.ObjectRef) !?a.Object {
        if (self.object_record) |value| if (value.reference.eql(ref)) return value;
        return null;
    }
    pub fn memberships(self: *Store, member: u64, after: ?u64) !a.Page(a.Membership) {
        var page: a.Page(a.Membership) = .{};
        var count: usize = 0;
        for (self.membership_records) |value| {
            if (value.member != member or value.id <= (after orelse 0)) continue;
            if (count == a.page_size) {
                page.next = page.records[count - 1].?.id;
                break;
            }
            page.records[count] = value;
            count += 1;
        }
        if (self.corrupt_page and count != 0) page.records[0].?.member = member + 1;
        return page;
    }
    pub fn grants(self: *Store, ref: a.ObjectRef, grantee: u64, after: ?u64) !a.Page(a.Grant) {
        var page: a.Page(a.Grant) = .{};
        var count: usize = 0;
        for (self.grant_records) |value| {
            if (!value.object.eql(ref) or value.grantee != grantee or value.id <= (after orelse 0)) continue;
            if (count == a.page_size) {
                page.next = page.records[count - 1].?.id;
                break;
            }
            page.records[count] = value;
            count += 1;
        }
        return page;
    }
};
const Evaluator = core.authorization.Evaluator(Store);

fn role(id: u64) a.Role {
    return .{ .id = id, .name = core.Value.init("role") catch unreachable, .owner = 0, .login = true, .revision = 1 };
}
fn grant(id: u64, grantor: u64, grantee: u64, bits: u64, options: u64) a.Grant {
    return .{ .id = id, .object = reference, .grantor = grantor, .grantee = grantee, .privileges = bits, .grant_options = options, .revision = 1 };
}
fn membership(id: u64, member: u64, target: u64) a.Membership {
    return .{ .id = id, .member = member, .role = target, .grantor = 0, .revision = 1 };
}
fn evaluate(store: *Store, subject: u64, requested: u64) !a.Decision {
    var evaluator = try Evaluator.init(store, policy_revision, .{});
    return evaluator.evaluate(subject, reference, requested);
}

test "ownership retains grant options after ordinary owner privileges are revoked" {
    var store: Store = .{ .role_records = &.{role(0)} };
    var decision = try evaluate(&store, 0, 3);
    try t.expectEqual(@as(u64, 0), decision.allowed);
    try t.expectEqual(@as(u64, 3), decision.grantable);
    store.grant_records = &.{grant(1, 0, 0, 1, 0)};
    decision = try evaluate(&store, 0, 3);
    try t.expectEqual(@as(u64, 1), decision.allowed);
    try t.expectEqual(@as(u64, 3), decision.grantable);
}

test "INHERIT SET and ADMIN are independent and membership delegation has provenance" {
    var edges = [_]a.Membership{ membership(1, 1, 2), membership(2, 2, 3), membership(3, 4, 3) };
    edges[0].set = false;
    edges[1].inherit = false;
    edges[1].admin = true;
    edges[2].grantor = 2;
    var store: Store = .{ .role_records = &.{ role(0), role(1), role(2), role(3), role(4) }, .membership_records = &edges, .grant_records = &.{ grant(1, 0, 2, 1, 0), grant(2, 0, 3, 2, 0) } };
    try t.expectEqual(@as(u64, 1), (try evaluate(&store, 1, 3)).allowed);
    try t.expectEqual(@as(u64, 2), (try evaluate(&store, 4, 3)).allowed);
    var evaluator = try Evaluator.init(&store, policy_revision, .{});
    try t.expect(!try evaluator.canSet(1, 2));
    try t.expect(try evaluator.canSet(2, 3));
    try t.expect(!try evaluator.admin(1, 3));
    try t.expect(try evaluator.admin(2, 3));
    edges[1].admin = false;
    try t.expectEqual(@as(u64, 0), (try evaluate(&store, 4, 3)).allowed);
}

test "grant revocation preserves independent paths and unanchored cycles confer nothing" {
    var grants = [_]a.Grant{ grant(1, 0, 1, 1, 1), grant(2, 1, 2, 1, 1), grant(3, 2, 1, 1, 1), grant(4, 0, 2, 1, 1) };
    var store: Store = .{ .role_records = &.{ role(0), role(1), role(2) }, .grant_records = &grants };
    try t.expect((try evaluate(&store, 2, 1)).permits());
    grants[0].enabled = false;
    try t.expect((try evaluate(&store, 1, 1)).permits());
    grants[3].enabled = false;
    try t.expect(!(try evaluate(&store, 1, 1)).permits());
    try t.expect(!(try evaluate(&store, 2, 1)).permits());
}

test "PUBLIC grants have no delegation and disabled roles and retired objects deny" {
    var roles = [_]a.Role{ role(0), role(1), role(2) };
    var store: Store = .{ .role_records = &roles, .grant_records = &.{grant(1, 0, a.public_role, 1, 0)} };
    const decision = try evaluate(&store, 1, 1);
    try t.expect(decision.permits());
    try t.expectEqual(@as(u64, 0), decision.grantable);
    roles[1].enabled = false;
    try t.expect(!(try evaluate(&store, 1, 1)).permits());
    try t.expect(!(try evaluate(&store, 9, 1)).permits());
    store.object_record.?.retired = true;
    try t.expect(!(try evaluate(&store, 2, 1)).permits());
    store.object_record = null;
    try t.expectError(error.UnknownAuthorizationObject, evaluate(&store, 2, 1));
}

test "ordered pages and budgets reject malformed or incomplete authority" {
    var roles: [300]a.Role = undefined;
    for (&roles, 0..) |*value, id| value.* = role(id);
    var edges: [12]a.Membership = undefined;
    for (&edges, 0..) |*value, index| value.* = membership(index + 1, 1, index + 2);
    var store: Store = .{ .role_records = &roles, .membership_records = &edges, .grant_records = &.{grant(1, 0, 13, 1, 0)} };
    // Retained cardinality exceeds the decision queue, but this reachable graph does not.
    try t.expect((try evaluate(&store, 1, 1)).permits());
    var evaluator = try Evaluator.init(&store, policy_revision, .{ .vertices = 4 });
    try t.expectError(error.AuthorizationBudgetExceeded, evaluator.evaluate(1, reference, 1));
    evaluator = try Evaluator.init(&store, policy_revision, .{ .records = 3 });
    try t.expectError(error.AuthorizationBudgetExceeded, evaluator.evaluate(1, reference, 1));
    evaluator = try Evaluator.init(&store, policy_revision, .{ .depth = 1 });
    try t.expectError(error.AuthorizationBudgetExceeded, evaluator.evaluate(1, reference, 1));
    store.corrupt_page = true;
    try t.expectError(error.InvalidAuthorizationState, evaluate(&store, 1, 1));
    store.corrupt_page = false;
    roles[1].revision = policy_revision + 1;
    try t.expectError(error.InvalidAuthorizationState, evaluate(&store, 1, 1));
}

test "grant evaluation agrees with independent least fixed point for every three role graph" {
    const edges = [_][2]u64{ .{ 0, 1 }, .{ 0, 2 }, .{ 1, 0 }, .{ 1, 2 }, .{ 2, 0 }, .{ 2, 1 } };
    for (0..64) |mask| {
        var grants: [6]a.Grant = undefined;
        var count: usize = 0;
        for (edges, 0..) |edge, index| {
            if (mask & (@as(usize, 1) << @intCast(index)) == 0) continue;
            grants[count] = grant(index + 1, edge[0], edge[1], 1, 1);
            count += 1;
        }
        // Oracle has no recursive traversal or evaluator helper: grow the set
        // from the ownership anchor until another pass adds no authority.
        var options = [_]bool{ true, false, false };
        var access = [_]bool{ false, false, false };
        var changed = true;
        while (changed) {
            changed = false;
            for (grants[0..count]) |edge| if (options[@intCast(edge.grantor)]) {
                const target: usize = @intCast(edge.grantee);
                if (!options[target]) changed = true;
                options[target] = true;
                access[target] = true;
            };
        }
        var store: Store = .{ .role_records = &.{ role(0), role(1), role(2) }, .grant_records = grants[0..count] };
        for (0..3) |subject| {
            const decision = try evaluate(&store, subject, 1);
            try t.expectEqual(access[subject], decision.allowed == 1);
            try t.expectEqual(options[subject], decision.grantable == 1);
        }
    }
}

test "membership closure agrees with independent transitive closure and detects cycles" {
    const edges = [_][2]u64{ .{ 1, 2 }, .{ 1, 3 }, .{ 2, 3 } };
    for (0..8) |mask| {
        var memberships: [3]a.Membership = undefined;
        var count: usize = 0;
        var closure: [4][4]bool = @splat(@splat(false));
        for (0..4) |id| closure[id][id] = true;
        for (edges, 0..) |edge, index| {
            if (mask & (@as(usize, 1) << @intCast(index)) == 0) continue;
            memberships[count] = membership(index + 1, edge[0], edge[1]);
            count += 1;
            closure[@intCast(edge[0])][@intCast(edge[1])] = true;
        }
        for (0..4) |via| for (0..4) |from| for (0..4) |to| {
            closure[from][to] = closure[from][to] or (closure[from][via] and closure[via][to]);
        };
        var store: Store = .{ .role_records = &.{ role(0), role(1), role(2), role(3) }, .membership_records = memberships[0..count], .grant_records = &.{grant(1, 0, 3, 1, 0)} };
        for (1..4) |from| {
            try t.expectEqual(closure[from][3], (try evaluate(&store, from, 1)).permits());
            for (1..4) |to| {
                var evaluator = try Evaluator.init(&store, policy_revision, .{});
                try t.expectEqual(closure[from][to], try evaluator.canSet(from, to));
                try t.expectEqual(closure[to][from], try evaluator.wouldCycle(from, to));
            }
        }
    }
}

test "disabled roles do not conceal cycles from membership administration" {
    var roles = [_]a.Role{ role(0), role(1), role(2), role(3) };
    roles[2].enabled = false;
    var store: Store = .{ .role_records = &roles, .membership_records = &.{ membership(1, 1, 2), membership(2, 2, 3) } };
    var evaluator = try Evaluator.init(&store, policy_revision, .{});
    try t.expect(!try evaluator.canSet(1, 3));
    try t.expect(try evaluator.wouldCycle(3, 1));
}
