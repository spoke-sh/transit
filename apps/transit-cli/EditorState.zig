//! Deterministic editor interaction and client ownership. Terminal performs the
//! returned effects in order: join cancellation, update suggestions, then action.
//! Text/undo are volatile; this owner neither performs I/O nor authorizes SQL.
const std = @import("std");
const q = @import("transit_query");
const Undo = @import("Undo.zig");
const Self = @This();
pub const max_bytes = q.fuze.Sql.max_statement_bytes;
pub const Mode = enum { editing, history, completion };
pub const Request = enum { idle, fetching, validating, obsolete, cancelling, executing };
pub const Freshness = enum { pending, current, unavailable };
pub const Intent = enum { choose, unique };
pub const Source = enum { local, remote };
pub const Action = enum { none, acquire, validate, apply, search_newest, search_older, submit, erase };
pub const Effects = struct {
    cancel: bool = false,
    clear: bool = false,
    install: bool = false,
    action: Action = .none,
};
pub const Reply = struct {
    unique: bool = false,
    matches: bool = false,
    interrupted: bool = false,
};
pub const Event = union(enum) {
    changed,
    open: Intent,
    refresh,
    remote,
    local: bool,
    reply: Reply,
    failed,
    protected_failure,
    joined,
    accept: bool,
    enter: bool,
    dismiss,
    cancel,
    search,
    history_accept,
    clear,
    executed,
};

mode: Mode = .editing,
request: Request = .idle,
freshness: Freshness = .pending,
intent: Intent = .choose,
source: Source = .remote,
generation: u32 = 0,
bytes: [max_bytes]u8 = undefined,
length: usize = 0,
cursor: usize = 0,
journal: Undo = .{},
history_position: ?u64 = null,
draft: [max_bytes]u8 = undefined,
draft_length: usize = 0,
draft_cursor: usize = 0,
search: [max_bytes]u8 = undefined,
search_length: usize = 0,
search_failed: bool = false,

pub fn text(self: *const Self) []const u8 {
    return self.bytes[0..self.length];
}
pub fn searching(self: *const Self) bool {
    return self.mode == .history;
}
pub fn completing(self: *const Self) bool {
    return self.mode == .completion;
}
pub fn accepting(self: *const Self) bool {
    return self.request == .validating;
}
pub fn quiet(self: *const Self) bool {
    return self.accepting() and self.intent == .unique;
}
pub fn available(self: *const Self) bool {
    return self.request == .idle;
}

pub fn transition(self: *Self, event: Event) Effects {
    // Terminal runs foreground execution and cancellation joins synchronously.
    // Queued input is decoded only after the corresponding completion event.
    if (self.request == .executing and event != .executed and event != .protected_failure and event != .changed and event != .clear and event != .dismiss) return .{};
    if (self.request == .cancelling and event != .joined and event != .protected_failure) return .{};
    switch (event) {
        .changed => {
            self.generation +%= 1;
            if (self.request == .fetching or self.request == .validating) self.request = .obsolete;
            self.intent = .choose;
            self.freshness = .pending;
        },
        .open => |intent| {
            if (!self.available() or self.searching()) return .{};
            self.mode = .completion;
            self.intent = intent;
            self.freshness = .pending;
            self.source = .remote;
            self.request = .fetching;
            return .{ .clear = true, .action = .acquire };
        },
        .refresh => {
            if (!self.completing() or !self.available() or self.freshness != .pending) return .{};
            self.request = .fetching;
            return .{ .action = .acquire };
        },
        .remote => self.source = .remote,
        .local => |is_unique| {
            if (!self.completing() or self.request != .fetching) return .{};
            self.request = .idle;
            self.source = .local;
            self.freshness = .current;
            const apply = self.intent == .unique and is_unique;
            self.intent = .choose;
            return .{ .install = true, .action = if (apply) .apply else .none };
        },
        .reply => |reply| {
            const request = self.request;
            if (request != .fetching and request != .validating and request != .obsolete) return .{};
            self.request = .idle;
            if (request == .obsolete or reply.interrupted or !self.completing()) {
                self.intent = .choose;
                self.freshness = .pending;
                return .{};
            }
            self.source = .remote;
            self.freshness = .current;
            if (request == .validating) {
                const apply = reply.matches and (self.intent != .unique or reply.unique);
                self.intent = .choose;
                return if (apply) .{ .action = .apply } else .{ .install = true };
            }
            if (self.intent == .unique and reply.unique) {
                self.request = .validating;
                return .{ .install = true, .action = .validate };
            }
            self.intent = .choose;
            return .{ .install = true };
        },
        .failed => {
            if (self.request == .obsolete) {
                self.request = .idle;
                return .{};
            }
            self.request = .idle;
            self.intent = .choose;
            self.freshness = .unavailable;
            return .{ .clear = true };
        },
        .protected_failure => {
            const effects = self.dismiss();
            self.mode = .editing;
            self.erase();
            return .{ .cancel = effects.cancel, .clear = true, .action = .erase };
        },
        .joined => {
            if (self.request == .cancelling) self.request = .idle;
        },
        .accept => |candidate| {
            if (self.searching()) return self.transition(.history_accept);
            if (!self.completing()) return self.transition(.{ .open = .unique });
            if (!self.available()) return .{};
            if (self.freshness == .unavailable) return self.transition(.{ .open = .choose });
            if (self.freshness == .pending) return self.transition(.refresh);
            if (!candidate) return self.dismiss();
            self.journal.boundary();
            if (self.source == .local) return .{ .action = .apply };
            self.request = .validating;
            return .{ .action = .validate };
        },
        .enter => |candidate| {
            if (self.searching()) return self.transition(.history_accept);
            if (self.completing()) return if (candidate) self.transition(.{ .accept = true }) else self.dismiss();
            if (!self.available()) return .{};
            self.request = .executing;
            return .{ .action = .submit };
        },
        .dismiss => return self.dismiss(),
        .cancel => {
            if (self.searching()) self.finishSearch(false);
            return self.dismiss();
        },
        .search => {
            if (self.searching()) return .{ .action = .search_older };
            const effects = self.dismiss();
            self.installPreview();
            self.journal.boundary();
            self.saveDraft();
            self.mode = .history;
            @memcpy(self.search[0..self.length], self.text());
            self.search_length = self.length;
            self.search_failed = false;
            self.history_position = null;
            self.generation +%= 1;
            return .{ .cancel = effects.cancel, .clear = true, .action = if (self.search_length > 0) .search_newest else .none };
        },
        .history_accept => {
            if (self.searching() and !self.search_failed and self.history_position != null) self.finishSearch(true);
        },
        .clear => {
            const effects = self.dismiss();
            if (self.searching()) self.finishSearch(false);
            if (self.length > 0) self.checkpoint(.atomic, false);
            self.length = 0;
            self.cursor = 0;
            self.mode = .editing;
            self.search_length = 0;
            self.search_failed = false;
            self.history_position = null;
            self.journal.boundary();
            self.generation +%= 1;
            return effects;
        },
        .executed => {
            if (self.request == .executing) self.request = .idle;
        },
    }
    return .{};
}
fn dismiss(self: *Self) Effects {
    const cancel = switch (self.request) {
        .fetching, .validating, .obsolete, .cancelling => true,
        .idle, .executing => false,
    };
    if (cancel) self.request = .cancelling;
    if (self.completing()) self.mode = .editing;
    self.intent = .choose;
    self.freshness = .pending;
    self.journal.boundary();
    return .{ .cancel = cancel, .clear = true };
}
pub fn checkpoint(self: *Self, group: Undo.Group, pasting: bool) void {
    if (pasting) return;
    if (self.searching()) {
        self.journal.save(self.search[0..self.search_length], self.search_length, .search, group);
        return;
    }
    self.installPreview();
    self.journal.save(self.text(), self.cursor, .draft, group);
}
pub fn installPreview(self: *Self) void {
    if (self.history_position != null and !self.searching()) {
        self.journal.save(self.draft[0..self.draft_length], self.draft_cursor, .draft, .atomic);
        self.history_position = null;
    }
}
pub fn saveDraft(self: *Self) void {
    @memcpy(self.draft[0..self.length], self.text());
    self.draft_length = self.length;
    self.draft_cursor = self.cursor;
}
pub fn restoreDraft(self: *Self) void {
    @memcpy(self.bytes[0..self.draft_length], self.draft[0..self.draft_length]);
    self.length = self.draft_length;
    self.cursor = self.draft_cursor;
    self.history_position = null;
    self.generation +%= 1;
}
fn finishSearch(self: *Self, accept: bool) void {
    self.journal.discardSearch();
    if (accept) self.journal.save(self.draft[0..self.draft_length], self.draft_cursor, .draft, .atomic) else self.restoreDraft();
    self.history_position = null;
    self.mode = .editing;
    self.search_length = 0;
    self.search_failed = false;
    self.generation +%= 1;
}
pub fn erase(self: *Self) void {
    std.crypto.secureZero(u8, &self.bytes);
    std.crypto.secureZero(u8, &self.draft);
    std.crypto.secureZero(u8, &self.search);
    self.journal.clear();
    self.length = 0;
    self.cursor = 0;
    self.draft_length = 0;
    self.draft_cursor = 0;
    self.search_length = 0;
    self.search_failed = false;
    self.history_position = null;
    self.generation +%= 1;
}

/// Metadata comparison is independent of allocation, transport and rendering.
pub fn unique(value: q.Assistance.Response) bool {
    return value.status == .ready and value.coverage == .complete and value.items.len == 1;
}
pub fn matches(prior: q.Assistance.Response, current: q.Assistance.Response, selected: q.Assistance.Item) bool {
    if (current.generation != prior.generation or current.profile != prior.profile or
        current.resource != prior.resource or current.resource_revision != prior.resource_revision or
        !std.meta.eql(current.range, prior.range) or !std.mem.eql(u8, &current.contract, &prior.contract) or
        !std.mem.eql(u8, current.policy_revision, prior.policy_revision)) return false;
    for (current.items) |candidate| {
        if (candidate.kind == selected.kind and std.mem.eql(u8, candidate.text, selected.text)) return true;
    }
    return false;
}

test "history cancellation restores text and cursor independently of filter and preview" {
    var state: Self = .{};
    defer state.erase();
    @memcpy(state.bytes[0..12], "CREATE TABLE");
    state.length = 12;
    state.cursor = 3;
    try std.testing.expectEqual(Action.search_newest, state.transition(.search).action);
    try std.testing.expectEqualStrings("CREATE TABLE", state.search[0..state.search_length]);
    @memcpy(state.search[0..4], "DROP");
    state.search_length = 4;
    @memcpy(state.bytes[0..11], "DROP TABLE;");
    state.length = 11;
    state.cursor = 11;
    state.history_position = 1;
    _ = state.transition(.cancel);
    try std.testing.expectEqualStrings("CREATE TABLE", state.text());
    try std.testing.expectEqual(3, state.cursor);
    try std.testing.expectEqual(Mode.editing, state.mode);
    _ = state.transition(.search);
    @memcpy(state.bytes[0..11], "DROP TABLE;");
    state.length = 11;
    state.cursor = 11;
    state.history_position = 1;
    _ = state.transition(.clear);
    const original = state.journal.restore(.draft, &state.bytes).?;
    try std.testing.expectEqualStrings("CREATE TABLE", state.bytes[0..original.length]);
    try std.testing.expectEqual(3, original.cursor);
}

test "completion validation is quiet, current and never queues acceptance" {
    const t = std.testing;
    var state: Self = .{};
    defer state.erase();
    try t.expectEqual(Action.acquire, state.transition(.{ .open = .unique }).action);
    try t.expectEqual(Action.none, state.transition(.{ .accept = true }).action);
    try t.expectEqual(Action.validate, state.transition(.{ .reply = .{ .unique = true } }).action);
    try t.expect(state.quiet());
    _ = state.transition(.changed);
    try t.expectEqual(Request.obsolete, state.request);
    const ignored = state.transition(.{ .reply = .{ .unique = true, .matches = true } });
    try t.expectEqualDeep(Effects{}, ignored);
    try t.expectEqual(Action.acquire, state.transition(.refresh).action);
    _ = state.transition(.{ .reply = .{ .unique = true } });
    try t.expectEqual(Action.validate, state.transition(.{ .accept = true }).action);
    try t.expectEqual(Action.apply, state.transition(.{ .reply = .{ .matches = true } }).action);
    _ = state.transition(.dismiss);
    _ = state.transition(.{ .open = .unique });
    _ = state.transition(.{ .reply = .{ .unique = true } });
    const ambiguous = state.transition(.{ .reply = .{ .matches = true } });
    try t.expect(ambiguous.install);
    try t.expectEqual(Action.none, ambiguous.action);
    try t.expect(!state.quiet());
}

test "cancel joins before client reuse and obsolete access failure erases private state" {
    const t = std.testing;
    var state: Self = .{};
    defer state.erase();
    @memcpy(state.bytes[0..5], "draft");
    state.length = 5;
    state.cursor = 5;
    state.checkpoint(.atomic, false);
    _ = state.transition(.{ .open = .unique });
    const dismissed = state.transition(.cancel);
    try t.expect(dismissed.cancel);
    try t.expectEqual(Request.cancelling, state.request);
    try t.expectEqual(Action.none, state.transition(.{ .enter = false }).action);
    _ = state.transition(.joined);
    try t.expectEqual(Action.submit, state.transition(.{ .enter = false }).action);
    try t.expectEqual(Action.none, state.transition(.{ .open = .choose }).action);
    _ = state.transition(.executed);
    _ = state.transition(.{ .open = .choose });
    _ = state.transition(.changed);
    const lost = state.transition(.protected_failure);
    try t.expect(lost.cancel and lost.clear and lost.action == .erase);
    try t.expectEqual(0, state.length);
    try t.expectEqual(0, state.journal.count);
    try t.expect(std.mem.allEqual(u8, &state.bytes, 0));
    try t.expect(std.mem.allEqual(u8, &state.draft, 0));
    try t.expect(std.mem.allEqual(u8, &state.search, 0));
}

test "acceptance compares every metadata basis and requires complete ready uniqueness" {
    const t = std.testing;
    const selected: q.Assistance.Item = .{ .text = "TABLE", .kind = .keyword, .detail = "" };
    const prior: q.Assistance.Response = .{ .generation = 2, .coverage = .complete, .status = .ready, .resource = 1, .resource_revision = 3, .contract = @splat(4), .policy_revision = "policy", .range = .{ .start = 6, .end = 6 }, .items = &.{selected} };
    try t.expect(matches(prior, prior, selected));
    try t.expect(unique(prior));
    for (0..10) |field| {
        var changed = prior;
        switch (field) {
            0 => changed.generation += 1,
            1 => changed.profile = .configuration_v1,
            2 => changed.resource += 1,
            3 => changed.resource_revision.? += 1,
            4 => changed.contract[0] += 1,
            5 => changed.policy_revision = "new policy",
            6 => changed.range.?.start -= 1,
            7 => changed.items = &.{.{ .text = "OTHER", .kind = .keyword, .detail = "" }},
            8 => changed.items = &.{.{ .text = "TABLE", .kind = .source, .detail = "" }},
            9 => changed.resource_revision = null,
            else => unreachable,
        }
        try t.expect(!matches(prior, changed, selected));
    }
    var direct = prior;
    direct.profile = .direct_table_v1;
    direct.resource_revision = null;
    try t.expect(matches(direct, direct, selected));
    var changed = prior;
    changed.coverage = .limited;
    try t.expect(!unique(changed));
    changed = prior;
    changed.status = .unsupported;
    try t.expect(!unique(changed));
    changed = prior;
    changed.items = &.{};
    try t.expect(!unique(changed));
    changed.items = &.{ selected, selected };
    try t.expect(!unique(changed));
}
