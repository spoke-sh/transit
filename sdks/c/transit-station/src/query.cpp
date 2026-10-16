#include "internal.hpp"
using namespace transit::sdk::station_detail;
using namespace transit::sdk::internal;
namespace transit::sdk::station_detail {
transit_station_manifest manifest(transit_station_turn &turn, uint64_t correlation) {
    require(correlation, "correlation"); const auto value = turn_apply(turn, "{\"query_completed\":" + quote(decimal(correlation)) + "}");
    const auto &raw = turn.bridge->local.raw; const uint64_t realm = turn.info.process.realm;
    transit_station_manifest out{}; const std::string path = "manifest/";
    out.result = raw.number(value, path + "result");
    out.source = {realm, raw.number(value, path + "source")}; out.destination = {realm, raw.number(value, path + "destination")};
    out.correlation = wide(raw, value, path + "correlation"); out.table = wide(raw, value, path + "table");
    if (!out.table || out.correlation != correlation) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "manifest");
    // Query manifests carry the object once, in `table`; their captured basis
    // contains resource/revision/head. Table read responses use another shape.
    out.policy_revision = wide(raw, value, path + "policy_revision"); out.basis = query_basis(raw, value, path + "basis", realm, out.table);
    require(out.policy_revision && out.basis.object == out.table, "manifest-basis");
    digest(raw, value, path + "plan", out.plan); out.segments = wide(raw, value, path + "segments"); out.bytes = wide(raw, value, path + "bytes"); out.rows = wide(raw, value, path + "rows");
    digest(raw, value, path + "chain", out.chain); digest(raw, value, path + "schema", out.schema); return out;
}

}
extern "C" {
transit_sdk_error transit_station_turn_allow_query(transit_station_turn *turn, transit_sdk_process destination, uint64_t table, uint64_t expected_revision, bool allow) {
    return with_turn(turn, false, [&](auto &owner) { peer(owner, destination); require(table, "table-id");
        turn_apply(owner, "{\"query_policy\":{\"peer\":" + decimal(destination.pid) + ",\"table\":" + quote(decimal(table)) + ",\"expected_revision\":" + quote(decimal(expected_revision)) + ",\"allow\":" + (allow ? "true" : "false") + "}}"); });
}
transit_sdk_error transit_station_turn_start_query(transit_station_turn *turn, uint64_t object, const transit_station_unified_plan *plan, transit_station_query_job *out) {
    if (out) *out = {};
    return with_turn(turn, false, [&](auto &owner) { require(object && plan && out, "start-query");
        const auto value = turn_apply(owner, "{\"query_start\":{\"id\":" + quote(decimal(object)) + ",\"plan\":" + query_plan_wire(*plan) + "}}");
        const auto &raw = owner.bridge->local.raw;
        *out = {raw.number(value, "query/result"), wide(raw, value, "query/correlation"), read_version(raw, value, "query/source")}; });
}
transit_sdk_error transit_station_turn_close_query(transit_station_turn *turn, uint64_t result, transit_station_query_close_reason reason) {
    return with_turn(turn, false, [&](auto &owner) { counter(result); require(reason == TRANSIT_QUERY_CANCELLED || reason == TRANSIT_QUERY_DENIED, "query-close-reason");
        turn_apply(owner, "{\"query_close\":{\"result\":" + decimal(result) + ",\"reason\":" + quote(reason == TRANSIT_QUERY_CANCELLED ? "cancelled" : "denied") + "}}"); });
}
transit_sdk_error transit_station_result_manifest(transit_station_turn *turn, uint64_t correlation, transit_station_manifest *out) {
    return with_turn(turn, true, [&](auto &owner) { require(out, "manifest"); *out = manifest(owner, correlation); });
}
transit_sdk_error transit_station_result_segment(transit_station_turn *turn, uint64_t correlation, uint64_t ordinal, transit_station_segment **out) {
    if (out) *out = nullptr;
    return with_turn(turn, true, [&](auto &owner) { require(out, "segment");
        auto segment = std::make_unique<transit_station_segment>(); segment->info.manifest = manifest(owner, correlation);
        require(ordinal < segment->info.manifest.segments, "segment-ordinal");
        const auto value = turn_apply(owner, "{\"query_segment\":{\"correlation\":" + quote(decimal(correlation)) + ",\"ordinal\":" + quote(decimal(ordinal)) + "}}");
        const auto &raw = owner.bridge->local.raw;
        segment->ipc = unhex(raw.field(value, "segment/ipc", true), owner.bridge->local.caps.segment);
        if (segment->ipc.size() != raw.number(value, "segment/bytes", true)) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "segment-length");
        segment->info.ordinal = wide(raw, value, "segment/ordinal");
        if (segment->info.ordinal != ordinal) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "segment-ordinal");
        segment->info.rows = raw.number(value, "segment/rows", true); digest(raw, value, "segment/digest", segment->info.digest); *out = segment.release(); });
}
transit_sdk_error transit_station_segment_inspect(const transit_station_segment *segment, transit_station_segment_info *out) {
    return boundary([&] { require(segment && out, "segment-info"); *out = segment->info; });
}
transit_sdk_error transit_station_segment_ipc(const transit_station_segment *segment, transit_sdk_buffer *out) {
    if (out) *out = {}; return boundary([&] { require(segment && out, "segment-ipc"); *out = owned(segment->ipc); });
}
void transit_station_segment_destroy(transit_station_segment *segment) { delete segment; }
}
