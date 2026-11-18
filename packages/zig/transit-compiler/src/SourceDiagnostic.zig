//! Bounded source diagnostics shared by pure compilation and its I/O adapters.
//! Captured names/types describe caller input, never source bodies or credentials.
const std = @import("std");
const d = @import("transit_protocol").Diagnostic;

pub const Span = struct { start: u32 = 0, end: u32 = 0 };

pub const Note = struct {
    file: ?usize = null,
    span: Span = .{},
    located: bool = false,
    bytes: [256]u8 = @splat(0),
    len: u16 = 0,
    pub fn slice(self: *const Note) []const u8 {
        return self.bytes[0..self.len];
    }
};

pub const CallFrame = struct {
    callee: [64]u8 = @splat(0),
    callee_len: u8 = 0,
    file: usize = 0,
    span: Span = .{},
    pub fn name(self: *const CallFrame) []const u8 {
        return self.callee[0..self.callee_len];
    }
};

pub const Report = struct {
    file: ?usize = null,
    span: Span = .{},
    has_span: bool = false,
    headline_bytes: [256]u8 = @splat(0),
    headline_len: u16 = 0,
    notes: [2]?Note = @splat(null),
    frames: [64]CallFrame = undefined,
    frames_len: u8 = 0,

    pub fn reset(self: *Report) void {
        self.* = .{};
    }
    pub fn headline(self: *const Report) ?[]const u8 {
        return if (self.headline_len == 0) null else self.headline_bytes[0..self.headline_len];
    }
    pub fn setSpan(self: *Report, file: ?usize, start: usize, end: usize) void {
        const s: u32 = @intCast(@min(start, std.math.maxInt(u32)));
        const e: u32 = @intCast(@min(@max(start, end), std.math.maxInt(u32)));
        self.file = file;
        self.span = .{ .start = s, .end = e };
        self.has_span = true;
    }
    pub fn setHeadline(self: *Report, comptime fmt: []const u8, args: anytype) void {
        self.headline_len = formatBounded(&self.headline_bytes, fmt, args);
    }
    pub fn addNote(self: *Report, file: ?usize, span: ?Span, comptime fmt: []const u8, args: anytype) void {
        for (&self.notes) |*slot| if (slot.* == null) {
            var item: Note = .{ .file = file, .span = span orelse .{}, .located = file != null and span != null };
            item.len = formatBounded(&item.bytes, fmt, args);
            if (item.len != 0) slot.* = item;
            return;
        };
    }
    pub fn pushFrame(self: *Report, callee: []const u8, file: usize, span: Span) void {
        if (self.frames_len >= self.frames.len) return;
        var frame: CallFrame = .{ .file = file, .span = span };
        const n: u8 = @intCast(@min(callee.len, frame.callee.len));
        @memcpy(frame.callee[0..n], callee[0..n]);
        frame.callee_len = n;
        self.frames[self.frames_len] = frame;
        self.frames_len += 1;
    }
    pub fn popFrame(self: *Report) void {
        if (self.frames_len > 0) self.frames_len -= 1;
    }
    /// Populate a concise Zig-style headline and optional guidance note from the
    /// error tag and context whenever the failing site only supplied an error.
    pub fn finalize(self: *Report, err: anyerror, context: Context) void {
        if (self.headline_len == 0) {
            switch (err) {
                error.MissingBuildEntry => {
                    self.setHeadline("cannot find build entry file", .{});
                    if (self.notes[0] == null) self.addNote(null, null, "create 'build.transit' or select a .transit file with '-f <file>'", .{});
                },
                error.UnsupportedSourceFileKind, error.SymLinkLoop => {
                    self.setHeadline("source path must be a regular .transit file", .{});
                    if (self.notes[0] == null) self.addNote(null, null, "symbolic links and special files are not supported inside source packages", .{});
                },
                error.IsDir => self.setHeadline("expected a regular .transit file, found a directory", .{}),
                error.NotDir => self.setHeadline("a component of the source path is not a directory", .{}),
                error.InvalidSourcePath => self.setHeadline("invalid source path; expected a package-relative '.transit' path", .{}),
                error.ExcludedSourcePath => {
                    self.setHeadline("source path enters an excluded directory", .{});
                    if (self.notes[0] == null) self.addNote(null, null, "imports cannot traverse '.git', '.transit', '.direnv' or 'node_modules'", .{});
                },
                error.InvalidSourceEncoding, error.InvalidUtf8 => self.setHeadline("source file contains invalid UTF-8 or disallowed control bytes", .{}),
                error.UnterminatedSqlToken => self.setHeadline("unterminated string literal, quoted identifier or comment", .{}),
                error.UnbalancedSqlBlock => self.setHeadline("unbalanced 'BEGIN ... END' block", .{}),
                error.InvalidSourceName => if (context.name) |n| self.setHeadline("invalid identifier '{s}'", .{n}) else self.setHeadline("expected a valid identifier (1..63 ASCII bytes)", .{}),
                error.InvalidCatalogName, error.InvalidInstanceName => self.setHeadline("invalid resource or instance identifier", .{}),
                error.DuplicateSourceName => if (context.name) |n| self.setHeadline("duplicate declaration of '{s}'", .{n}) else self.setHeadline("duplicate declaration name in this scope", .{}),
                error.DuplicateTestCase => self.setHeadline("duplicate test case identity in target", .{}),
                error.ExportOutsideModule => self.setHeadline("'EXPORT' is only allowed inside 'CREATE MODULE'", .{}),
                error.TestAssertionOutsideCase => self.setHeadline("test assertion is only allowed inside a 'TEST' block", .{}),
                error.TestStatementOutsideCase => self.setHeadline("SQL statement in test target must be inside a 'TEST' block", .{}),
                error.TestInBuildTarget => self.setHeadline("'TEST' case cannot be evaluated inside a build target", .{}),
                error.NestedTestCase => self.setHeadline("nested 'TEST' blocks are not supported", .{}),
                error.InvalidTestName => self.setHeadline("test name must be 1..128 non-control UTF-8 bytes", .{}),
                error.InvalidTestCount => self.setHeadline("expected non-negative 64-bit integer count", .{}),
                error.InvalidTestStatement => {
                    self.setHeadline("unexpected ';' inside assertion statement", .{});
                    if (self.notes[0] == null) self.addNote(null, null, "omit the trailing ';' inside ASSERT (...)", .{});
                },
                error.TestRowsRequired => self.setHeadline("'ASSERT ROWS' requires a 'SELECT' or 'CONSUME' query", .{}),
                error.TestCommandRequired => self.setHeadline("'ASSERT COMMAND' requires a Table DDL or DML statement", .{}),
                error.TestMutationRequired => self.setHeadline("'ASSERT STATEMENT ... FAILS WITH' requires 'INSERT', 'UPDATE' or 'DELETE'", .{}),
                error.MissingSource => if (context.name) |n| self.setHeadline("cannot find imported source for '{s}'", .{n}) else self.setHeadline("cannot find imported '.transit' file", .{}),
                error.UnknownImport => if (context.name) |n| self.setHeadline("unknown import alias '{s}'", .{n}) else self.setHeadline("unknown import alias", .{}),
                error.UnknownSourceSymbol => if (context.name) |n| self.setHeadline("unknown symbol '{s}'", .{n}) else self.setHeadline("unknown source symbol", .{}),
                error.PrivateSourceSymbol => {
                    if (context.name) |n| self.setHeadline("symbol '{s}' is private", .{n}) else self.setHeadline("imported symbol is private", .{});
                    if (self.notes[0] == null) self.addNote(null, null, "mark exported module declarations with 'PUBLIC'", .{});
                },
                error.UnknownSourceExport => if (context.name) |n| self.setHeadline("module instance has no export named '{s}'", .{n}) else self.setHeadline("unknown module export", .{}),
                error.UnknownSourceOperand => if (context.name) |n| self.setHeadline("unbound template parameter '${s}'", .{n}) else self.setHeadline("unbound '$parameter' in SQL template", .{}),
                error.UnknownBuildTable => if (context.name) |n| self.setHeadline("unknown resource '{s}' in proposed catalog", .{n}) else self.setHeadline("unknown Table, Stream or Queue in proposed catalog", .{}),
                error.UnknownBuildProgram => if (context.name) |n| self.setHeadline("unknown dataflow program '{s}'", .{n}) else self.setHeadline("unknown dataflow program in proposed catalog", .{}),
                error.UndeclaredDependency => if (context.name) |n| self.setHeadline("import references undeclared dependency package '{s}'", .{n}) else self.setHeadline("import references an undeclared dependency package", .{}),
                error.SourceImportCycle => self.setHeadline("import cycle detected between '.transit' files", .{}),
                error.SourceDependencyCycle => self.setHeadline("dependency cycle detected between packages", .{}),
                error.MissingSourceTarget, error.MissingMigrationTarget => if (context.name) |n| self.setHeadline("target '{s}' is not declared", .{n}) else self.setHeadline("selected target is not declared", .{}),
                error.WrongSourceTargetKind => {
                    if (context.name) |n| self.setHeadline("target '{s}' has the wrong kind for this command", .{n}) else self.setHeadline("selected target has the wrong kind for this command", .{});
                    if (self.notes[0] == null) self.addNote(null, null, "use 'CREATE TARGET' / 'CREATE MIGRATION TARGET' with 'transit build' and 'CREATE TEST TARGET' with 'transit test'", .{});
                },
                error.EmptyBuildTarget => self.setHeadline("build target emitted no SQL statements", .{}),
                error.EmptyTestTarget => self.setHeadline("test target selected zero 'TEST' cases", .{}),
                error.EmptyTestCase => self.setHeadline("test case contains no SQL statements or assertions", .{}),
                error.SourceDomainMismatch => if (context.expected != null and context.actual != null)
                    (if (context.column) |col| self.setHeadline("domain mismatch on column '{s}': expected '{s}', found '{s}'", .{ col, context.expected.?, context.actual.? }) else if (context.name) |n| self.setHeadline("domain mismatch for '{s}': expected '{s}', found '{s}'", .{ n, context.expected.?, context.actual.? }) else self.setHeadline("domain mismatch: expected '{s}', found '{s}'", .{ context.expected.?, context.actual.? }))
                else
                    self.setHeadline("nominal source domains do not match", .{}),
                error.DuplicateDomainIdentity => self.setHeadline("duplicate nominal domain identity string", .{}),
                error.InvalidDomainIdentity => self.setHeadline("domain identity must be 1..128 valid UTF-8 bytes", .{}),
                error.SourceTypeMismatch, error.ProgramTypeMismatch => if (context.expected != null and context.actual != null)
                    (if (context.name) |n| self.setHeadline("type mismatch for '{s}': expected '{s}', found '{s}'", .{ n, context.expected.?, context.actual.? }) else self.setHeadline("type mismatch: expected '{s}', found '{s}'", .{ context.expected.?, context.actual.? }))
                else
                    self.setHeadline("type mismatch", .{}),
                error.TableInterfaceMismatch => if (context.column != null and context.expected != null and context.actual != null)
                    self.setHeadline("resource signature mismatch on column '{s}': expected '{s}', found '{s}'", .{ context.column.?, context.expected.?, context.actual.? })
                else
                    self.setHeadline("resource column signature does not match parameter type", .{}),
                error.ModuleInterfaceMismatch => self.setHeadline("module signature does not match declared 'INTERFACE'", .{}),
                error.SourceArgumentCount, error.ProgramArgumentMismatch => if (context.name) |n| self.setHeadline("wrong number of arguments in call to '{s}'", .{n}) else self.setHeadline("wrong number of arguments in call", .{}),
                error.NonExhaustiveSourceMatch => self.setHeadline("non-exhaustive 'MATCH': every variant constructor must be handled", .{}),
                error.DuplicateSourceMatchArm => self.setHeadline("duplicate constructor arm in 'MATCH'", .{}),
                error.UnknownVariantConstructor => self.setHeadline("unknown variant constructor", .{}),
                error.InvalidVariantConstructor => self.setHeadline("expected a 'VARIANT' constructor", .{}),
                error.NotModuleConstructor => self.setHeadline("referenced symbol is not a 'MODULE'", .{}),
                error.NotSourceDomain => self.setHeadline("referenced type is not a 'DOMAIN'", .{}),
                error.NullablePrimaryKey => self.setHeadline("primary key column cannot be nullable", .{}),
                error.ConflictingModuleInstance => if (context.name) |n| self.setHeadline("duplicate catalog resource name '{s}'", .{n}) else self.setHeadline("conflicting catalog resource name across module instances", .{}),
                error.ForeignTableExport => self.setHeadline("module can only export resources created within the same module instance", .{}),
                error.UnknownColumn => if (context.column) |col| self.setHeadline("unknown column '{s}'", .{col}) else self.setHeadline("unknown column in scope", .{}),
                error.UnknownProgramVariable => self.setHeadline("unknown variable in program scope", .{}),
                error.UnknownProgramField => self.setHeadline("unknown field on record value", .{}),
                error.UnknownProgramResource => self.setHeadline("unknown resource in program scope", .{}),
                error.DuplicateProgramVariable, error.DuplicateProgramField, error.DuplicateProgramResource => self.setHeadline("duplicate name in program scope", .{}),
                error.MissingRequiredField, error.NullNotAllowed => self.setHeadline("required non-null column is missing or NULL", .{}),
                error.InvalidRowWidth => self.setHeadline("row value count does not match target column count", .{}),
                error.LiteralOutOfRange, error.Overflow => self.setHeadline("numeric literal is out of range for target type", .{}),
                error.MissingSourceLock => {
                    self.setHeadline("missing 'transit.lock' for declared dependencies", .{});
                    if (self.notes[0] == null) self.addNote(null, null, "run 'transit build --fetch' to populate verified dependencies and write transit.lock", .{});
                },
                error.StaleSourceLock, error.SourceDigestMismatch, error.RepositoryRevisionMismatch => {
                    self.setHeadline("locked dependency state does not match declared dependencies", .{});
                    if (self.notes[0] == null) self.addNote(null, null, "run 'transit build --fetch' to refresh transit.lock and verified packages", .{});
                },
                error.InvalidSourceLock, error.InvalidSourceDigest, error.IncompatibleSourceDefinition => self.setHeadline("invalid or incompatible 'transit.lock'", .{}),
                error.ConflictingDependency, error.DuplicateDependency => self.setHeadline("conflicting dependency declarations for the same package name", .{}),
                error.UndeclaredOverride => self.setHeadline("'--override' names a package that is not declared as a dependency", .{}),
                error.RepositoryCredentialsForbidden => self.setHeadline("dependency repository URL must not embed credentials, query parameters or fragments", .{}),
                error.UnsupportedRepositoryTransport => self.setHeadline("unsupported dependency repository transport; use 'https://', 'file://' or an absolute path", .{}),
                error.InvalidRepositoryRevision => self.setHeadline("dependency revision must be a 40-character hexadecimal commit SHA", .{}),
                error.RuntimePrivateOrUnsupportedDeclaration => {
                    self.setHeadline("declaration requires 'PUBLIC' or uses an unsupported resource kind", .{});
                    if (self.notes[0] == null) self.addNote(null, null, "use 'CREATE PUBLIC TABLE', 'CREATE PUBLIC STREAM', 'CREATE PUBLIC QUEUE' or 'CREATE PUBLIC DATAFLOW'", .{});
                },
                error.MutationOutsideAtomic => {
                    self.setHeadline("mutation or procedure call requires a 'BEGIN ATOMIC ... END' block", .{});
                },
                error.MutationInsideGuard => self.setHeadline("read-only 'GUARD' cannot open 'ATOMIC' or mutate state", .{}),
                error.ProcedureOutsideAtomic => self.setHeadline("'PROCEDURE' body must begin with 'AS BEGIN ATOMIC'", .{}),
                error.ImpureSourceFunction => self.setHeadline("'FUNCTION' body must be a single pure 'RETURN <expr>;'", .{}),
                error.MissingProcedureReturn => self.setHeadline("returning 'PROCEDURE' must end with a top-level 'RETURN <expr>;'", .{}),
                error.UnexpectedProcedureReturn => self.setHeadline("early or void 'RETURN' is not allowed here", .{}),
                error.ProcedureHasNoResult => self.setHeadline("'LET ... = CALL' requires a 'PROCEDURE' declared with 'RETURNS'", .{}),
                error.RecursiveSourceCall => self.setHeadline("recursive call cycle detected between source helpers", .{}),
                error.NestedAtomicProgram => self.setHeadline("'BEGIN ATOMIC' blocks cannot be nested", .{}),
                error.UnsupportedNominalColumn => self.setHeadline("nominal domain column must be 'NOT NULL' without 'DEFAULT' or 'CHECK'", .{}),
                error.UnsupportedNominalOperation => self.setHeadline("operation is not supported on nominal domain values; use assignment, '=', '<>' or 'IS [NOT] NULL'", .{}),
                error.InvalidQueuePredicate => self.setHeadline("unsupported expression in Queue acquisition 'WHERE' predicate", .{}),
                error.MigrationTransformRequired => {
                    if (context.name) |n| self.setHeadline("migration of table '{s}' requires an explicit data transform", .{n}) else self.setHeadline("schema change requires an explicit reviewed migration", .{});
                    if (self.notes[0] == null) self.addNote(null, null, "automatic synthesis supports new Tables and safe trailing 'ADD COLUMN' steps only", .{});
                },
                error.MigrationVersionOrder => self.setHeadline("migration version must be strictly greater than all prior versions in basis", .{}),
                error.MigrationHistoryChanged, error.MigrationBasisMismatch => self.setHeadline("existing migration history or basis sidecar was modified or is inconsistent", .{}),
                error.MigrationNamespaceMismatch => self.setHeadline("migration target database/schema does not match prior basis", .{}),
                error.MissingMigrationBasis => self.setHeadline("cannot find prior migration basis file", .{}),
                error.BuildOutputExists, error.PathAlreadyExists => {
                    self.setHeadline("output directory already exists", .{});
                    if (self.notes[0] == null) self.addNote(null, null, "pass a new directory path to '--out' so existing artifacts are not overwritten", .{});
                },
                error.BuildArtifactMismatch => self.setHeadline("existing build artifact bytes do not match fresh compilation", .{}),
                error.UnsupportedTestOption => self.setHeadline("unsupported option in 'EXPORT TARGET ... WITH (...)'", .{}),
                error.FileNotFound => self.setHeadline("file not found", .{}),
                error.AccessDenied, error.PermissionDenied => self.setHeadline("permission denied", .{}),
                else => {
                    const name = @errorName(err);
                    const family = families.get(name) orelse if (std.mem.indexOf(u8, name, "Limit") != null or err == error.OutOfMemory or err == error.ProgramTooComplex or err == error.ProgramTooDeep) Family.limit else if (std.mem.startsWith(u8, name, "Unsupported")) Family.capability else Family.internal;
                    if (family == .limit) {
                        if (context.budget != null and context.limit != null) {
                            self.setHeadline("{s} limit exceeded (limit: {d})", .{ context.budget.?, context.limit.? });
                        } else if (context.limit) |lim| {
                            self.setHeadline("compilation budget exceeded ({s}, limit: {d})", .{ name, lim });
                        } else {
                            self.setHeadline("compilation budget exceeded ({s})", .{name});
                        }
                    } else if (family == .syntax) {
                        self.setHeadline("invalid .transit syntax", .{});
                    } else if (family == .capability) {
                        self.setHeadline("unsupported construct in .transit source ({s})", .{name});
                    } else {
                        const selected = rule(family);
                        const period = std.mem.indexOfScalar(u8, selected.message, '.') orelse selected.message.len;
                        self.setHeadline("{s}", .{selected.message[0..period]});
                    }
                },
            }
        }
    }
};

fn formatBounded(buf: []u8, comptime fmt: []const u8, args: anytype) u16 {
    var scratch: [512]u8 = undefined;
    var w: std.Io.Writer = .fixed(&scratch);
    w.print(fmt, args) catch {};
    const written = w.buffered();
    var end = @min(written.len, buf.len);
    while (end > 0 and (written[end - 1] & 0xc0) == 0x80) end -= 1;
    if (end > 0 and written[end - 1] >= 0x80 and !std.unicode.utf8ValidateSlice(written[0..end])) {
        while (end > 0 and !std.unicode.utf8ValidateSlice(written[0..end])) end -= 1;
    }
    @memcpy(buf[0..end], written[0..end]);
    return @intCast(end);
}
pub const Context = struct {
    offset: ?usize = null,
    end: ?usize = null,
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
const Family = enum { entry, file_kind, path, encoding, syntax, import, target, domain, type, dependency, capability, limit, io, output, migration, internal };
const Rule = struct { code: []const u8, category: d.Category, stage: d.Stage, message: []const u8 };
fn rule(family: Family) Rule {
    return switch (family) {
        .entry => .{ .code = "application.source.entry", .category = .binding, .stage = .input, .message = "Cannot find the build entry. Create build.transit, run from its directory, or select an existing .transit file with -f PATH." },
        .file_kind => .{ .code = "application.source.file_kind", .category = .unsupported, .stage = .input, .message = "Cannot load a source entry of this kind. Use a regular .transit file inside the package; source links and special files are not supported." },
        .path => .{ .code = "application.source.path", .category = .binding, .stage = .input, .message = "The source path is invalid or excluded. Use a relative .transit path inside the package, without parent traversal, links or excluded directory components." },
        .encoding => .{ .code = "application.source.encoding", .category = .syntax, .stage = .input, .message = "The source is not valid UTF-8. Save the indicated .transit file as UTF-8 before compiling it." },
        .syntax => .{ .code = "application.source.syntax", .category = .syntax, .stage = .parse, .message = "Invalid application source syntax. Correct the statement at the indicated location using the supported .transit grammar." },
        .import => .{ .code = "application.source.import", .category = .binding, .stage = .bind, .message = "Cannot resolve the source import or symbol. Check its path, package declaration and PUBLIC export; imports must stay inside their declared package." },
        .target => .{ .code = "application.source.target", .category = .binding, .stage = .bind, .message = "The selected target is missing, empty or has the wrong kind. Select a declared CREATE TARGET or CREATE MIGRATION TARGET for build or CREATE TEST TARGET for test with --target NAME." },
        .domain => .{ .code = "application.source.domain", .category = .binding, .stage = .bind, .message = "Source domains do not match. Pass a value of the expected domain; equal scalar representations do not make distinct domains interchangeable." },
        .type => .{ .code = "application.source.type", .category = .binding, .stage = .bind, .message = "The source operand or interface has the wrong type. Match the declared parameter, resource kind and complete column signature; source holes are typed operands." },
        .dependency => .{ .code = "application.source.dependency", .category = .integrity, .stage = .input, .message = "The dependency, lock or verified cache is unavailable or inconsistent. Check the named dependency and exact revision; use transit build --fetch explicitly to prepare reviewed dependencies, then retry offline." },
        .capability => .{ .code = "application.source.unsupported", .category = .unsupported, .stage = .compile, .message = "This construct is outside the supported source or runtime profile. Use an admitted source form and public-data dependency; compilation cannot enable unavailable runtime facilities." },
        .limit => .{ .code = "application.source.limit", .category = .limit, .stage = .compile, .message = "A source compilation budget was exceeded. Reduce the indicated input or expansion; keep each atomic SQL statement intact and within its owning limit." },
        .io => .{ .code = "application.source.io", .category = .unavailable, .stage = .input, .message = "Cannot read the indicated build input. Check that the path exists, is a regular file and is readable; preserve the lock and verified source contents." },
        .output => .{ .code = "application.source.output", .category = .unavailable, .stage = .output, .message = "Cannot publish or verify the build output. Check the named destination, permissions and available space; use a fresh --out directory for an explicit output and preserve existing artifacts." },
        .migration => .{ .code = "application.source.migration", .category = .binding, .stage = .compile, .message = "Cannot synthesize this Table migration. Check the explicit basis, immutable SQL history, target namespace and strictly increasing version; restore missing or modified inputs." },
        .internal => .{ .code = "application.source.failure", .category = .internal, .stage = .compile, .message = "Application compilation failed. Inspect the reported location and cause; if the input meets the source contract, report the failure with the compiler revision." },
    };
}
const families = std.StaticStringMap(Family).initComptime(.{
    .{ "MissingBuildEntry", .entry },
    .{ "MissingMigrationTarget", .target },
    .{ "MigrationHistoryLimit", .limit },
    .{ "MigrationStepLimit", .limit },
    .{ "InvalidMigrationBasisPath", .migration },
    .{ "InvalidMigrationBasis", .migration },
    .{ "IncompatibleMigrationBasis", .migration },
    .{ "MigrationNamespaceMismatch", .migration },
    .{ "MissingMigrationBasis", .migration },
    .{ "MigrationBasisMismatch", .migration },
    .{ "MigrationVersionOrder", .migration },
    .{ "MigrationHistoryChanged", .migration },
    .{ "DuplicateMigrationBinding", .migration },
    .{ "InvalidMigrationVersion", .migration },
    .{ "MigrationTransformRequired", .migration },
    .{ "UnsupportedMigrationDefinition", .migration },
    .{ "UnsupportedMigrationHistory", .migration },
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
    .{ "MutationInsideGuard", .capability },
    .{ "ProcedureOutsideAtomic", .capability },
    .{ "ImpureSourceFunction", .capability },
    .{ "MissingProcedureReturn", .syntax },
    .{ "UnexpectedProcedureReturn", .syntax },
    .{ "ProcedureHasNoResult", .type },
    .{ "RecursiveSourceCall", .capability },
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
    .{ "UnsupportedTestOption", .capability },
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
        error.MigrationTransformRequired => "This object requires an explicit reviewed data transform or definition change. Automatic synthesis supports new Tables and safe trailing column additions only; it cannot infer drops, renames, nominal changes, constraint tightening or type/codec/collation rewrites.",
        error.UnsupportedMigrationHistory, error.UnsupportedMigrationDefinition => "This migration target accepts only Table CREATE declarations and immutable history containing CREATE plus safe ADD COLUMN steps. Keep data transforms and other resource kinds in separately reviewed ordinary migrations.",
        error.InvalidQueuePredicate => "The Queue acquisition predicate cannot use this expression. Use supported direct column/literal comparisons, Boolean combinations or null tests; move other guards into the program body.",
        error.ImpureSourceFunction => "A source function must be a pure deterministic RETURN expression. Move Table reads and REQUIRE checks into a GUARD, and move mutations into an atomic PROCEDURE or DATAFLOW block.",
        error.MutationInsideGuard => "A source guard is read-only and cannot open an atomic block or mutate Tables, Streams or Queues. Keep mutations in an atomic PROCEDURE or DATAFLOW block.",
        error.ProcedureOutsideAtomic => "A source procedure must declare AS BEGIN ATOMIC ... END so its inlined mutations execute within one atomic transaction boundary.",
        error.MissingProcedureReturn, error.UnexpectedProcedureReturn => "A returning procedure must end with one top-level RETURN expression. Add RETURNS with the result type, keep the final RETURN after all branches, and remove early returns.",
        error.ProcedureHasNoResult => "LET result = CALL requires a procedure with RETURNS and a final RETURN expression. Use statement-form CALL when the procedure has no result.",
        error.RecursiveSourceCall => "Source functions, guards and procedures must form a finite acyclic call graph. Remove the direct or mutual recursion so every program lowers into bounded SQL.",
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
    inline for (.{ error.InvalidQueuePredicate, error.ImpureSourceFunction, error.MutationInsideGuard, error.ProcedureOutsideAtomic, error.RecursiveSourceCall, error.UnknownProgramVariable, error.DuplicateProgramVariable, error.MissingRequiredField, error.UnsupportedNominalColumn, error.UnsupportedNominalOperation }) |cause| {
        const value = project(cause, null, null, null);
        try value.validate();
    }
}
