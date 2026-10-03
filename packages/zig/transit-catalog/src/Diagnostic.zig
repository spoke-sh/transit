//! Authorized catalog evidence, independent of presentation or transport. A
//! historical receipt is never replaced by an observation of today's catalog.
const c = @import("root.zig");
const d = c.protocol.Diagnostic;
const m = c.Model;

pub fn receipt(value: m.Receipt) !d {
    try value.validate();
    var result = try d.init(switch (value.outcome) {
        .applied => "catalog.applied",
        .name_conflict => "catalog.name_conflict",
        .object_conflict => "catalog.object_conflict",
        .table_conflict => "catalog.table_conflict",
    }, if (value.outcome == .applied) .lifecycle else .constraint, .execute, if (value.outcome == .applied) .applied else .rejected, .domain_status, switch (value.outcome) {
        .applied => "This CREATE TABLE applied. Its receipt records the original declaration; inspect the current catalog separately if its present binding is needed.",
        .name_conflict => "The requested name was already bound in this catalog. This CREATE TABLE created no Table.",
        .object_conflict => "The requested object identity was already occupied in this catalog. This CREATE TABLE created no Table.",
        .table_conflict => "The requested Table identity was already occupied in the target resource. This CREATE TABLE created no Table.",
    });
    result.identity = .{ .domain = .catalog, .id = .init(value.request.operation), .realm = .init(value.request.scope.realm), .resource = .init(value.request.scope.resource) };
    try result.fact(.native_input, .owner, .{ .unsigned = .init(value.input) });
    try result.fact(.scope, .owner, .{ .unsigned = .init(value.request.scope.catalog) });
    try result.fact(.object, .caller, .{ .unsigned = .init(value.request.object) });
    try result.fact(.table, .caller, .{ .unsigned = .init(value.request.table) });
    try result.text(.name, .caller, value.request.name.slice());
    try result.action(.inspect_status);
    if (value.outcome != .applied) {
        try result.action(.inspect_scope);
        try result.action(.correct_input);
    }
    try result.validate();
    return result;
}

pub fn input(value: m.Disposition) !d {
    try value.validate();
    const applied = value.outcome == .initialized or value.outcome == .policy_applied;
    const code = switch (value.outcome) {
        inline else => |outcome| "catalog.input." ++ @tagName(outcome),
    };
    var result = try d.init(code, switch (value.outcome) {
        .initialized, .policy_applied => .lifecycle,
        .invalid_command => .binding,
        .denied => .access,
        .identity_conflict, .stale_policy => .conflict,
    }, .admission, if (applied) .applied else .input_rejected, .domain_status, switch (value.outcome) {
        .initialized => "The catalog initialization command applied. This disposition does not describe a CREATE TABLE outcome.",
        .policy_applied => "The catalog policy command applied. Later commands still require current authorization.",
        .invalid_command => "The catalog could not decode this creation or control command. Inspect the recorded input and any original operation receipt.",
        .denied => "The current principal or catalog policy did not permit this command. Preserve its original operation identity and inspect current permissions.",
        .identity_conflict => "This command conflicts with the recorded catalog operation identity. Preserve the original command and inspect its receipt.",
        .stale_policy => "The catalog command's expected policy revision is stale. Inspect its recorded input and the current policy before preparing any new command.",
    });
    // A native input position is not a catalog operation ID. The disposition
    // intentionally does not invent a namespace or promise CREATE cancellation.
    result.identity = .{ .domain = .transport, .id = .init(value.input), .realm = .init(value.scope.realm), .resource = .init(value.scope.resource) };
    try result.fact(.native_input, .owner, .{ .unsigned = .init(value.input) });
    try result.fact(.scope, .owner, .{ .unsigned = .init(value.scope.catalog) });
    try result.fact(.source_basis, .owner, .{ .digest = value.payload });
    try result.text(.operation, .owner, "catalog input");
    try result.action(.inspect_status);
    if (value.outcome == .denied or value.outcome == .stale_policy) try result.action(.inspect_scope);
    try result.validate();
    return result;
}

// Caller attempt evidence is independent of a saved domain outcome.
const AttemptInfo = struct { code: []const u8, category: d.Category, message: []const u8 };
fn attemptInfo(cause: anyerror) AttemptInfo {
    return switch (cause) {
        error.CatalogDenied, error.AccessDenied => .{ .code = "catalog.access_denied", .category = .access, .message = "The current native grant or catalog policy does not permit this operation. Create and inspect permissions are separate." },
        error.CatalogOwnerUnavailable, error.ResourceUnavailable => .{ .code = "catalog.owner_unavailable", .category = .unavailable, .message = "The configured catalog owner is unavailable. Preserve the original saved command and inspect its owner before continuing." },
        error.CatalogNotInitialized => .{ .code = "catalog.not_initialized", .category = .lifecycle, .message = "The catalog has not been initialized for this configuration. Inspect its owner and initialization disposition." },
        error.CatalogIdentityConflict, error.Conflict => .{ .code = "catalog.identity_conflict", .category = .conflict, .message = "The supplied catalog operation identity conflicts with recorded work. Preserve the original command and inspect its receipt." },
        error.CatalogScopeChanged, error.CatalogOwnerChanged, error.CatalogConfigurationChanged => .{ .code = "catalog.scope_changed", .category = .conflict, .message = "The catalog scope or owner configuration changed. Use the original scope to inspect saved work before preparing another command." },
        error.CatalogPolicyConflict => .{ .code = "catalog.policy_changed", .category = .conflict, .message = "The expected catalog policy revision changed. Inspect current policy before preparing a new conditional policy command." },
        error.CatalogCursorChanged => .{ .code = "catalog.cursor_changed", .category = .conflict, .message = "The catalog changed during pagination. Discard the partial listing and restart the read; preserve saved write commands." },
        error.CatalogDefinitionChanged, error.CatalogSourceChanged => .{ .code = "catalog.definition_changed", .category = .conflict, .message = "The catalog definition or Table descriptor changed. Inspect current metadata before preparing a new declaration." },
        error.InvalidCatalogIdentity, error.InvalidCatalogPrepared, error.InvalidCatalogInteger, error.InvalidCatalogPolicy, error.InvalidCatalogBinding, error.InvalidColumnName => .{ .code = "catalog.invalid_command", .category = .binding, .message = "The catalog identity, policy or saved command is invalid. Supply its canonical fields and original connection scope." },
        error.InvalidCatalogPage, error.InvalidCatalogDefinition, error.InvalidCatalogDisposition => .{ .code = "catalog.invalid_record", .category = .integrity, .message = "The returned catalog metadata is inconsistent. Preserve the original command and recorded evidence for inspection." },
        error.SignatureVerificationFailed => .{ .code = "catalog.invalid_signature", .category = .integrity, .message = "The saved command signature is invalid. Preserve the original bytes and signing identity; no command was sent." },
        error.IncompatibleDefinition => .{ .code = "catalog.incompatible_definition", .category = .integrity, .message = "The saved command or peer uses a different contract definition. Use matching binaries and preserve the original bytes; no fallback reinterprets accepted work." },
        error.OutOfMemory, error.Unavailable, error.ConnectionRefused, error.ConnectionResetByPeer, error.ConnectionTimedOut, error.Timeout, error.Canceled => .{ .code = "catalog.unavailable", .category = .unavailable, .message = "The operation could not complete because a required resource or transport is unavailable. Preserve any saved command and its previously observed outcome." },
        else => .{ .code = "catalog.internal_failure", .category = .internal, .message = "The caller could not complete this operation. Preserve saved work and inspect its original status; this failure does not establish its outcome." },
    };
}
pub fn category(action: c.Bridge.Action, cause: anyerror) d.Category {
    if (action == .compile) if (c.fuze.SqlDiagnostic.category(cause)) |value| return value;
    return attemptInfo(cause).category;
}
pub fn attempt(action: c.Bridge.Action, cause: anyerror, binding: c.fuze.Sql.Binding, dispatched: bool, identity: ?d.Identity) !d {
    if (action == .compile) if (c.fuze.SqlDiagnostic.writeCompiler(action.compile.sql, cause, .declaration, binding)) |detail| return detail.structured();
    const stage: d.Stage = switch (action) {
        .compile => .compile,
        .prepare_initialize, .prepare_create, .prepare_policy => .prepare,
        .submit => if (dispatched) .submit else .prepare,
        else => .read,
    };
    const info = attemptInfo(cause);
    const sending = dispatched and action == .submit;
    const rejected = cause == error.AccessDenied or cause == error.Rejected or cause == error.Conflict;
    var result = if (sending and !rejected)
        try d.init("catalog.send_unknown", .unavailable, .submit, .unknown, .saved_intent, "The signed command outcome is unknown. Retain its exact saved bytes and reconcile before preparing another command.")
    else if (sending)
        try d.init("catalog.command_rejected", if (cause == error.AccessDenied) .access else .conflict, .submit, .not_applicable, .none, "The authority rejected this signed command. This does not establish the original operation outcome; inspect its saved status.")
    else
        try d.init(info.code, info.category, stage, if (stage == .read) .not_applicable else .not_submitted, if (stage == .read) .none else .local_before_dispatch, info.message);
    result.cause = try d.Code.init(@errorName(cause));
    result.identity = identity;
    try result.text(.operation, .caller, @tagName(action));
    if (sending) {
        try result.action(.inspect_status);
        if (!rejected and identity != null) try result.action(.resume_exact);
        if (rejected) try result.action(.inspect_scope);
    } else switch (info.category) {
        .access, .conflict => try result.action(.inspect_scope),
        .lifecycle => try result.action(.inspect_status),
        .unavailable => try result.action(if (stage == .read) .retry_read else .inspect_status),
        .binding, .syntax, .unsupported, .limit, .constraint => try result.action(.correct_input),
        .internal, .integrity => try result.action(.contact_operator),
    }
    try result.validate();
    return result;
}
pub fn invalidEnvelope(cause: anyerror) !d {
    var result = if (cause == error.OutOfMemory)
        try d.init("catalog.memory_unavailable", .unavailable, .input, .not_submitted, .local_before_dispatch, "The caller could not allocate memory to read this request. No command was sent.")
    else
        try d.init("catalog.invalid_envelope", .syntax, .input, .not_submitted, .local_before_dispatch, "The action is not a valid bounded request object. No command was sent.");
    result.cause = try d.Code.init(@errorName(cause));
    return result;
}
