//! Resumable offline transfer into a private candidate sink. Every event remains
//! provisional until source verification and consumption both finish. This owns
//! no storage, pins, transaction, authorization or publication.
const std = @import("std");
const Profile = @import("Profile.zig");
const Reader = @import("Reader.zig");
const Event = @import("Event.zig").Event;
const contract = Profile.contract;
const Self = @This();

pub const Ticket = struct { binding: [32]u8, ordinal: u64 };
pub const Pending = struct { ticket: Ticket, event: Event };
pub const Step = struct {
    consumed: usize,
    result: union(enum) { event: Pending, need_input, yield, verified },
};
pub const Offered = enum { consumed, blocked };
pub const PumpStep = struct {
    consumed: usize,
    result: enum { progress, blocked, need_input, yield, verified },
};

binding: contract.Candidate.Binding,
reader: Reader,
pending: ?Pending = null,
ordinal: u64 = 0,
state: enum { reading, verified, failed, cancelled } = .reading,
cause: ?anyerror = null,

/// The first driver handles one exact local part without relationships. Compound
/// commitments remain useful vocabulary, but do not resolve parts or grant pins.
pub fn init(binding: contract.Candidate.Binding, part: contract.Part, workspace: Reader.Workspace) !Self {
    try binding.validate();
    try binding.source.requireExact();
    try (try Profile.capabilities(binding.interpretation)).require(binding.interpretation, .parse);
    if (binding.source.parts != 1 or binding.source.root != 0 or binding.source.relationships != 0) return error.UnsupportedDocumentCandidateSource;
    var source = try contract.Container.Commitment.init(binding.interpretation.digest, 0);
    try source.addPart(part);
    if (!std.meta.eql(try source.finish(), binding.source)) return error.DocumentCandidateConflict;
    return .{ .binding = binding, .reader = try Reader.init(binding.interpretation, part, workspace) };
}

/// Reoffers a pending event with zero input consumption until consume() succeeds.
/// Input is borrowed only for this call. Event bytes belong to parser workspace
/// until consumption followed by the next next()/pump() call, cancel or failure.
pub fn next(self: *Self, input: []const u8, eof: bool, work: u32) !Step {
    if (work == 0) return error.InvalidDocumentWorkBudget;
    try self.requireUsable();
    if (self.pending) |pending| return .{ .consumed = 0, .result = .{ .event = pending } };
    if (self.state == .verified) {
        if (input.len != 0) return error.DocumentParserComplete;
        return .{ .consumed = 0, .result = .verified };
    }
    return self.advance(input, eof, work) catch |err| {
        self.fail(err);
        return err;
    };
}

fn advance(self: *Self, input: []const u8, eof: bool, work: u32) !Step {
    const step = try self.reader.next(input, eof, work);
    const result: @FieldType(Step, "result") = switch (step.result) {
        .event => |event| result: {
            self.ordinal = std.math.add(u64, self.ordinal, 1) catch return error.DocumentNodeLimitExceeded;
            const pending: Pending = .{ .ticket = .{ .binding = self.binding.digest, .ordinal = self.ordinal }, .event = event };
            self.pending = pending;
            break :result .{ .event = pending };
        },
        .need_input => .need_input,
        .yield => .yield,
        .complete => result: {
            _ = try self.reader.verifiedPart();
            self.state = .verified;
            break :result .verified;
        },
    };
    return .{ .consumed = step.consumed, .result = result };
}

/// Local buffer handoff, not durable acceptance or a protocol acknowledgement.
/// The sink must finish using/copying the event before consuming its ticket.
pub fn consume(self: *Self, ticket: Ticket) !void {
    try self.requireUsable();
    const pending = self.pending orelse return error.DocumentCandidateNoEvent;
    if (!std.meta.eql(ticket, pending.ticket)) return error.DocumentCandidateConflict;
    self.pending = null;
}

/// Optional push adapter: sink.offer(event) returns Offered or an error. It is
/// called once per pump, must bound its own work and may borrow bytes only until
/// this event is consumed. A blocked offer must not consume a partial event.
/// Sink errors invalidate this candidate; the sink must discard private output.
pub fn pump(self: *Self, input: []const u8, eof: bool, work: u32, sink: anytype) !PumpStep {
    const step = try self.next(input, eof, work);
    const result: @FieldType(PumpStep, "result") = switch (step.result) {
        .event => |pending| result: {
            const offered: Offered = sink.offer(pending.event) catch |err| {
                self.fail(err);
                return err;
            };
            if (offered == .blocked) break :result .blocked;
            try self.consume(pending.ticket);
            break :result .progress;
        },
        .need_input => .need_input,
        .yield => .yield,
        .verified => .verified,
    };
    return .{ .consumed = step.consumed, .result = result };
}

/// Cancelling even a verified offline candidate invalidates its local result.
/// Existing failures retain their first cause. No remote rollback is implied.
pub fn cancel(self: *Self) void {
    if (self.state == .failed or self.state == .cancelled) return;
    self.state = .cancelled;
    self.pending = null;
}

pub fn verifiedPart(self: *const Self) !contract.Part {
    if (self.state != .verified or self.pending != null) return error.IncompleteDocumentFrame;
    return self.reader.verifiedPart();
}

pub fn verifiedBinding(self: *const Self) !contract.Candidate.Binding {
    _ = try self.verifiedPart();
    return self.binding;
}

fn requireUsable(self: *const Self) !void {
    switch (self.state) {
        .failed => return error.DocumentCandidateFailed,
        .cancelled => return error.DocumentCandidateCancelled,
        .reading, .verified => {},
    }
}

fn fail(self: *Self, err: anyerror) void {
    self.cause = err;
    self.state = .failed;
    self.pending = null;
}
