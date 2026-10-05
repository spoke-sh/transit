//! Inspect the actual compiler-inferred public error sets. An open error set
//! remains explicit; a lexical source inventory cannot close it by assumption.
const std = @import("std");
const q = @import("transit_query");
const c = @import("transit_catalog");
const a = @import("transit_station_app");
const s = @import("transit_serving");

fn report(out: *std.Io.Writer, comptime name: []const u8, comptime function: anytype) !void {
    const result = @typeInfo(@TypeOf(function)).@"fn".return_type.?;
    const errors = @typeInfo(@typeInfo(result).error_union.error_set).error_set.error_names;
    try std.json.Stringify.value(.{ .boundary = name, .causes = errors }, .{}, out);
    try out.writeByte('\n');
}

pub fn main(init: std.process.Init) !void {
    var buffer: [8192]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try report(&stdout.interface, "query", q.Bridge.applyDiagnostic);
    try report(&stdout.interface, "mutation", q.TableMutationBridge.applyDiagnostic);
    try report(&stdout.interface, "catalog", c.Bridge.applyDiagnostic);
    try report(&stdout.interface, "application", a.Host.runDiagnostic);
    try report(&stdout.interface, "application-compiler", a.Host.compileDiagnostic);
    try report(&stdout.interface, "sql-select", q.fuze.Sql.parse);
    try report(&stdout.interface, "sql-template", q.fuze.Sql.parseTemplate);
    try report(&stdout.interface, "sql-declaration", q.fuze.Declaration.compileTableDiagnostic);
    try report(&stdout.interface, "sql-table-ddl", q.fuze.TableDdl.compile);
    try report(&stdout.interface, "sql-table-dml", q.fuze.TableDml.compile);
    try report(&stdout.interface, "sql-mutation", q.fuze.TableMutation.compileDiagnostic);
    try report(&stdout.interface, "sql-inspection", q.fuze.Sql.parseInspection);
    try report(&stdout.interface, "file-compiler", q.fuze.FileQuery.compileDiagnostic);
    try report(&stdout.interface, "file-discovery", q.fuze.FileSource.discoverDiagnostic);
    try report(&stdout.interface, "serving-read", s.Adapter.read);
    try report(&stdout.interface, "serving-submit", s.Adapter.submit);
    try report(&stdout.interface, "reactive-read", s.ReactiveAdapter.read);
    try report(&stdout.interface, "reactive-caller", s.ReactiveClient.apply);
    try fallbacks(&stdout.interface);
    try stdout.interface.flush();
}

fn emit(out: *std.Io.Writer, owner: []const u8, scenario: []const u8, detail: q.protocol.Diagnostic) !void {
    try detail.validate();
    try std.json.Stringify.value(.{ .owner = owner, .scenario = scenario, .code = detail.code.slice(), .category = detail.category, .stage = detail.stage, .outcome = detail.outcome, .evidence = detail.evidence, .identity = detail.identity, .actions = detail.actions }, .{}, out);
    try out.writeByte('\n');
}
fn fallbacks(out: *std.Io.Writer) !void {
    const cause = error.UnregisteredCallbackFailure;
    const identity: q.protocol.Diagnostic.Identity = .{ .domain = .transport, .id = .init(12), .sequence = .init(12) };
    try emit(out, "query", "read", try q.ApiDiagnostic.project(.{ .status = "19" }, cause, .{}, false, null));
    try emit(out, "query", "dispatched", try q.ApiDiagnostic.project(.{ .submit = "original" }, cause, .{}, true, identity));
    try emit(out, "mutation", "read", try q.MutationDiagnostic.attempt(.{ .status = "invalid" }, cause, .{}, false, null));
    try emit(out, "mutation", "dispatched", try q.MutationDiagnostic.attempt(.{ .submit = "original" }, cause, .{}, true, identity));
    try emit(out, "catalog", "read", try c.Diagnostic.attempt(.{ .list = null }, cause, .{}, false, null));
    try emit(out, "catalog", "dispatched", try c.Diagnostic.attempt(.{ .submit = "original" }, cause, .{}, true, identity));
    const config: a.Host.Config = .{ .scope = .{ .realm = 1, .application = 2, .pid = 3, .resource = 4, .namespace = .{ .value = 5 } } };
    const signed: a.Native.Signed = .{ .prepared = try a.Native.prepare(config.scope, 6, .{ .value = 12 }, .initialize), .signature = @splat(0) };
    try emit(out, "application", "read", try a.HostDiagnostic.attempt(config, .info, cause, false, null));
    try emit(out, "application", "dispatched", try a.HostDiagnostic.attempt(config, .{ .submit = signed }, cause, true, null));
    var attempt: s.ServingDiagnostic.Attempt = .{ .mode = .read };
    try emit(out, "serving", "read", try attempt.project(cause));
    attempt.mode = .control;
    attempt.identity = identity;
    attempt.dispatched = true;
    try emit(out, "serving", "dispatched", try attempt.project(cause));
    attempt.receipt = 17;
    try emit(out, "serving", "receipt", try attempt.project(cause));
}
