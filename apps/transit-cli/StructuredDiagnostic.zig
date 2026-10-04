//! Projection only: no reads, retries, authority decisions or captured secrets.
const std = @import("std");
const d = @import("transit_query").protocol.Diagnostic;
const Cli = @import("Diagnostic.zig");

pub fn project(self: Cli, err: anyerror) !d {
    var result = if (self.envelope) |value|
        value
    else if (self.write) |write|
        write.envelope
    else if (self.query) |query|
        try query.structured()
    else if (self.source) |source|
        try source.structured(err)
    else if (self.sql) |sql|
        try sql.structured()
    else
        try general(self, err);
    if (self.input) |input| try input.enrich(&result);
    if (result.location) |*location| {
        if (location.source == null) if (self.file) |file| (try d.SourcePath.init(file)).apply(location);
    }
    try result.validate();
    return result;
}

/// A failure to add optional presentation evidence cannot change the original
/// known outcome. Strip optional context and actions, retain the owner decision.
pub fn fallback(self: Cli, err: anyerror) d {
    var result = if (self.envelope) |value| value else if (self.write) |value| value.envelope else if (self.query) |value| value.structured() catch null else null;
    if (result) |*value| {
        value.facts = @splat(null);
        value.location = null;
        value.actions = @splat(null);
        value.message = d.Message.init("Diagnostic context could not be rendered. The original code, cause, identity and recorded outcome are retained.") catch unreachable;
        if (value.validate()) |_| return value.* else |_| {}
    }
    var value = d.init("cli.diagnostic_unavailable", .internal, .output, .not_applicable, .none, "The operation failed and its diagnostic detail could not be rendered. Preserve saved work; this rendering failure does not establish the operation outcome.") catch unreachable;
    value.cause = d.Code.init(@errorName(self.cause orelse err)) catch null;
    return value;
}

/// File names are POSIX bytes; a path without a known offset is a fact, never
/// a fabricated line-one location. Keep escaped byte boundaries intact.
pub fn pathFact(value: *d, bytes: []const u8) !void {
    const path = try d.SourcePath.init(bytes);
    var end: usize = @min(256, path.path.slice().len);
    if (path.encoding == .escaped_bytes) {
        end = 0;
        while (end < path.path.slice().len) {
            const size: usize = if (path.path.slice()[end] == '\\') 4 else 1;
            if (end + size > 256) break;
            end += size;
        }
    } else while (!std.unicode.utf8ValidateSlice(path.path.slice()[0..end])) end -= 1;
    try value.add(.{ .field = .object, .origin = .caller, .availability = if (path.truncated or end < path.path.slice().len) .truncated else .provided, .value = .{ .text = try d.Text.init(path.path.slice()[0..end]) } });
    try value.text(.source_kind, .caller, if (path.encoding == .utf8) "file/utf8" else "file/escaped_bytes");
}

fn general(self: Cli, err: anyerror) !d {
    const cause = self.cause orelse err;
    const local = self.presentation != .general or switch (err) {
        error.InvalidConfiguration, error.InvalidConfigurationPath, error.InvalidCredentialFile, error.InvalidQueryInput, error.QueryInputTooLarge, error.ConsoleWriterRequired, error.ConsoleCatalogRequired, error.ConsoleRecoveryRequired, error.UnknownConsoleCommand, error.UnknownHelpTopic, error.InvalidTimingCommand, error.UnsupportedFormat => true,
        else => false,
    };
    const info: struct { []const u8, d.Category, d.Stage, []const u8 } = switch (err) {
        error.InvalidInvocation => .{ "cli.invalid_invocation", .syntax, .input, "The command or its options are invalid." },
        error.InvalidConfiguration, error.InvalidConfigurationPath => .{ "cli.invalid_configuration", .binding, .input, "The command configuration could not be loaded or validated." },
        error.InvalidCredentialFile => .{ "cli.credential_unavailable", .access, .prepare, "The signing credential could not be loaded. Check the configured file and its permissions without disclosing its contents." },
        error.InvalidQueryInput => .{ "cli.invalid_query_input", .syntax, .input, "Supply a JSON query object or exact scalar parameter array for this interface." },
        error.QueryInputTooLarge => .{ "cli.query_input_limit", .limit, .input, "The SQL query input exceeds 131072 bytes." },
        error.ConsoleWriterRequired => .{ "cli.writer_required", .unsupported, .prepare, "Configure writes.table to execute this Table mutation. A query connection does not grant writes." },
        error.ConsoleCatalogRequired => .{ "cli.catalog_required", .unsupported, .prepare, "Configure writes.catalog to execute CREATE TABLE." },
        error.ConsoleRecoveryRequired => .{ "cli.recovery_required", .binding, .prepare, "Automatic queries require a private recovery_file in the console configuration." },
        error.InvalidTimingCommand => .{ "cli.invalid_timing", .syntax, .input, "Use .timer on or .timer off." },
        error.UnknownConsoleCommand, error.UnknownHelpTopic, error.UnknownCommand => .{ "cli.unknown_command", .unsupported, .input, "Use .help to inspect supported commands and SQL routes." },
        error.CatalogCancellationUnsupported => .{ "catalog.cancellation_unsupported", .unsupported, .control, "CREATE TABLE cannot be cancelled. Inspect or reconcile the saved creation; interrupting does not undo it." },
        error.NoQuery, error.NoSavedWrite, error.NoPendingSubmission => .{ "cli.no_saved_operation", .lifecycle, .reconcile, "This connection has no saved operation for the requested recovery command." },
        error.CatalogNameNotFound => .{ "catalog.name_not_found", .binding, .read, "The configured catalog has no Table with that name. Inspect that catalog with SHOW TABLES." },
        error.CatalogCursorChanged => .{ "catalog.cursor_changed", .conflict, .read, "The catalog changed during listing. Discard the partial listing and restart the read." },
        error.AccessDenied, error.QueryDenied, error.MutationDenied, error.CatalogDenied => .{ "cli.access_denied", .access, .read, "Current permissions do not allow this operation. Losing access does not establish the outcome of earlier work." },
        error.ConsoleRecoveryInUse, error.ManagementClientInUse, error.InstallationInUse => .{ "cli.recovery_in_use", .conflict, .prepare, "Another process holds the installation or recovery lock. Preserve the same configuration and recovery location." },
        error.ConsoleRecoveryIdentityMismatch, error.RecoveryIdentityMismatch, error.InstallationIdentityMismatch, error.StorageIdentityMismatch, error.AuthorityRollback => .{ "cli.recovery_identity_mismatch", .integrity, .reconcile, "The configuration, executable or retained state does not match recorded recovery evidence. Restore the matching artifacts; never reset or delete evidence to bypass this check." },
        error.ConsoleRecoveryWriteFailed, error.ConsoleRecoverySyncFailed, error.InstallationSyncFailed => .{ "cli.recovery_persistence_failed", .unavailable, .reconcile, "Recovery state could not be persisted. Preserve original files and restore storage before reconciling saved work." },
        error.ApplicationOutcomeUnknown, error.MutationOutcomeUnknown, error.CatalogOutcomeUnknown => .{ "cli.outcome_unknown", .unavailable, .submit, "The operation outcome is unknown. Preserve the original saved command and reconcile its exact identity before preparing new work." },
        error.ConsoleInterrupted, error.ConsoleQueryInterrupted => .{ "cli.interrupted", .lifecycle, .control, "The console was interrupted. Interruption does not establish cancellation or undo accepted work." },
        error.FileQueryInterrupted, error.InteractiveQueryCancelled => .{ "cli.read_interrupted", .lifecycle, .read, "The local query wait was interrupted. Any disclosed result prefix remains incomplete." },
        error.WriteFailed, error.BrokenPipe, error.ConsoleOutputTimeout => .{ "cli.output_incomplete", .unavailable, .output, "Output could not be written completely. This output failure does not undo accepted work." },
        error.ConsoleCommandFailed => .{ "cli.commands_failed", .lifecycle, .control, "One or more preceding console commands failed. Inspect their individual diagnostics and saved operation identities." },
        error.OutOfMemory, error.NoSpaceLeft, error.ConnectionRefused, error.ConnectionResetByPeer, error.ConnectionTimedOut, error.AuthorityTimeout, error.Timeout => .{ "cli.unavailable", .unavailable, .read, "A required resource is unavailable. Preserve saved work; this failure does not establish its outcome." },
        else => .{ "cli.internal_failure", .internal, .control, "The command failed. Inspect the original cause and preserve saved work; this failure does not establish its outcome." },
    };
    const unknown = err == error.ApplicationOutcomeUnknown or err == error.MutationOutcomeUnknown or err == error.CatalogOutcomeUnknown;
    var value = try d.init(info[0], info[1], info[2], if (unknown) .unknown else if (local) .not_submitted else .not_applicable, if (local) .local_before_dispatch else .none, self.summary orelse info[3]);
    value.cause = try d.Code.init(@errorName(cause));
    if (self.argument) |argument| try value.fact(.argument, .caller, .{ .unsigned = .init(argument) });
    if (self.option) |option| try value.text(.option, .caller, option);
    if (self.field) |field| try value.text(.field_path, .owner, field);
    if (self.file) |file| {
        if (self.offset != null and self.line != null and self.column != null) {
            value.location = .{ .offset = .init(self.offset.?), .length = .init(0), .line = .init(self.line.?), .byte_column = .init(self.column.?) };
            (try d.SourcePath.init(file)).apply(&value.location.?);
        } else try pathFact(&value, file);
    }
    if (local) try value.action(.correct_input) else if (info[1] == .access) try value.action(.inspect_scope);
    return value;
}
