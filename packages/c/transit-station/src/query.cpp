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
    out.correlation = wide(raw, value, path + "correlation"); const auto table = raw.number(value, path + "table");
    if (table > UINT32_MAX || out.correlation != correlation) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "manifest"); out.table = static_cast<uint32_t>(table);
    out.policy_revision = wide(raw, value, path + "policy_revision"); out.basis = basis(raw, value, path + "basis", realm);
    digest(raw, value, path + "basis/contract", out.source_contract);
    digest(raw, value, path + "plan", out.plan); out.segments = wide(raw, value, path + "segments"); out.bytes = wide(raw, value, path + "bytes"); out.rows = wide(raw, value, path + "rows");
    digest(raw, value, path + "chain", out.chain); digest(raw, value, path + "schema", out.schema); return out;
}
static std::string plan_wire(const transit_station_query_plan &plan, size_t bound) {
    const char *projection = plan.projection == TRANSIT_PROJECT_BOTH ? "both" : plan.projection == TRANSIT_PROJECT_KEY ? "key" : plan.projection == TRANSIT_PROJECT_VALUE ? "value" : nullptr;
    const char *aggregate = plan.aggregate == TRANSIT_AGGREGATE_ROWS ? "rows" : plan.aggregate == TRANSIT_AGGREGATE_COUNT ? "count" : plan.aggregate == TRANSIT_AGGREGATE_SUM ? "sum" : plan.aggregate == TRANSIT_AGGREGATE_COUNT_VALUES ? "count_values" : nullptr;
    require(projection && aggregate, "query-plan"); std::string predicate;
    if (plan.predicate == TRANSIT_PREDICATE_ALL) predicate = "{\"all\":{}}";
    else {
        require(plan.column == TRANSIT_COLUMN_KEY || plan.column == TRANSIT_COLUMN_VALUE, "query-column");
        const auto column = decimal(plan.column == TRANSIT_COLUMN_KEY ? 0 : 1);
        if (plan.predicate == TRANSIT_PREDICATE_NULL) predicate = "{\"is_null\":" + column + "}";
        else {
            require(plan.predicate == TRANSIT_PREDICATE_COMPARE, "query-predicate");
            const char *operation = plan.comparison == TRANSIT_COMPARE_EQ ? "eq" : plan.comparison == TRANSIT_COMPARE_NE ? "ne" : plan.comparison == TRANSIT_COMPARE_LT ? "lt" :
                plan.comparison == TRANSIT_COMPARE_LE ? "le" : plan.comparison == TRANSIT_COMPARE_GT ? "gt" : plan.comparison == TRANSIT_COMPARE_GE ? "ge" : nullptr;
            require(operation, "query-comparison"); predicate = "{\"compare\":{\"column\":" + column + ",\"op\":" + quote(operation) + ",\"value\":" + cell_wire(plan.value, bound) + "}}";
        }
    }
    return "{\"projection\":" + quote(projection) + ",\"aggregate\":" + quote(aggregate) + ",\"limit\":" + (plan.has_limit ? quote(decimal(plan.limit)) : "null") + ",\"predicate\":" + predicate + "}";
}
}
extern "C" {
transit_sdk_error transit_station_turn_allow_query(transit_station_turn *turn, transit_sdk_process destination, uint32_t table, uint64_t expected_revision, bool allow) {
    return with_turn(turn, false, [&](auto &owner) { peer(owner, destination); require(table, "table-id"); counter(expected_revision, true);
        turn_apply(owner, "{\"query_policy\":{\"peer\":" + decimal(destination.pid) + ",\"table\":" + decimal(table) + ",\"expected_revision\":" + decimal(expected_revision) + ",\"allow\":" + (allow ? "true" : "false") + "}}"); });
}
transit_sdk_error transit_station_table_start_query(transit_station_table *table, const transit_station_query_plan *plan, transit_station_query_job *out) {
    return with_turn(table ? table->turn : nullptr, false, [&](auto &owner) { require(plan && out && !table->retained, "start-query");
        const auto value = turn_apply(owner, "{\"query_start\":{\"id\":" + decimal(table->id) + ",\"plan\":" + plan_wire(*plan, owner.bridge->local.caps.cell) + "}}");
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
