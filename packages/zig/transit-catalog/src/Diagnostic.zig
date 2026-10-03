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
