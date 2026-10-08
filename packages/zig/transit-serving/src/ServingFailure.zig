//! Original rejected-control evidence. A native receipt is not a domain outcome.
const std = @import("std");
const root = @import("root.zig");
const p = root.protocol;
const d = p.Diagnostic;
const m = root.Model;
pub const Reason = enum(u8) {
    InvalidServingFrame,
    ServingExternalOriginRequired,
    UnexpectedServingOrigin,
    InvalidServingCommand,
    InvalidServingIdentity,
    InvalidServiceBinding,
    InvalidServicePolicy,
    ServingDenied,
    ServiceRevisionConflict,
    ServingIdentityConflict,
    ServingCapacity,
    ServiceUnpublished,
    InvalidWaitLifetime,
    ServingOperationNotFound,
    UnknownServingCorrelation,
    UnexpectedServingReplySource,
    UnexpectedTimerObserver,
    InvalidTimerObservation,
    PrematureTimer,
    UnsupportedServingFrame,
    InvalidReactiveSource,
    ReactiveSessionNotFound,
    ReactiveGenerationConflict,
    ReactiveSessionClosed,
    ReactiveSessionExpired,
    ReactiveResetRequired,
    InvalidReactiveLease,
    ReactiveCapacity,
    InvalidReactiveAttachment,
    ReactiveAttachmentConflict,
    ReactiveSubscriptionConflict,
    ReactiveLeaseConflict,
    InvalidRefreshBudget,
    InvalidRefreshTemplate,
    RefreshGenerationConflict,
    RefreshNotFound,
    RefreshResultConflict,
    UnexpectedRefreshWake,
    AccessDenied,
    QueryDenied,
    CatalogDenied,
    ResourceUnavailable,
    QuerySourceUnavailable,
    ResultUnavailable,
    PublicationNotPublished,
    UnsupportedReactiveSource,
    InvalidReactiveProgress,
    TableNotFound,
};
pub fn reason(cause: anyerror) ?Reason {
    return std.meta.stringToEnum(Reason, @errorName(cause));
}
pub const Class = struct { code: []const u8, category: d.Category, stage: d.Stage, message: []const u8 };
pub fn classification(value: Reason) Class {
    return switch (value) {
        .UnsupportedReactiveSource => .{ .code = "reactive.unsupported_source", .category = .unsupported, .stage = .admission, .message = "The declared watch requires two int64 columns with the first as the non-null primary key. The observed Table has a different shape or type. This control did not establish watch coverage; inspect the retained expected and actual types." },
        .InvalidReactiveProgress => .{ .code = "reactive.invalid_progress", .category = .integrity, .stage = .admission, .message = "The watch progress marker has a zero revision or a revision beyond the acquired source cut. This control did not establish coverage. Inspect the marker and source revision; do not infer continuity or a completed snapshot." },
        .TableNotFound => .{ .code = "reactive.table_absent", .category = .lifecycle, .stage = .admission, .message = "The declared Table was absent in the acquired watch source. This control did not establish coverage. Check the retained Table identity and source declaration under current read authority." },
        .InvalidServingFrame => .{ .code = "serving.invalid_frame", .category = .syntax, .stage = .input, .message = "The owner rejected a malformed Station frame. Use the current serving command encoder. This input did not admit an application operation or change a session." },
        .ServingExternalOriginRequired => .{ .code = "serving.external_origin_required", .category = .access, .stage = .input, .message = "Serving controls require the authenticated external caller origin. This input did not admit an application operation or change a session." },
        .UnexpectedServingOrigin => .{ .code = "serving.unexpected_origin", .category = .access, .stage = .input, .message = "This frame kind or authority-derived origin is not a serving command. This input did not admit an application operation or change a session." },
        .InvalidServingCommand => .{ .code = "serving.invalid_command", .category = .syntax, .stage = .input, .message = "The input is not a valid current serving command. Check its command variant, encoding, identities and the 64-byte inline payload bound. This input did not admit an application operation." },
        .InvalidServingIdentity => .{ .code = "serving.invalid_identity", .category = .binding, .stage = .input, .message = "Serving identities and counters must be nonzero native safe integers, at most 9007199254740991. This input did not perform its requested control." },
        .InvalidServiceBinding => .{ .code = "serving.invalid_binding", .category = .binding, .stage = .input, .message = "A service binding requires a nonzero codec, target and revision, a finite wait deadline and an active limit from 1 through 8. This input did not replace the binding." },
        .InvalidServicePolicy => .{ .code = "serving.invalid_policy", .category = .binding, .stage = .input, .message = "A service policy requires a nonzero revision and an active limit from 1 through 8. Command permission and read permission are separate. This input did not replace policy." },
        .ServingDenied => .{ .code = "serving.denied", .category = .access, .stage = .admission, .message = "This input lacked the required service permission or configured operator identity. It did not perform its requested control. Earlier admitted operations retain their own outcomes; inspect current rights before continuing." },
        .ServiceRevisionConflict => .{ .code = "serving.revision_conflict", .category = .conflict, .stage = .admission, .message = "The requested binding, codec or conditional publication revision differs from the original observed value. This input did not replace a declaration or admit an operation. Compare the retained expected and observed fields." },
        .ServingIdentityConflict => .{ .code = "serving.identity_conflict", .category = .conflict, .stage = .admission, .message = "This operation or session identity already names different frozen input. This input did not replace it. Compare the original and submitted commitments and inspect the original identity before reviewing new work." },
        .ServingCapacity => .{ .code = "serving.active_limit", .category = .limit, .stage = .admission, .message = "The service or caller active-operation limit has been reached. This input did not admit another operation. Inspect the original limit and active count; capacity pressure cannot expire earlier work." },
        .ServiceUnpublished => .{ .code = "serving.unpublished", .category = .lifecycle, .stage = .admission, .message = "The required service binding was absent or unpublished at this check. This input did not admit new work. Existing operations keep their recorded destinations and outcomes; inspect the required publication." },
        .InvalidWaitLifetime => .{ .code = "serving.wait_limit", .category = .limit, .stage = .admission, .message = "The requested wait deadline exceeds an applicable binding, process or resource lifetime. This input did not admit the operation. Compare the original requested deadline and applicable bound." },
        .ServingOperationNotFound => .{ .code = "serving.operation_absent", .category = .lifecycle, .stage = .admission, .message = "The owner found no operation at this caller-scoped identity. This input did not cancel or create one. Check the original operation and native admission receipt." },
        .UnknownServingCorrelation => .{ .code = "serving.correlation_absent", .category = .lifecycle, .stage = .input, .message = "The reply or timer names no retained serving wait at this correlation. This input did not complete another operation. Inspect the exact original wait and operation." },
        .UnexpectedServingReplySource => .{ .code = "serving.reply_source", .category = .access, .stage = .input, .message = "The reply came from a different authority-derived source than the recorded wait target. It did not complete the operation. Inspect the original destination and correlation." },
        .UnexpectedTimerObserver => .{ .code = "serving.timer_observer", .category = .access, .stage = .input, .message = "The timer input did not come from the configured authenticated observer. It did not time out the wait. A client clock cannot replace an authorized observation." },
        .InvalidTimerObservation => .{ .code = "serving.invalid_timer", .category = .binding, .stage = .input, .message = "The timer observation has invalid encoding, observer or deadline evidence. It did not time out the wait. Inspect the exact recorded wait before sending another observation." },
        .PrematureTimer => .{ .code = "serving.premature_timer", .category = .conflict, .stage = .input, .message = "The timer observation precedes the recorded wait deadline. This input did not close the wait. Observe the original deadline through the configured observer." },
        .UnsupportedServingFrame => .{ .code = "serving.unsupported_frame", .category = .unsupported, .stage = .input, .message = "This Station frame kind is not supported by the serving owner. This input did not admit or complete an application operation. Use its declared command and reply interfaces." },
        .InvalidReactiveSource => .{ .code = "reactive.invalid_source", .category = .binding, .stage = .input, .message = "The watch declaration has an invalid identity, invalid catalog metadata commitment, or names a different service target. This input did not publish the watch." },
        .ReactiveSessionNotFound => .{ .code = "reactive.session_absent", .category = .lifecycle, .stage = .admission, .message = "The owner found no session in this caller scope. This input did not create or renew one. Inspect the exact original open request and its committed disposition." },
        .ReactiveGenerationConflict => .{ .code = "reactive.generation_conflict", .category = .conflict, .stage = .admission, .message = "The requested session generation differs from the original recorded generation. This input did not change the session. Inspect the original session and reject replies belonging to another generation." },
        .ReactiveSessionClosed => .{ .code = "reactive.session_closed", .category = .lifecycle, .stage = .admission, .message = "This session was explicitly closed. This input did not reopen it or cancel accepted application commands. Inspect the original close outcome before explicitly opening a new session identity." },
        .ReactiveSessionExpired => .{ .code = "reactive.session_expired", .category = .lifecycle, .stage = .admission, .message = "The session has a recorded expiry or its lease deadline has been reached. This input did not renew it. A reached deadline alone does not prove the owner reclaimed its active slot; inspect the recorded phase." },
        .ReactiveResetRequired => .{ .code = "reactive.watch_changed", .category = .conflict, .stage = .admission, .message = "The watch, schema or progress marker was absent, unpublished or differed from the session source basis. This input did not continue the old watch. Inspect the original expected and observed source before an explicit authorized snapshot." },
        .InvalidReactiveLease => .{ .code = "reactive.invalid_lease", .category = .limit, .stage = .admission, .message = "The lease must advance beyond the recorded clock, remain within 30000 milliseconds and respect binding, process and resource deadlines. This input did not change the lease. Compare the original deadline and limiting bound." },
        .ReactiveCapacity => .{ .code = "reactive.active_limit", .category = .limit, .stage = .admission, .message = "The active session limit has been reached: four per service and two per caller. This input did not open another session. Inspect active sessions; transport loss or quota pressure cannot implicitly close them." },
        .InvalidReactiveAttachment => .{ .code = "reactive.invalid_attachment", .category = .binding, .stage = .input, .message = "An attachment requires a nonzero challenge nonce and the exact session identity. This input did not attach a transport. Use the declared challenge bootstrap and preserve any uncertain signed attachment." },
        .ReactiveAttachmentConflict => .{ .code = "reactive.attachment_conflict", .category = .conflict, .stage = .admission, .message = "The requested attachment generation differs from the recorded generation. This input did not replace the attachment. Inspect the existing attachment and fence older transport replies." },
        .ReactiveSubscriptionConflict => .{ .code = "reactive.subscription_conflict", .category = .conflict, .stage = .admission, .message = "The subscription identity or generation conflicts with the recorded session subscription. This input did not replace or remove it. Compare the original subscription fields before continuing." },
        .ReactiveLeaseConflict => .{ .code = "reactive.lease_conflict", .category = .conflict, .stage = .admission, .message = "The expected lease differs from the recorded lease, or the requested deadline does not advance it. This input did not renew the session. Inspect the original lease fields and committed clock." },
        .InvalidRefreshBudget => .{ .code = "refresh.invalid_budget", .category = .limit, .stage = .input, .message = "Follow requires a nonzero template identity and a budget from 1 through 8 selected query intents. This input did not create another Follow generation. Review the explicit finite budget." },
        .InvalidRefreshTemplate => .{ .code = "refresh.invalid_template", .category = .binding, .stage = .admission, .message = "The Follow template is not a complete query result for the declared source contract and schema. This input did not start a refresh. Inspect the original template and exact source basis." },
        .RefreshGenerationConflict => .{ .code = "refresh.generation_conflict", .category = .conflict, .stage = .admission, .message = "The requested Follow generation differs from the recorded generation. This input did not replace it. Inspect the exact current generation and retain its accepted query identities." },
        .RefreshNotFound => .{ .code = "refresh.absent", .category = .lifecycle, .stage = .admission, .message = "The owner found no Follow view at this identity. This input did not create or pause one. Inspect the original Follow request and its committed disposition." },
        .RefreshResultConflict => .{ .code = "refresh.result_conflict", .category = .conflict, .stage = .admission, .message = "The acknowledged query namespace or phase differs from the retained ready result. This input did not mark it covered. Verify the complete exact result before acknowledging its original namespace." },
        .UnexpectedRefreshWake => .{ .code = "refresh.unexpected_wake", .category = .access, .stage = .input, .message = "Only this owner may schedule its refresh wakeup. This input did not create query demand or authority. Use the declared Follow controls." },
        .AccessDenied => .{ .code = "serving.native_denied", .category = .access, .stage = .admission, .message = "Current native authority denied this control. This input did not complete its requested transition. Earlier accepted work remains independent; inspect current scope before continuing." },
        .CatalogDenied => .{ .code = "reactive.catalog_denied", .category = .access, .stage = .admission, .message = "Current catalog inspect/read policy denied this caller. No watch coverage was established. Review the caller policy in the retained catalog scope; the service identity does not grant the caller access." },
        .QueryDenied => .{ .code = "refresh.query_denied", .category = .access, .stage = .admission, .message = "The query authority denied this Follow control. This input did not establish result coverage. Inspect the current query and source permissions without repeating accepted work." },
        .ResourceUnavailable => .{ .code = "serving.resource_unavailable", .category = .lifecycle, .stage = .admission, .message = "A required resource or process was unavailable at this check. This input did not complete the requested transition. Unavailability does not establish the outcome of earlier admitted work." },
        .QuerySourceUnavailable => .{ .code = "refresh.source_unavailable", .category = .lifecycle, .stage = .admission, .message = "The required query source is unavailable. This input did not establish a replacement result. Retain the last exact basis and inspect the original source and query identities." },
        .ResultUnavailable => .{ .code = "refresh.result_unavailable", .category = .lifecycle, .stage = .admission, .message = "The required retained result is unavailable. This input did not prove coverage or replace the displayed result. Inspect the exact query and its retention state." },
        .PublicationNotPublished => .{ .code = "refresh.result_unpublished", .category = .lifecycle, .stage = .admission, .message = "The required result publication is not complete. This input did not acknowledge coverage. Inspect the exact original query publication before continuing." },
    };
}

pub const Kind = enum(u8) { service = 0, reactive = 1, refresh = 2 };
pub const Record = struct { reason: Reason, input: u64, kind: Kind, subject: u64, generation: u64, payload: [32]u8, cause: p.Value, witness: Witness };
pub const RevisionKind = enum(u8) { binding = 0, policy = 1, watch = 2, refresh = 3 };
pub const CapacityKind = enum(u8) { service = 0, caller = 1, service_slots = 2, sessions = 3, caller_sessions = 4 };
pub const LeaseKind = enum(u8) { clock = 0, interval = 1, binding = 2, process = 3, resource = 4, observer = 5 };
pub const ReaderCause = enum(u8) { AccessDenied, Forbidden, StateResourceExpired, UnknownStateResource, DeadlineExpired, RetiredProcess, CatalogDenied, QueryDenied, QuerySourceUnavailable, ResultUnavailable, PublicationNotPublished };
pub const ReaderOperation = enum(u8) { identity, source, requester, result };
pub const ReaderIdentity = enum(u8) { principal, pid, permissions, turn_pid };
pub const ResourceRole = enum(u8) { source, requester };
pub const Witness = union(enum(u8)) {
    none = 0,
    revision: struct { kind: RevisionKind, expected: u64, actual: u64, proposed: u64, present: bool } = 1,
    policy: struct { principal: u64, revision: u64, present: bool, commands: bool, reads: bool } = 2,
    identity: struct { expected: [32]u8, actual: [32]u8 } = 3,
    capacity: struct { kind: CapacityKind, actual: u8, limit: u8 } = 4,
    generation: struct { expected: u64, actual: u64 } = 5,
    session: struct { phase: root.ReactiveModel.Phase, deadline: u64, observed: u64, clock_known: bool } = 6,
    source: struct { expected: u64, actual: u64, present: bool, published: bool, target: u64, resource: u64, metadata: [32]u8 } = 7,
    lease: struct { kind: LeaseKind, requested: u64, observed: u64, limit: u64 } = 8,
    attachment: struct { expected: u64, actual: u64 } = 9,
    subscription: struct { expected: u64, actual: u64, requested: u64, active: u64 } = 10,
    renewal: struct { expected: u64, actual: u64, proposed: u64 } = 11,
    binding: struct { expected: u64, actual: u64, expected_codec: u16, actual_codec: u16, target: u64, present: bool, published: bool } = 12,
    refresh: struct { expected: root.RefreshModel.Namespace, actual: root.RefreshModel.Namespace, phase: root.RefreshModel.Phase } = 13,
    frame: struct { correlation: u64, expected: u64, actual: u64, kind: enum(u8) { reply_source, observer, timer, administrator }, actual_known: bool = true } = 14,
    target: struct { expected: u64, actual: u64, kind: enum(u8) { source, resource } } = 15,
    basis: struct { expected: [32]u8, actual: [32]u8, kind: enum(u8) { schema, contract, metadata } } = 16,
    source_kind: struct { expected: root.query.fuze.Unified.SourceKind, actual: root.query.fuze.Unified.SourceKind } = 17,
    table: root.RefreshModel.Namespace = 18,
    watch_type: struct { expected: root.query.fuze.Types.Tag, actual: root.query.fuze.Types.Tag, column: u8 = 1 } = 19,
    progress: struct { present: bool, actual: u64, limit: u64, key: [32]u8, length: u8 } = 20,
    reader_identity: struct { field: ReaderIdentity, expected: u64, actual: u64, present: bool = true, policy_revision: u64 = 0, policy_known: bool = false } = 21,
    reader_failure: struct { operation: ReaderOperation, principal: u64, resource: u64, namespace: u64 = 0, cause: ReaderCause } = 22,
    reader_resource: struct { role: ResourceRole, resource: u64, expected_writer: u64, actual_writer: u64, phase: @FieldType(p.Growth.Resource, "phase"), writer_check: bool, revision: u64 } = 23,
    watch_shape: struct { columns: u8, first_nullable: bool, primary_columns: u8, primary_first: bool } = 25,
    reader_template: struct { namespace: u64, present: bool, phase: root.query.UnifiedRequest.Phase = .uploading, manifest: bool = false } = 24,
};
pub const Context = struct { witness: Witness = .none, cause: ?anyerror = null };
/// Storage uses compact u64 fields. Public supplied identities use decimal text,
/// including rejected values outside the native safe-integer range.
pub const Summary = struct { reason: Reason, input: u64, kind: Kind, subject: d.Unsigned, generation: d.Unsigned, payload: [32]u8, cause: p.Value };
pub const Disposition = struct { record: Summary, diagnostic: ?d };
pub fn remember(context: ?*Context, witness: Witness) void {
    if (context) |value| value.witness = witness;
}
pub fn bindingWitness(value: ?m.Binding, expected: u64, codec: u16) Witness {
    return .{ .binding = .{ .expected = expected, .actual = if (value) |v| v.revision else 0, .expected_codec = codec, .actual_codec = if (value) |v| v.codec else 0, .target = if (value) |v| v.target else 0, .present = value != null, .published = if (value) |v| v.published else false } };
}
pub fn sourceWitness(value: ?root.ReactiveModel.Source, expected: u64) Witness {
    return .{ .source = .{ .expected = expected, .actual = if (value) |v| v.revision else 0, .present = value != null, .published = if (value) |v| v.published else false, .target = if (value) |v| v.target else 0, .resource = if (value) |v| v.resource else 0, .metadata = if (value) |v| v.metadata_digest else @splat(0) } };
}
pub fn progressWitness(key: p.Value, actual: ?u64, limit: u64) !Witness {
    if (key.len == 0 or key.len > 32) return error.InvalidServingRecord;
    var value: Witness = .{ .progress = .{ .present = actual != null, .actual = actual orelse 0, .limit = limit, .key = @splat(0), .length = @intCast(key.len) } };
    @memcpy(value.progress.key[0..key.len], key.slice());
    return value;
}
pub fn capture(turn: *const root.station.Turn, command: ?m.Command, value: Reason, context: Context) !Record {
    var result: Record = .{ .reason = value, .input = turn.delivery.input.position, .kind = .service, .subject = 0, .generation = 0, .payload = undefined, .witness = context.witness, .cause = try p.Value.init(if (context.cause) |cause| @errorName(cause) else @tagName(value)) };
    if (result.cause.len > 64) return error.InvalidServingRecord;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.serving.input.v1\x00");
    hash.update(turn.delivery.input.value.slice());
    result.payload = hash.finalResult();
    if (command) |input| switch (input) {
        .submit => |request| result.subject = request.operation,
        .cancel => |id| result.subject = id,
        .reactive => |request| {
            result.kind = .reactive;
            const identity: root.ReactiveModel.SessionIdentity = switch (request) {
                .open => |open| .{ .session = open.session, .generation = 0 },
                inline .attach, .subscribe, .renew, .unsubscribe, .expire => |control| control.identity,
                .close => |id| id,
                else => .{ .session = 0, .generation = 0 },
            };
            result.subject = identity.session;
            result.generation = identity.generation;
        },
        .refresh => |request| {
            result.kind = .refresh;
            const identity = switch (request) {
                .follow => |follow| follow.view.session,
                .acknowledged => |ack| ack.selection.session,
                .invalidate, .pause => |selection| selection.session,
            };
            result.subject = identity.session;
            result.generation = identity.generation;
        },
        else => {},
    };
    return result;
}
pub fn record(turn: *root.station.Turn, command: ?m.Command, value: Reason, context: Context) !void {
    const principal = if (turn.delivery.input.origin == .external) turn.delivery.input.origin.external.principal else 0;
    const primary = try capture(turn, command, value, context);
    try turn.write(m.key('e', principal, primary.input), try root.Codec.encode('e', primary));
}
pub fn read(reader: anytype, realm: u64, resource: u64, service: u64, principal: u64, input: u64) !?Disposition {
    const encoded = (try reader.read(m.key('e', principal, input))) orelse return null;
    const primary = try root.Codec.decode(Record, 'e', encoded);
    if (primary.input != input) return error.InvalidServingRecord;
    return .{ .record = .{ .reason = primary.reason, .input = primary.input, .kind = primary.kind, .subject = .init(primary.subject), .generation = .init(primary.generation), .payload = primary.payload, .cause = primary.cause }, .diagnostic = try project(realm, resource, service, primary) };
}
pub fn project(realm: u64, resource: u64, service: u64, primary: Record) !d {
    try m.identity(service);
    try m.identity(primary.input);
    if (primary.cause.len == 0 or primary.cause.len > 64) return error.InvalidServingRecord;
    const info = classification(primary.reason);
    var result = try d.init(info.code, info.category, info.stage, .input_rejected, .domain_status, info.message);
    result.cause = try d.Code.init(primary.cause.slice());
    const scoped = primary.subject != 0 and primary.subject <= p.max_counter;
    result.identity = .{ .domain = if (primary.kind != .service and scoped) .reactive else .application, .id = .init(if (scoped) primary.subject else service), .realm = .init(realm), .resource = .init(resource) };
    try result.fact(.native_input, .owner, .{ .unsigned = .init(primary.input) });
    try result.fact(.source_basis, .owner, .{ .digest = primary.payload });
    try result.text(.source_kind, .owner, @tagName(primary.kind));
    if (primary.subject != 0) try result.fact(.object, .caller, .{ .unsigned = .init(primary.subject) });
    if (primary.generation != 0) try result.fact(.generation, .caller, .{ .unsigned = .init(primary.generation) });
    try facts(&result, primary.witness);
    try result.action(.inspect_status);
    if (info.category == .access) try result.action(.inspect_scope);
    try result.validate();
    return result;
}
pub fn facts(result: *d, witness: Witness) !void {
    switch (witness) {
        .none => {},
        .reader_identity => |value| {
            try result.text(.field_path, .owner, switch (value.field) {
                .principal => "identity.principal",
                .pid => "identity.pid",
                .permissions => "identity.permissions",
                .turn_pid => "requester.pid",
            });
            try result.fact(.expected_value, .owner, .{ .unsigned = .init(value.expected) });
            if (value.present) try result.fact(.supplied_value, .execution, .{ .unsigned = .init(value.actual) }) else try result.absent(.supplied_value, .execution, .inapplicable);
            try result.text(.constraint, .owner, if (value.field == .permissions) "Native permissions must contain every required bit." else "The observed identity must equal the required identity.");
            if (value.policy_known) try result.fact(.actual_policy, .execution, .{ .unsigned = .init(value.policy_revision) });
        },
        .reader_failure => |value| {
            result.cause = try d.Code.init(@tagName(value.cause));
            try result.text(.native_cause, .execution, @tagName(value.cause));
            try result.text(.operation, .owner, @tagName(value.operation));
            try result.fact(.principal, .execution, .{ .unsigned = .init(value.principal) });
            if (value.resource != 0) try result.fact(.actual_resource, .caller, .{ .unsigned = .init(value.resource) });
            if (value.namespace != 0) try result.fact(.actual_namespace, .owner, .{ .unsigned = .init(value.namespace) });
        },
        .reader_resource => |value| {
            try result.text(.field_path, .owner, switch (value.role) {
                .source => if (value.writer_check) "source.writer" else "source.phase",
                .requester => if (value.writer_check) "requester.writer" else "requester.phase",
            });
            try result.fact(.actual_resource, .owner, .{ .unsigned = .init(value.resource) });
            try result.fact(.actual_revision, .execution, .{ .unsigned = .init(value.revision) });
            if (value.writer_check) {
                try result.fact(.expected_value, .owner, .{ .unsigned = .init(value.expected_writer) });
                try result.fact(.supplied_value, .execution, .{ .unsigned = .init(value.actual_writer) });
            } else {
                try result.text(.expected_value, .owner, "active");
                try result.text(.supplied_value, .execution, @tagName(value.phase));
            }
        },
        .reader_template => |value| {
            try result.text(.field_path, .owner, "template.status");
            try result.fact(.actual_namespace, .owner, .{ .unsigned = .init(value.namespace) });
            try result.fact(.presence, .execution, .{ .boolean = value.present });
            try result.text(.expected_value, .owner, "complete with a result manifest");
            if (value.present) {
                try result.text(.supplied_value, .execution, @tagName(value.phase));
                try result.fact(.published, .execution, .{ .boolean = value.manifest });
            } else try result.absent(.supplied_value, .execution, .inapplicable);
        },
        .table => |value| try result.fact(.table, .owner, .{ .unsigned = .init(value.value) }),
        .watch_shape => |value| {
            try result.fact(.expected_count, .owner, .{ .unsigned = .init(2) });
            try result.fact(.actual_count, .owner, .{ .unsigned = .init(value.columns) });
            try result.fact(.presence, .owner, .{ .boolean = value.first_nullable });
            try result.fact(.key, .owner, .{ .boolean = value.primary_first });
            try result.fact(.required, .owner, .{ .unsigned = .init(value.primary_columns) });
            try result.text(.unit, .owner, "columns; nullable first column; primary key on first column; primary key columns");
        },
        .watch_type => |value| {
            try result.fact(.column, .owner, .{ .unsigned = .init(value.column) });
            try result.text(.expected_type, .owner, @tagName(value.expected));
            try result.text(.actual_type, .owner, @tagName(value.actual));
        },
        .progress => |value| {
            if (value.length == 0 or value.length > value.key.len) return error.InvalidServingRecord;
            const hex = std.fmt.bytesToHex(value.key, .lower);
            try result.text(.source_key, .owner, hex[0 .. @as(usize, value.length) * 2]);
            try result.text(.unit, .owner, "hex progress-marker key and source revision");
            try result.fact(.presence, .owner, .{ .boolean = value.present });
            if (value.present) try result.fact(.actual_revision, .owner, .{ .unsigned = .init(value.actual) }) else try result.absent(.actual_revision, .owner, .inapplicable);
            try result.fact(.limit, .owner, .{ .unsigned = .init(value.limit) });
        },
        .target => |value| {
            try result.fact(if (value.kind == .source) .expected_source else .expected_resource, .owner, .{ .unsigned = .init(value.expected) });
            try result.fact(if (value.kind == .source) .actual_source else .actual_resource, .owner, .{ .unsigned = .init(value.actual) });
        },
        .basis => |value| {
            try result.fact(.expected_schema, .owner, .{ .digest = value.expected });
            try result.fact(.actual_schema, .owner, .{ .digest = value.actual });
            try result.text(.schema_origin, .owner, @tagName(value.kind));
        },
        .source_kind => |value| {
            try result.text(.expected_type, .owner, @tagName(value.expected));
            try result.text(.actual_type, .owner, @tagName(value.actual));
            try result.text(.unit, .owner, "query source kind");
        },
        .frame => |value| {
            try result.fact(.operation, .caller, .{ .unsigned = .init(value.correlation) });
            try result.fact(if (value.kind == .timer) .lease else .expected_source, .owner, .{ .unsigned = .init(value.expected) });
            if (value.actual_known) try result.fact(if (value.kind == .timer) .observed_clock else .actual_source, .caller, .{ .unsigned = .init(value.actual) }) else try result.absent(.actual_source, .owner, .inapplicable);
            try result.text(.unit, .owner, @tagName(value.kind));
        },
        .revision => |value| {
            try result.text(.operation, .owner, @tagName(value.kind));
            try result.fact(.expected_revision, .owner, .{ .unsigned = .init(value.expected) });
            try result.fact(.actual_revision, .owner, .{ .unsigned = .init(value.actual) });
            try result.fact(.proposal, .caller, .{ .unsigned = .init(value.proposed) });
            try result.fact(.presence, .owner, .{ .boolean = value.present });
        },
        .policy => |value| {
            try result.fact(.scope, .owner, .{ .unsigned = .init(value.principal) });
            try result.fact(.actual_policy, .owner, .{ .unsigned = .init(value.revision) });
            try result.fact(.permissions, .owner, .{ .unsigned = .init(@as(u8, @intFromBool(value.commands)) | (@as(u8, @intFromBool(value.reads)) << 1)) });
            try result.text(.unit, .owner, "service permissions: command=1, read=2");
            try result.fact(.presence, .owner, .{ .boolean = value.present });
        },
        .identity => |value| {
            try result.fact(.expected_schema, .owner, .{ .digest = value.expected });
            try result.fact(.actual_schema, .owner, .{ .digest = value.actual });
            try result.text(.schema_origin, .owner, "original and submitted identity commitments");
        },
        .capacity => |value| {
            try result.text(.budget, .owner, @tagName(value.kind));
            try result.fact(.actual_count, .owner, .{ .unsigned = .init(value.actual) });
            try result.fact(.limit, .owner, .{ .unsigned = .init(value.limit) });
            try result.fact(.required, .owner, .{ .unsigned = .init(@as(u16, value.actual) + 1) });
            try result.text(.unit, .owner, "active slots");
        },
        inline .generation, .attachment => |value| {
            try result.fact(.expected_revision, .owner, .{ .unsigned = .init(value.expected) });
            try result.fact(.actual_revision, .owner, .{ .unsigned = .init(value.actual) });
            try result.text(.unit, .owner, if (witness == .generation) "session generation" else "attachment generation");
        },
        .session => |value| {
            try result.text(.operation, .owner, @tagName(value.phase));
            try result.fact(.lease, .owner, .{ .unsigned = .init(value.deadline) });
            if (value.clock_known) try result.fact(.observed_clock, .owner, .{ .unsigned = .init(value.observed) }) else try result.absent(.observed_clock, .owner, .unrecorded);
            try result.text(.unit, .owner, "lease deadline and observed clock in milliseconds");
        },
        .source => |value| {
            try result.fact(.expected_revision, .owner, .{ .unsigned = .init(value.expected) });
            try result.fact(.actual_revision, .owner, .{ .unsigned = .init(value.actual) });
            try result.fact(.actual_resource, .owner, .{ .unsigned = .init(value.resource) });
            try result.fact(.actual_source, .owner, .{ .unsigned = .init(value.target) });
            if (value.present) try result.fact(.actual_schema, .owner, .{ .digest = value.metadata }) else try result.absent(.actual_schema, .owner, .inapplicable);
            try result.fact(.published, .owner, .{ .boolean = value.published });
            try result.fact(.presence, .owner, .{ .boolean = value.present });
        },
        .lease => |value| {
            try result.text(.budget, .owner, @tagName(value.kind));
            try result.fact(.lease, .caller, .{ .unsigned = .init(value.requested) });
            if (value.observed != 0 or value.kind == .clock or value.kind == .observer) try result.fact(.observed_clock, .owner, .{ .unsigned = .init(value.observed) }) else try result.absent(.observed_clock, .owner, .unrecorded);
            try result.fact(.limit, .owner, .{ .unsigned = .init(value.limit) });
            try result.text(.unit, .owner, "milliseconds");
        },
        .subscription => |value| {
            try result.fact(.expected_revision, .caller, .{ .unsigned = .init(value.expected) });
            try result.fact(.actual_revision, .owner, .{ .unsigned = .init(value.actual) });
            try result.fact(.proposal, .caller, .{ .unsigned = .init(value.requested) });
            try result.fact(.subscription, .owner, .{ .unsigned = .init(value.active) });
            try result.text(.unit, .owner, "subscription generation and identity");
        },
        .renewal => |value| {
            try result.fact(.expected_revision, .caller, .{ .unsigned = .init(value.expected) });
            try result.fact(.actual_revision, .owner, .{ .unsigned = .init(value.actual) });
            try result.fact(.lease, .caller, .{ .unsigned = .init(value.proposed) });
            try result.text(.unit, .owner, "lease deadline in milliseconds");
        },
        .binding => |value| {
            try result.fact(.expected_revision, .caller, .{ .unsigned = .init(value.expected) });
            try result.fact(.actual_revision, .owner, .{ .unsigned = .init(value.actual) });
            try result.fact(.expected_codec, .caller, .{ .unsigned = .init(value.expected_codec) });
            try result.fact(.actual_codec, .owner, .{ .unsigned = .init(value.actual_codec) });
            try result.fact(.actual_source, .owner, .{ .unsigned = .init(value.target) });
            try result.fact(.published, .owner, .{ .boolean = value.published });
            try result.fact(.presence, .owner, .{ .boolean = value.present });
        },
        .refresh => |value| {
            try result.fact(.expected_namespace, .caller, .{ .unsigned = .init(value.expected.value) });
            try result.fact(.actual_namespace, .owner, .{ .unsigned = .init(value.actual.value) });
            try result.text(.operation, .owner, @tagName(value.phase));
        },
    }
}
