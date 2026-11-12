//! Bounded source diagnostics shared by pure compilation and its I/O adapters.
//! Captured names/types describe caller input, never source bodies or credentials.
const std = @import("std");
const d = @import("transit_protocol").Diagnostic;
pub const Context = struct {
    offset: ?usize = null,
    name: ?[]const u8 = null,
    column: ?[]const u8 = null,
    expected: ?[]const u8 = null,
    actual: ?[]const u8 = null,
    budget: ?[]const u8 = null,
    limit: ?u64 = null,
    required: ?u64 = null,
    pub fn apply(self: Context, value: *d) void {
        inline for (.{ .{ "name", d.Field.name }, .{ "column", d.Field.column }, .{ "expected", d.Field.expected_type }, .{ "actual", d.Field.actual_type }, .{ "budget", d.Field.budget } }) |item|
            if (@field(self, item[0])) |text| value.text(item[1], .caller, text) catch {};
        if (self.limit) |number| value.fact(.limit, .owner, .{ .unsigned = .init(number) }) catch {};
        if (self.required) |number| value.fact(.required, .caller, .{ .unsigned = .init(number) }) catch {};
    }
};
const Family = enum { entry, file_kind, path, encoding, syntax, import, target, domain, type, dependency, capability, limit, io, output, internal };
const Rule = struct { code: []const u8, category: d.Category, stage: d.Stage, message: []const u8 };
fn rule(family: Family) Rule {
    return switch (family) {
        .entry => .{ .code = "application.source.entry", .category = .binding, .stage = .input, .message = "Cannot find the build entry. Create build.transit, run from its directory, or select an existing .transit file with -f PATH." },
        .file_kind => .{ .code = "application.source.file_kind", .category = .unsupported, .stage = .input, .message = "Cannot load a source entry of this kind. Use a regular .transit file inside the package; source links and special files are not supported." },
        .path => .{ .code = "application.source.path", .category = .binding, .stage = .input, .message = "The source path is invalid or excluded. Use a relative .transit path inside the package, without parent traversal, links or excluded directory components." },
        .encoding => .{ .code = "application.source.encoding", .category = .syntax, .stage = .input, .message = "The source is not valid UTF-8. Save the indicated .transit file as UTF-8 before compiling it." },
        .syntax => .{ .code = "application.source.syntax", .category = .syntax, .stage = .parse, .message = "Invalid application source syntax. Correct the statement at the indicated location using the supported .transit grammar." },
        .import => .{ .code = "application.source.import", .category = .binding, .stage = .bind, .message = "Cannot resolve the source import or symbol. Check its path, package declaration and PUBLIC export; imports must stay inside their declared package." },
        .target => .{ .code = "application.source.target", .category = .binding, .stage = .bind, .message = "The selected target is missing, empty or has the wrong kind. Select a declared CREATE TARGET for build or CREATE TEST TARGET for test with --target NAME." },
        .domain => .{ .code = "application.source.domain", .category = .binding, .stage = .bind, .message = "Source domains do not match. Pass a value of the expected domain; equal scalar representations do not make distinct domains interchangeable." },
        .type => .{ .code = "application.source.type", .category = .binding, .stage = .bind, .message = "The source operand or interface has the wrong type. Match the declared parameter, resource kind and complete column signature; source holes are typed operands." },
        .dependency => .{ .code = "application.source.dependency", .category = .integrity, .stage = .input, .message = "The dependency, lock or verified cache is unavailable or inconsistent. Check the named dependency and exact revision; use transit build --fetch explicitly to prepare reviewed dependencies, then retry offline." },
        .capability => .{ .code = "application.source.unsupported", .category = .unsupported, .stage = .compile, .message = "This construct is outside the supported source or runtime profile. Use an admitted source form and public-data dependency; compilation cannot enable unavailable runtime facilities." },
        .limit => .{ .code = "application.source.limit", .category = .limit, .stage = .compile, .message = "A source compilation budget was exceeded. Reduce the indicated input or expansion; keep each atomic SQL statement intact and within its owning limit." },
        .io => .{ .code = "application.source.io", .category = .unavailable, .stage = .input, .message = "Cannot read the indicated build input. Check that the path exists, is a regular file and is readable; preserve the lock and verified source contents." },
        .output => .{ .code = "application.source.output", .category = .unavailable, .stage = .output, .message = "Cannot publish or verify the build output. Check the named destination, permissions and available space; use a fresh --out directory for an explicit output and preserve existing artifacts." },
        .internal => .{ .code = "application.source.failure", .category = .internal, .stage = .compile, .message = "Application compilation failed. Inspect the reported location and cause; if the input meets the source contract, report the failure with the compiler revision." },
    };
}
const families = std.StaticStringMap(Family).initComptime(.{
    .{ "MissingBuildEntry", .entry },
    .{ "UnsupportedSourceFileKind", .file_kind },
    .{ "SymLinkLoop", .file_kind },
    .{ "InvalidSourcePath", .path },
    .{ "ExcludedSourcePath", .path },
    .{ "InvalidSourceEncoding", .encoding },
    .{ "InvalidUtf8", .encoding },
    .{ "InvalidSourceSyntax", .syntax },
    .{ "InvalidSourceTemplate", .syntax },
    .{ "InvalidSqlSyntax", .syntax },
    .{ "UnterminatedSqlToken", .syntax },
    .{ "InvalidSourceName", .syntax },
    .{ "MissingSource", .import },
    .{ "UnknownImport", .import },
    .{ "UnknownSourceSymbol", .import },
    .{ "PrivateSourceSymbol", .import },
    .{ "UndeclaredDependency", .import },
    .{ "SourceImportCycle", .import },
    .{ "SourceDependencyCycle", .import },
    .{ "MissingSourceTarget", .target },
    .{ "WrongSourceTargetKind", .target },
    .{ "EmptyBuildTarget", .target },
    .{ "EmptyTestTarget", .target },
    .{ "TestInBuildTarget", .target },
    .{ "SourceDomainMismatch", .domain },
    .{ "DuplicateDomainIdentity", .domain },
    .{ "SourceTypeMismatch", .type },
    .{ "TableInterfaceMismatch", .type },
    .{ "InvalidSourceOperand", .type },
    .{ "InvalidSourceTypeOperand", .type },
    .{ "SourceTableBindingMismatch", .type },
    .{ "ProgramTypeMismatch", .type },
    .{ "ProgramNullabilityMismatch", .type },
    .{ "ProgramResourceKindMismatch", .type },
    .{ "ProgramArgumentMismatch", .type },
    .{ "UnknownProgramVariable", .type },
    .{ "UnknownProgramField", .type },
    .{ "UnknownProgramResource", .type },
    .{ "UnknownColumn", .type },
    .{ "DuplicateProgramVariable", .type },
    .{ "DuplicateProgramField", .type },
    .{ "DuplicateProgramResource", .type },
    .{ "LiteralOutOfRange", .type },
    .{ "InvalidQueuePredicate", .capability },
    .{ "UnknownProgramFunction", .capability },
    .{ "PredicateTooLarge", .limit },
    .{ "UnbalancedSqlBlock", .syntax },
    .{ "ModuleIsNotSqlOperand", .type },
    .{ "InvalidModuleInterface", .type },
    .{ "MissingSourceLock", .dependency },
    .{ "StaleSourceLock", .dependency },
    .{ "InvalidSourceLock", .dependency },
    .{ "InvalidSourceDigest", .dependency },
    .{ "IncompatibleSourceDefinition", .dependency },
    .{ "SourceDigestMismatch", .dependency },
    .{ "ConflictingDependency", .dependency },
    .{ "RepositoryFetchFailed", .dependency },
    .{ "RepositoryRevisionMismatch", .dependency },
    .{ "EmptySourcePackage", .dependency },
    .{ "UndeclaredOverride", .dependency },
    .{ "FetchWithOverride", .dependency },
    .{ "RuntimePrivateOrUnsupportedDeclaration", .capability },
    .{ "ApplicationHostUnavailable", .capability },
    .{ "MutationOutsideAtomic", .capability },
    .{ "NestedAtomicProgram", .capability },
    .{ "ProtectedProgramValue", .capability },
    .{ "FileNotFound", .io },
    .{ "AccessDenied", .io },
    .{ "PermissionDenied", .io },
    .{ "InputOutput", .io },
    .{ "SourceReadFailed", .io },
    .{ "IsDir", .file_kind },
    .{ "NotDir", .file_kind },
    .{ "InvalidBuildOutput", .output },
    .{ "BuildOutputExists", .output },
    .{ "BuildArtifactMismatch", .output },
    .{ "BuildSyncFailed", .output },
    .{ "BuildProvenanceLimit", .limit },
    .{ "BuildStatementLimit", .limit },
    .{ "BuildMemoryLimit", .limit },
    .{ "BuildOutputLimit", .limit },
    .{ "BuildToolingMemoryLimit", .limit },
    .{ "BuildWorkLimit", .limit },
    .{ "CompilerArtifactLimit", .limit },
    .{ "DependencyLimit", .limit },
    .{ "RepositoryOutputLimit", .limit },
    .{ "SourceBytesLimit", .limit },
    .{ "SourceConstructorLimit", .limit },
    .{ "SourceDependencyLimit", .limit },
    .{ "SourceDepthLimit", .limit },
    .{ "SourceExportLimit", .limit },
    .{ "SourceFileBytesLimit", .limit },
    .{ "SourceFileLimit", .limit },
    .{ "SourceLockLimit", .limit },
    .{ "SourceParameterLimit", .limit },
    .{ "SourceReadLimit", .limit },
    .{ "SourceTreeEntryLimit", .limit },
    .{ "TestActionLimit", .limit },
    .{ "TestCaseLimit", .limit },
    .{ "TestObservationLimit", .limit },
    .{ "TestResultBytesLimit", .limit },
    .{ "TestResultLimit", .limit },
    .{ "TestRowLimit", .limit },
    .{ "TestRowsLimit", .limit },
    .{ "OutOfMemory", .limit },
    .{ "ProgramTooComplex", .limit },
    .{ "ProgramTooDeep", .limit },
    .{ "ConflictingModuleInstance", .type },
    .{ "DuplicateSourceMatchArm", .type },
    .{ "ForeignTableExport", .type },
    .{ "InvalidParameterType", .type },
    .{ "InvalidRowWidth", .type },
    .{ "MissingRequiredField", .type },
    .{ "NullNotAllowed", .type },
    .{ "InvalidTestSchema", .type },
    .{ "InvalidVariantConstructor", .type },
    .{ "ModuleInterfaceMismatch", .type },
    .{ "NonExhaustiveSourceMatch", .type },
    .{ "NotModuleConstructor", .type },
    .{ "NotSourceDomain", .type },
    .{ "NullablePrimaryKey", .type },
    .{ "SourceArgumentCount", .type },
    .{ "UnboundBuildParameter", .type },
    .{ "DuplicateSourceName", .syntax },
    .{ "DuplicateTestCase", .syntax },
    .{ "ExportOutsideModule", .syntax },
    .{ "InvalidCatalogName", .syntax },
    .{ "InvalidInstanceName", .syntax },
    .{ "InvalidTestCount", .syntax },
    .{ "InvalidTestName", .syntax },
    .{ "InvalidTestStatement", .syntax },
    .{ "NestedTestCase", .syntax },
    .{ "TestAssertionOutsideCase", .syntax },
    .{ "TestCommandRequired", .syntax },
    .{ "TestMutationRequired", .syntax },
    .{ "TestRowsRequired", .syntax },
    .{ "TestStatementOutsideCase", .syntax },
    .{ "EmptyTestCase", .target },
    .{ "InvalidDomainIdentity", .domain },
    .{ "UnknownBuildProgram", .import },
    .{ "UnknownBuildTable", .import },
    .{ "UnknownSourceExport", .import },
    .{ "UnknownSourceOperand", .import },
    .{ "UnknownVariantConstructor", .import },
    .{ "DuplicateDependency", .dependency },
    .{ "InvalidPackageName", .dependency },
    .{ "InvalidRepository", .dependency },
    .{ "InvalidRepositoryRevision", .dependency },
    .{ "InvalidRepositoryTree", .dependency },
    .{ "RepositoryCredentialsForbidden", .dependency },
    .{ "ReservedPackageName", .dependency },
    .{ "UnsupportedRepositoryTransport", .dependency },
    .{ "InvalidDataflowTransition", .capability },
    .{ "UnsupportedBuildLogConfiguration", .capability },
    .{ "UnsupportedBuildProgramControl", .capability },
    .{ "UnsupportedBuildProgramDependency", .capability },
    .{ "UnsupportedBuildStatement", .capability },
    .{ "UnsupportedLogOperand", .capability },
    .{ "UnsupportedNominalColumn", .capability },
    .{ "UnsupportedNominalOperation", .capability },
    .{ "UnsupportedProgramInstruction", .capability },
    .{ "UnsupportedProgramPartitioning", .capability },
    .{ "UnsupportedRecursiveExports", .capability },
    .{ "UnsupportedSourceDeclaration", .capability },
    .{ "UnsupportedSourceType", .capability },
    .{ "UnsupportedSymbolicProgram", .capability },
    .{ "UnsupportedSymbolicSchema", .capability },
    .{ "UnsupportedTestAssertion", .capability },
    .{ "UnsupportedTestRefusal", .capability },
    .{ "UnsupportedVariantField", .capability },
    .{ "BuildEmissionMismatch", .internal },
    .{ "CompilerArtifactChanged", .internal },
    .{ "DuplicateSourceFile", .internal },
    .{ "InvalidBuildBudget", .internal },
    .{ "InvalidCompilerIdentity", .internal },
    .{ "Overflow", .type },
    .{ "ReadFailed", .io },
    .{ "WriteFailed", .output },
    .{ "PathAlreadyExists", .output },
});
pub fn project(err: anyerror, at: ?d.Location, call: ?d.Location, instance: ?[]const u8) d {
    const name = @errorName(err);
    const family = families.get(name) orelse if (std.mem.indexOf(u8, name, "Limit") != null or err == error.OutOfMemory or err == error.ProgramTooComplex or err == error.ProgramTooDeep) Family.limit else if (std.mem.startsWith(u8, name, "Unsupported")) Family.capability else Family.internal;
    const selected = rule(family);
    const message = switch (err) {
        error.InvalidQueuePredicate => "The Queue acquisition predicate cannot use this expression. Use supported direct column/literal comparisons, Boolean combinations or null tests; move other guards into the program body.",
        error.UnknownProgramVariable, error.UnknownProgramField, error.UnknownProgramResource, error.UnknownColumn => "The program name or field is not in scope. Check the bound resource signature and lexical names; branch/body locals are not available after scope exit or in a failure handler.",
        error.DuplicateProgramVariable, error.DuplicateProgramField, error.DuplicateProgramResource => "The program declares a name more than once. Give each field, resource and in-scope variable a distinct name.",
        error.MissingRequiredField, error.NullNotAllowed => "A required column is missing or NULL. Supply a non-null value for each required destination column, preserving its declared source domain.",
        error.UnsupportedNominalColumn => "A nominal column must be NOT NULL and cannot have a DEFAULT or participate in a CHECK constraint. Supply explicitly typed values and use an explicit runtime guard for additional validation.",
        error.UnsupportedNominalOperation => "This operation cannot preserve a source domain. Use direct assignments, same-domain equality/inequality or null tests; keep arithmetic, ordering, casts and function arguments on ordinary scalar fields.",
        else => selected.message,
    };
    var result = d.init(selected.code, selected.category, selected.stage, .not_submitted, .local_before_dispatch, message) catch unreachable;
    result.location = at;
    result.text(.native_cause, .owner, name) catch unreachable;
    if (call) |value| result.fact(.first_occurrence, .caller, .{ .location = value }) catch unreachable;
    if (instance) |value| result.text(.scope, .caller, value) catch unreachable;
    result.action(.correct_input) catch unreachable;
    return result;
}
/// Filesystem facts have no invented source coordinates. This field always
/// uses escaped POSIX bytes (including backslashes), with complete escapes.
pub fn path(value: *d, bytes: []const u8) void {
    var buffer: [256]u8 = undefined;
    var out: std.Io.Writer = .fixed(&buffer);
    var consumed: usize = 0;
    for (bytes) |byte| {
        const printable = byte >= 0x20 and byte <= 0x7e and byte != '\\' and byte != '"';
        if (out.buffer.len - out.end < @as(usize, if (printable) 1 else 4)) break;
        if (printable) out.writeByte(byte) catch unreachable else out.print("\\x{x:0>2}", .{byte}) catch unreachable;
        consumed += 1;
    }
    value.add(.{ .field = .actual_source, .origin = .caller, .availability = if (consumed == bytes.len) .provided else .truncated, .value = .{ .text = d.Text.init(out.buffered()) catch unreachable } }) catch {};
}
pub fn input(err: anyerror, source: []const u8, operation: []const u8, kind: ?[]const u8) d {
    var result = project(err, null, null, null);
    result.stage = .input;
    path(&result, source);
    result.text(.operation, .owner, operation) catch {};
    if (kind) |actual| result.text(.source_kind, .owner, actual) catch {};
    return result;
}
pub fn dependency(err: anyerror, source: []const u8, operation: []const u8) d {
    var result = input(err, source, operation, null);
    const selected = rule(.dependency);
    result.code = d.Code.init(selected.code) catch unreachable;
    result.message = d.Message.init(selected.message) catch unreachable;
    result.category = selected.category;
    return result;
}
pub fn output(err: anyerror, destination: []const u8, operation: []const u8) d {
    var result = input(err, destination, operation, null);
    const selected = rule(.output);
    result.code = d.Code.init(selected.code) catch unreachable;
    result.message = d.Message.init(selected.message) catch unreachable;
    result.category = selected.category;
    result.stage = selected.stage;
    return result;
}
test "source failures retain actionable families and escaped paths without invented locations" {
    const t = std.testing;
    const value = input(error.UnsupportedSourceFileKind, "modules/\xff\x1b\\name.transit", "read source", "sym_link");
    try value.validate();
    try t.expectEqualStrings("application.source.file_kind", value.code.slice());
    try t.expectEqual(d.Stage.input, value.stage);
    try t.expect(value.location == null);
    try t.expectEqualStrings("modules/\\xff\\x1b\\x5cname.transit", value.facts[1].?.value.?.text.slice());
    var long_path: [256]u8 = @splat('a');
    long_path[255] = 0xff;
    const long = input(error.AccessDenied, &long_path, "read source", null);
    try long.validate();
    try t.expectEqual(d.Availability.truncated, long.facts[1].?.availability);
    try t.expectEqual(@as(usize, 255), long.facts[1].?.value.?.text.slice().len);
    const failed_output = output(error.AccessDenied, "output", "publish SQL");
    try failed_output.validate();
    try t.expectEqual(d.Stage.output, failed_output.stage);
}
test "source diagnostic families validate within the shared envelope bounds" {
    for (families.values()) |family| {
        const selected = rule(family);
        const value = try d.init(selected.code, selected.category, selected.stage, .not_submitted, .local_before_dispatch, selected.message);
        try value.validate();
    }
}
