//! Neutral index declarations and exact coverage attribution, without I/O.
//! Validation proves shape/bindings, never existence, completeness or authority.
const std = @import("std");
const p = @import("root.zig");
const d = p.DataLifecycle;

/// One definition's work bound, not a total index/catalog cardinality bound.
pub const max_columns = 128;
pub const Key = struct {
    column: u64,
    direction: enum(u8) { ascending = 1, descending = 2 },
    nulls: enum(u8) { first = 1, last = 2 },
    /// Logical type and collation come from the exact source definition. The
    /// shared contract pins their comparison algorithms; no codec implies order.
    comparison: enum(u8) { declared_column = 1 },
};
pub const Constraint = struct {
    interpretation: d.Definition,
    kind: enum(u8) { primary_key = 1, unique = 2 },
    /// Distinct/equal governs uniqueness; Key.nulls independently governs order.
    nulls: enum(u8) { forbidden = 1, distinct = 2, equal = 3 },
};
pub const Purpose = union(enum) { acceleration: void, constraint: Constraint };

/// Slices borrow the caller. The definition digest commits to all fields other
/// than itself, with the domain/framing in INDEX_LIFECYCLE_V1.md.
pub const Declaration = struct {
    definition: p.Growth.Definition,
    interpretation: d.Definition,
    source: d.Definition,
    keys: []const Key,
    included: []const u64,
    purpose: Purpose,

    pub const json_schema_sequence_bounds = .{
        .keys = max_columns,
        .included = max_columns,
    };

    fn validateFields(self: Declaration) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.interpretation.validate();
        try self.source.validate();
        try sameCatalog(self.interpretation.object, self.source.object);
        if (self.interpretation.object.object == self.source.object.object) return error.InvalidIndexDependency;
        if (self.keys.len == 0 or self.keys.len > max_columns or self.included.len > max_columns or
            self.keys.len + self.included.len > max_columns) return error.InvalidIndexColumns;
        for (self.keys, 0..) |key, i| {
            if (key.column == 0) return error.InvalidIndexColumns;
            for (self.keys[0..i]) |previous| if (previous.column == key.column) return error.InvalidIndexColumns;
        }
        for (self.included, 0..) |column, i| {
            if (column == 0) return error.InvalidIndexColumns;
            for (self.keys) |key| if (key.column == column) return error.InvalidIndexColumns;
            for (self.included[0..i]) |previous| if (previous == column) return error.InvalidIndexColumns;
        }
        switch (self.purpose) {
            .acceleration => {},
            .constraint => |constraint| {
                try constraint.interpretation.validate();
                try sameCatalog(self.interpretation.object, constraint.interpretation.object);
                const object = constraint.interpretation.object.object;
                if (object == self.interpretation.object.object or object == self.source.object.object)
                    return error.InvalidIndexDependency;
                if (constraint.kind == .primary_key and constraint.nulls != .forbidden)
                    return error.InvalidIndexConstraint;
            },
        }
    }

    pub fn validate(self: Declaration) !void {
        if (!std.mem.eql(u8, &self.interpretation.digest, &try self.fingerprint())) return error.IndexDefinitionMismatch;
    }

    /// Computes a digest without allocation or copying an unbounded definition.
    /// Use when authoring a new declaration, never to repair a decoded artifact.
    pub fn fingerprint(self: Declaration) ![32]u8 {
        try self.validateFields();
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.index.declaration.v1\x00");
        hash.update(&p.Growth.definition_bytes);
        hashObject(&hash, self.interpretation.object);
        hashInt(&hash, self.interpretation.revision);
        hashDefinition(&hash, self.source);
        hashInt(&hash, self.keys.len);
        for (self.keys) |key| {
            hashInt(&hash, key.column);
            hash.update(&.{ @backingInt(key.direction), @backingInt(key.nulls), @backingInt(key.comparison) });
        }
        hashInt(&hash, self.included.len);
        for (self.included) |column| hashInt(&hash, column);
        switch (self.purpose) {
            .acceleration => hash.update(&.{0}),
            .constraint => |constraint| {
                hash.update(&.{1});
                hashDefinition(&hash, constraint.interpretation);
                hash.update(&.{ @backingInt(constraint.kind), @backingInt(constraint.nulls) });
            },
        }
        return hash.finalResult();
    }
};

/// One build identity and its complete starting basis, including unflushed WAL.
/// A new rebuild uses a different nonzero generation and original operation ID.
pub const Generation = struct {
    definition: p.Growth.Definition,
    declaration: d.Definition,
    generation: u64,
    operation: d.Operation,
    base: d.SourceCut,

    pub fn validate(self: Generation) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.declaration.validate();
        try self.operation.validate();
        try self.base.validate();
        if (self.generation == 0) return error.InvalidIndexGeneration;
        try sameCatalog(self.declaration.object, self.base.interpretation.object);
        if (self.declaration.object.object == self.base.interpretation.object.object or
            !std.meta.eql(self.operation.scope, self.declaration.object.scope)) return error.InvalidIndexDependency;
    }

    pub fn requireDeclaration(self: Generation, declaration: Declaration) !void {
        try self.validate();
        try declaration.validate();
        if (!std.meta.eql(self.declaration, declaration.interpretation) or
            !std.meta.eql(self.base.interpretation, declaration.source)) return error.IndexDefinitionMismatch;
    }
};

/// Maintenance observations cannot establish query eligibility. `complete`
/// still requires separately accepted coverage publication and current rights.
pub const Progress = struct {
    build: Generation,
    phase: enum { backfill, catch_up, validating, complete },
    through: ?d.Position,

    pub fn validate(self: Progress) !void {
        try self.build.validate();
        if (self.phase == .backfill) {
            if (self.through != null) return error.InvalidIndexProgress;
        } else {
            const through = self.through orelse return error.InvalidIndexProgress;
            try advancing(self.build.base.accepted, through);
        }
    }
};

/// An alleged complete immutable index root for exactly this source cut. Shape
/// validation cannot prove that its pages exist or contain all visible rows.
pub const Coverage = struct {
    build: Generation,
    source: d.SourceCut,
    root: d.Content,

    pub fn validate(self: Coverage) !void {
        try self.build.validate();
        try self.source.validate();
        try self.root.validate();
        if (!std.meta.eql(self.build.base.interpretation, self.source.interpretation)) return error.IndexDefinitionMismatch;
        try advancing(self.build.base.accepted, self.source.accepted);
    }

    /// Checks exact logical attribution, not catalog membership, coverage truth,
    /// permission or retention. Physical checkpoint changes at the same logical
    /// cut are allowed. Neither a newer nor an older frontier matches implicitly.
    pub fn requireBasis(self: Coverage, declaration: Declaration, snapshot: d.Snapshot, requested: d.SourceCut) !void {
        try self.validate();
        try self.build.requireDeclaration(declaration);
        if (snapshot.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try snapshot.requireSource(requested);
        if (!std.meta.eql(self.source.interpretation, requested.interpretation) or
            !std.meta.eql(self.source.accepted, requested.accepted)) return error.IndexCoverageMismatch;
    }
};

/// Frozen proposal for conditional publication in the existing catalog owner.
/// Null expects no prior publication; otherwise the complete prior accepted
/// publication commitment must match. This is not an installed request route.
pub const Publication = struct {
    definition: p.Growth.Definition,
    operation: d.Operation,
    coverage: Coverage,
    expected: ?d.Content,

    pub fn validate(self: Publication) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.operation.validate();
        try self.coverage.validate();
        if (!std.meta.eql(self.operation.scope, self.coverage.build.declaration.object.scope)) return error.InvalidIndexDependency;
        if (self.expected) |expected| try expected.validate();
    }

    pub fn requireSame(self: Publication, other: Publication) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.IndexPublicationConflict;
    }
};

/// Schema roots only; no endpoint, storage format or index capability is added.
pub const SchemaTypes = struct {
    declaration: Declaration,
    constraint_declaration: Declaration,
    progress: Progress,
    coverage: Coverage,
    publication: Publication,
};

fn sameCatalog(a: d.Object, b: d.Object) !void {
    if (!std.meta.eql(a.scope, b.scope) or a.branch != b.branch) return error.InvalidIndexDependency;
}
fn advancing(base: d.Position, through: d.Position) !void {
    try through.validate();
    if (base.partition != through.partition or through.next_lsn < base.next_lsn) return error.InvalidIndexProgress;
}
fn hashInt(hash: *std.crypto.hash.sha2.Sha256, value: u64) void {
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, value, .big);
    hash.update(&bytes);
}
fn hashObject(hash: *std.crypto.hash.sha2.Sha256, object: d.Object) void {
    for ([_]u64{ object.scope.realm, object.scope.resource, object.scope.catalog, object.branch, object.object }) |value| hashInt(hash, value);
}
fn hashDefinition(hash: *std.crypto.hash.sha2.Sha256, definition: d.Definition) void {
    hashObject(hash, definition.object);
    hashInt(hash, definition.revision);
    hash.update(&definition.digest);
}

test {
    _ = @import("index_lifecycle_test.zig");
}
