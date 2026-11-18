//! Zig-compiler and build-system style human diagnostics for `transit build` and `transit test`.
//! All caller paths, identifiers and source lines are terminal-escaped before styling.
const std = @import("std");
const c = @import("transit_compiler");
const testlib = @import("transit_test");
const p = @import("transit_query").protocol;
const Style = @import("Style.zig");
const Options = @import("BuildOptions.zig");
const Sources = @import("BuildSources.zig");
const EnvelopeDiagnostic = @import("EnvelopeDiagnostic.zig");

pub const Mode = enum { build, test_suite };

pub const Workspace = struct {
    cwd: []const u8 = "",
    root_path: []const u8 = "",
    selected_target: ?[]const u8 = null,
    sources: []const c.Source = &.{},
    overrides: []const Options.Override = &.{},
    resolutions: []const Sources.Resolution = &.{},
};

pub const CaseView = struct {
    name: []const u8,
    status: enum { passed, failed, not_run },
    location: p.Diagnostic.Location,
    action_location: ?p.Diagnostic.Location = null,
    error_code: ?[]const u8 = null,
    failure: ?testlib.Runner.Failure = null,
    detail: testlib.Runner.Detail = .{},
};

const Connectors = struct {
    branch: []const u8,
    last: []const u8,
    fn init(style: Style) Connectors {
        return if (style.ascii_tree)
            .{ .branch = "+- ", .last = "+- " }
        else
            .{ .branch = "├─ ", .last = "└─ " };
    }
};

pub fn renderFailure(
    out: *std.Io.Writer,
    style: Style,
    mode: Mode,
    options: Options,
    workspace: Workspace,
    envelope: p.Diagnostic,
    report: ?*const c.SourceDiagnostic.Report,
) !void {
    try envelope.validate();
    const tree = Connectors.init(style);
    const root_name = switch (mode) {
        .build => "build",
        .test_suite => "test",
    };

    var step_buf: [128]u8 = undefined;
    var succeeded: usize = 0;
    var total_steps: usize = 2;
    const effective_target = workspace.selected_target orelse (if (report) |r| r.selectedTarget() else null) orelse options.target;
    const step_label = stepLabel(&step_buf, mode, options, effective_target, envelope, &succeeded, &total_steps);

    try out.writeAll(root_name);
    try out.writeByte('\n');
    try style.text(out, .comment, tree.last);
    try out.writeAll(step_label);
    try out.writeByte(' ');
    try style.text(out, .failure, "failure");
    try out.writeByte('\n');

    const fact_path = findFactText(envelope, .actual_source);
    const fact_path_truncated = findFactTruncated(envelope, .actual_source);
    const fact_kind = findFactText(envelope, .source_kind);

    var headline_buf: [384]u8 = undefined;
    const headline = buildHeadline(&headline_buf, envelope, report, if (envelope.location == null) fact_kind else null);

    if (envelope.location) |at| {
        try out.writeAll(style.code(.emphasis));
        try writeLocation(out, workspace, at);
        try out.writeAll(": ");
        try out.writeAll(style.code(.plain));
        try style.text(out, .failure, "error:");
        try out.writeByte(' ');
        try out.writeAll(style.code(.emphasis));
        try EnvelopeDiagnostic.escaped(out, headline);
        try out.writeAll(style.code(.plain));
        try out.writeByte('\n');
        if (findSourceText(workspace.sources, at)) |src_text| {
            try writeExcerpt(out, style, src_text, try at.line.value(), try at.byte_column.value(), try at.length.value());
        }
    } else if (fact_path) |raw_path| {
        try out.writeAll(style.code(.emphasis));
        try out.writeAll(raw_path);
        if (fact_path_truncated) try out.writeAll(" [truncated]");
        try out.writeAll(": ");
        try out.writeAll(style.code(.plain));
        try style.text(out, .failure, "error:");
        try out.writeByte(' ');
        try out.writeAll(style.code(.emphasis));
        try EnvelopeDiagnostic.escaped(out, headline);
        try out.writeAll(style.code(.plain));
        try out.writeByte('\n');
    } else {
        try style.text(out, .failure, "error:");
        try out.writeByte(' ');
        try out.writeAll(style.code(.emphasis));
        try EnvelopeDiagnostic.escaped(out, headline);
        try out.writeAll(style.code(.plain));
        try out.writeByte('\n');
    }

    if (envelope.location != null and (fact_path != null or fact_kind != null)) {
        var shown_in_headline = false;
        if (fact_path) |fp| shown_in_headline = std.mem.indexOf(u8, headline, fp) != null;
        if (!shown_in_headline or fact_kind != null) {
            try style.text(out, .note, "note:");
            try out.writeByte(' ');
            if (fact_path) |fp| {
                try out.writeAll("path '");
                try out.writeAll(fp);
                if (fact_path_truncated) try out.writeAll(" [truncated]");
                try out.writeByte('\'');
                if (fact_kind) |fk| {
                    try out.writeAll(" has kind '");
                    try EnvelopeDiagnostic.escaped(out, fk);
                    try out.writeByte('\'');
                }
            } else if (fact_kind) |fk| {
                try out.writeAll("observed source kind '");
                try EnvelopeDiagnostic.escaped(out, fk);
                try out.writeByte('\'');
            }
            try out.writeByte('\n');
        }
    }

    if (report) |r| {
        for (r.notes) |slot| if (slot) |note| {
            if (note.located and note.file != null and note.file.? < workspace.sources.len) {
                const src = workspace.sources[note.file.?];
                const note_loc = c.Compiler.locationSpan(src, note.span);
                try out.writeAll(style.code(.emphasis));
                try writeLocation(out, workspace, note_loc);
                try out.writeAll(": ");
                try out.writeAll(style.code(.plain));
                try style.text(out, .note, "note:");
                try out.writeByte(' ');
                try EnvelopeDiagnostic.escaped(out, note.slice());
                try out.writeByte('\n');
                try writeExcerpt(out, style, src.text, try note_loc.line.value(), try note_loc.byte_column.value(), try note_loc.length.value());
            } else {
                try style.text(out, .note, "note:");
                try out.writeByte(' ');
                try EnvelopeDiagnostic.escaped(out, note.slice());
                try out.writeByte('\n');
            }
        };

        if (r.frames_len > 0) {
            try style.text(out, .comment, "referenced by:");
            try out.writeByte('\n');
            var i: usize = r.frames_len;
            while (i > 0) {
                i -= 1;
                const frame = r.frames[i];
                if (frame.file >= workspace.sources.len) continue;
                const frame_loc = c.Compiler.locationSpan(workspace.sources[frame.file], frame.span);
                try out.writeAll("    ");
                try EnvelopeDiagnostic.escaped(out, frame.name());
                try style.text(out, .comment, ": ");
                try out.writeAll(style.code(.emphasis));
                try writeLocation(out, workspace, frame_loc);
                try out.writeAll(style.code(.plain));
                try out.writeByte('\n');
            }
        }
    } else {
        for (envelope.facts) |slot| if (slot) |fact| {
            if (fact.field == .first_occurrence and fact.value != null and fact.value.? == .location) {
                const call_at = fact.value.?.location;
                try out.writeAll(style.code(.emphasis));
                try writeLocation(out, workspace, call_at);
                try out.writeAll(": ");
                try out.writeAll(style.code(.plain));
                try style.text(out, .note, "note:");
                try out.writeAll(" instantiated here\n");
                if (findSourceText(workspace.sources, call_at)) |src_text| {
                    try writeExcerpt(out, style, src_text, try call_at.line.value(), try call_at.byte_column.value(), try call_at.length.value());
                }
            }
        };
    }

    try out.writeByte('\n');
    try style.text(out, .emphasis, if (mode == .build) "Build Summary:" else "Test Summary:");
    try out.writeByte(' ');
    var count_buf: [64]u8 = undefined;
    const succ_str = std.fmt.bufPrint(&count_buf, "{d}/{d} steps succeeded", .{ succeeded, total_steps }) catch "0 steps succeeded";
    if (succeeded > 0) try style.text(out, .span, succ_str) else try out.writeAll(succ_str);
    try out.writeAll("; ");
    try style.text(out, .failure, "1 failed");
    if (mode == .test_suite and envelope.outcome == .not_submitted) {
        try out.writeAll(" (no SQL submitted)");
    }
    try out.writeByte('\n');
    try out.writeAll(root_name);
    try out.writeByte(' ');
    try style.text(out, .category, "transitive failure");
    try out.writeByte('\n');
    try style.text(out, .comment, tree.last);
    try out.writeAll(step_label);
    try out.writeByte(' ');
    try style.text(out, .failure, "1 error");
    try out.writeByte('\n');
}

pub fn renderTestSuiteFailure(
    out: *std.Io.Writer,
    style: Style,
    target: []const u8,
    workspace: Workspace,
    cases: []const CaseView,
) !void {
    const tree = Connectors.init(style);
    var passed: usize = 0;
    var failed: usize = 0;
    var not_run: usize = 0;
    for (cases) |item| switch (item.status) {
        .passed => passed += 1,
        .failed => failed += 1,
        .not_run => not_run += 1,
    };

    try out.writeAll("test\n");
    try style.text(out, .comment, tree.last);
    try out.writeAll("run target '");
    try out.writeAll(style.code(.emphasis));
    try EnvelopeDiagnostic.escaped(out, target);
    try out.writeAll(style.code(.plain));
    try out.writeAll("' ");
    var buf: [96]u8 = undefined;
    const pass_str = std.fmt.bufPrint(&buf, "{d}/{d} passed", .{ passed, cases.len }) catch "passed";
    if (passed > 0) try style.text(out, .span, pass_str) else try out.writeAll(pass_str);
    try out.writeAll(", ");
    var fail_buf: [48]u8 = undefined;
    const fail_str = std.fmt.bufPrint(&fail_buf, "{d} failed", .{failed}) catch "failed";
    try style.text(out, .failure, fail_str);
    if (not_run > 0) {
        try out.writeAll(", ");
        var skip_buf: [48]u8 = undefined;
        const skip_str = std.fmt.bufPrint(&skip_buf, "{d} not run", .{not_run}) catch "not run";
        try style.text(out, .category, skip_str);
    }
    try out.writeByte('\n');

    var seen_failed: usize = 0;
    for (cases) |item| {
        if (item.status != .failed) continue;
        seen_failed += 1;
        try out.writeAll("   ");
        try style.text(out, .comment, if (seen_failed == failed) tree.last else tree.branch);
        try out.writeByte('\'');
        try out.writeAll(style.code(.emphasis));
        try EnvelopeDiagnostic.escaped(out, item.name);
        try out.writeAll(style.code(.plain));
        try out.writeAll("' ");
        try style.text(out, .failure, "failure");
        try out.writeByte('\n');
    }

    for (cases) |item| {
        if (item.status != .failed) continue;
        const primary = item.action_location orelse item.location;
        var msg_buf: [320]u8 = undefined;
        const msg = formatTestFailure(&msg_buf, item);
        try out.writeAll(style.code(.emphasis));
        try writeLocation(out, workspace, primary);
        try out.writeAll(": ");
        try out.writeAll(style.code(.plain));
        try style.text(out, .failure, "error:");
        try out.writeByte(' ');
        try out.writeAll(style.code(.emphasis));
        try EnvelopeDiagnostic.escaped(out, msg);
        try out.writeAll(style.code(.plain));
        try out.writeByte('\n');
        if (findSourceText(workspace.sources, primary)) |src_text| {
            try writeExcerpt(out, style, src_text, try primary.line.value(), try primary.byte_column.value(), try primary.length.value());
        }
        if (item.action_location != null) {
            try out.writeAll(style.code(.emphasis));
            try writeLocation(out, workspace, item.location);
            try out.writeAll(": ");
            try out.writeAll(style.code(.plain));
            try style.text(out, .note, "note:");
            try out.writeAll(" in test '");
            try EnvelopeDiagnostic.escaped(out, item.name);
            try out.writeAll("'\n");
            if (findSourceText(workspace.sources, item.location)) |case_src| {
                try writeExcerpt(out, style, case_src, try item.location.line.value(), try item.location.byte_column.value(), try item.location.length.value());
            }
        }
    }

    try out.writeByte('\n');
    try style.text(out, .emphasis, "Test Summary:");
    try out.writeByte(' ');
    const summary_pass = std.fmt.bufPrint(&buf, "{d}/{d} tests passed", .{ passed, cases.len }) catch "tests passed";
    if (passed > 0) try style.text(out, .span, summary_pass) else try out.writeAll(summary_pass);
    try out.writeAll("; ");
    try style.text(out, .failure, fail_str);
    if (not_run > 0) {
        try out.writeAll("; ");
        var skip_buf: [48]u8 = undefined;
        const skip_str = std.fmt.bufPrint(&skip_buf, "{d} not run", .{not_run}) catch "not run";
        try style.text(out, .category, skip_str);
    }
    try out.writeByte('\n');
    try out.writeAll("test ");
    try style.text(out, .category, "transitive failure");
    try out.writeByte('\n');
    try style.text(out, .comment, tree.last);
    try out.writeAll("run target '");
    try EnvelopeDiagnostic.escaped(out, target);
    try out.writeAll("' ");
    try style.text(out, .failure, fail_str);
    if (not_run > 0) {
        try out.writeAll(", ");
        var skip_buf: [48]u8 = undefined;
        const skip_str = std.fmt.bufPrint(&skip_buf, "{d} not run", .{not_run}) catch "not run";
        try style.text(out, .category, skip_str);
    }
    try out.writeByte('\n');
}

fn stepLabel(buf: *[128]u8, mode: Mode, options: Options, target_name: []const u8, envelope: p.Diagnostic, succeeded: *usize, total: *usize) []const u8 {
    if (mode == .build) {
        if (options.fetch) {
            succeeded.* = 0;
            total.* = 1;
            return "fetch dependencies";
        }
        if (options.check) {
            succeeded.* = 0;
            total.* = 1;
            return std.fmt.bufPrint(buf, "check target '{s}'", .{target_name}) catch "check target";
        }
        total.* = 2;
        if (envelope.stage == .output) {
            succeeded.* = 1;
            return "publish artifacts";
        }
        succeeded.* = 0;
        if (std.mem.eql(u8, envelope.code.slice(), "application.source.dependency")) return "verify dependencies";
        return std.fmt.bufPrint(buf, "compile target '{s}'", .{target_name}) catch "compile target";
    }
    succeeded.* = 0;
    total.* = 2;
    if (std.mem.eql(u8, envelope.code.slice(), "application.source.dependency")) return "verify dependencies";
    return std.fmt.bufPrint(buf, "compile target '{s}'", .{target_name}) catch "compile target";
}

fn buildHeadline(buf: *[384]u8, envelope: p.Diagnostic, report: ?*const c.SourceDiagnostic.Report, kind_suffix: ?[]const u8) []const u8 {
    const base = if (report) |r| (r.headline() orelse fallbackEnvelopeMessage(envelope)) else fallbackEnvelopeMessage(envelope);
    if (kind_suffix) |kind| {
        return std.fmt.bufPrint(buf, "{s} (found {s})", .{ base, kind }) catch base;
    }
    return base;
}

fn fallbackEnvelopeMessage(envelope: p.Diagnostic) []const u8 {
    const msg = envelope.message.slice();
    const period = std.mem.indexOfScalar(u8, msg, '.') orelse return msg;
    return msg[0..period];
}

fn formatTestFailure(buf: *[320]u8, item: CaseView) []const u8 {
    if (item.error_code) |code| {
        if (std.mem.eql(u8, code, "TestDeadline")) return "test case exceeded 30s execution deadline (TestDeadline)";
        if (std.mem.eql(u8, code, "TestSuiteDeadline")) return "test suite exceeded 5m execution deadline (TestSuiteDeadline)";
        if (std.mem.eql(u8, code, "TestRowsLimit")) return "query exceeded 10,000-row test observation limit (TestRowsLimit)";
        if (std.mem.eql(u8, code, "TestResultBytesLimit")) return "query exceeded 16 MiB test result byte limit (TestResultBytesLimit)";
        if (std.mem.eql(u8, code, "TestMemoryLimit")) return "test case exceeded 256 MiB host memory limit (TestMemoryLimit)";
        if (std.mem.eql(u8, code, "GatewayMutationRejected")) return "statement was refused during test execution (GatewayMutationRejected)";
        return std.fmt.bufPrint(buf, "statement failed during test execution ({s})", .{code}) catch "statement failed during test execution";
    }
    if (item.failure) |failure| {
        const d = item.detail;
        return switch (failure) {
            .rows => if (d.schema_mismatch)
                "row assertion failed: query result schema did not match expectation"
            else if (d.expected_primary != d.observed_primary)
                (std.fmt.bufPrint(buf, "row assertion failed: expected {d} {s}, observed {d} {s}", .{
                    d.expected_primary,
                    if (d.expected_primary == 1) "row" else "rows",
                    d.observed_primary,
                    if (d.observed_primary == 1) "row" else "rows",
                }) catch "row assertion failed")
            else
                (std.fmt.bufPrint(buf, "row assertion failed: observed {d} {s} did not match expected values", .{
                    d.observed_primary,
                    if (d.observed_primary == 1) "row" else "rows",
                }) catch "row assertion failed"),
            .counts => std.fmt.bufPrint(buf, "command assertion failed: expected matched {d}, changed {d}; observed matched {d}, changed {d}", .{
                d.expected_primary,
                d.expected_secondary,
                d.observed_primary,
                d.observed_secondary,
            }) catch "command assertion failed",
            .expected_refusal => if (d.expectedReason().len > 0)
                (std.fmt.bufPrint(buf, "statement assertion failed: expected refusal '{s}', but statement succeeded", .{d.expectedReason()}) catch "statement assertion failed: expected refusal, but statement succeeded")
            else
                "statement assertion failed: expected refusal, but statement succeeded",
            .refusal_reason => std.fmt.bufPrint(buf, "statement assertion failed: expected refusal '{s}', observed '{s}'", .{
                d.expectedReason(),
                d.observedReason(),
            }) catch "statement assertion failed: refusal reason did not match",
            .workflow_counts => std.fmt.bufPrint(buf, "workflow assertion failed: counters exceeded expectation (expected completed {d}, refused {d}; observed completed {d}, refused {d})", .{
                d.expected_primary,
                d.expected_secondary,
                d.observed_primary,
                d.observed_secondary,
            }) catch "workflow assertion failed: counters exceeded expectation",
            .workflow_progress => std.fmt.bufPrint(buf, "workflow assertion failed: insufficient progress after {d} observations (expected completed {d}, refused {d}; observed completed {d}, refused {d})", .{
                d.observations,
                d.expected_primary,
                d.expected_secondary,
                d.observed_primary,
                d.observed_secondary,
            }) catch "workflow assertion failed: insufficient progress",
        };
    }
    return "test case failed";
}

fn findFactText(envelope: p.Diagnostic, field: p.Diagnostic.Field) ?[]const u8 {
    for (&envelope.facts) |*slot| if (slot.*) |*fact| {
        if (fact.field == field and fact.value != null and fact.value.? == .text) return fact.value.?.text.slice();
    };
    return null;
}

fn findFactTruncated(envelope: p.Diagnostic, field: p.Diagnostic.Field) bool {
    for (envelope.facts) |slot| if (slot) |fact| {
        if (fact.field == field) return fact.availability == .truncated;
    };
    return false;
}

fn findSourceText(sources: []const c.Source, at: p.Diagnostic.Location) ?[]const u8 {
    const src = at.source orelse return null;
    if (at.source_truncated or at.source_encoding != .utf8) return null;
    const raw = src.slice();
    const slash = std.mem.indexOfScalar(u8, raw, '/') orelse return null;
    const pkg = raw[0..slash];
    const rel = raw[slash + 1 ..];
    for (sources) |candidate| {
        if (std.mem.eql(u8, candidate.package, pkg) and std.mem.eql(u8, candidate.path, rel)) return candidate.text;
    }
    return null;
}

pub fn writeLocation(out: *std.Io.Writer, workspace: Workspace, at: p.Diagnostic.Location) !void {
    if (at.source) |*source| {
        const raw = source.slice();
        if (!at.source_truncated and at.source_encoding == .utf8) {
            if (std.mem.indexOfScalar(u8, raw, '/')) |slash| {
                const pkg = raw[0..slash];
                const rel = raw[slash + 1 ..];
                try writePackagePath(out, workspace, pkg, rel);
            } else try EnvelopeDiagnostic.escaped(out, raw);
        } else {
            try EnvelopeDiagnostic.escaped(out, raw);
            if (at.source_truncated) try out.writeAll(" [truncated]");
            if (at.source_encoding == .escaped_bytes) try out.writeAll(" [escaped bytes]");
        }
        try out.print(":{d}:{d}", .{ try at.line.value(), try at.byte_column.value() });
    } else {
        try out.print("line {d}, byte column {d}", .{ try at.line.value(), try at.byte_column.value() });
    }
}

fn writePackagePath(out: *std.Io.Writer, workspace: Workspace, pkg: []const u8, rel: []const u8) !void {
    if (std.mem.eql(u8, pkg, "root")) {
        if (workspace.cwd.len > 0 and workspace.root_path.len > 0 and !std.mem.eql(u8, workspace.cwd, workspace.root_path)) {
            if (std.mem.startsWith(u8, workspace.root_path, workspace.cwd) and
                workspace.root_path.len > workspace.cwd.len and
                workspace.root_path[workspace.cwd.len] == '/')
            {
                try EnvelopeDiagnostic.escaped(out, workspace.root_path[workspace.cwd.len + 1 ..]);
                try out.writeByte('/');
            } else {
                try EnvelopeDiagnostic.escaped(out, workspace.root_path);
                try out.writeByte('/');
            }
        }
        return EnvelopeDiagnostic.escaped(out, rel);
    }
    for (workspace.overrides) |ov| if (std.mem.eql(u8, ov.name, pkg)) {
        try EnvelopeDiagnostic.escaped(out, ov.directory);
        if (!std.mem.endsWith(u8, ov.directory, "/")) try out.writeByte('/');
        return EnvelopeDiagnostic.escaped(out, rel);
    };
    for (workspace.resolutions) |res| if (std.mem.eql(u8, res.name, pkg)) {
        if (workspace.cwd.len > 0 and workspace.root_path.len > 0 and !std.mem.eql(u8, workspace.cwd, workspace.root_path) and
            std.mem.startsWith(u8, workspace.root_path, workspace.cwd) and workspace.root_path.len > workspace.cwd.len and workspace.root_path[workspace.cwd.len] == '/')
        {
            try EnvelopeDiagnostic.escaped(out, workspace.root_path[workspace.cwd.len + 1 ..]);
            try out.writeByte('/');
        }
        try out.writeAll(".transit/packages/");
        try EnvelopeDiagnostic.escaped(out, res.digest);
        try out.writeByte('/');
        return EnvelopeDiagnostic.escaped(out, rel);
    };
    try EnvelopeDiagnostic.escaped(out, pkg);
    try out.writeByte('/');
    try EnvelopeDiagnostic.escaped(out, rel);
}

pub fn writeExcerpt(out: *std.Io.Writer, style: Style, text: []const u8, line_num: u64, byte_col: u64, span_len: u64) !void {
    if (line_num == 0) return;
    var current_line: u64 = 1;
    var line_start: usize = 0;
    var idx: usize = 0;
    while (idx < text.len and current_line < line_num) : (idx += 1) {
        if (text[idx] == '\n') {
            current_line += 1;
            line_start = idx + 1;
        }
    }
    if (current_line != line_num) return;
    var line_end = line_start;
    while (line_end < text.len and text[line_end] != '\n') line_end += 1;
    if (line_end > line_start and text[line_end - 1] == '\r') line_end -= 1;

    const raw_line = text[line_start..line_end];
    const raw_col = if (byte_col > 0) @min(@as(usize, @intCast(byte_col - 1)), raw_line.len) else 0;
    const raw_end = @min(raw_line.len, raw_col +| @as(usize, @intCast(span_len)));

    var visual_buf: [2048]u8 = undefined;
    var vw: std.Io.Writer = .fixed(&visual_buf);
    var vis_start: usize = 0;
    var vis_end: usize = 0;
    var set_start = false;
    var set_end = false;

    for (raw_line, 0..) |byte, i| {
        if (i == raw_col) {
            vis_start = vw.end;
            set_start = true;
        }
        if (i == raw_end) {
            vis_end = vw.end;
            set_end = true;
        }
        if (vw.buffer.len - vw.end < 4) break;
        switch (byte) {
            0x20...0x7e => vw.writeByte(byte) catch unreachable,
            '\t' => vw.writeAll("    ") catch unreachable,
            else => vw.print("\\x{x:0>2}", .{byte}) catch unreachable,
        }
    }
    if (!set_start) vis_start = vw.end;
    if (!set_end) vis_end = vw.end;

    const vis = vw.buffered();
    const max_width: usize = 120;
    var win_start: usize = 0;
    var win_end: usize = vis.len;
    if (vis.len > max_width) {
        const half: usize = 50;
        win_start = if (vis_start > half) @min(vis_start - half, vis.len - max_width) else 0;
        win_end = @min(vis.len, win_start + max_width);
    }

    const left_ellipsis = win_start > 0;
    const right_ellipsis = win_end < vis.len;

    if (left_ellipsis) try out.writeAll("...");
    try out.writeAll(vis[win_start..win_end]);
    if (right_ellipsis) try out.writeAll("...");
    try out.writeByte('\n');

    const caret_pos = (if (left_ellipsis) @as(usize, 3) else 0) + (vis_start -| win_start);
    const clamped_end = @min(vis_end, win_end);
    const tilde_count = if (clamped_end > vis_start + 1) clamped_end - vis_start - 1 else 0;

    try out.splatByteAll(' ', caret_pos);
    try out.writeAll(style.code(.span));
    try out.writeByte('^');
    if (tilde_count > 0) try out.splatByteAll('~', tilde_count);
    try out.writeAll(style.code(.plain));
    try out.writeByte('\n');
}

test "Zig-style build report strips root prefix escapes control bytes and styles spans" {
    const t = std.testing;
    const src_text = "CREATE TARGET default BEGIN\n\tINSERT INTO items VALUES ('\x1b[31m');\nEND;";
    const sources = [_]c.Source{.{ .package = "root", .path = "build.transit", .text = src_text }};
    var envelope: ?p.Diagnostic = null;
    var report: c.SourceDiagnostic.Report = .{};
    try t.expectError(error.InvalidSourceSyntax, c.compile(t.allocator, &sources, .{ .compiler_revision = "test", .report = &report }, &envelope));

    var plain_out: std.Io.Writer.Allocating = .init(t.allocator);
    defer plain_out.deinit();
    try renderFailure(&plain_out.writer, .{}, .build, .{}, .{ .cwd = "/work", .root_path = "/work", .sources = &sources }, envelope.?, &report);
    const plain = plain_out.written();
    try t.expect(std.mem.indexOf(u8, plain, "build.transit:1:23: error: expected 'AS', found 'BEGIN'") != null);
    try t.expect(std.mem.indexOf(u8, plain, "root/build.transit") == null);
    try t.expect(std.mem.indexOf(u8, plain, "Code: application.source") == null);
    try t.expect(std.mem.indexOf(u8, plain, "native_cause:") == null);
    try t.expect(std.mem.indexOf(u8, plain, "^~~~~") != null);
    try t.expect(std.mem.indexOf(u8, plain, "Build Summary: 0/2 steps succeeded; 1 failed") != null);
    try t.expect(std.mem.indexOfScalar(u8, plain, 0x1b) == null);

    var colored_out: std.Io.Writer.Allocating = .init(t.allocator);
    defer colored_out.deinit();
    try renderFailure(&colored_out.writer, .{ .enabled = true }, .test_suite, .{ .target = "tests" }, .{ .cwd = "/work", .root_path = "/work", .sources = &sources }, envelope.?, &report);
    const colored = colored_out.written();
    try t.expect(std.mem.indexOf(u8, colored, "\x1b[1;31merror:\x1b[0m") != null);
    try t.expect(std.mem.indexOf(u8, colored, "\x1b[1;32m^~~~~\x1b[0m") != null);
    try t.expect(std.mem.indexOf(u8, colored, "(no SQL submitted)") != null);

    var excerpt_out: std.Io.Writer.Allocating = .init(t.allocator);
    defer excerpt_out.deinit();
    try writeExcerpt(&excerpt_out.writer, .{}, src_text, 2, 2, 6);
    try t.expect(std.mem.indexOf(u8, excerpt_out.written(), "    INSERT INTO items VALUES ('\\x1b[31m');\n    ^~~~~~\n") != null);
    try t.expect(std.mem.indexOfScalar(u8, excerpt_out.written(), 0x1b) == null);
}
