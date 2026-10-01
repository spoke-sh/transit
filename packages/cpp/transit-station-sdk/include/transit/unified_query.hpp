#pragma once
#include <transit/station.hpp>
#include <transit/unified_query.h>

namespace transit::sdk::station::unified {
enum class Type { Int64, UInt64, Float64, Boolean, Utf8, Binary };
enum class State { Missing, Null, TypeError, Value, Conflict };
enum class ProjectionMode { Scalar, Text, ElementCounter, ElementReplica };
using Scalar = std::variant<int64_t, uint64_t, double, bool, std::string, Bytes>;
struct Column { std::string name; Type type; };
struct Decoder { Type type; uint8_t version = 1; };
struct KvSource { ResourceRef resource; Bytes prefix; Decoder key, value; };
struct TableSource { ResourceRef resource; uint32_t id; std::array<std::string, 2> names; Type value_type; };
struct Projection {
    Column column; std::vector<std::string> path;
    bool relative = false; ProjectionMode mode = ProjectionMode::Scalar;
    uint16_t text_bytes = 4096, text_steps = 4096;
};
struct DocumentSource {
    DocumentReference reference; std::vector<Projection> projections;
    std::optional<std::vector<std::string>> expand;
};
using Source = std::variant<KvSource, TableSource, DocumentSource>;
struct IsState { uint8_t column; State state; };
struct Compare { uint8_t column; Comparison comparison; Scalar value; };
struct Plan {
    std::vector<uint8_t> projection;
    std::variant<All, IsState, Compare> predicate;
    Aggregate aggregate = Aggregate::Rows;
    std::optional<uint64_t> limit;
    std::optional<std::vector<std::optional<std::string>>> output_names;
};
struct Budgets { uint64_t pages, segments, result_bytes; };
namespace detail {
inline transit_station_unified_scalar scalar(const Scalar &value) {
    transit_station_unified_scalar out{};
    std::visit([&](const auto &v) {
        using T = std::decay_t<decltype(v)>;
        if constexpr (std::is_same_v<T, int64_t>) { out.type = TRANSIT_UNIFIED_INT64; out.signed_value = v; }
        else if constexpr (std::is_same_v<T, uint64_t>) { out.type = TRANSIT_UNIFIED_UINT64; out.unsigned_value = v; }
        else if constexpr (std::is_same_v<T, double>) { out.type = TRANSIT_UNIFIED_FLOAT64; out.float_value = v; }
        else if constexpr (std::is_same_v<T, bool>) { out.type = TRANSIT_UNIFIED_BOOLEAN; out.boolean = v; }
        else if constexpr (std::is_same_v<T, std::string>) { out.type = TRANSIT_UNIFIED_UTF8; out.bytes = {reinterpret_cast<const uint8_t *>(v.data()), v.size()}; }
        else { out.type = TRANSIT_UNIFIED_BINARY; out.bytes = bytes_view(v); }
    }, value);
    return out;
}
inline Scalar scalar(transit_station_unified_scalar value) {
    switch (value.type) {
        case TRANSIT_UNIFIED_INT64: return value.signed_value;
        case TRANSIT_UNIFIED_UINT64: return value.unsigned_value;
        case TRANSIT_UNIFIED_FLOAT64: return value.float_value;
        case TRANSIT_UNIFIED_BOOLEAN: return value.boolean;
        case TRANSIT_UNIFIED_UTF8: return value.bytes.size ? std::string(reinterpret_cast<const char *>(value.bytes.data), value.bytes.size) : std::string{};
        case TRANSIT_UNIFIED_BINARY: return copy_bytes(value.bytes);
    }
    throw failure(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "query-scalar");
}
inline transit_station_unified_column column(const Column &v) {
    checked_string(v.name);
    return {v.name.c_str(), static_cast<transit_station_unified_type>(v.type)};
}
inline std::vector<const char *> path(const std::vector<std::string> &v) {
    std::vector<const char *> out;
    for (const auto &name : v) { checked_string(name); out.push_back(name.c_str()); }
    return out;
}
// All pointers borrow the supplied Source through the synchronous C operation.
// This view cannot move: its native projections point into its own arrays.
struct SourceView {
    transit_station_unified_source value{};
    std::array<transit_station_unified_projection, 8> projections{};
    std::array<std::vector<const char *>, 8> paths;
    std::vector<const char *> expansion;
    SourceView(const SourceView &) = delete;
    explicit SourceView(const Source &source) {
        std::visit([&](const auto &v) {
            using T = std::decay_t<decltype(v)>;
            if constexpr (std::is_same_v<T, KvSource>) {
                value.kind = TRANSIT_UNIFIED_KV; value.resource = v.resource.native();
                value.source.kv = {bytes_view(v.prefix), {v.key.version, static_cast<transit_station_unified_type>(v.key.type)}, {v.value.version, static_cast<transit_station_unified_type>(v.value.type)}};
            } else if constexpr (std::is_same_v<T, TableSource>) {
                value.kind = TRANSIT_UNIFIED_TABLE; value.resource = v.resource.native();
                for (const auto &name : v.names) checked_string(name);
                value.source.table = {v.id, {v.names[0].c_str(), v.names[1].c_str()}, static_cast<transit_station_unified_type>(v.value_type)};
            } else {
                if (v.projections.size() > projections.size()) throw failure(TRANSIT_SDK_INVALID_ARGUMENT, "query-projections");
                value.kind = TRANSIT_UNIFIED_DOCUMENT; value.resource = v.reference.resource.native();
                auto &d = value.source.document; d.reference = v.reference.native();
                for (size_t i = 0; i < v.projections.size(); ++i) {
                    const auto &p = v.projections[i]; paths[i] = path(p.path);
                    projections[i] = {column(p.column), paths[i].data(), paths[i].size(), p.relative, static_cast<transit_station_unified_projection_mode>(p.mode), p.text_bytes, p.text_steps};
                }
                d.projections = projections.data(); d.projection_count = v.projections.size();
                d.has_expansion = v.expand.has_value(); if (v.expand) expansion = path(*v.expand);
                d.expand = expansion.data(); d.expand_count = expansion.size();
            }
        }, source);
    }
};
inline transit_station_unified_plan plan(const Plan &v) {
    transit_station_unified_plan out{};
    out.projection = v.projection.data(); out.projection_count = v.projection.size();
    if(v.output_names){
        if(v.output_names->size()!=v.projection.size() || v.output_names->size()>8)throw failure(TRANSIT_SDK_INVALID_ARGUMENT,"query-output-names");
        for(size_t i=0;i<v.output_names->size();++i)if((*v.output_names)[i])out.output_names[i]=(*v.output_names)[i]->c_str();
    }
    out.aggregate = static_cast<transit_station_aggregate>(v.aggregate);
    out.has_limit = v.limit.has_value(); out.limit = v.limit.value_or(0);
    std::visit([&](const auto &p) {
        using P = std::decay_t<decltype(p)>;
        if constexpr (std::is_same_v<P, IsState>) { out.predicate = TRANSIT_UNIFIED_IS_STATE; out.column = p.column; out.state = static_cast<transit_station_unified_state>(p.state); }
        else if constexpr (std::is_same_v<P, Compare>) { out.predicate = TRANSIT_UNIFIED_COMPARE; out.column = p.column; out.comparison = static_cast<transit_station_comparison>(p.comparison); out.value = scalar(p.value); }
    }, v.predicate);
    return out;
}
template<class T, auto Destroy, auto Import, auto View> class OwnedBytes {
    std::unique_ptr<T, decltype(Destroy)> value_;
public:
    explicit OwnedBytes(T *value) : value_(value, Destroy) {}
    OwnedBytes(OwnedBytes &&) noexcept = default;
    OwnedBytes &operator=(OwnedBytes &&) noexcept = default;
    static OwnedBytes recover(const Bytes &bytes) { T *out = nullptr; check(Import(bytes_view(bytes), &out)); return OwnedBytes(out); }
    Bytes data() const { transit_sdk_bytes out{}; check(View(value_.get(), &out)); return copy_bytes(out); }
    const T *native() const { return value_.get(); }
};
}
using Bundle = detail::OwnedBytes<transit_station_unified_bundle, transit_station_unified_bundle_destroy, transit_station_unified_bundle_import, transit_station_unified_bundle_bytes>;
using Prepared = detail::OwnedBytes<transit_station_unified_prepared, transit_station_unified_prepared_destroy, transit_station_unified_prepared_import, transit_station_unified_prepared_bytes>;
using Cursor = detail::OwnedBytes<transit_station_unified_cursor, transit_station_unified_cursor_destroy, transit_station_unified_cursor_import, transit_station_unified_cursor_bytes>;
inline Bundle prepare(const Source &source, const Plan &plan, Budgets budgets, const char *directory = nullptr) {
    const detail::SourceView s(source); const auto p = detail::plan(plan); transit_station_unified_bundle *out = nullptr;
    check(transit_station_unified_prepare_bundle(&s.value, &p, {budgets.pages, budgets.segments, budgets.result_bytes}, directory, &out)); return Bundle(out);
}
struct Missing {};
struct Null {};
struct TypeError { std::string actual_kind; };
using AlternativeValue = std::variant<Null, TypeError, Scalar>;
struct Alternative { uint64_t counter, replica; AlternativeValue value; };
struct Conflict { std::vector<Alternative> alternatives; };
using Cell = std::variant<Missing, Null, TypeError, Scalar, Conflict>;
using Rows = std::vector<std::vector<Cell>>;
inline Rows decode_arrow(const std::vector<Column> &columns, const Bytes &ipc, uint8_t count, const char *directory = nullptr) {
    std::vector<transit_station_unified_column> schema;
    for (const auto &c : columns) schema.push_back(detail::column(c));
    transit_station_unified_rows *value = nullptr;
    check(transit_station_unified_decode_arrow(schema.data(), schema.size(), bytes_view(ipc), count, directory, &value));
    std::unique_ptr<transit_station_unified_rows, decltype(&transit_station_unified_rows_destroy)> owner(value, transit_station_unified_rows_destroy);
    Rows rows;
    for (size_t row = 0; row < count; ++row) {
        std::vector<Cell> cells;
        for (size_t col = 0; col < columns.size(); ++col) {
            transit_station_unified_cell cell{}; check(transit_station_unified_rows_cell(value, row, col, &cell));
            switch (cell.state) {
                case TRANSIT_UNIFIED_MISSING: cells.emplace_back(Missing{}); break;
                case TRANSIT_UNIFIED_NULL: cells.emplace_back(Null{}); break;
                case TRANSIT_UNIFIED_TYPE_ERROR: cells.emplace_back(TypeError{cell.actual_kind}); break;
                case TRANSIT_UNIFIED_VALUE: cells.emplace_back(detail::scalar(cell.value)); break;
                case TRANSIT_UNIFIED_CONFLICT: {
                    Conflict conflict;
                    for (size_t i = 0; i < cell.alternative_count; ++i) {
                        transit_station_unified_alternative alt{}; check(transit_station_unified_rows_alternative(value, row, col, i, &alt));
                        Alternative a{alt.counter, alt.replica, Null{}};
                        if (alt.cell.state == TRANSIT_UNIFIED_TYPE_ERROR) a.value = TypeError{alt.cell.actual_kind};
                        if (alt.cell.state == TRANSIT_UNIFIED_VALUE) a.value = detail::scalar(alt.cell.value);
                        conflict.alternatives.push_back(std::move(a));
                    }
                    cells.emplace_back(std::move(conflict)); break;
                }
            }
        }
        rows.push_back(std::move(cells));
    }
    return rows;
}
struct Connection { ProcessRef source; ResourceRef resource; ProcessRef requester; ResourceRef requests; };
using Description = transit_station_unified_description;
enum class SourceKind { Kv, Table, Document };
enum class InspectionOperator { Scan, Filter, Limit, Project, Count, Sum };
struct InspectedState { std::string column; State state; };
struct InspectedComparison { std::string column; Comparison comparison; Type type; };
using InspectedPredicate = std::variant<All, InspectedState, InspectedComparison>;
struct SourceDescription { std::vector<Column> columns; };
struct TableListing { std::vector<std::string> names; };
struct Explanation {
    std::vector<InspectionOperator> operators; InspectedPredicate predicate;
    std::vector<std::string> projection; std::optional<uint64_t> limit;
    Aggregate aggregate; std::vector<Column> columns; Budgets budgets;
};
struct Inspection {
    std::string name; ResourceRef resource; SourceKind source_kind;
    std::array<uint8_t,32> source_digest, schema_digest;
    uint64_t resource_revision, policy_revision;
    std::variant<SourceDescription, TableListing, Explanation> details;
};
using Manifest = transit_station_unified_manifest;
enum class Phase { Uploading, Sealed, Admitted, Complete, Cancelled, Denied, Rejected, Retired };
struct Status { Phase phase; uint64_t correlation; std::array<uint8_t, 72> reference; std::optional<std::array<uint8_t, 72>> manifest; bool collected; };
enum class Observed { Pending, Committed, Rejected };
struct Observation { Observed state; std::string reason; };
enum class Control { Cancel, Retire, Collect };
struct Page {
    Manifest manifest; uint64_t ordinal; uint8_t rows;
    std::vector<Column> columns; Bytes ipc; std::optional<Cursor> next;
    Rows decode(const char *directory = nullptr) const { return decode_arrow(columns, ipc, rows, directory); }
};
class Client {
    std::unique_ptr<transit_station_unified_client, decltype(&transit_station_unified_client_destroy)> value_;
    explicit Client(transit_station_unified_client *v) : value_(v, transit_station_unified_client_destroy) {}
public:
    Client(Client &&) noexcept = default;
    Client &operator=(Client &&) noexcept = default;
    static Client open(const ClientConfig &config, const Credential &credential, const Connection &connection) {
        const auto cfg = config.native(); const auto identity = credential.native(); transit_station_unified_client *out = nullptr;
        check(transit_station_unified_open(&cfg, &identity, {connection.source.native(), connection.requester.native(), connection.resource.native(), connection.requests.native()}, &out)); return Client(out);
    }
    Description describe(const Source &source) { const detail::SourceView s(source); Description out{}; check(transit_station_unified_describe(value_.get(), &s.value, &out)); return out; }
    Inspection inspect_sql(const Source &source,const std::string &name,const std::string &sql,Budgets budgets) {
        checked_string(name); checked_string(sql); const detail::SourceView s(source); transit_station_unified_inspection out{};
        check(transit_station_unified_inspect_sql(value_.get(),&s.value,name.c_str(),sql.c_str(),{budgets.pages,budgets.segments,budgets.result_bytes},&out));
        Inspection result{out.name,ResourceRef(out.resource.realm,out.resource.resource),static_cast<SourceKind>(out.source_kind),{},{},out.resource_revision,out.policy_revision,SourceDescription{}};
        std::copy(std::begin(out.source_digest),std::end(out.source_digest),result.source_digest.begin());
        std::copy(std::begin(out.schema_digest),std::end(out.schema_digest),result.schema_digest.begin());
        auto columns=[](const transit_station_unified_source_description &v) {
            std::vector<Column> values; for(size_t i=0;i<v.column_count;++i)values.push_back({v.columns[i].name,static_cast<Type>(v.columns[i].type)}); return values;
        };
        if(out.kind==TRANSIT_UNIFIED_DESCRIPTION)result.details=SourceDescription{columns(out.details.description)};
        else if(out.kind==TRANSIT_UNIFIED_TABLES){TableListing list;for(size_t i=0;i<out.details.tables.count;++i)list.names.emplace_back(out.details.tables.names[i]);result.details=std::move(list);}
        else {
            const auto &p=out.details.explanation;Explanation plan{{},All{},{},std::nullopt,static_cast<Aggregate>(p.aggregate),columns(p.output),{p.budgets.pages,p.budgets.segments,p.budgets.result_bytes}};
            for(size_t i=0;i<p.operator_count;++i)plan.operators.push_back(static_cast<InspectionOperator>(p.operators[i]));
            for(size_t i=0;i<p.projection_count;++i)plan.projection.emplace_back(p.projection[i]);
            if(p.has_limit)plan.limit=p.limit;
            if(p.predicate==TRANSIT_UNIFIED_IS_STATE)plan.predicate=InspectedState{p.column,static_cast<State>(p.state)};
            else if(p.predicate==TRANSIT_UNIFIED_COMPARE)plan.predicate=InspectedComparison{p.column,static_cast<Comparison>(p.comparison),static_cast<Type>(p.type)};
            result.details=std::move(plan);
        }
        return result;
    }
    std::optional<Prepared> prepare_next(uint64_t ns, const Bundle &bundle) {
        transit_station_unified_prepared *out = nullptr; check(transit_station_unified_prepare_next(value_.get(), ns, bundle.native(), &out));
        if (!out) return {}; return Prepared(out);
    }
    Prepared prepare_control(Control control, uint64_t ns) {
        transit_station_unified_prepared *out = nullptr; check(transit_station_unified_prepare_control(value_.get(), static_cast<transit_station_unified_control>(control), ns, &out)); return Prepared(out);
    }
    // Persist Prepared::data() first. Error UNKNOWN_OUTCOME retains the same
    // caller-owned token; do not replace it with a newly prepared operation.
    AdmissionReceipt submit(const Prepared &command) {
        uint64_t input = 0; check(transit_station_unified_submit(value_.get(), command.native(), &input)); return {input};
    }
    Observation observe(uint64_t input) { transit_station_unified_observation out{}; check(transit_station_unified_observe(value_.get(), input, &out)); return {static_cast<Observed>(out.state), out.reason}; }
    std::optional<Status> status(uint64_t ns) {
        transit_station_unified_status out{}; check(transit_station_unified_status_read(value_.get(), ns, &out));
        if (!out.found) return {};
        Status result{static_cast<Phase>(out.phase), out.correlation, {}, {}, out.collected};
        std::copy_n(out.reference, 72, result.reference.begin());
        if (out.has_manifest) { result.manifest.emplace(); std::copy_n(out.manifest, 72, result.manifest->begin()); }
        return result;
    }
    Page page(uint64_t ns, const Cursor *cursor = nullptr) {
        transit_station_unified_page *out = nullptr; check(transit_station_unified_page_read(value_.get(), ns, cursor ? cursor->native() : nullptr, &out));
        std::unique_ptr<transit_station_unified_page, decltype(&transit_station_unified_page_destroy)> owner(out, transit_station_unified_page_destroy);
        transit_station_unified_page_info info{}; check(transit_station_unified_page_get(out, &info));
        Page result{info.manifest, info.ordinal, info.rows, {}, copy_bytes(info.ipc), {}};
        for (size_t i = 0; i < info.column_count; ++i) result.columns.push_back({info.columns[i].name, static_cast<Type>(info.columns[i].type)});
        transit_station_unified_cursor *next = nullptr; check(transit_station_unified_page_next(out, &next)); if (next) result.next.emplace(next);
        return result;
    }
    void close() { check(transit_station_unified_close(value_.get())); }
};
}
