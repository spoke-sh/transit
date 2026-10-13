//! Authorized hosts supply immutable, seekable content and current access checks.
//! Discovery and each execution pass bind exact digests/options; failed prefixes
//! never gain completion. This module performs no filesystem/network operations.
const std = @import("std");
const types = @import("Types.zig");
const framing = @import("FileFraming.zig");
const inference = @import("Inference.zig");
const values = types.Values;
pub const BudgetDiagnostic = @import("BudgetDiagnostic.zig");
pub const ValueDiagnostic = @import("FileValueDiagnostic.zig");
pub const definition = "transit.fuze.source.v1.2026-09-30";
pub const Mode = enum(u8) { explicit, sampled, full, raw };
pub const Mismatch = enum(u8) { fail, type_error };
pub const Options = struct {
    format: framing.Format,
    dialect: framing.Dialect = .{},
    mode: Mode = .sampled,
    mismatch: Mismatch = .fail,
    sample_records: u64 = 1024,
    sample_bytes: u64 = 1024 * 1024,
    max_scan_bytes: u64 = 1024 * 1024 * 1024,
    max_records: u64 = 100_000_000,
    max_record_bytes: u32 = 65536,
    max_fields: u16 = 128,
    pub fn validate(self: Options) !void {
        try self.dialect.validate();
        if (self.sample_records == 0 or self.sample_bytes == 0 or self.max_scan_bytes == 0 or self.max_records == 0 or
            self.max_record_bytes == 0 or self.max_record_bytes > 65536 or self.max_fields == 0 or self.max_fields > 128) return error.InvalidSourceBudget;
    }
    pub fn fingerprint(self: Options) ![32]u8 {
        try self.validate();
        var bytes: [2048]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try writer.writeAll(definition);
        try writer.writeAll(&.{ @intFromBool(self.format == .jsonl), @backingInt(self.mode), @backingInt(self.mismatch), self.dialect.delimiter, self.dialect.quote, @intFromBool(self.dialect.header) });
        for ([_]u64{ self.sample_records, self.sample_bytes, self.max_scan_bytes, self.max_records, self.max_record_bytes, self.max_fields }) |number| try writer.writeInt(u64, number, .little);
        try writer.writeByte(@intCast(self.dialect.null_tokens.len));
        for (self.dialect.null_tokens) |token| {
            try writer.writeInt(u16, @intCast(token.len), .little);
            try writer.writeAll(token);
        }
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(writer.buffered(), &digest, .{});
        return digest;
    }
};
pub const Source = struct {
    context: *anyopaque,
    /// The callback returns 0 only at EOF, never more than output.len. It reads
    /// the already captured version at offset, not a freshly resolved pathname.
    read: *const fn (*anyopaque, u64, []u8) anyerror!usize,
    /// Checks current authority and cancellation, including buffered disclosure.
    check: *const fn (*anyopaque) anyerror!void,
    length: u64,
    digest: [32]u8,
};
pub const Origin = enum(u8) { inferred, specified, raw };
pub const Evidence = struct { records: u64 = 0, sampled_bytes: u64 = 0, complete: bool = true };
pub const Binding = struct {
    schema: types.Decoded,
    options: Options,
    options_digest: [32]u8,
    sources_digest: [32]u8,
    digest: [32]u8,
    evidence: Evidence,
    origins: [128]Origin = @splat(.raw),
    pub fn deinit(self: *Binding) void {
        self.schema.deinit();
        self.* = undefined;
    }
    pub fn validateMetadata(self: *const Binding) !void {
        try self.options.validate();
        try self.schema.type.validate(.{});
        if (self.schema.type != .structure or self.schema.type.structure.len > self.options.max_fields) return error.InvalidExplicitSchema;
        if (self.options.format == .csv) for (self.schema.type.structure) |field| switch (field.type) {
            .structure, .list, .array, .map, .tagged_union, .json, .interval => return error.UnsupportedCsvType,
            else => {},
        };
        if (self.evidence.records > self.options.max_records or self.evidence.sampled_bytes > self.options.max_scan_bytes or
            (self.options.mode == .sampled and (self.evidence.records > self.options.sample_records or self.evidence.sampled_bytes > self.options.sample_bytes)) or
            (self.options.mode == .full and !self.evidence.complete)) return error.InvalidSourceEvidence;
        for (self.origins[0..self.schema.type.structure.len]) |origin| {
            if (self.options.mode == .explicit and origin != .specified) return error.InvalidSourceEvidence;
            if (self.options.mode == .raw and origin != .raw) return error.InvalidSourceEvidence;
        }
        if (!std.mem.eql(u8, &try self.options.fingerprint(), &self.options_digest) or
            !std.mem.eql(u8, &try bindingDigest(self.schema.type, self.options_digest, self.sources_digest, self.evidence, self.origins[0..self.schema.type.structure.len]), &self.digest)) return error.SourceChanged;
    }
    pub fn validate(self: *const Binding, sources: []const Source) !void {
        try self.validateMetadata();
        if (!std.mem.eql(u8, &try sourceDigest(sources, self.options), &self.sources_digest)) return error.SourceChanged;
        for (sources) |handle| try handle.check(handle.context);
    }
};
fn sourceDigest(sources: []const Source, options: Options) ![32]u8 {
    if (sources.len == 0 or sources.len > 128) return error.InvalidSourceCount;
    var total: u64 = 0;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update(definition);
    var number: [8]u8 = undefined;
    std.mem.writeInt(u64, &number, @intCast(sources.len), .little);
    hash.update(&number);
    for (sources) |source| {
        total = std.math.add(u64, total, source.length) catch return error.SourceBudgetExceeded;
        if (total > options.max_scan_bytes) return error.SourceBudgetExceeded;
        std.mem.writeInt(u64, &number, source.length, .little);
        hash.update(&number);
        hash.update(&source.digest);
    }
    return hash.finalResult();
}
fn bindingDigest(schema: types.Type, options: [32]u8, sources: [32]u8, evidence: Evidence, origins: []const Origin) ![32]u8 {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update(definition);
    hash.update(&try schema.fingerprint());
    hash.update(&options);
    hash.update(&sources);
    var number: [8]u8 = undefined;
    std.mem.writeInt(u64, &number, evidence.records, .little);
    hash.update(&number);
    std.mem.writeInt(u64, &number, evidence.sampled_bytes, .little);
    hash.update(&number);
    for (origins) |origin| hash.update(&.{@backingInt(origin)});
    hash.update(&.{@intFromBool(evidence.complete)});
    return hash.finalResult();
}
const Reader = struct {
    source: Source,
    framer: framing.Framer,
    chunk: [8192]u8 = undefined,
    chunk_length: usize = 0,
    chunk_offset: usize = 0,
    offset: u64 = 0,
    consumed: u64 = 0,
    previous_record: u64 = 0,
    logical_record: u64 = 0,
    record_start: u64 = 0,
    record_bytes: u64 = 0,
    hash: std.crypto.hash.sha2.Sha256 = .init(.{}),
    verified: bool = false,
    budget: ?BudgetDiagnostic = null,
    fn init(source: Source, options: Options, record: []u8) !Reader {
        try source.check(source.context);
        return .{ .source = source, .framer = try framing.Framer.init(options.format, options.dialect, record) };
    }
    fn next(self: *Reader) !?[]u8 {
        self.logical_record = std.math.add(u64, self.logical_record, 1) catch return error.SourceWorkExceeded;
        self.record_start = self.consumed;
        try self.source.check(self.source.context);
        if (self.framer.ready) try self.framer.release();
        if (self.framer.ended) return null;
        while (true) {
            if (self.chunk_offset == self.chunk_length) {
                try self.source.check(self.source.context);
                const n = try self.source.read(self.source.context, self.offset, &self.chunk);
                if (n > self.chunk.len or n > self.source.length -| self.offset) return error.SourceChanged;
                self.chunk_offset = 0;
                self.chunk_length = n;
                if (n == 0) {
                    if (self.offset != self.source.length or !std.mem.eql(u8, &self.hash.finalResult(), &self.source.digest)) return error.SourceChanged;
                    self.verified = true;
                    self.framer.finish() catch |err| {
                        if (err == error.RecordTooLarge) self.budget = .{ .dimension = .record_bytes, .required = self.framer.length + 1, .limit = self.framer.buffer.len, .minimum = true };
                        return err;
                    };
                    if (!self.framer.ready) return null;
                    self.record_bytes = self.consumed - self.previous_record;
                    self.previous_record = self.consumed;
                    return try self.framer.record();
                }
                self.hash.update(self.chunk[0..n]);
                self.offset += n;
            }
            const consumed = self.framer.feed(self.chunk[self.chunk_offset..self.chunk_length]) catch |err| {
                if (err == error.RecordTooLarge) self.budget = .{ .dimension = .record_bytes, .required = self.framer.length + 1, .limit = self.framer.buffer.len, .minimum = true };
                return err;
            };
            self.chunk_offset += consumed;
            self.consumed += consumed;
            if (self.framer.ready) {
                self.record_bytes = self.consumed - self.previous_record;
                self.previous_record = self.consumed;
                return try self.framer.record();
            }
        }
    }
};
const Header = struct {
    storage: [4096]u8 = undefined,
    length: usize = 0,
    names: [128][]const u8 = undefined,
    count: usize = 0,
    fn append(self: *Header, text: []const u8, diagnostic: ?*Location) !void {
        if (diagnostic) |location| {
            location.name(text);
            location.field_index = self.count;
            if (text.len > 255) location.budget = .{ .dimension = .field_name_bytes, .required = text.len, .limit = 255 };
        }
        if (text.len == 0 or text.len > 255 or std.mem.indexOfScalar(u8, text, 0) != null or !std.unicode.utf8ValidateSlice(text)) return error.InvalidFieldName;
        if (self.count == self.names.len) {
            if (diagnostic) |location| location.budget = .{ .dimension = .record_fields, .required = self.count + 1, .limit = self.names.len, .minimum = true };
            return error.FieldBudgetExceeded;
        }
        if (text.len > self.storage.len - self.length) {
            if (diagnostic) |location| location.budget = .{ .dimension = .header_name_bytes, .required = self.length + text.len, .limit = self.storage.len, .minimum = true };
            return error.HeaderNameBudgetExceeded;
        }
        for (self.names[0..self.count], 0..) |name, index| if (std.mem.eql(u8, name, text)) {
            if (diagnostic) |location| location.earlier_field_index = index;
            return error.DuplicateField;
        };
        @memcpy(self.storage[self.length..][0..text.len], text);
        self.names[self.count] = self.storage[self.length..][0..text.len];
        self.length += text.len;
        self.count += 1;
    }
    fn fromFields(self: *Header, fields: []const framing.CsvField, has_header: bool, diagnostic: ?*Location) !void {
        for (fields, 0..) |field, i| {
            if (has_header) try self.append(field.text, diagnostic) else {
                var text: [32]u8 = undefined;
                try self.append(try std.fmt.bufPrint(&text, "column{d}", .{i + 1}), diagnostic);
            }
        }
    }
};
pub fn discover(allocator: std.mem.Allocator, sources: []const Source, options: Options, overrides: []const types.Field) !Binding {
    return discoverDiagnostic(allocator, sources, options, overrides, null);
}
pub fn discoverDiagnostic(allocator: std.mem.Allocator, sources: []const Source, options: Options, overrides: []const types.Field, diagnostic: ?*Location) !Binding {
    if (diagnostic) |location| location.* = .{};
    try options.validate();
    const source_digest = try sourceDigest(sources, options);
    const options_digest = try options.fingerprint();
    if (options.mode == .raw and overrides.len != 0) return error.InvalidExplicitSchema;
    if (overrides.len > options.max_fields or (options.mode == .explicit and overrides.len == 0)) return error.InvalidExplicitSchema;
    var builder = inference.Builder.init();
    builder.failure = if (diagnostic) |location| &location.inference else null;
    var evidence: Evidence = .{};
    const record_buffer = try allocator.alloc(u8, options.max_record_bytes);
    defer allocator.free(record_buffer);
    for (sources, 0..) |source, source_index| {
        if (diagnostic) |location| location.* = .{ .source = source_index };
        var reader = try Reader.init(source, options, record_buffer);
        errdefer if (diagnostic) |location| {
            location.discovery = .{ .records = evidence.records, .sampled_bytes = evidence.sampled_bytes, .complete = false };
            location.record = reader.logical_record;
            location.byte = reader.record_start;
            location.prefix_bytes = if (reader.logical_record == 1) reader.framer.prefix_bytes else 0;
            if (reader.framer.encoding_offset) |offset| location.json = .{ .kind = .encoding, .offset = offset };
            if (reader.budget) |budget| location.budget = budget;
        };
        var header: Header = .{};
        var first = true;
        while (try reader.next()) |record| {
            var csv_fields: [128]framing.CsvField = undefined;
            const row = if (options.format == .csv) try framing.csvDiagnostic(record, options.dialect, csv_fields[0..options.max_fields], if (diagnostic) |location| &location.budget else null) else &.{};
            if (options.format == .csv and first) {
                try header.fromFields(row, options.dialect.header, diagnostic);
                for (header.names[0..header.count]) |name| _ = try builder.ensureField(0, name);
                if (diagnostic) |location| location.* = .{ .source = source_index };
                first = false;
                if (options.dialect.header) {
                    if (options.mode == .explicit or options.mode == .raw) {
                        evidence.complete = false;
                        break;
                    }
                    continue;
                }
            }
            if (options.mode == .explicit or options.mode == .raw) {
                evidence.complete = false;
                break;
            }
            if (options.mode == .sampled and (evidence.records >= options.sample_records or reader.record_bytes > options.sample_bytes -| evidence.sampled_bytes)) {
                evidence.complete = false;
                break;
            }
            if (evidence.records == options.max_records) {
                if (diagnostic) |location| location.budget = .{ .dimension = .scan_records, .required = evidence.records + 1, .limit = options.max_records, .minimum = true };
                return error.SourceWorkExceeded;
            }
            evidence.records += 1;
            evidence.sampled_bytes = std.math.add(u64, evidence.sampled_bytes, reader.record_bytes) catch return error.SourceBudgetExceeded;
            if (options.format == .csv) try builder.csvRow(header.names[0..header.count], row, false) else {
                var parsed = try types.Json.parseContext(allocator, record, .{ .bytes = options.max_record_bytes, .fields = options.max_fields }, if (diagnostic) |location| &location.budget else null, if (diagnostic) |location| &location.json else null);
                defer parsed.deinit();
                try builder.jsonRow(parsed.value);
            }
        }
        if (first and options.format == .csv and options.dialect.header and options.mode != .explicit) return error.MissingCsvHeader;
        try source.check(source.context);
    }
    if (diagnostic) |location| location.* = .{ .discovery = evidence };
    var schema = if (options.mode == .explicit) blk: {
        var buffer: [types.max_encoding_bytes]u8 = undefined;
        break :blk try types.decode(allocator, try (types.Type{ .structure = overrides }).encode(&buffer));
    } else if (options.mode == .raw and options.format == .jsonl) blk: {
        var buffer: [types.max_encoding_bytes]u8 = undefined;
        break :blk try types.decode(allocator, try (types.Type{ .structure = &.{.{ .name = "record", .type = .json }} }).encode(&buffer));
    } else try builder.freezeDiagnostic(allocator, options.format == .csv, overrides, if (diagnostic) |location| &location.descriptor else null);
    errdefer schema.deinit();
    if (schema.type.structure.len > options.max_fields) {
        if (diagnostic) |location| location.budget = .{ .dimension = .schema_fields, .required = schema.type.structure.len, .limit = options.max_fields };
        return error.FieldBudgetExceeded;
    }
    if (options.format == .csv) for (schema.type.structure) |field| switch (field.type) {
        .structure, .list, .array, .map, .tagged_union, .json, .interval => {
            if (diagnostic) |location| {
                location.name(field.name);
                location.unsupported_type = field.type.tag();
            }
            return error.UnsupportedCsvType;
        },
        else => {},
    };
    var origins: [128]Origin = @splat(.raw);
    for (schema.type.structure, 0..) |field, i| {
        if (options.mode == .explicit or findField(overrides, field.name) != null) origins[i] = .specified else if (options.mode != .raw) {
            const node = try builder.ensureField(0, field.name);
            origins[i] = if (builder.nodes[node].kind == null or builder.nodes[node].kind == .json) .raw else .inferred;
        }
    }
    var owned_options = options;
    const owned_tokens = try schema.arena.allocator().alloc([]const u8, options.dialect.null_tokens.len);
    for (options.dialect.null_tokens, owned_tokens) |token, *owned| owned.* = try schema.arena.allocator().dupe(u8, token);
    owned_options.dialect.null_tokens = owned_tokens;
    const result: Binding = .{
        .schema = schema,
        .options = owned_options,
        .options_digest = options_digest,
        .sources_digest = source_digest,
        .evidence = evidence,
        .origins = origins,
        .digest = try bindingDigest(schema.type, options_digest, source_digest, evidence, origins[0..schema.type.structure.len]),
    };
    try result.validate(sources);
    return result;
}
pub const Row = @import("LogicalQuery.zig").Row;
/// Source-local logical record coordinates, including a CSV header. Byte is
/// the zero-based record start in the captured, expanded input, not a guessed
/// physical line or the reader's prefetched offset.
pub const Location = struct {
    source: ?usize = null,
    record: ?u64 = null,
    byte: ?u64 = null,
    prefix_bytes: u8 = 0,
    field: [128]u8 = @splat(0),
    field_len: usize = 0,
    field_truncated: bool = false,
    conversion: ?ValueDiagnostic = null,
    inference: ?types.Diagnostic = null,
    descriptor: ?types.Diagnostic = null,
    json: ?types.Json.Diagnostic = null,
    discovery: ?Evidence = null,
    budget: ?BudgetDiagnostic = null,
    field_index: ?usize = null,
    earlier_field_index: ?usize = null,
    unsupported_type: ?types.Tag = null,
    pub fn context(self: *Location, name_value: []const u8) ValueDiagnostic.Context {
        self.name(name_value);
        return .{ .failure = &self.conversion, .path = (ValueDiagnostic.Path{}).field(name_value) };
    }
    pub fn name(self: *Location, value: []const u8) void {
        self.field_len = @min(value.len, self.field.len);
        @memcpy(self.field[0..self.field_len], value[0..self.field_len]);
        self.field_truncated = value.len > self.field.len;
    }
};
pub const Scan = struct {
    location: Location = .{},
    reported: ?@import("BatchProvenance.zig").Location = null,
    allocator: std.mem.Allocator,
    binding: *const Binding,
    sources: []const Source,
    record_buffer: []u8,
    reader: ?Reader = null,
    file: usize = 0,
    header: Header = .{},
    records: u64 = 0,
    complete: bool = false,
    failed: bool = false,
    pub fn init(allocator: std.mem.Allocator, binding: *const Binding, sources: []const Source) !Scan {
        try binding.validate(sources);
        return .{ .allocator = allocator, .binding = binding, .sources = sources, .record_buffer = try allocator.alloc(u8, binding.options.max_record_bytes) };
    }
    pub fn deinit(self: *Scan) void {
        self.allocator.free(self.record_buffer);
        self.* = undefined;
    }
    pub fn position(self: *const Scan) Location {
        if (self.reported) |value| return .{ .source = value.source, .record = value.record, .byte = value.byte, .prefix_bytes = value.prefix_bytes };
        var result = self.location;
        result.source = if (self.file < self.sources.len) self.file else null;
        if (self.reader) |reader| {
            result.record = reader.logical_record;
            result.byte = reader.record_start;
            result.prefix_bytes = if (reader.logical_record == 1) reader.framer.prefix_bytes else 0;
            if (reader.framer.encoding_offset) |offset| result.json = .{ .kind = .encoding, .offset = offset };
            if (reader.budget) |budget| result.budget = budget;
        }
        return result;
    }
    pub fn batchPosition(self: *const Scan) ?@import("BatchProvenance.zig").Location {
        const value = self.position();
        return .{ .source = value.source orelse return null, .record = value.record orelse return null, .byte = value.byte orelse return null, .prefix_bytes = value.prefix_bytes };
    }
    pub fn restoreBatchPosition(self: *Scan, value: @import("BatchProvenance.zig").Location) void {
        self.reported = value;
    }
    fn conversionOrigin(self: *Scan, column: usize) void {
        if (self.location.conversion) |*value| {
            value.origin = switch (self.binding.origins[column]) {
                .inferred => .inferred,
                .specified => .specified,
                .raw => .raw,
            };
            value.sampling_records = self.binding.evidence.records;
            value.sampling_bytes = self.binding.evidence.sampled_bytes;
            value.sampling_complete = self.binding.evidence.complete;
        }
    }
    /// Buffered compute does not cache source permission or cancellation.
    pub fn validateBatchDisclosure(self: *Scan) !void {
        try self.binding.validate(self.sources);
    }
    pub fn next(self: *Scan) !?Row {
        if (self.failed) return error.FailedSource;
        if (self.complete) return null;
        errdefer {
            self.failed = true;
            if (self.location.conversion) |*detail| {
                detail.sampling_records = self.binding.evidence.records;
                detail.sampling_bytes = self.binding.evidence.sampled_bytes;
                detail.sampling_complete = self.binding.evidence.complete;
            }
        }
        try self.binding.validate(self.sources);
        while (self.file < self.sources.len) {
            if (self.reader == null) {
                self.reader = try Reader.init(self.sources[self.file], self.binding.options, self.record_buffer);
                self.header = .{};
            }
            self.location = .{};
            const record = (try self.reader.?.next()) orelse {
                if (!self.reader.?.verified) return error.IncompleteSource;
                self.reader = null;
                self.file += 1;
                continue;
            };
            var arena: std.heap.ArenaAllocator = .init(self.allocator);
            errdefer arena.deinit();
            const alloc = arena.allocator();
            const schema = self.binding.schema.type.structure;
            const cells = try alloc.alloc(values.Cell, schema.len);
            if (self.binding.options.format == .csv) {
                var fields: [128]framing.CsvField = undefined;
                const parsed = try framing.csvDiagnostic(record, self.binding.options.dialect, fields[0..self.binding.options.max_fields], &self.location.budget);
                if (self.header.count == 0) {
                    try self.header.fromFields(parsed, self.binding.options.dialect.header, &self.location);
                    for (self.header.names[0..self.header.count]) |name| if (findField(schema, name) == null) {
                        self.location.context(name).capture(null, .{ .string = name });
                        return error.UnknownField;
                    };
                    if (self.binding.options.dialect.header) {
                        arena.deinit();
                        continue;
                    }
                }
                self.location = .{};
                if (parsed.len != self.header.count) {
                    self.location.conversion = ValueDiagnostic.init(.{}, .{ .structure = schema }, null);
                    self.location.conversion.?.actual = .array;
                    self.location.conversion.?.expected_count = self.header.count;
                    self.location.conversion.?.actual_count = parsed.len;
                    return error.RaggedCsvRow;
                }
                for (schema, cells, 0..) |field, *cell, column| {
                    const context = self.location.context(field.name);
                    errdefer self.conversionOrigin(column);
                    const index = for (self.header.names[0..self.header.count], 0..) |name, i| {
                        if (std.mem.eql(u8, field.name, name)) break i;
                    } else null;
                    if (index) |i| {
                        if (parsed[i].is_null) cell.* = .null else cell.* = textCell(alloc, parsed[i].text, field.type, self.binding.options.mismatch) catch |err| {
                            context.capture(field.type, .{ .string = parsed[i].text });
                            return err;
                        };
                    } else cell.* = .missing;
                    try context.validate(cell.*, field, if (index) |i| if (parsed[i].is_null) .null else .{ .string = parsed[i].text } else null);
                }
            } else {
                var parsed = try types.Json.parseContext(alloc, record, .{ .bytes = self.binding.options.max_record_bytes, .fields = self.binding.options.max_fields }, &self.location.budget, &self.location.json);
                defer parsed.deinit();
                if (parsed.value != .object) {
                    self.location.conversion = ValueDiagnostic.init(.{}, .{ .structure = schema }, parsed.value);
                    return error.JsonObjectRequired;
                }
                if (self.binding.options.mode == .raw) cells[0] = .{ .value = .{ .json = try alloc.dupe(u8, record) } } else {
                    for (parsed.value.object.keys()) |key| if (findField(schema, key) == null) {
                        self.location.context(key).capture(null, parsed.value.object.get(key));
                        return error.UnknownField;
                    };
                    for (schema, cells, 0..) |field, *cell, column| {
                        const context = self.location.context(field.name);
                        errdefer self.conversionOrigin(column);
                        const actual = parsed.value.object.get(field.name);
                        cell.* = if (actual) |value| try jsonCell(alloc, value, field.type, self.binding.options.mismatch, 0, context) else .missing;
                        try context.validate(cell.*, field, actual);
                    }
                }
            }
            if (self.records == self.binding.options.max_records) {
                self.location.budget = .{ .dimension = .scan_records, .required = self.records + 1, .limit = self.binding.options.max_records, .minimum = true };
                return error.SourceWorkExceeded;
            }
            self.records += 1;
            try self.sources[self.file].check(self.sources[self.file].context);
            return .{ .arena = arena, .cells = cells };
        }
        try self.binding.validate(self.sources);
        self.complete = true;
        return null;
    }
};
fn findField(fields: []const types.Field, name: []const u8) ?usize {
    for (fields, 0..) |field, i| if (std.mem.eql(u8, field.name, name)) return i;
    return null;
}
fn textCell(allocator: std.mem.Allocator, text: []const u8, expected: types.Type, mismatch: Mismatch) !values.Cell {
    const atom = types.Semantics.bind(text, expected) catch |err| {
        if (mismatch == .type_error) return .{ .type_error = .utf8 };
        return err;
    };
    return .{ .value = .{ .atom = if (atom == .bytes) .{ .bytes = try allocator.dupe(u8, atom.bytes) } else atom } };
}
fn actualKind(value: std.json.Value) types.Tag {
    return switch (value) {
        .bool => .boolean,
        .string => .utf8,
        .array => .list,
        .object => .structure,
        .number_string => .decimal,
        else => .json,
    };
}
fn jsonCell(allocator: std.mem.Allocator, value: std.json.Value, expected: types.Type, mismatch: Mismatch, depth: usize, context: ValueDiagnostic.Context) anyerror!values.Cell {
    if (depth >= 16) return error.ValueBudgetExceeded;
    if (value == .null) return .null;
    const before = context.failure.*;
    const result = jsonValue(allocator, value, expected, mismatch, depth, context) catch |err| {
        // Allocation, shape budgets and unknown fields are terminal. A policy
        // cannot convert capacity/authorization failures into data values.
        switch (err) {
            error.TypeMismatch,
            error.InvalidLiteral,
            error.Overflow,
            error.Inexact,
            error.NonFiniteValue,
            error.InvalidDate,
            error.InvalidTime,
            error.InvalidTimestamp,
            error.InvalidUuid,
            error.UnsupportedLiteralType,
            => if (mismatch == .type_error) {
                context.failure.* = before;
                return .{ .type_error = types.Kind.fromTag(actualKind(value)) };
            },
            else => {},
        }
        context.capture(expected, value);
        return err;
    };
    return .{ .value = result };
}
fn jsonValue(allocator: std.mem.Allocator, value: std.json.Value, expected: types.Type, mismatch: Mismatch, depth: usize, context: ValueDiagnostic.Context) anyerror!values.Value {
    switch (expected) {
        .json => return .{ .json = try std.json.Stringify.valueAlloc(allocator, value, .{}) },
        .structure => |fields| {
            if (value != .object) return error.TypeMismatch;
            for (value.object.keys()) |key| if (findField(fields, key) == null) {
                context.child(key).capture(null, value.object.get(key));
                return error.UnknownField;
            };
            const cells = try allocator.alloc(values.Cell, fields.len);
            for (fields, cells) |field, *cell| {
                const at = context.child(field.name);
                const actual = value.object.get(field.name);
                cell.* = if (actual) |child| try jsonCell(allocator, child, field.type, mismatch, depth + 1, at) else .missing;
                try at.validate(cell.*, field, actual);
            }
            return .{ .structure = cells };
        },
        .list, .array => {
            if (value != .array) return error.TypeMismatch;
            if (expected == .array and value.array.items.len != expected.array.length) return error.InvalidArrayLength;
            const element = if (expected == .list) expected.list else expected.array.element;
            const cells = try allocator.alloc(values.Cell, value.array.items.len);
            for (cells, value.array.items, 0..) |*cell, child, ordinal| {
                const at = context.index(ordinal);
                cell.* = try jsonCell(allocator, child, element.type.*, mismatch, depth + 1, at);
                try at.validate(cell.*, .{ .name = "element", .type = element.type.*, .nullable = element.nullable }, child);
            }
            return if (expected == .list) .{ .list = cells } else .{ .array = cells };
        },
        .map => |map| {
            if (value != .object) return error.TypeMismatch;
            const entries = try allocator.alloc(values.Entry, value.object.count());
            for (value.object.keys(), value.object.values(), entries) |key, child, *entry| {
                const at = context.child(key);
                const bound_key = types.Semantics.bind(key, map.key.*) catch |err| {
                    var key_context = at;
                    key_context.map_key = true;
                    key_context.capture(map.key.*, .{ .string = key });
                    return err;
                };
                entry.* = .{ .key = bound_key, .value = try jsonCell(allocator, child, map.value.type.*, mismatch, depth + 1, at) };
                try at.validate(entry.value, .{ .name = "value", .type = map.value.type.*, .nullable = map.value.nullable }, child);
                if (entry.key == .bytes) entry.key = .{ .bytes = try allocator.dupe(u8, entry.key.bytes) };
            }
            // Bounded insertion sort admits checked ordering and duplicate errors.
            for (1..@max(1, entries.len)) |i| {
                var j = i;
                while (j > 0) : (j -= 1) {
                    switch (try values.atomOrder(entries[j - 1].key, entries[j].key, map.key.*)) {
                        .lt => break,
                        .eq => {
                            const key = value.object.keys()[i];
                            var at = context.child(key);
                            at.map_key = true;
                            at.capture(map.key.*, .{ .string = key });
                            return error.MapKeyOrder;
                        },
                        .gt => std.mem.swap(values.Entry, &entries[j - 1], &entries[j]),
                    }
                }
            }
            return .{ .map = entries };
        },
        .tagged_union => |alternatives| {
            if (value != .object or value.object.count() != 2) return error.TypeMismatch;
            const tag = value.object.get("tag") orelse return error.TypeMismatch;
            if (tag != .string) return error.TypeMismatch;
            const index = findField(alternatives, tag.string) orelse return error.TypeMismatch;
            const child = value.object.get("value") orelse return error.TypeMismatch;
            const cell = try allocator.create(values.Cell);
            const at = context.child("value");
            cell.* = try jsonCell(allocator, child, alternatives[index].type, mismatch, depth + 1, at);
            var field = alternatives[index];
            field.optional = false;
            try at.validate(cell.*, field, child);
            return .{ .tagged_union = .{ .index = @intCast(index), .value = cell } };
        },
        .interval => {
            if (value != .object or value.object.count() != 3) return error.TypeMismatch;
            var components: [3]i64 = undefined;
            for ([_][]const u8{ "months", "days", "nanos" }, 0..) |name, i| {
                const child = value.object.get(name) orelse return error.TypeMismatch;
                const at = context.child(name);
                const kind: types.Type = if (i == 2) .int64 else .int32;
                if (child != .number_string) {
                    at.capture(kind, child);
                    return error.TypeMismatch;
                }
                const atom = types.Semantics.bind(child.number_string, kind) catch |err| {
                    at.capture(kind, child);
                    return err;
                };
                components[i] = @intCast(atom.signed);
            }
            return .{ .atom = .{ .interval = .{ .months = @intCast(components[0]), .days = @intCast(components[1]), .nanos = components[2] } } };
        },
        .boolean => {
            if (value != .bool) return error.TypeMismatch;
            return .{ .atom = .{ .boolean = value.bool } };
        },
        else => {
            const numeric = types.Semantics.integer(expected) != null or expected == .float32 or expected == .float64 or expected == .decimal;
            if (numeric and value != .number_string) return error.TypeMismatch;
            if (!numeric and value != .string) return error.TypeMismatch;
            const text = if (numeric) value.number_string else value.string;
            const atom = try types.Semantics.bind(text, expected);
            return .{ .atom = if (atom == .bytes) .{ .bytes = try allocator.dupe(u8, atom.bytes) } else atom };
        },
    }
}

const Memory = struct {
    bytes: []const u8,
    width: usize = 8192,
    allowed: bool = true,
    cancelled: bool = false,
    checks: usize = 0,
    deny_after: ?usize = null,
    fn read(context: *anyopaque, offset: u64, output: []u8) !usize {
        const self: *Memory = @ptrCast(@alignCast(context));
        if (offset > self.bytes.len) return error.SourceChanged;
        const n = @min(@min(self.bytes.len - @as(usize, @intCast(offset)), output.len), self.width);
        @memcpy(output[0..n], self.bytes[@intCast(offset)..][0..n]);
        return n;
    }
    fn check(context: *anyopaque) !void {
        const self: *Memory = @ptrCast(@alignCast(context));
        self.checks += 1;
        if (self.cancelled) return error.Cancelled;
        if (!self.allowed or (self.deny_after != null and self.checks >= self.deny_after.?)) return error.Denied;
    }
    fn source(self: *Memory) Source {
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(self.bytes, &digest, .{});
        return .{ .context = self, .read = read, .check = check, .length = self.bytes.len, .digest = digest };
    }
};
test "sampled CSV freezes lossless IDs and reports late errors without successful completion" {
    const t = std.testing;
    var memory: Memory = .{ .bytes = "id,value\n001,1\n002,2\n003,outlier\n", .width = 1 };
    const sources = [_]Source{memory.source()};
    var binding = try discover(t.allocator, &sources, .{ .format = .csv, .sample_records = 2 }, &.{});
    defer binding.deinit();
    try t.expect(!binding.evidence.complete);
    try t.expectEqual(types.Tag.utf8, binding.schema.type.structure[0].type.tag());
    try t.expectEqual(types.Tag.int64, binding.schema.type.structure[1].type.tag());
    var scan = try Scan.init(t.allocator, &binding, &sources);
    defer scan.deinit();
    for ([_][]const u8{ "001", "002" }) |id| {
        var row = (try scan.next()).?;
        defer row.deinit();
        try t.expectEqualStrings(id, row.cells[0].value.atom.bytes);
    }
    try t.expectError(error.InvalidLiteral, scan.next());
    try t.expectError(error.FailedSource, scan.next());
    try t.expect(!scan.complete);
    var tolerant = try discover(t.allocator, &sources, .{ .format = .csv, .sample_records = 2, .mismatch = .type_error }, &.{});
    defer tolerant.deinit();
    var other = try Scan.init(t.allocator, &tolerant, &sources);
    defer other.deinit();
    var count: usize = 0;
    while (try other.next()) |owned| {
        var row = owned;
        defer row.deinit();
        if (count == 2) try t.expectEqual(types.Kind.utf8, row.cells[1].type_error);
        count += 1;
    }
    try t.expect(other.complete);
    try t.expectEqual(@as(usize, 3), count);
}
test "CSV full discovery aligns names across files and never rounds large integers" {
    const t = std.testing;
    var left: Memory = .{ .bytes = "id,value\n1,9007199254740993\n" };
    var right: Memory = .{ .bytes = "value,id\n18446744073709551615,2\n" };
    const sources = [_]Source{ left.source(), right.source() };
    var binding = try discover(t.allocator, &sources, .{ .format = .csv, .mode = .full }, &.{});
    defer binding.deinit();
    try t.expect(binding.evidence.complete);
    try t.expectEqual(types.Tag.int128, binding.schema.type.structure[1].type.tag());
    var scan = try Scan.init(t.allocator, &binding, &sources);
    defer scan.deinit();
    for ([_]i128{ 9007199254740993, 18446744073709551615 }) |expected| {
        var row = (try scan.next()).?;
        defer row.deinit();
        try t.expectEqual(expected, row.cells[1].value.atom.signed);
    }
    try t.expect((try scan.next()) == null);
    try t.expect(scan.complete);
}
test "JSON nested discovery preserves null missing heterogeneous raw and exact decimals" {
    const t = std.testing;
    var memory: Memory = .{ .bytes = "{\"x\":{\"a\":1},\"items\":[1,null],\"n\":1.25}\n{\"x\":{\"b\":true},\"items\":[\"001\"],\"n\":2.50}\n" };
    const sources = [_]Source{memory.source()};
    var binding = try discover(t.allocator, &sources, .{ .format = .jsonl, .mode = .full }, &.{});
    defer binding.deinit();
    var scan = try Scan.init(t.allocator, &binding, &sources);
    defer scan.deinit();
    var first = (try scan.next()).?;
    defer first.deinit();
    try t.expectEqualStrings("1", first.cells[0].value.list[0].value.json);
    try t.expect(first.cells[0].value.list[1] == .null);
    try t.expectEqual(@as(i128, 125), first.cells[1].value.atom.decimal);
    try t.expect(first.cells[2].value.structure[1] == .missing);
    var second = (try scan.next()).?;
    defer second.deinit();
    try t.expectEqualStrings("\"001\"", second.cells[0].value.list[0].value.json);
    try t.expectEqual(@as(i128, 250), second.cells[1].value.atom.decimal);
    try t.expect(second.cells[2].value.structure[0] == .missing);
    try t.expect((try scan.next()) == null);
    try t.expect(scan.complete);
}
test "changed content current denial and cancellation fence buffered rows and completion" {
    const t = std.testing;
    var memory: Memory = .{ .bytes = "id\n1\n2\n" };
    const sources = [_]Source{memory.source()};
    var binding = try discover(t.allocator, &sources, .{ .format = .csv, .mode = .full }, &.{});
    defer binding.deinit();
    memory.bytes = "id\n9\n8\n";
    var changed = try Scan.init(t.allocator, &binding, &sources);
    defer changed.deinit();
    for (0..2) |_| {
        var row = (try changed.next()).?;
        row.deinit();
    }
    try t.expectError(error.SourceChanged, changed.next());
    try t.expect(!changed.complete);
    memory.bytes = "id\n1\n2\n";
    var scan = try Scan.init(t.allocator, &binding, &sources);
    defer scan.deinit();
    var first = (try scan.next()).?;
    first.deinit();
    memory.allowed = false;
    try t.expectError(error.Denied, scan.next());
    try t.expect(!scan.complete);
    memory.allowed = true;
    memory.cancelled = true;
    try t.expectError(error.Cancelled, Scan.init(t.allocator, &binding, &sources));
}
fn allocationSchedule(allocator: std.mem.Allocator) !void {
    var memory: Memory = .{ .bytes = "{\"id\":1,\"text\":\"hello🙂\"}\n{\"id\":2,\"text\":\"world\"}\n" };
    const sources = [_]Source{memory.source()};
    var binding = try discover(allocator, &sources, .{ .format = .jsonl, .mode = .full }, &.{});
    defer binding.deinit();
    var scan = try Scan.init(allocator, &binding, &sources);
    defer scan.deinit();
    var count: usize = 0;
    while (try scan.next()) |owned| {
        var row = owned;
        defer row.deinit();
        count += 1;
    }
    try std.testing.expectEqual(@as(usize, 2), count);
}
test "discovery and row ownership release every allocation on failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationSchedule, .{});
}

test "explicit partial raw and empty input modes own schema and option evidence" {
    const t = std.testing;
    var memory: Memory = .{ .bytes = "id,value\n001,NA\n002,\"NA\"\n" };
    const sources = [_]Source{memory.source()};
    var token = [_]u8{ 'N', 'A' };
    const options: Options = .{ .format = .csv, .mode = .full, .dialect = .{ .null_tokens = &.{&token} } };
    var binding = try discover(t.allocator, &sources, options, &.{.{ .name = "id", .type = .utf8 }});
    defer binding.deinit();
    token[0] = 'X'; // Binding owns the original option bytes.
    try binding.validate(&sources);
    try t.expectEqual(Origin.specified, binding.origins[0]);
    try t.expectEqual(Origin.inferred, binding.origins[1]);
    var scan = try Scan.init(t.allocator, &binding, &sources);
    defer scan.deinit();
    var first = (try scan.next()).?;
    defer first.deinit();
    try t.expect(first.cells[1] == .null);
    var second = (try scan.next()).?;
    defer second.deinit();
    try t.expectEqualStrings("NA", second.cells[1].value.atom.bytes);
    try t.expect((try scan.next()) == null);
    var raw = try discover(t.allocator, &sources, .{ .format = .csv, .mode = .raw }, &.{});
    defer raw.deinit();
    try t.expectEqual(types.Tag.utf8, raw.schema.type.structure[0].type.tag());
    try t.expectError(error.InvalidExplicitSchema, discover(t.allocator, &sources, .{ .format = .csv, .mode = .raw }, &.{.{ .name = "id", .type = .int64 }}));
    var empty: Memory = .{ .bytes = "" };
    const empty_sources = [_]Source{empty.source()};
    var json = try discover(t.allocator, &empty_sources, .{ .format = .jsonl, .mode = .raw }, &.{});
    defer json.deinit();
    var empty_scan = try Scan.init(t.allocator, &json, &empty_sources);
    defer empty_scan.deinit();
    try t.expect((try empty_scan.next()) == null);
    try t.expect(empty_scan.complete);
    try t.expectError(error.UnresolvedSchema, discover(t.allocator, &empty_sources, .{ .format = .jsonl }, &.{}));
}
test "late new fields ragged rows duplicates and independent scan budgets fail explicitly" {
    const t = std.testing;
    var late: Memory = .{ .bytes = "{\"a\":1}\n{\"a\":2,\"new\":3}\n" };
    const sources = [_]Source{late.source()};
    var binding = try discover(t.allocator, &sources, .{ .format = .jsonl, .sample_records = 1 }, &.{});
    defer binding.deinit();
    var scan = try Scan.init(t.allocator, &binding, &sources);
    defer scan.deinit();
    var row = (try scan.next()).?;
    row.deinit();
    try t.expectError(error.UnknownField, scan.next());
    try t.expect(!scan.complete);
    var ragged: Memory = .{ .bytes = "a,b\n1,2,3\n" };
    try t.expectError(error.RaggedCsvRow, discover(t.allocator, &.{ragged.source()}, .{ .format = .csv, .mode = .full }, &.{}));
    var duplicate: Memory = .{ .bytes = "a,a\n1,2\n" };
    try t.expectError(error.DuplicateField, discover(t.allocator, &.{duplicate.source()}, .{ .format = .csv }, &.{}));
    try t.expectError(error.SourceBudgetExceeded, discover(t.allocator, &sources, .{ .format = .jsonl, .max_scan_bytes = 1 }, &.{}));
    try t.expectError(error.SourceWorkExceeded, discover(t.allocator, &sources, .{ .format = .jsonl, .mode = .full, .max_records = 1 }, &.{}));
}
test "source identity options and resolved schema mutations invalidate a binding" {
    const t = std.testing;
    var memory: Memory = .{ .bytes = "id\n1\n" };
    var sources = [_]Source{memory.source()};
    var binding = try discover(t.allocator, &sources, .{ .format = .csv, .mode = .full }, &.{});
    defer binding.deinit();
    sources[0].digest[0] ^= 1;
    try t.expectError(error.SourceChanged, binding.validate(&sources));
    sources[0].digest[0] ^= 1;
    binding.options.mismatch = .type_error;
    try t.expectError(error.SourceChanged, binding.validate(&sources));
    binding.options.mismatch = .fail;
    binding.origins[0] = .specified;
    try t.expectError(error.SourceChanged, binding.validate(&sources));
    binding.origins[0] = .inferred;
    try binding.validate(&sources);
}

test "saved bindings reject truncation foreign definitions changed sources and current denial" {
    const t = std.testing;
    const codec = @import("SourceCodec.zig");
    var memory: Memory = .{ .bytes = "id\n1\n" };
    const sources = [_]Source{memory.source()};
    var binding = try discover(t.allocator, &sources, .{ .format = .csv, .mode = .full }, &.{});
    defer binding.deinit();
    var buffer: [codec.max_bytes]u8 = undefined;
    const bytes = try codec.encode(&binding, &buffer);
    var restored = try codec.decode(t.allocator, bytes, &sources);
    defer restored.deinit();
    try t.expectEqualSlices(u8, &binding.digest, &restored.digest);
    for (0..bytes.len) |length| {
        if (codec.decode(t.allocator, bytes[0..length], &sources)) |owned| {
            var value = owned;
            value.deinit();
            return error.AcceptedTruncation;
        } else |_| {}
    }
    buffer[5] ^= 1;
    try t.expectError(error.IncompatibleDefinition, codec.decode(t.allocator, bytes, &sources));
    buffer[5] ^= 1;
    memory.allowed = false;
    try t.expectError(error.Denied, codec.decode(t.allocator, bytes, &sources));
    memory.allowed = true;
    try t.checkAllAllocationFailures(t.allocator, struct {
        fn run(allocator: std.mem.Allocator, encoded: []const u8, handles: []const Source) !void {
            var decoded = try codec.decode(allocator, encoded, handles);
            defer decoded.deinit();
        }
    }.run, .{ bytes, @as([]const Source, &sources) });
}

test "independent Python CSV JSON decimal oracles agree with full discovery and every output cell" {
    const t = std.testing;
    const Case = struct { name: []const u8, format: []const u8, inputs: [][]const u8, schema_hex: []const u8, rows_hex: [][]const u8 };
    const parsed = try std.json.parseFromSlice(struct { cases: []Case }, t.allocator, @embedFile("fixtures/sources.json"), .{});
    defer parsed.deinit();
    for (parsed.value.cases) |fixture| {
        for ([_]usize{ 1, 2, 3, 7, 8192 }) |width| {
            var memories: [8]Memory = undefined;
            var sources: [8]Source = undefined;
            for (fixture.inputs, 0..) |input, i| {
                memories[i] = .{ .bytes = input, .width = width };
                sources[i] = memories[i].source();
            }
            const handles = sources[0..fixture.inputs.len];
            var binding = try discover(t.allocator, handles, .{ .format = if (std.mem.eql(u8, fixture.format, "csv")) .csv else .jsonl, .mode = .full }, &.{});
            defer binding.deinit();
            var expected: [16384]u8 = undefined;
            var actual: [16384]u8 = undefined;
            try t.expectEqualSlices(u8, try std.fmt.hexToBytes(&expected, fixture.schema_hex), try binding.schema.type.encode(&actual));
            var scan = try Scan.init(t.allocator, &binding, handles);
            defer scan.deinit();
            var count: usize = 0;
            while (try scan.next()) |owned| {
                var row = owned;
                defer row.deinit();
                try t.expect(count < fixture.rows_hex.len);
                const cell: values.Cell = .{ .value = .{ .structure = row.cells } };
                const encoded = try types.Codec.encode(cell, .{ .name = "row", .type = binding.schema.type }, &actual);
                try t.expectEqualSlices(u8, try std.fmt.hexToBytes(&expected, fixture.rows_hex[count]), encoded);
                count += 1;
            }
            try t.expectEqual(fixture.rows_hex.len, count);
            try t.expect(scan.complete);
        }
    }
}

test "file conversion failure retains exact nested path type scalar and schema provenance" {
    const t = std.testing;
    const decimal: types.Type = .{ .decimal = .{ .precision = 4, .scale = 2 } };
    const item: types.Type = .{ .structure = &.{.{ .name = "price", .type = decimal }} };
    const nested: types.Type = .{ .structure = &.{.{ .name = "list", .type = .{ .list = .{ .type = &item } } }} };
    const number: types.Type = .int8;
    const Case = struct { input: []const u8, type: types.Type, cause: anyerror, path: []const u8, expected: []const u8, scalar: ?[]const u8 = null, map_key: bool = false };
    for ([_]Case{
        .{ .input = "{\"payload\":{\"tag\":\"price\",\"value\":null}}\n", .type = .{ .tagged_union = item.structure }, .cause = error.NullNotAllowed, .path = "/payload/value", .expected = "decimal(4,2)", .scalar = "null" },
        .{ .input = "{\"payload\":{\"01\":1,\"1\":2}}\n", .type = .{ .map = .{ .key = &number, .value = .{ .type = &number } } }, .cause = error.MapKeyOrder, .path = "/payload/1", .expected = "int8", .scalar = "1", .map_key = true },
        .{ .input = "{\"payload\":{\"list\":[{\"price\":1.234}]}}\n", .type = nested, .cause = error.Inexact, .path = "/payload/list/0/price", .expected = "decimal(4,2)", .scalar = "1.234" },
        .{ .input = "{\"payload\":{\"list\":[{\"price\":null}]}}\n", .type = nested, .cause = error.NullNotAllowed, .path = "/payload/list/0/price", .expected = "decimal(4,2)", .scalar = "null" },
        .{ .input = "{\"payload\":{\"list\":[{}]}}\n", .type = nested, .cause = error.MissingRequiredField, .path = "/payload/list/0/price", .expected = "decimal(4,2)" },
        .{ .input = "{\"payload\":{\"list\":[{\"price\":1.20,\"bad/~\":\"x\"}]}}\n", .type = nested, .cause = error.UnknownField, .path = "/payload/list/0/bad~1~0", .expected = "declared field", .scalar = "x" },
        .{ .input = "{\"payload\":[1]}\n", .type = .{ .array = .{ .length = 2, .element = .{ .type = &number } } }, .cause = error.InvalidArrayLength, .path = "/payload", .expected = "array(2)" },
        .{ .input = "{\"payload\":{\"months\":999999999999999,\"days\":0,\"nanos\":0}}\n", .type = .interval, .cause = error.Overflow, .path = "/payload/months", .expected = "int32", .scalar = "999999999999999" },
        .{ .input = "{\"payload\":{\"wat\":2}}\n", .type = .{ .map = .{ .key = &number, .value = .{ .type = &number } } }, .cause = error.InvalidLiteral, .path = "/payload/wat", .expected = "int8", .scalar = "wat", .map_key = true },
    }) |case| {
        var memory: Memory = .{ .bytes = case.input, .width = 1 };
        const sources = [_]Source{memory.source()};
        var binding = try discover(t.allocator, &sources, .{ .format = .jsonl, .mode = .explicit }, &.{.{ .name = "payload", .type = case.type }});
        defer binding.deinit();
        var scan = try Scan.init(t.allocator, &binding, &sources);
        defer scan.deinit();
        try t.expectError(case.cause, scan.next());
        const detail = scan.position().conversion.?;
        try t.expectEqualStrings(case.path, detail.path.slice());
        try t.expectEqualStrings(case.expected, detail.expectedType());
        try t.expectEqual(ValueDiagnostic.Origin.specified, detail.origin.?);
        try t.expectEqual(case.map_key, detail.map_key);
        if (case.scalar) |scalar| try t.expectEqualStrings(scalar, detail.scalar()) else try t.expect(!detail.has_preview);
        try t.expectEqual(@as(?u64, 1), scan.position().record);
        try t.expectEqual(@as(?u64, 0), scan.position().byte);
        try t.expect(!scan.complete);
        try t.expectError(error.FailedSource, scan.next());
        try t.expectEqualDeep(detail, scan.position().conversion.?);
    }
}

test "tolerated nested conversion does not replace a later terminal field failure" {
    const t = std.testing;
    const number: types.Type = .int8;
    var memory: Memory = .{ .bytes = "{\"payload\":{\"wat\":2}}\n" };
    const sources = [_]Source{memory.source()};
    var binding = try discover(t.allocator, &sources, .{ .format = .jsonl, .mode = .explicit, .mismatch = .type_error }, &.{
        .{ .name = "payload", .type = .{ .map = .{ .key = &number, .value = .{ .type = &number } } } },
        .{ .name = "required", .type = .int8 },
    });
    defer binding.deinit();
    var scan = try Scan.init(t.allocator, &binding, &sources);
    defer scan.deinit();
    try t.expectError(error.MissingRequiredField, scan.next());
    const detail = scan.position().conversion.?;
    try t.expectEqualStrings("/required", detail.path.slice());
    try t.expectEqual(ValueDiagnostic.Actual.missing, detail.actual);
    try t.expect(!detail.map_key and !detail.has_preview);
}
