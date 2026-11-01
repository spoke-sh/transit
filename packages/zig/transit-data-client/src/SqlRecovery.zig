//! SQL adapter for explicit local recovery. One borrower per adapter/executor;
//! independent adapters may share the store's serialized exclusive owner.
const std = @import("std");
const sql = @import("transit_sql_client");
const Store = @import("LocalRecoveryStore.zig");
const Self = @This();
pub const Attempt = struct { key: Store.Key, revision: u64 };
pub const Config = struct { parse_bytes: usize = 4 * 1024 * 1024 };
pub const Loaded = struct {
    submission: std.json.Parsed(sql.Executor.Submission),
    completion: ?std.json.Parsed(Completion),
    attempt: Attempt,
    pub fn deinit(self: *Loaded) void {
        if (self.completion) |completion| completion.deinit();
        self.submission.deinit();
        self.* = undefined;
    }
    pub fn pending(self: Loaded, client: *sql.Client) !sql.Pending {
        // A saved completion is local evidence, never permission to disclose
        // remote data or skip current authorization on a recovery observation.
        return self.submission.value.pending(client);
    }
};
pub const Completion = struct { definition: sql.protocol.native.Definition, value: sql.results.CommandCompletion };
pub const Execution = struct {
    outcome: *sql.Executor.Outcome,
    attempt: ?Attempt,
    /// Separate from the authoritative outcome, including known commitment.
    persistence_failure: ?anyerror,
    pub fn deinit(self: Execution) void {
        self.outcome.deinit();
    }
};
allocator: std.mem.Allocator,
store: *Store,
buffer: []u8,
scratch: []u8,
last: ?Attempt = null,

pub fn init(allocator: std.mem.Allocator, store: *Store, config: Config) !Self {
    if (config.parse_bytes == 0 or config.parse_bytes > 64 * 1024 * 1024) return error.RecoveryRecordCapacity;
    const buffer = try allocator.alloc(u8, store.buffer.len);
    errdefer allocator.free(buffer);
    const scratch = try allocator.alloc(u8, config.parse_bytes);
    return .{ .allocator = allocator, .store = store, .buffer = buffer, .scratch = scratch };
}
pub fn deinit(self: *Self) void {
    std.crypto.secureZero(u8, self.buffer);
    self.allocator.free(self.buffer);
    std.crypto.secureZero(u8, self.scratch);
    self.allocator.free(self.scratch);
    self.* = undefined;
}
pub fn key(submission: sql.Executor.Submission) !Store.Key {
    try submission.validate();
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.sql.submission.v1\x00");
    hash.update(&submission.instance);
    hash.update(&submission.account);
    hash.update(&submission.execute.token.?);
    return hash.finalResult();
}
fn encode(self: *Self, value: anytype) ![]const u8 {
    var writer: std.Io.Writer = .fixed(self.buffer);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    sql.protocol.Json.write(value, &encoder) catch return error.RecoveryRecordCapacity;
    return writer.buffered();
}
pub fn save(self: *Self, submission: sql.Executor.Submission) !Attempt {
    const identity = try key(submission);
    const bytes = try self.encode(submission);
    return .{ .key = identity, .revision = try self.store.insert(identity, bytes) };
}
fn persist(raw: *anyopaque, submission: sql.Executor.Submission) !void {
    const self: *Self = @ptrCast(@alignCast(raw));
    self.last = try self.save(submission);
}

/// Owns persistence ordering through the existing Executor, not SQL parsing or
/// replay. Preparation refusal can return without an attempt. Post-dispatch
/// errors leave saved originals enumerable even when no Execution is returned.
pub fn execute(self: *Self, executor: *sql.Executor, text: []const u8, parameters: ?[]const sql.results.fuze.LogicalJson.Atom, options: sql.Executor.Options) !Execution {
    if (options.before_submit != null) return error.DuplicateSubmissionPersistence;
    self.last = null;
    var configured = options;
    configured.before_submit = .{ .context = self, .persist = persist };
    const outcome = try executor.execute(text, parameters, configured);
    var persistence_failure: ?anyerror = null;
    if (outcome.value == .command) if (self.last) |attempt| {
        self.last = self.saveCompletion(attempt, outcome.value.command) catch |err| failed: {
            persistence_failure = err;
            break :failed attempt;
        };
    };
    return .{ .outcome = outcome, .attempt = self.last, .persistence_failure = persistence_failure };
}

/// Caller supplies a bounded output allocator. Both parsed values own their
/// slices independently of the adapter's buffer and the next store operation.
pub fn load(self: *Self, output: std.mem.Allocator, identity: Store.Key) !Loaded {
    const record = try self.store.get(identity, self.buffer) orelse return error.RecoveryRecordMissing;
    const submission = try sql.protocol.Json.parseFromSliceOwned(sql.Executor.Submission, output, record.original);
    errdefer submission.deinit();
    if (!std.mem.eql(u8, &identity, &try key(submission.value))) return error.RecoveryKeyConflict;
    const completion = if (record.evidence.len == 0) null else try sql.protocol.Json.parseFromSliceOwned(Completion, output, record.evidence);
    errdefer if (completion) |value| value.deinit();
    if (completion) |value| {
        if (value.value.definition != sql.protocol.native.current_definition) return error.IncompatibleRecoveryStore;
        try validateCompletion(submission.value, value.value.value);
    }
    return .{ .submission = submission, .completion = completion, .attempt = .{ .key = identity, .revision = record.revision } };
}
fn validateCompletion(submission: sql.Executor.Submission, completion: sql.results.CommandCompletion) !void {
    try completion.validate();
    if (completion.operation) |operation| if (!std.mem.eql(u8, &operation.account, &submission.account)) return error.RecoveryKeyConflict;
    if (submission.transaction) |handle| if (completion.transaction) |transaction| {
        if (!std.meta.eql(handle, transaction.handle)) return error.RecoveryKeyConflict;
    };
}
pub fn saveCompletion(self: *Self, attempt: Attempt, completion: sql.results.CommandCompletion) !Attempt {
    // Reusable bounded parsing storage, independent of retained record count.
    var scratch: std.heap.FixedBufferAllocator = .init(self.scratch);
    var loaded = try self.load(scratch.allocator(), attempt.key);
    defer loaded.deinit();
    if (loaded.attempt.revision != attempt.revision) return error.RecoveryRevisionConflict;
    try validateCompletion(loaded.submission.value, completion);
    const bytes = try self.encode(Completion{ .definition = sql.protocol.native.current_definition, .value = completion });
    if (loaded.completion) |prior| {
        // Never overwrite known completion with conflicting evidence. Compare
        // canonical bytes, including counts, transaction handle and diagnostics.
        const original = try sql.protocol.Json.valueAlloc(scratch.allocator(), prior.value);
        if (!std.mem.eql(u8, original, bytes)) return error.RecoveryOutcomeConflict;
    }
    return .{ .key = attempt.key, .revision = try self.store.update(attempt.key, attempt.revision, bytes) };
}

const t = std.testing;
const prepared: sql.Executor.Submission = .{
    .version = 1,
    .definition = sql.protocol.native.current_definition,
    .instance = @splat(7),
    .account = @splat(9),
    .database = "transit",
    .source = null,
    .transaction = null,
    .execute = .{ .sql = "INSERT INTO items VALUES (17)", .token = @splat(1) },
};
const applied: sql.results.CommandCompletion = .{
    .kind = .insert,
    .outcome = .applied,
    .counts = .{ .matched = 1, .changed = 1 },
    .operation = .{ .account = @splat(9), .id = 43 },
    .pending_restart = false,
    .diagnostic = null,
};
test "SQL local recovery retains frozen scope and completion across independent owners" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    const identity = try key(prepared);
    {
        var store = try Store.open(t.allocator, t.io, tmp.dir, "recovery", .{ .record_bytes = 8192 });
        defer store.deinit();
        var adapter = try Self.init(t.allocator, &store, .{});
        defer adapter.deinit();
        const attempt = try adapter.save(prepared);
        var conflicting = prepared;
        conflicting.execute.sql = "DELETE FROM items";
        try t.expectError(error.RecoveryKeyConflict, adapter.save(conflicting));
        const saved = try adapter.saveCompletion(attempt, applied);
        try t.expectEqual(2, saved.revision);
        _ = try adapter.saveCompletion(saved, applied);
        var wrong = applied;
        wrong.outcome = .rejected;
        try t.expectError(error.RecoveryOutcomeConflict, adapter.saveCompletion(saved, wrong));
    }
    var store = try Store.open(t.allocator, t.io, tmp.dir, "recovery", .{ .record_bytes = 8192 });
    defer store.deinit();
    var adapter = try Self.init(t.allocator, &store, .{});
    defer adapter.deinit();
    var loaded = try adapter.load(t.allocator, identity);
    defer loaded.deinit();
    try t.expectEqualStrings(prepared.execute.sql.?, loaded.submission.value.execute.sql.?);
    try t.expectEqual(.applied, loaded.completion.?.value.value.outcome);
    try t.expectEqual(43, loaded.completion.?.value.value.operation.?.id);
    const config: sql.Client.Config = .{ .endpoint = "http://127.0.0.1:1", .authentication = .trust };
    var client = try sql.Client.init(t.allocator, t.io, config);
    defer client.deinit();
    client.instance = prepared.instance;
    client.account = prepared.account;
    client.session = @splat(2);
    try t.expectEqual(prepared.execute.token.?, (try loaded.pending(&client)).token);
    client.account = @splat(3);
    try t.expectError(error.SqlObservationDenied, loaded.pending(&client));
}

test "SQL recovery uses fixed encoding and parsing reserves after initialization" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var failing: t.FailingAllocator = .init(t.allocator, .{});
    var store = try Store.open(failing.allocator(), t.io, tmp.dir, "recovery", .{ .record_bytes = 8192 });
    defer store.deinit();
    var adapter = try Self.init(failing.allocator(), &store, .{ .parse_bytes = 128 * 1024 });
    defer adapter.deinit();
    failing.fail_index = failing.alloc_index;
    for (0..16) |i| {
        var submission = prepared;
        submission.execute.token = @splat(@intCast(i + 1));
        const attempt = try adapter.save(submission);
        _ = try adapter.saveCompletion(attempt, applied);
    }
    try t.expect(!failing.has_induced_failure);
}
