//! Public Transit I/O for a finite effect worker. No external transport lives
//! here. The host supplies protocol admission/policy and freshly fenced ownership.
const std = @import("std");
const x = @import("root.zig");
const s = x.station;
const p = x.p;
const g = p.Growth;
const Turn = s.Turn;
const Server = s.GenServer;
pub const Options = struct { tick: []const u8, admission_missing: anyerror, followup_missing: anyerror, request_oversize: anyerror, limits: x.Limits };
pub fn For(comptime Host: type, comptime Adapter: type, comptime options: Options) type {
    return struct {
        pub const Operation = union(enum) {
            idle,
            create: struct { deadline: u64, limits: x.Limits, policy: ?Adapter.Policy.Reference = null },
            begin: struct { ordinal: u32, kind: Adapter.Kind, spec: x.Publication.Spec },
            append: struct { ordinal: u32, chunk: u32, bytes: p.Value },
            seal: u32,
            intent,
            attempts: u32,
            bind: g.Effect,
            settle: g.Effect,
            release_caller: u64,
            retire,
            collect,
            publish,
            finish: u32,
            unknown,
        };
        pub fn admission(self: *Host) !Adapter.Service.Admission {
            const policy = self.config.admission orelse return options.admission_missing;
            return .{ .caller = policy.caller, .resource = policy.resource, .endpoint_revision = self.config.endpoint_revision, .reconcile_before_ms = self.config.reconcile_before_ms orelse return error.MissingReconciliationDeadline, .max_attempts = self.config.max_attempts };
        }
        pub fn exchange(self: *Host) !x.Exchange {
            const association = (try self.server.session.association(try p.Value.init(self.config.association))) orelse return error.MissingStateAssociation;
            return .{ .resource = association.resource, .id = self.config.exchange };
        }
        pub fn command(self: *Host, command_value: g.Command) !p.Receipt {
            const sequence = (try self.reader.query(.{ .capabilities = {} })).principal_sequence + 1;
            const signed = try g.sign(.{ .realm = self.config.realm, .principal = self.config.principal, .sequence = sequence, .command = command_value }, self.reader.key);
            // Retry only identical Transit bytes. Returning uncertainty terminates
            // this activation; a new OS worker must obtain fresh fenced ownership.
            for (0..3) |_| {
                return self.reader.wire.submit(signed) catch |err| {
                    if (err == error.Rejected or err == error.Conflict or err == error.AccessDenied) return err;
                    continue;
                };
            }
            return error.AuthorityOutcomeUnknown;
        }
        pub fn handle(raw: ?*anyopaque, turn: *Turn, frame: s.Frame) !void {
            const self: *Host = @ptrCast(@alignCast(raw.?));
            const ex: x.Exchange = .{ .resource = turn.view.resource, .id = self.config.exchange };
            // This first worker owns a private control mailbox. Application ingress
            // is a separately scoped service obligation, not arbitrary callback data.
            switch (turn.delivery.input.origin) {
                .external => |origin| if (origin.principal != self.config.principal or frame.kind != .cast or !std.mem.eql(u8, frame.payload.slice(), "Adapter.tick.v1")) return error.UnexpectedWorkerInput,
                .effect => |origin| {
                    const descriptor = try ex.inspect(turn);
                    if (origin.id != descriptor.effect or origin.attempt != descriptor.attempt or origin.executor != descriptor.executor) return error.InvalidExchangeAttempt;
                    if (frame.kind != .cast) return error.UnexpectedWorkerInput;
                    const reference = try x.Client.Reference.decode(frame.payload);
                    if (!std.meta.eql(reference, try ex.reference(turn))) return error.InvalidExchangeCoverage;
                    return;
                },
                .process => {
                    if (std.mem.startsWith(u8, frame.payload.slice(), Adapter.Service.Release.magic)) {
                        try Adapter.Service.release(turn, ex, try self.admission());
                    } else if (std.mem.startsWith(u8, frame.payload.slice(), Adapter.Service.Followup.magic)) {
                        const target = self.config.followup orelse return Adapter.Service.rejectCall(turn, .denied);
                        _ = try Adapter.Service.admitFollowup(turn, ex.id, try self.admission(), target, options.limits, self);
                    } else {
                        if (self.config.followup != null) return Adapter.Service.rejectCall(turn, .denied);
                        _ = try Adapter.Service.admit(turn, ex.id, try self.admission(), options.limits);
                    }
                    return;
                },
            }
            switch (self.operation) {
                .idle => {},
                .create => |c| {
                    if (self.config.followup) |follow| {
                        const parent: x.Exchange = .{ .resource = turn.view.resource, .id = follow.parent };
                        const policy = c.policy orelse return options.followup_missing;
                        const context = if (try ex.lineage(turn)) |linked| linked.context else p.Value{};
                        _ = try parent.followupWithContext(turn, ex.id, follow.reason, policy.id, policy.revision, c.limits, context);
                    } else {
                        const prior = if (try turn.read(x.Exchange.key(ex.id, 'd', 0))) |value| try x.Descriptor.decode(value) else null;
                        _ = try x.Exchange.create(turn, ex.id, .{ .caller = if (prior) |d| d.caller else turn.delivery.pid, .input = if (prior) |d| d.input else turn.delivery.input.position, .protocol = Adapter.protocol_format }, c.limits, c.deadline);
                    }
                },
                .begin => |b| {
                    _ = try ex.beginSegment(turn, b.ordinal, @backingInt(b.kind), b.spec);
                },
                .append => |a| {
                    _ = try ex.append(turn, a.ordinal, a.chunk, a.bytes.slice());
                },
                .seal => |ordinal| {
                    _ = try ex.sealSegment(turn, ordinal);
                },
                .intent => {
                    _ = try ex.commitIntent(turn);
                },
                .attempts => |limit| try ex.configureAttempts(turn, limit),
                .bind => |authorized| {
                    _ = try ex.bind(turn, authorized);
                },
                .settle => |terminal| {
                    _ = try ex.settle(turn, terminal);
                },
                .release_caller => |caller| {
                    _ = try ex.releaseCaller(turn, caller);
                },
                .retire => {
                    _ = try ex.retire(turn);
                },
                .collect => {
                    _ = try ex.collect(turn);
                },
                .publish => {
                    _ = try Adapter.Service.publish(turn, ex);
                },
                .finish => |code| {
                    _ = try ex.finish(turn, code);
                },
                .unknown => {
                    _ = try ex.closeUnknown(turn);
                },
            }
        }
        pub fn drive(self: *Host) !void {
            return self.driveUntil(null);
        }
        pub fn driveUntil(self: *Host, input: ?u64) !void {
            const handler: Server.Handler = .{ .context = self, .handle = handle };
            for (0..32) |_| {
                const result = self.server.step(handler, now(self.io) + 30000) catch |err| {
                    if (err == error.Rejected or err == error.Conflict or err == error.AccessDenied or self.server.pending == null) return err;
                    continue;
                };
                switch (result) {
                    .committed => {
                        if (input == null) return;
                        if (self.server.confirmation) |confirmed| if (confirmed.kind == .commit and confirmed.input == input.?) return;
                    },
                    .idle => return if (input == null) {} else error.WorkerMailboxBusy,
                    .progress => {},
                    .blocked => return self.server.handler_error orelse error.BehaviorBlocked,
                }
            }
            return error.AuthorityOutcomeUnknown;
        }
        pub fn apply(self: *Host, operation: Operation) !void {
            if (self.server.pending != null) return error.AuthorityOutcomeUnknown;
            self.operation = operation;
            defer self.operation = .idle;
            const sent = try self.command(.{ .send = .{ .pid = self.config.pid, .value = try (s.Frame{ .kind = .cast, .payload = try p.Value.init("Adapter.tick.v1") }).encode() } });
            try self.driveUntil(sent.position);
        }
        pub fn stage(self: *Host, kind: Adapter.Kind, bytes: []const u8) !void {
            const ex = try self.exchange();
            const ordinal = (try self.reader.inspect(ex.resource, ex.id)).segments;
            return self.stageAt(ordinal, kind, bytes);
        }
        pub fn stageAt(self: *Host, ordinal: u32, kind: Adapter.Kind, bytes: []const u8) !void {
            const ex = try self.exchange();
            const spec = try x.Publication.Digest.of(Adapter.protocol_format, bytes);
            var source = try self.reader.reader(ex.resource);
            if (ordinal < (try ex.inspect(&source)).segments) {
                const member = try ex.member(&source, ordinal);
                if (member.kind != @backingInt(kind) or !std.meta.eql(member.spec(), spec)) return error.ExchangeIdentityConflict;
                return;
            }
            try self.apply(.{ .begin = .{ .ordinal = ordinal, .kind = kind, .spec = spec } });
            for (0..spec.chunks()) |i| try self.apply(.{ .append = .{ .ordinal = ordinal, .chunk = @intCast(i), .bytes = try p.Value.init(bytes[i * 256 ..][0..try spec.size(@intCast(i))]) } });
            try self.apply(.{ .seal = ordinal });
        }
        pub fn capture(raw: *anyopaque, kind: Adapter.Kind, bytes: []const u8) !void {
            const self: *Host = @ptrCast(@alignCast(raw));
            try self.stage(kind, bytes);
        }
        pub fn effect(self: *Host) !g.Effect {
            const ex = try self.exchange();
            return self.effectFor(ex);
        }
        pub fn effectFor(self: *Host, ex: x.Exchange) !g.Effect {
            const source = try self.reader.reader(ex.resource);
            const page = try self.reader.query(.{ .entries = .{ .resource = ex.resource, .revision = source.view.revision, .key = x.Exchange.key(ex.id, 'i', 0) } });
            const record = page.body.entries.page.entries[0] orelse return error.UnknownEffect;
            // Growing v1 gives entries and the same-turn effect their publication
            // position. The immutable intent is therefore a durable exact lookup
            // anchor, avoiding a scan through all of this PID's earlier effects.
            if (record.revision == 0) return error.InvalidExchangeAttempt;
            const effect_value = (try self.reader.query(.{ .effects = .{ .pid = self.config.pid, .after = record.revision - 1, .position = page.position } })).body.effects.entries[0] orelse return error.UnknownEffect;
            if (effect_value.id != record.revision or !effect_value.payload.eql(record.value)) return error.InvalidExchangeAttempt;
            const intent = try x.Intent.decode(effect_value.payload);
            if (intent.resource != ex.resource or intent.exchange != ex.id) return error.InvalidExchangeAttempt;
            return effect_value;
        }
        pub fn load(self: *Host, ordinal: u32, buffer: []u8) ![]const u8 {
            return self.loadFrom(try self.exchange(), ordinal, buffer);
        }
        pub fn loadFrom(self: *Host, ex: x.Exchange, ordinal: u32, buffer: []u8) ![]const u8 {
            var source = try self.reader.reader(ex.resource);
            const member = try ex.member(&source, ordinal);
            if (member.length > buffer.len) return options.request_oversize;
            var cursor = try ex.publication().open(&source, @as(u64, ordinal) + 1);
            if (!std.meta.eql(cursor.spec, member.spec())) return error.InvalidExchangeCoverage;
            var count: usize = 0;
            while (true) {
                const part = try ex.publication().read(&source, cursor);
                @memcpy(buffer[count..][0..part.bytes.len], part.bytes.slice());
                count += part.bytes.len;
                cursor = part.next orelse break;
            }
            return buffer[0..count];
        }
    };
}
fn now(io: std.Io) u64 {
    return @intCast(std.Io.Clock.real.now(io).toMilliseconds());
}
