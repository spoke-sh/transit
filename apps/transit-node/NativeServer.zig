//! Shared native HTTP admission, current-rights checks and snapshot ownership.
//! Provider composition supplies persistence; these request semantics are shared.
const std = @import("std");
const core = @import("transit_core");
const wire = @import("transit_client");
const observations = @import("transit_observability");
const telemetry = observations.telemetry;
const g = wire.protocol.Growth;
const http = @import("transit_http_server");
const memory = @import("transit_memory");
const Notifications = @import("Notifications.zig");

pub const Metrics = struct {
    requests: u64 = 0,
    failures: u64 = 0,
    elapsed_ns: u64 = 0,
    request_payload_bytes: u64 = 0,
    response_bytes: u64 = 0,
};

pub fn Host(comptime Provider: type) type {
    return struct {
        const Engine = Provider.Engine;
        const Lane = Provider.Lane;
        pub fn serve(init: std.process.Init, engine: *Engine, lanes: []Lane, config: anytype, diagnostics: *telemetry.Runtime) !void {
            var server: Server = .{ .io = init.io, .allocator = init.gpa, .engine = engine, .accept_trace_parent = config.accept_trace_parent, .request_metrics = config.request_metrics };
            var listener = try (try std.Io.net.IpAddress.parseIp4(config.listen, config.port)).listen(init.io, .{ .reuse_address = true });
            defer listener.deinit(init.io);
            const shared_pages = try init.gpa.alloc(?Provider.PageStore.Cached, config.resident_pages);
            defer init.gpa.free(shared_pages);
            @memcpy(shared_pages, engine.page_store.cache);
            var shared_pages_count: usize = 0;
            for (shared_pages) |*slot| {
                if (slot.* == null) break;
                shared_pages_count += 1;
            }
            var context: Context = .{
                .server = &server,
                .diagnostics = diagnostics,
                .lanes = lanes,
                .snapshots = .{ .epoch = engine.snapshot_epoch.? },
                .position = engine.head.position,
                .latest_cached = engine.journal.cached,
                .shared_pages = shared_pages,
                .shared_pages_count = shared_pages_count,
                .shared_access = engine.page_store.access,
            };
            diagnostics.event(.{ .name = "service.ready" });
            try http.serve(init.io, init.gpa, &listener, .{ .connections = 16, .requests = 4, .control_requests = 2, .wait_requests = 4, .header_timeout_ms = @min(1000, config.request_timeout_ms), .request_timeout_ms = config.request_timeout_ms, .requests_per_connection = 64 }, &context);
        }
        const Server = struct {
            io: std.Io,
            allocator: std.mem.Allocator,
            request_metrics: bool,
            allocation_probe: ?*memory.AllocationProbe = null,
            engine: *Engine,
            observation: telemetry.Http = .{},
            accept_trace_parent: bool,
            context: *Context = undefined,
            lane: *Lane = undefined,
            mutex: *std.Io.Mutex = undefined,
            working: bool = false,
            changed: *Notifications = undefined,
            position: *u64 = undefined,
            snapshots: *core.SnapshotLeases = undefined,
            snapshot_lease: ?core.SnapshotLeases.Lease = null,
            lock_wait_ns: u64 = 0,
            work_started: ?std.Io.Clock.Timestamp = null,
            cache_hits: u64 = 0,
            cache_misses: u64 = 0,
            before_metrics: Metrics = .{},
            before_pages: u64 = 0,
            before_bytes: u64 = 0,
            before_blocks: u64 = 0,
            before_block_bytes: u64 = 0,
            metrics: ?Work = null,
            work_failure: ?[]const u8 = null,
            read_only: bool = true,
            uncertain_mutation: bool = false,

            const Work = struct {
                wait_ns: u64,
                work_ns: u64,
                cache_hits: u64,
                cache_misses: u64,
                staged_pages: u64,
                staged_bytes: u64,
                staged_blocks: u64,
                staged_block_bytes: u64,
                provider: Metrics,
                failure: ?[]const u8 = null,
                /// Backing allocations through the handler's allocator before
                /// writing the response. Excludes separately owned engine/I/O
                /// buffers; live bytes still belong to this in-flight request.
                request_memory: ?struct {
                    alloc_attempts: usize,
                    growing_resize_attempts: usize,
                    remap_attempts: usize,
                    acquired_bytes: usize,
                    live_bytes: usize,
                    peak_bytes: usize,
                } = null,
            };

            fn beginWork(self: *Server) void {
                // Lane ownership was acquired before dispatch. There is no shared
                // mutable engine or provider client to lock across storage I/O.
                self.working = true;
                self.work_started = .now(self.io, .awake);
                self.cache_hits = self.engine.page_store.hits;
                self.cache_misses = self.engine.page_store.misses;
                if (Provider.readMetrics(self.engine)) |metrics| {
                    self.before_metrics = metrics;
                    self.before_pages = self.engine.page_store.created;
                    self.before_bytes = self.engine.page_store.create_payload_bytes_attempted;
                    self.before_blocks = self.engine.page_store.blocks_created;
                    self.before_block_bytes = self.engine.page_store.block_payload_bytes_attempted;
                }
                Provider.trace(self.engine, self.observation.span.context);
            }
            fn finishWork(self: *Server) void {
                if (!self.working) return;
                const work_ns: u64 = @intCast(@max(0, self.work_started.?.durationTo(.now(self.io, .awake)).raw.toNanoseconds()));
                self.observation.work_ns = (self.observation.work_ns orelse 0) +| work_ns;
                self.observation.cache_hits = self.engine.page_store.hits - self.cache_hits;
                self.observation.cache_misses = self.engine.page_store.misses - self.cache_misses;
                if (Provider.readMetrics(self.engine)) |metrics| {
                    var delta: Metrics = undefined;
                    inline for (@typeInfo(Metrics).@"struct".field_names) |field|
                        @field(delta, field) = @field(metrics, field) - @field(self.before_metrics, field);
                    const previous = self.metrics;
                    self.metrics = .{
                        .wait_ns = self.lock_wait_ns,
                        .work_ns = work_ns,
                        .cache_hits = self.observation.cache_hits.?,
                        .cache_misses = self.observation.cache_misses.?,
                        .staged_pages = self.engine.page_store.created - self.before_pages,
                        .staged_bytes = self.engine.page_store.create_payload_bytes_attempted - self.before_bytes,
                        .staged_blocks = self.engine.page_store.blocks_created - self.before_blocks,
                        .staged_block_bytes = self.engine.page_store.block_payload_bytes_attempted - self.before_block_bytes,
                        .provider = delta,
                        .failure = self.work_failure,
                    };
                    if (previous) |prior| {
                        inline for (.{ "wait_ns", "work_ns", "cache_hits", "cache_misses", "staged_pages", "staged_bytes", "staged_blocks", "staged_block_bytes" }) |field|
                            @field(self.metrics.?, field) +|= @field(prior, field);
                        inline for (@typeInfo(Metrics).@"struct".field_names) |field|
                            @field(self.metrics.?.provider, field) +|= @field(prior.provider, field);
                    }
                }
                Provider.trace(self.engine, null);
                self.working = false;
            }
            /// Called by core only after signature and current native admission checks.
            pub fn begin(self: *Server, engine: *Engine, principal: core.growing.Principal, kind: @FieldType(g.Query, "kind")) !void {
                const selector = core.SnapshotLeases.Selector.from(kind) orelse return;
                const clock = engine.clock orelse return error.ClockUnavailable;
                try self.mutex.lock(self.io);
                defer self.mutex.unlock(self.io);
                // Sample under the short registry lock. An older sample waiting behind
                // a newer reservation must not look like a trusted-clock rollback.
                const now = try clock.sample();
                try engine.validateTime(now);
                self.snapshot_lease = try self.snapshots.acquire(principal.grant.subject, principal.epoch, selector, now);
                engine.snapshot_time_floor_ms = self.snapshots.time_floor_ms;
                engine.snapshot_serial = self.snapshot_lease.?.serial;
                engine.snapshot_slots = &self.snapshot_lease.?.values;
            }
            pub fn end(self: *Server, engine: *Engine, success: bool) void {
                const lease = self.snapshot_lease orelse return;
                engine.snapshot_slots = null;
                self.mutex.lockUncancelable(self.io);
                defer self.mutex.unlock(self.io);
                // No untrusted data enters release: core produced this exclusively
                // reserved slot and the host owns its ticket through cancellation.
                self.snapshots.release(lease, success, engine.snapshot_time_floor_ms) catch unreachable;
                self.snapshot_lease = null;
            }
            fn json(self: *Server, request: *std.http.Server.Request, status: std.http.Status, value: anytype) !void {
                // The response owns its bytes. Slow peers must not hold authority access.
                self.finishWork();
                const bytes = try wire.protocol.Json.valueAlloc(self.allocator, value);
                defer self.allocator.free(bytes);
                self.observation.status = @backingInt(status);
                if (@hasField(@TypeOf(value), "err")) {
                    self.observation.error_type = @tagName(value.err);
                    self.observation.protocol_outcome = if (self.uncertain_mutation or status == .service_unavailable) .uncertain else .rejected;
                }
                return self.jsonBytes(request, status, bytes);
            }
            fn jsonBytes(self: *Server, request: *std.http.Server.Request, status: std.http.Status, bytes: []const u8) !void {
                self.finishWork();
                self.observation.status = @backingInt(status);
                var metric_buffer: [1536]u8 = undefined;
                var metric_writer: std.Io.Writer = .fixed(&metric_buffer);
                var headers: [2]std.http.Header = undefined;
                headers[0] = .{ .name = "content-type", .value = "application/json" };
                var count: usize = 1;
                if (self.metrics) |recorded| {
                    var metrics = recorded;
                    if (self.allocation_probe) |probe| metrics.request_memory = .{
                        .alloc_attempts = probe.counts.alloc_attempts,
                        .growing_resize_attempts = probe.counts.growing_resize_attempts,
                        .remap_attempts = probe.counts.remap_attempts,
                        .acquired_bytes = probe.counts.acquired_bytes,
                        .live_bytes = probe.live_bytes,
                        .peak_bytes = probe.peak_bytes,
                    };
                    // Diagnostics are optional and never change the authority result.
                    if (std.json.Stringify.value(metrics, .{}, &metric_writer)) |_| {
                        headers[1] = .{ .name = "x-transit-work", .value = metric_writer.buffered() };
                        count += 1;
                    } else |_| {}
                }
                try request.respond(bytes, .{ .status = status, .keep_alive = true, .extra_headers = headers[0..count] });
                self.observation.written = true;
            }

            fn payload(self: *Server, request: *std.http.Server.Request) !void {
                if (comptime @hasDecl(Provider, "payload")) {
                    const w = wire.protocol.NativePayload;
                    if (request.head.method != .POST) return self.json(request, .not_found, wire.protocol.ErrorResponse{ .err = .NotFound });
                    if (try http.header(request, "x-transit-wait") != null or try http.header(request, "x-transit-control") != null)
                        return self.json(request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidRequest });
                    const bytes = request.readerExpectNone(&.{}).allocRemaining(self.allocator, .limited(wire.max_body)) catch return self.json(request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidBody });
                    defer self.allocator.free(bytes);
                    const parsed = std.json.parseFromSlice(w.Request, self.allocator, bytes, .{}) catch return self.json(request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidRequest });
                    defer parsed.deinit();
                    parsed.value.validate() catch return self.json(request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidRequest });
                    self.read_only = parsed.value.operation.kind != .create;
                    self.uncertain_mutation = !self.read_only;
                    self.observation.protocol_outcome = if (self.read_only) .read else .uncertain;
                    self.observation.realm = parsed.value.proof.claim.realm;
                    self.observation.pid = parsed.value.operation.payload.pid;
                    self.observation.operation = switch (parsed.value.operation.kind) {
                        .create => "payload.create",
                        .verify => "payload.verify",
                        .read => "payload.read",
                    };
                    const response = try self.allocator.create(w.Response);
                    defer self.allocator.destroy(response);
                    self.beginWork();
                    Provider.payload(self.engine, &parsed.value, response) catch |err| return self.failure(request, err);
                    self.observation.protocol_outcome = if (self.read_only) .read else .none;
                    return self.json(request, .ok, response.*);
                } else return self.json(request, .not_found, wire.protocol.ErrorResponse{ .err = .NotFound });
            }

            fn table(self: *Server, request: *std.http.Server.Request) !void {
                if (comptime @hasDecl(Provider, "TableHost")) {
                    const owner = self.lane.table orelse return self.json(request, .not_found, wire.protocol.ErrorResponse{ .err = .NotFound });
                    if (request.head.method != .POST) return self.json(request, .not_found, wire.protocol.ErrorResponse{ .err = .NotFound });
                    if (try http.header(request, "x-transit-wait") != null) return self.json(request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidRequest });
                    const control = if (try http.header(request, "x-transit-control")) |hint| blk: {
                        if (!std.mem.eql(u8, hint, "table")) return self.json(request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidRequest });
                        break :blk true;
                    } else false;
                    const response = self.tableWork(request, owner, control) catch |err| switch (err) {
                        error.Canceled => return error.Canceled,
                        error.InvalidBody => return self.json(request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidBody }),
                        error.InvalidRequest => return self.json(request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidRequest }),
                        error.CatalogDenied, error.TableDelegationDenied, error.InvalidAuthorizationCredential, error.AuthorizationChanged => return self.json(request, .forbidden, wire.protocol.ErrorResponse{ .err = .AccessDenied }),
                        error.TableDefinitionChanged => return self.json(request, .conflict, wire.protocol.ErrorResponse{ .err = .TableDefinitionChanged }),
                        error.StaleClientLease, error.ClientTokenConflict, error.ClientBudgetConflict, error.ClientOperationConflict, error.ClientOperationPending => return self.json(request, .conflict, wire.protocol.ErrorResponse{ .err = .Conflict }),
                        error.ClientTokenCapacity => return self.json(request, .service_unavailable, wire.protocol.ErrorResponse{ .err = .StorageQuota }),
                        error.SourceChanged, error.DataIdentityConflict, error.CatalogObjectBusy, error.CatalogObservationChanged, error.TableDataChanged, error.TableHistoryConflict, error.NamedResourceNotAdmitted, error.NamedResourceAllocationUnreconciled, error.NamedResourceAllocationMismatch, error.NamedResourceIdentityConflict, error.NativeAllocationSequenceChanged, error.NativeAllocationBusy => return self.json(request, .conflict, wire.protocol.ErrorResponse{ .err = .Conflict }),
                        error.TableSnapshotReleased, error.TableSnapshotNotPinned => return self.json(request, .conflict, wire.protocol.ErrorResponse{ .err = .QueryExpired }),
                        error.TableHistoryMissing, error.WalHistoryMissing, error.WalHistoryTrimmed => return self.json(request, .conflict, wire.protocol.ErrorResponse{ .err = .HistoryReclaimed }),
                        error.InvalidTableBasis, error.TableHistoryRetentionRequired, error.IncompatibleColumnEncoding, error.IncompatibleColumnCollation, error.UnsupportedColumnCollation, error.IbmHfpUnderflow, error.IbmHfpOverflow, error.UnrepresentableEbcdic037 => return self.json(request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidRequest }),
                        error.ClientOperationMissing, error.InvalidDirectRecord, error.DirectRecordMissing, error.InvalidClientToken, error.InvalidPlanEncoding, error.InvalidProjection, error.InvalidTableBinary, error.TablePayloadTooLarge, error.InvalidTableMutationIntent, error.InvalidInsertRowIdentity, error.InvalidTableStatementIntent, error.InvalidTableAccessRequest, error.InvalidMutationPlan, error.MutationBatchTooLarge, error.UnsupportedTableMutationShape, error.TableBatchTooLarge, error.InvalidTableReadBudget, error.InvalidTableCursor, error.InvalidTableSnapshotCursor, error.TableReadBudgetTooSmall, error.InvalidTableKey, error.TableSchemaChanged => return self.json(request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidRequest }),
                        else => return self.failure(request, err),
                    };
                    defer self.allocator.free(response);
                    // Typed results distinguish admission, commitment and reads;
                    // a successful HTTP exchange alone is not a native receipt.
                    self.observation.protocol_outcome = if (self.read_only) .read else .none;
                    return self.jsonBytes(request, .ok, response);
                } else return self.json(request, .not_found, wire.protocol.ErrorResponse{ .err = .NotFound });
            }
            /// All request parsing and catalog scratch ends before either a
            /// success or failure response waits on the transport. The separately
            /// allocated result crosses the final authority fence inside execute.
            fn tableWork(self: *Server, request: *std.http.Server.Request, owner: anytype, control: bool) ![]const u8 {
                const w = Provider.TableHost.Protocol;
                var arena = std.heap.ArenaAllocator.init(self.allocator);
                defer arena.deinit();
                const allocator = arena.allocator();
                const bytes = request.readerExpectNone(&.{}).allocRemaining(allocator, .limited(w.max_request_bytes)) catch |err| return switch (err) {
                    error.OutOfMemory => err,
                    else => error.InvalidBody,
                };
                const parsed = w.Request.parse(allocator, bytes) catch |err| return if (err == error.OutOfMemory) err else error.InvalidRequest;
                if (control and parsed.value.transport().control == null) return error.InvalidRequest;
                self.read_only = !parsed.value.transport().mutation;
                self.uncertain_mutation = !self.read_only;
                self.observation.protocol_outcome = if (self.read_only) .read else .uncertain;
                self.observation.realm = parsed.value.connection.scope.realm;
                self.observation.operation = parsed.value.transport().operation;
                self.beginWork();
                const before = self.engine.head.position;
                return execution: {
                    defer {
                        // Registrar commits share native authority with public
                        // commands. Even a later failure must wake native waits.
                        if (self.engine.head.position != before) {
                            self.mutex.lockUncancelable(self.io);
                            defer self.mutex.unlock(self.io);
                            self.position.* = @max(self.position.*, self.engine.head.position);
                            self.context.syncFromLane(self.lane);
                            self.changed.publishAll(self.io);
                        }
                    }
                    break :execution owner.execute(self.io, self.engine, &arena, self.allocator, parsed.value);
                };
            }
            fn failure(self: *Server, request: *std.http.Server.Request, err: anyerror) !void {
                const denied = switch (err) {
                    error.Unauthorized, error.Forbidden, error.WrongProtocolRealm, error.SignatureVerificationFailed, error.IdentityElement, error.NonCanonical, error.InvalidEncoding => true,
                    error.UnknownAuthorizationRole, error.UnknownAuthorizationObject, error.UnknownAuthorizationGrant, error.UnknownAuthorizationChange, error.UnknownRoleMembership, error.RetiredAuthorizationRole, error.RetiredAuthorizationObject, error.InvalidAuthorizationDomain => true,
                    else => false,
                };
                if (denied) return self.json(request, .forbidden, wire.protocol.ErrorResponse{ .err = .AccessDenied });
                // Opt-in work diagnostics retain a compiler-defined cause category.
                // No arbitrary provider text, keys, payloads or authorization details.
                self.work_failure = @errorName(err);
                const code = std.meta.stringToEnum(wire.protocol.ErrorCode, @errorName(err)) orelse .AuthorityUnavailable;
                const status: std.http.Status = switch (code) {
                    .Conflict, .TableDefinitionChanged, .QueryExpired, .HistoryReclaimed, .StaleAuthorizationRevision, .StaleAuthorizationCredential, .AuthorizationSubjectDenied => .conflict,
                    .AuthorityUnavailable, .ClockRollback, .ClockUnavailable, .DeadlineUncertain, .UntrustedTime, .AdmissionClosed, .ControlCapacity, .StorageQuota => .service_unavailable,
                    else => .unprocessable_entity,
                };
                return self.json(request, status, wire.protocol.ErrorResponse{ .err = code });
            }
            /// Reobserve only the same signed read after a moving authority cut. The
            /// engine validates its signature, scope, source and current rights on every
            /// attempt. This bound neither retries mutations nor changes read selectors.
            fn readQuery(self: *Server, signed: g.SignedQuery, body: ?*wire.protocol.Blocks.Body) !g.Response {
                for (0..8) |_| {
                    return (if (body) |output| self.engine.queryBlocks(signed, self, output) else self.engine.queryWithSnapshots(signed, self)) catch |err| {
                        if (err == error.Conflict) continue;
                        return err;
                    };
                }
                return error.Conflict;
            }
            /// An ordinary CAS loss accepted no transition. Reprepare only this exact
            /// signed identity/body at the new head; every grant, generation, sequence
            /// and expected resource revision is validated again. Other failures leave
            /// uncertainty/reconciliation with the caller.
            fn submitCommand(self: *Server, signed: g.SignedRequest, body: ?*const wire.protocol.Blocks.Body) !u64 {
                for (0..8) |_| {
                    return self.engine.submitWithBlocks(signed, body) catch |err| {
                        if (err == error.Conflict) continue;
                        return err;
                    };
                }
                return error.Conflict;
            }
            pub fn handle(self: *Server, request: *std.http.Server.Request) !void {
                defer self.finishWork();
                const route: []const u8 = route: {
                    inline for (.{ "/health", "/v1/command", "/v1/query", "/v1/blocks", "/v1/payload", "/table/v1" }) |known| if (std.mem.eql(u8, request.head.target, known)) break :route known;
                    break :route "unmatched";
                };
                self.observation.received(request, route, self.accept_trace_parent);
                if (std.mem.eql(u8, route, "/table/v1")) return self.table(request);
                if (std.mem.eql(u8, route, "/v1/payload")) return self.payload(request);
                const control = if (try http.header(request, "x-transit-control")) |value| control: {
                    if (!std.mem.eql(u8, value, "snapshot")) return self.json(request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidRequest });
                    break :control true;
                } else false;
                if (request.head.method == .GET and std.mem.eql(u8, route, "/health")) {
                    self.beginWork();
                    try self.engine.refresh();
                    return self.json(request, .ok, .{ .ready = true, .profile = "native_v1" });
                }
                const hint: ?wire.WaitHint = if (try http.header(request, "x-transit-wait")) |value|
                    wire.WaitHint.parse(value) catch return self.json(request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidRequest })
                else
                    null;
                const mutation = std.mem.eql(u8, route, "/v1/command");
                const bulk = std.mem.eql(u8, route, "/v1/blocks");
                if (hint != null and (mutation or control)) return self.json(request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidRequest });
                if (request.head.method != .POST or (!mutation and !bulk and !std.mem.eql(u8, route, "/v1/query"))) return self.json(request, .not_found, wire.protocol.ErrorResponse{ .err = .NotFound });
                const bytes = request.readerExpectNone(&.{}).allocRemaining(self.allocator, .limited(wire.max_body)) catch return self.json(request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidBody });
                defer self.allocator.free(bytes);
                if (mutation) {
                    const parsed = std.json.parseFromSlice(g.CommandEnvelope, self.allocator, bytes, .{}) catch return self.json(request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidRequest });
                    defer parsed.deinit();
                    g.validate(parsed.value.request) catch return self.json(request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidRequest });
                    self.beginWork();
                    self.observation.protocol_outcome = .uncertain;
                    const position = self.submitCommand(parsed.value.signed(), if (parsed.value.blocks) |*body| body else null) catch |err| return self.failure(request, err);
                    // Coalesced local hints only. Reconciliation can also discover a
                    // commit by another node; every waiter still revalidates its query.
                    {
                        self.mutex.lockUncancelable(self.io);
                        defer self.mutex.unlock(self.io);
                        self.position.* = @max(self.position.*, self.engine.head.position);
                        self.context.syncFromLane(self.lane);
                        self.changed.publish(self.io, parsed.value.request.command);
                    }
                    self.observation.protocol_outcome = .receipt;
                    self.observation.realm = parsed.value.request.realm;
                    self.observation.sequence = parsed.value.request.sequence;
                    self.observation.pid = g.commandPid(parsed.value.request.command);
                    self.observation.operation = @tagName(parsed.value.request.command);
                    self.observation.position = position;
                    return self.json(request, .ok, wire.Receipt{ .position = position });
                }
                const parsed = std.json.parseFromSlice(g.SignedQuery, self.allocator, bytes, .{}) catch return self.json(request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidRequest });
                defer parsed.deinit();
                if (control and parsed.value.query.kind != .close_snapshot and !(parsed.value.query.kind == .snapshot_read and parsed.value.query.kind.snapshot_read.finish)) return self.json(request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidRequest });
                g.validateQuery(parsed.value.query) catch return self.json(request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidRequest });
                self.beginWork();
                if (hint != null and !wire.WaitHint.allows(parsed.value.query)) return self.json(request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidRequest });
                if (bulk) {
                    if (hint != null or control) return self.json(request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidRequest });
                    const acquired = try self.allocator.create(g.BlockRead.Response);
                    defer self.allocator.destroy(acquired);
                    acquired.response = self.readQuery(parsed.value, &acquired.blocks) catch |err| return self.failure(request, err);
                    self.observation.protocol_outcome = .read;
                    self.observation.realm = acquired.response.realm;
                    self.observation.operation = @tagName(parsed.value.query.kind);
                    self.observation.position = acquired.response.position;
                    return self.json(request, .ok, acquired.*);
                }
                var response = self.readQuery(parsed.value, null) catch |err| return self.failure(request, err);
                if (hint) |wait| {
                    if (wait.after > response.position) return self.json(request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidRequest });
                    if (wait.after == response.position) {
                        self.finishWork();
                        // Compare and register under the same lock used by publication;
                        // a commit between the read and registration cannot be missed.
                        {
                            try self.mutex.lock(self.io);
                            defer self.mutex.unlock(self.io);
                            self.context.syncFromLane(self.lane);
                            if (self.position.* <= wait.after) {
                                try self.changed.wait(self.io, self.mutex, parsed.value.query, wait.milliseconds);
                            }
                            self.context.syncToLane(self.lane);
                        }
                        self.beginWork();
                        // Recheck signature, grants, scope, lifecycle and authority tail
                        // after every wake/timeout, including remote commits and revoke.
                        response = self.readQuery(parsed.value, null) catch |err| return self.failure(request, err);
                    }
                }
                self.observation.protocol_outcome = .read;
                self.observation.realm = response.realm;
                self.observation.operation = @tagName(parsed.value.query.kind);
                self.observation.position = response.position;
                return self.json(request, .ok, response);
            }
        };

        /// Bounded lanes own mutable execution/cache/transport state. The short shared
        /// mutex covers only admission, notification registration and volatile pin slots.
        const Context = struct {
            server: *Server,
            diagnostics: *telemetry.Runtime,
            mutex: std.Io.Mutex = .init,
            changed: Notifications = .{},
            lanes: []Lane,
            snapshots: core.SnapshotLeases,
            position: u64,
            latest_cached: @FieldType(Provider.Store, "cached") = null,
            shared_pages: []?Provider.PageStore.Cached,
            shared_pages_count: usize = 0,
            shared_pages_epoch: u64 = 1,
            shared_access: u64 = 0,

            fn touchShared(self: *Context) u64 {
                if (self.shared_access == std.math.maxInt(u64)) {
                    for (self.shared_pages[0..self.shared_pages_count]) |*slot| if (slot.*) |*entry| {
                        entry.used = 0;
                    };
                    self.shared_access = 0;
                }
                self.shared_access += 1;
                return self.shared_access;
            }

            fn rememberShared(self: *Context, ref: *const core.pages.Reference, page: *const core.pages.Page) void {
                if (self.shared_pages.len == 0) return;
                for (self.shared_pages[0..self.shared_pages_count]) |*slot| if (slot.*) |*entry| {
                    if (std.meta.eql(ref.*, entry.reference)) {
                        entry.used = self.touchShared();
                        return;
                    }
                };
                var selected: usize = 0;
                if (self.shared_pages_count < self.shared_pages.len) {
                    selected = self.shared_pages_count;
                    self.shared_pages_count += 1;
                } else {
                    var oldest: u64 = std.math.maxInt(u64);
                    for (self.shared_pages, 0..) |*slot, i| {
                        const entry = &(slot.* orelse {
                            selected = i;
                            break;
                        });
                        if (entry.used < oldest) {
                            oldest = entry.used;
                            selected = i;
                        }
                    }
                }
                self.shared_pages[selected] = .{ .reference = ref.*, .page = page.*, .used = self.touchShared() };
                self.shared_pages_epoch +|= 1;
            }

            fn syncToLane(self: *Context, lane: *Lane) void {
                if (self.latest_cached) |shared_entry| {
                    if (lane.journal.cached == null or shared_entry.at >= lane.journal.cached.?.at) {
                        lane.journal.cached = shared_entry;
                    }
                }
                if (self.shared_pages.len == lane.pages.cache.len and lane.pages_epoch != self.shared_pages_epoch) {
                    const count = self.shared_pages_count;
                    @memcpy(lane.pages.cache[0..count], self.shared_pages[0..count]);
                    if (count < lane.pages.cache.len) {
                        lane.pages.cache[count] = null;
                    }
                    lane.pages.access = self.shared_access;
                    lane.pages_epoch = self.shared_pages_epoch;
                }
                lane.acquired_access = lane.pages.access;
                lane.acquired_created = lane.pages.created;
                lane.acquired_misses = lane.pages.misses;
            }

            fn syncFromLane(self: *Context, lane: *Lane) void {
                if (lane.journal.cached) |lane_entry| {
                    if (self.latest_cached == null or lane_entry.at >= self.latest_cached.?.at) {
                        self.latest_cached = lane_entry;
                    }
                } else if (self.latest_cached) |shared_entry| {
                    if (shared_entry.at < lane.engine.head.history_floor) {
                        self.latest_cached = null;
                    }
                }
                if (self.shared_pages.len > 0 and self.shared_pages.len == lane.pages.cache.len) {
                    if (lane.pages.created != lane.acquired_created or lane.pages.misses != lane.acquired_misses) {
                        const prior_epoch = self.shared_pages_epoch;
                        for (lane.pages.cache) |*slot| {
                            const entry = &(slot.* orelse break);
                            if (entry.used > lane.acquired_access) {
                                self.rememberShared(&entry.reference, &entry.page);
                            }
                        }
                        if (lane.pages_epoch == prior_epoch) {
                            lane.pages_epoch = self.shared_pages_epoch;
                        }
                    }
                    lane.acquired_access = lane.pages.access;
                    lane.acquired_created = lane.pages.created;
                    lane.acquired_misses = lane.pages.misses;
                }
            }

            fn acquire(self: *Context, io: std.Io) !*Lane {
                try self.mutex.lock(io);
                defer self.mutex.unlock(io);
                for (self.lanes) |*lane| if (!lane.busy) {
                    lane.busy = true;
                    self.syncToLane(lane);
                    return lane;
                };
                return error.ControlCapacity;
            }
            fn release(self: *Context, io: std.Io, lane: *Lane) void {
                self.mutex.lockUncancelable(io);
                defer self.mutex.unlock(io);
                self.syncFromLane(lane);
                lane.busy = false;
            }
            pub fn isWait(_: *@This(), request: *std.http.Server.Request) bool {
                return (http.header(request, "x-transit-wait") catch null) != null;
            }
            pub fn isControl(_: *@This(), request: *std.http.Server.Request) bool {
                return std.mem.eql(u8, request.head.target, "/v1/command") or
                    (if (http.header(request, "x-transit-control") catch null) |value| std.mem.eql(u8, value, "snapshot") or std.mem.eql(u8, value, "table") else false);
            }
            pub fn connectionError(self: *@This(), err: anyerror, started: bool) void {
                if (!started and err != error.EndOfStream) self.diagnostics.event(.{ .name = "transit.http.connection", .level = .debug, .error_type = @errorName(err) });
            }
            pub fn handle(self: *@This(), io: std.Io, allocator: std.mem.Allocator, request: *std.http.Server.Request) !void {
                const lane = try self.acquire(io);
                defer self.release(io, lane);
                var server = self.server.*;
                // One probe per admitted handler; response buffers remain
                // charged while request.respond waits on a slow client. Engine
                // caches and provider owners retain their separate allocators.
                var allocations: memory.AllocationProbe = .{ .parent = allocator };
                server.io = io;
                server.allocator = if (server.request_metrics) allocations.allocator() else allocator;
                server.allocation_probe = if (server.request_metrics) &allocations else null;
                server.context = self;
                server.lane = lane;
                server.mutex = &self.mutex;
                server.changed = &self.changed;
                server.engine = &lane.engine;
                server.position = &self.position;
                server.snapshots = &self.snapshots;
                server.observation = .{ .span = self.diagnostics.begin(.server, null) };
                var failure: ?anyerror = null;
                server.read_only = !std.mem.eql(u8, request.head.target, "/v1/command");
                defer server.observation.finish("transit.http.request", failure, if (failure) |err| err == error.Canceled else false, server.read_only);
                server.handle(request) catch |err| {
                    failure = err;
                    return err;
                };
            }
        };
    };
}
