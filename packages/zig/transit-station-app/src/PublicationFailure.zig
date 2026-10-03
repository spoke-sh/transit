//! Retained rejected-input evidence, separate from a publication operation receipt.
const std = @import("std");
const root = @import("root.zig");
const p = root.protocol;
const d = p.Diagnostic;
const Wide = root.Model.Wide;
pub const Reason = enum(u8) {
    InvalidApplicationFrame,
    ApplicationExternalOriginRequired,
    InvalidApplicationCommand,
    ApplicationDenied,
    ApplicationPolicyConflict,
    ApplicationIdentityConflict,
    ApplicationRecordOccupied,
    ApplicationOperationNotFound,
    ApplicationAlreadyApplied,
    ApplicationNotAbandoned,
    ApplicationDigestMismatch,
    ApplicationDefinitionMismatch,
    NoncanonicalApplicationProgram,
    ApplicationUploadPartConflict,
    InvalidApplicationPart,
    InvalidApplicationOperation,
    InvalidApplicationPolicy,
    InvalidApplicationProposal,
    PublicationQuotaExceeded,
    PublicationGap,
    InvalidPublicationPart,
    PublicationPartConflict,
    IncompletePublication,
    InvalidApplicationProgram,
    InterfaceProgramTooLarge,
};
pub fn reason(cause: anyerror) ?Reason {
    inline for (@typeInfo(Reason).@"enum".field_names) |name| {
        if (cause == @field(anyerror, name)) return @field(Reason, name);
    }
    return null;
}
pub const Location = struct {
    offset: u32 = std.math.maxInt(u32),
    line: u32 = 1,
    column: u32 = 1,
    fn diagnostic(self: Location) ?d.Location {
        if (self.offset == std.math.maxInt(u32)) return null;
        return .{ .offset = .init(self.offset), .length = .init(0), .line = .init(self.line), .byte_column = .init(self.column) };
    }
};
pub const Declaration = struct {
    body_digest: [32]u8,
    location: Location,
    member: p.Value,
    option: p.Value,
    extra: union(enum(u8)) { none = 0, expected: p.Value = 1, reference: p.Value = 2 },
};
pub const Embedded = struct { body_digest: [32]u8, location: Location, member: p.Value, sql: Location };
pub const Witness = union(enum(u8)) {
    none = 0,
    policy: struct { principal: u64, expected: Wide, actual: Wide, present: bool, publish: bool } = 1,
    declaration: Declaration = 2,
    sql: Embedded = 3,
    upload: struct { record: Wide, written: u32, required: u32, length: u32 } = 4,
};
pub const Record = struct {
    reason: Reason,
    input: u64,
    operation: Wide,
    payload: [32]u8,
    cause: p.Value,
    code: p.Value,
    category: d.Category,
    stage: d.Stage,
};
pub const Context = struct {
    witness: Witness = .none,
    compiler: ?root.Diagnostic = null,
    cause: ?anyerror = null,
    pub fn program(self: *Context, detail: root.Diagnostic, cause: anyerror, body_digest: [32]u8) void {
        self.compiler = detail;
        self.cause = cause;
        const location: Location = .{ .offset = if (detail.offset) |offset| @intCast(offset) else std.math.maxInt(u32), .line = @intCast(detail.line), .column = @intCast(detail.column) };
        const member = p.Value.init(detail.member[0..detail.member_len]) catch unreachable;
        self.witness = if (detail.sql) |sql|
            .{ .sql = .{ .body_digest = body_digest, .location = location, .member = member, .sql = .{ .offset = if (sql.location) |value| @intCast(value.offset) else std.math.maxInt(u32), .line = @intCast(sql.line), .column = @intCast(sql.column) } } }
        else
            .{ .declaration = .{ .body_digest = body_digest, .location = location, .member = member, .option = p.Value.init(detail.option[0..detail.option_len]) catch unreachable, .extra = if (detail.reference_len != 0) .{ .reference = p.Value.init(detail.reference[0..detail.reference_len]) catch unreachable } else if (detail.expected) |expected| .{ .expected = p.Value.init(expected) catch unreachable } else .none } };
    }
};
const Class = struct { code: []const u8, category: d.Category, message: []const u8 };
fn classification(value: Reason) Class {
    return switch (value) {
        .InvalidApplicationFrame => .{ .code = "publication.invalid_frame", .category = .syntax, .message = "The owner rejected a malformed Station frame. Use the current application command encoder; no publication transition was committed by this input." },
        .ApplicationExternalOriginRequired => .{ .code = "publication.external_origin_required", .category = .access, .message = "Publication requires an external signed operator cast. A process-origin message or another frame kind cannot publish an interface." },
        .InvalidApplicationCommand => .{ .code = "publication.invalid_command", .category = .syntax, .message = "The admitted input does not contain a valid current application command. Check its command variant, fixed encoding, identities and bounds. This input did not change publication state." },
        .ApplicationDenied => .{ .code = "publication.denied", .category = .access, .message = "The owner rejected this input under its operator policy. The original policy evidence belongs to that turn. Earlier staging or applied receipts keep their outcomes; inspect this operation before continuing under restored rights." },
        .ApplicationPolicyConflict => .{ .code = "publication.policy_conflict", .category = .conflict, .message = "The operator policy revision differed from the expected revision. This input did not replace the policy. Compare the recorded revisions before reviewing another policy update." },
        .ApplicationIdentityConflict => .{ .code = "publication.identity_conflict", .category = .conflict, .message = "This operation identity already names a different frozen proposal. Retain and inspect the original proposal; changing its body, record or base cannot reconcile it." },
        .ApplicationRecordOccupied => .{ .code = "publication.record_occupied", .category = .conflict, .message = "The proposed body record is already occupied. This input did not acquire that record or permission to abandon its owner. Inspect the reviewed operation before selecting a new record." },
        .ApplicationOperationNotFound => .{ .code = "publication.operation_absent", .category = .lifecycle, .message = "The owner found no receipt for this operator's selected publication operation in the rejecting turn. This input did not create one. Check the exact operation and operator scope." },
        .ApplicationAlreadyApplied => .{ .code = "publication.already_applied", .category = .lifecycle, .message = "The selected publication already applied. This cleanup input was rejected; abandonment cannot roll back an active interface revision. Inspect its original receipt." },
        .ApplicationNotAbandoned => .{ .code = "publication.not_abandoned", .category = .lifecycle, .message = "Collection requires an explicitly abandoned upload. This input did not collect its bytes or release its reservation. Inspect the exact operation before requesting its authorized cleanup." },
        .ApplicationDigestMismatch => .{ .code = "publication.digest_mismatch", .category = .integrity, .message = "The assembled body does not match the proposal's content commitment. This input did not activate it. Preserve the frozen proposal and inspect its original upload before reviewing a replacement." },
        .ApplicationDefinitionMismatch => .{ .code = "publication.definition_mismatch", .category = .binding, .message = "The assembled definition's realm, interface name or revision does not match the configured application and frozen proposal. It was not activated. Inspect the original reviewed definition and operation." },
        .NoncanonicalApplicationProgram => .{ .code = "publication.noncanonical_program", .category = .binding, .message = "The assembled program is valid but is not the canonical output of the application compiler. It was not activated. Reconcile this upload before reviewing a proposal for the compiler's exact canonical bytes." },
        .ApplicationUploadPartConflict, .PublicationPartConflict => .{ .code = "publication.part_conflict", .category = .conflict, .message = "The upload part conflicts with bytes or half-part progress already retained for this operation. This input did not replace them. Resume only the original frozen body and exact part." },
        .InvalidApplicationPart, .InvalidPublicationPart => .{ .code = "publication.invalid_part", .category = .binding, .message = "The upload part does not match its required ordinal, half or byte count. Application parts contain 1–128 bytes. Inspect the exact operation's recorded progress before selecting a continuation." },
        .InvalidApplicationOperation => .{ .code = "publication.invalid_operation", .category = .binding, .message = "A publication control requires a nonzero uint64 operation identity. This input did not change publication state." },
        .InvalidApplicationPolicy => .{ .code = "publication.invalid_policy", .category = .binding, .message = "A policy update requires a nonzero native principal and the next uint64 revision exactly one greater than its expected revision, without overflow. This input did not change policy." },
        .InvalidApplicationProposal => .{ .code = "publication.invalid_proposal", .category = .binding, .message = "The proposal requires nonzero operation/record identities, next revision exactly base plus one, application format, and 1–65536 body bytes. This input did not admit an upload." },
        .PublicationQuotaExceeded => .{ .code = "publication.staging_quota", .category = .limit, .message = "The publication namespace has insufficient staging quota for this proposal. Its bound is two bodies and 131072 bytes. Existing reservations are not expired by pressure; inspect and explicitly close unused uploads." },
        .PublicationGap => .{ .code = "publication.part_gap", .category = .conflict, .message = "The requested upload part skips the next required ordinal. This input did not advance the upload. Read the exact operation and continue from its retained progress." },
        .IncompletePublication => .{ .code = "publication.incomplete_upload", .category = .conflict, .message = "The assembled upload lacks required complete chunks. This publish input did not activate an interface; the upload remains separate. Compare recorded written and required chunks, then inspect current progress before continuing." },
        .InvalidApplicationProgram => .{ .code = "publication.invalid_program", .category = .binding, .message = "The owner rejected the assembled interface program. Its original compiler cause and declaration location identify the failed construct. This input did not activate the body; reconcile its upload before reviewing a corrected proposal." },
        .InterfaceProgramTooLarge => .{ .code = "publication.program_limit", .category = .limit, .message = "The canonical interface program exceeds 65536 bytes. This input did not activate it. Reconcile the original upload before reviewing a smaller complete definition." },
    };
}
fn stage(value: Reason) d.Stage {
    return switch (value) {
        .InvalidApplicationFrame, .InvalidApplicationCommand, .ApplicationExternalOriginRequired => .input,
        .ApplicationAlreadyApplied, .ApplicationNotAbandoned => .cleanup,
        .ApplicationPolicyConflict => .control,
        .ApplicationDefinitionMismatch => .bind,
        .NoncanonicalApplicationProgram, .InterfaceProgramTooLarge, .InvalidApplicationProgram => .compile,
        .ApplicationDigestMismatch, .IncompletePublication => .execute,
        else => .admission,
    };
}
pub fn capture(turn: *const root.station.Turn, command: ?root.Request.Command, value: Reason, context: Context) !Record {
    const info = classification(value);
    var digest = std.crypto.hash.sha2.Sha256.init(.{});
    digest.update("transit.application.input.v1\x00");
    digest.update(turn.delivery.input.value.slice());
    const original = context.cause;
    const compiler = if (context.compiler) |detail| if (original) |cause| detail.structured(cause) catch null else null else null;
    return .{ .reason = value, .input = turn.delivery.input.position, .operation = if (command) |cmd| switch (cmd) {
        .begin => |proposal| proposal.operation,
        .part => |part| part.operation,
        .publish, .abandon, .collect => |operation| operation,
        else => .{},
    } else .{}, .payload = digest.finalResult(), .cause = try p.Value.init(if (original) |cause| @errorName(cause) else @tagName(value)), .code = try p.Value.init(if (compiler) |detail| detail.code.slice() else info.code), .category = if (compiler) |detail| detail.category else info.category, .stage = if (compiler) |detail| detail.stage else stage(value) };
}
pub fn project(scope: root.Native.Scope, value: Record, witness: Witness) !d {
    try scope.validate();
    if (value.input == 0 or value.input > p.max_counter or value.cause.len > 96 or value.code.len > 96) return error.InvalidApplicationRecord;
    try validateWitness(witness);
    const info = classification(value.reason);
    if (value.reason != .InvalidApplicationProgram and
        (!std.mem.eql(u8, value.code.slice(), info.code) or value.category != info.category or value.stage != stage(value.reason))) return error.InvalidApplicationRecord;
    var message = info.message;
    var buffer: [384]u8 = undefined;
    if (value.reason == .InvalidApplicationProgram) {
        if (root.Diagnostic.namedExplanation(value.cause.slice())) |explanation|
            message = std.fmt.bufPrint(&buffer, "{s} This input did not activate the definition; inspect its upload before reviewing a corrected proposal.", .{explanation}) catch message;
    }
    var result = try d.init(value.code.slice(), value.category, value.stage, .input_rejected, .domain_status, message);
    result.cause = try d.Code.init(value.cause.slice());
    result.identity = .{ .domain = if (value.operation.value == 0) .application else .publication, .id = .init(if (value.operation.value == 0) scope.application else value.operation.value), .realm = .init(scope.realm), .resource = .init(scope.resource) };
    try result.fact(.native_input, .owner, .{ .unsigned = .init(value.input) });
    try result.fact(.source_basis, .owner, .{ .digest = value.payload });
    try result.text(.operation, .owner, "rejected publication input");
    switch (witness) {
        .none => try result.absent(.source_kind, .owner, .unrecorded),
        .policy => |policy| {
            try result.fact(.scope, .owner, .{ .unsigned = .init(policy.principal) });
            if (value.reason == .ApplicationPolicyConflict) try result.fact(.expected_policy, .owner, .{ .unsigned = .init(policy.expected.value) }) else try result.absent(.expected_policy, .owner, .inapplicable);
            try result.fact(.actual_policy, .owner, .{ .unsigned = .init(policy.actual.value) });
            try result.fact(.permissions, .owner, .{ .boolean = policy.publish });
            try result.fact(.object, .owner, .{ .boolean = policy.present });
        },
        .declaration => |detail| {
            result.location = detail.location.diagnostic();
            if (result.location) |*location| location.source = try d.Path.init("assembled interface body");
            try result.fact(.expected_schema, .owner, .{ .digest = detail.body_digest });
            try result.text(.schema_origin, .owner, "verified assembled interface body");
            if (detail.member.len != 0) try result.text(.name, .owner, detail.member.slice());
            if (detail.option.len != 0) try result.text(.option, .owner, detail.option.slice());
            switch (detail.extra) {
                .none => {},
                .expected => |expected| try result.text(.expected_type, .owner, expected.slice()),
                .reference => |reference| try result.text(.scope, .owner, reference.slice()),
            }
        },
        .sql => |detail| {
            result.location = detail.location.diagnostic();
            if (result.location) |*location| location.source = try d.Path.init("assembled interface body");
            try result.fact(.expected_schema, .owner, .{ .digest = detail.body_digest });
            try result.text(.schema_origin, .owner, "verified assembled interface body");
            if (detail.member.len != 0) try result.text(.name, .owner, detail.member.slice());
            try result.text(.option, .owner, "query");
            if (detail.sql.diagnostic()) |location| try result.fact(.expression, .owner, .{ .location = location });
        },
        .upload => |upload| {
            try result.fact(.object, .owner, .{ .unsigned = .init(upload.record.value) });
            try result.fact(.actual_count, .owner, .{ .unsigned = .init(upload.written) });
            try result.fact(.required, .owner, .{ .unsigned = .init(upload.required) });
            try result.text(.unit, .owner, "complete publication chunks");
            try result.fact(.expected_bytes, .owner, .{ .unsigned = .init(upload.length) });
        },
    }
    try result.action(.inspect_status);
    if (value.category == .access) try result.action(.inspect_scope);
    try result.validate();
    return result;
}

fn validateWitness(value: Witness) !void {
    switch (value) {
        .none => {},
        .policy => |policy| {
            if (policy.principal == 0 or policy.principal > p.max_counter or
                (!policy.present and (policy.actual.value != 0 or policy.publish)) or
                (policy.present and policy.actual.value == 0)) return error.InvalidApplicationRecord;
        },
        .declaration => |detail| {
            try validateLocation(detail.location, root.Model.max_program_bytes);
            try validateText(detail.member);
            try validateText(detail.option);
            switch (detail.extra) {
                .none => {},
                .expected, .reference => |value_text| try validateText(value_text),
            }
        },
        .sql => |detail| {
            try validateLocation(detail.location, root.Model.max_program_bytes);
            try validateLocation(detail.sql, 4096);
            try validateText(detail.member);
        },
        .upload => |upload| {
            if (upload.record.value == 0 or upload.length == 0 or upload.length > root.Model.max_program_bytes or
                upload.required != (upload.length + root.station.Publication.chunk_bytes - 1) / root.station.Publication.chunk_bytes or upload.written > upload.required) return error.InvalidApplicationRecord;
        },
    }
}
fn validateLocation(value: Location, maximum: usize) !void {
    if ((value.offset != std.math.maxInt(u32) and value.offset > maximum) or value.line == 0 or value.column == 0 or value.line > maximum + 1 or value.column > maximum + 1) return error.InvalidApplicationRecord;
}
fn validateText(value: p.Value) !void {
    try value.validate();
    if (value.len > 64 or !std.unicode.utf8ValidateSlice(value.slice())) return error.InvalidApplicationRecord;
}
