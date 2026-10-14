//! Deterministic, bounded authorization over one immutable policy revision.
//! Store supplies owned role/object records and ordered eight-record pages.
//! This evaluator never caches decisions across revisions or acquires identity.
const std = @import("std");
const p = @import("root.zig").protocol;
const a = p.Authorization;

pub fn Evaluator(comptime Store: type) type {
    return struct {
        const Self = @This();
        store: *Store,
        policy_revision: u64,
        limits: a.Limits = .{},
        /// Dependency cleanup follows retained grant provenance even while a
        /// role is disabled. Never use this mode to admit a caller operation.
        include_disabled: bool = false,
        records: u16 = 0,
        vertices: [a.max_vertices]u64 = undefined,
        vertex_count: usize = 0,
        stack: [a.max_depth]Frame = undefined,
        depth: usize = 0,

        const Frame = union(enum) { membership: u64, grant: u64 };
        const Walk = enum { inherit, set, cycle };
        const Roles = struct { values: [a.max_vertices]u64 = undefined, len: usize = 0 };

        pub fn init(store: *Store, policy_revision: u64, limits: a.Limits) !Self {
            try a.revision(policy_revision);
            try limits.validate();
            return .{ .store = store, .policy_revision = policy_revision, .limits = limits };
        }
        fn charge(self: *Self) !void {
            if (self.records == self.limits.records) return error.AuthorizationBudgetExceeded;
            self.records += 1;
        }
        fn vertex(self: *Self, id: u64) !void {
            for (self.vertices[0..self.vertex_count]) |previous| if (previous == id) return;
            if (self.vertex_count == self.limits.vertices) return error.AuthorizationBudgetExceeded;
            self.vertices[self.vertex_count] = id;
            self.vertex_count += 1;
        }
        fn role(self: *Self, id: u64) anyerror!?a.Role {
            const value = (try self.storedRole(id)) orelse return null;
            if ((!value.enabled and !self.include_disabled) or value.retired) return null;
            return value;
        }
        fn storedRole(self: *Self, id: u64) anyerror!?a.Role {
            try a.roleId(id);
            try self.vertex(id);
            try self.charge();
            const value = (try self.store.role(id)) orelse return null;
            try value.validate();
            if (value.id != id or value.revision > self.policy_revision) return error.InvalidAuthorizationState;
            return value;
        }
        fn enter(self: *Self, frame: Frame) !bool {
            for (self.stack[0..self.depth]) |previous| if (std.meta.eql(previous, frame)) return false;
            if (self.depth == self.limits.depth) return error.AuthorizationBudgetExceeded;
            self.stack[self.depth] = frame;
            self.depth += 1;
            return true;
        }
        fn leave(self: *Self) void {
            self.depth -= 1;
        }
        fn memberValid(self: *Self, edge: a.Membership) anyerror!bool {
            try edge.validate();
            if (edge.revision > self.policy_revision) return error.InvalidAuthorizationState;
            if (!edge.enabled) return false;
            if (!try self.enter(.{ .membership = edge.id })) return false;
            defer self.leave();
            if (try self.role(edge.member) == null or try self.role(edge.grantor) == null) return false;
            const target = (try self.role(edge.role)) orelse return false;
            if (edge.grantor == a.root_role or edge.grantor == target.owner) return true;
            return self.admin(edge.grantor, edge.role);
        }
        pub fn admin(self: *Self, grantor: u64, target: u64) anyerror!bool {
            if (try self.role(grantor) == null) return false;
            const target_role = (try self.role(target)) orelse return false;
            if (grantor == a.root_role or grantor == target_role.owner) return true;
            var after: ?u64 = null;
            while (true) {
                try self.charge();
                const page = try self.store.memberships(grantor, after);
                var last = after orelse 0;
                var ended = false;
                for (page.records) |slot| {
                    const edge = slot orelse {
                        ended = true;
                        continue;
                    };
                    if (ended or edge.id <= last or edge.member != grantor) return error.InvalidAuthorizationState;
                    try self.charge();
                    last = edge.id;
                    if (edge.role == target and edge.admin and try self.memberValid(edge)) return true;
                }
                after = try next(page.next, after, last);
                if (after == null) return false;
            }
        }
        fn next(cursor: ?u64, previous: ?u64, last: u64) !?u64 {
            if (cursor) |id| if (id != last or id <= (previous orelse 0)) return error.InvalidAuthorizationState;
            return cursor;
        }
        fn roles(self: *Self, start: u64, mode: Walk) anyerror!Roles {
            var result: Roles = .{};
            if ((if (mode == .cycle) try self.storedRole(start) else try self.role(start)) == null) return result;
            result.values[0] = start;
            result.len = 1;
            var index: usize = 0;
            // A per-decision work queue, not a limit on retained role count.
            var depths: [a.max_vertices]u8 = @splat(0);
            while (index < result.len) : (index += 1) {
                var after: ?u64 = null;
                while (true) {
                    try self.charge();
                    const page = try self.store.memberships(result.values[index], after);
                    var last = after orelse 0;
                    var ended = false;
                    for (page.records) |slot| {
                        const edge = slot orelse {
                            ended = true;
                            continue;
                        };
                        if (ended or edge.id <= last or edge.member != result.values[index]) return error.InvalidAuthorizationState;
                        last = edge.id;
                        try self.charge();
                        if (!(switch (mode) {
                            .inherit => edge.inherit,
                            .set => edge.set,
                            .cycle => true,
                        })) continue;
                        if (mode == .cycle) {
                            // Disabled roles or temporarily unsupported delegation
                            // must not hide a cycle that could activate later.
                            try edge.validate();
                            if (edge.revision > self.policy_revision) return error.InvalidAuthorizationState;
                            if (!edge.enabled) continue;
                            if (try self.storedRole(edge.role) == null) return error.InvalidAuthorizationState;
                        } else if (!try self.memberValid(edge)) continue;
                        var seen = false;
                        for (result.values[0..result.len]) |id| if (id == edge.role) {
                            seen = true;
                            break;
                        };
                        if (seen) continue;
                        if (result.len == self.limits.vertices or depths[index] + 1 >= self.limits.depth) return error.AuthorizationBudgetExceeded;
                        result.values[result.len] = edge.role;
                        depths[result.len] = depths[index] + 1;
                        result.len += 1;
                    }
                    after = try next(page.next, after, last);
                    if (after == null) break;
                }
            }
            return result;
        }
        pub fn canSet(self: *Self, login: u64, selected: u64) anyerror!bool {
            const subject = (try self.role(login)) orelse return false;
            if (!subject.login) return false;
            const eligible = try self.roles(login, .set);
            for (eligible.values[0..eligible.len]) |id| if (id == selected) return true;
            return false;
        }
        pub fn wouldCycle(self: *Self, member: u64, target: u64) anyerror!bool {
            if (member == target) return true;
            const inherited = try self.roles(target, .cycle);
            for (inherited.values[0..inherited.len]) |id| if (id == member) return true;
            return false;
        }
        pub fn inherits(self: *Self, subject: u64, target: u64) anyerror!bool {
            const inherited = try self.roles(subject, .inherit);
            for (inherited.values[0..inherited.len]) |id| if (id == target) return true;
            return false;
        }
        pub fn owns(self: *Self, subject: u64, reference: a.ObjectRef) anyerror!bool {
            try reference.validate();
            try self.charge();
            const object = (try self.store.object(reference)) orelse return false;
            try object.validate();
            if (!object.reference.eql(reference) or object.revision > self.policy_revision) return error.InvalidAuthorizationState;
            if (object.retired) return false;
            if (subject == a.root_role) return try self.role(subject) != null;
            return self.inherits(subject, object.owner);
        }
        pub fn validMembership(self: *Self, edge: a.Membership) anyerror!bool {
            return self.memberValid(edge);
        }
        fn grants(self: *Self, who: u64, object: a.Object, bit: u64, option: bool) anyerror!bool {
            var after: ?u64 = null;
            while (true) {
                try self.charge();
                const page = try self.store.grants(object.reference, who, after);
                var last = after orelse 0;
                var ended = false;
                for (page.records) |slot| {
                    const edge = slot orelse {
                        ended = true;
                        continue;
                    };
                    if (ended or edge.id <= last or edge.grantee != who or !edge.object.eql(object.reference)) return error.InvalidAuthorizationState;
                    last = edge.id;
                    try self.charge();
                    try edge.validate();
                    if (edge.revision > self.policy_revision or edge.privileges & ~object.actions != 0) return error.InvalidAuthorizationState;
                    if (!edge.enabled or (if (option) edge.grant_options else edge.privileges) & bit == 0) continue;
                    if (!try self.enter(.{ .grant = edge.id })) continue;
                    const valid = self.privilege(edge.grantor, object, bit, true) catch |err| {
                        self.leave();
                        return err;
                    };
                    self.leave();
                    if (valid) return true;
                }
                after = try next(page.next, after, last);
                if (after == null) return false;
            }
        }
        fn privilege(self: *Self, subject: u64, object: a.Object, bit: u64, option: bool) anyerror!bool {
            const inherited = try self.roles(subject, .inherit);
            if (inherited.len == 0) return false;
            for (inherited.values[0..inherited.len]) |who| {
                if (option and who == object.owner) return true;
                if (try self.grants(who, object, bit, option)) return true;
            }
            if (!option and try self.grants(a.public_role, object, bit, false)) return true;
            return false;
        }
        pub fn evaluate(self: *Self, subject: u64, reference: a.ObjectRef, requested: u64) anyerror!a.Decision {
            try reference.validate();
            try a.mask(requested);
            try self.charge();
            const object = (try self.store.object(reference)) orelse return error.UnknownAuthorizationObject;
            try object.validate();
            if (!object.reference.eql(reference) or object.revision > self.policy_revision) return error.InvalidAuthorizationState;
            if (requested & ~object.actions != 0) return error.InvalidAuthorizationPrivilege;
            var decision: a.Decision = .{ .policy_revision = self.policy_revision, .role = subject, .object = reference, .requested = requested, .allowed = 0, .grantable = 0, .records = 0 };
            if (!object.retired) {
                var remaining = requested;
                while (remaining != 0) {
                    const bit = @as(u64, 1) << @as(u6, @intCast(@ctz(remaining)));
                    remaining &= ~bit;
                    if (try self.privilege(subject, object, bit, false)) decision.allowed |= bit;
                    if (try self.privilege(subject, object, bit, true)) decision.grantable |= bit;
                }
            }
            decision.records = self.records;
            return decision;
        }
    };
}
