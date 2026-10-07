#pragma once
#include <transit/station.hpp>
#include <transit/catalog_values.hpp>
#include <transit/unified_query.h>

namespace transit::sdk::station::unified {
enum class DecoderType { Int64, UInt64, Float64, Boolean, Utf8, Binary };
using Type = logical::Type;
enum class ProjectionMode { Scalar, Text, ElementCounter, ElementReplica };
struct Column { std::string name; Type type; bool nullable = false, optional = false; };
struct DecoderColumn { std::string name; DecoderType type; };
struct Decoder { DecoderType type; uint8_t version = 1; };
struct KvSource { ResourceRef resource; Bytes prefix; Decoder key, value; };
struct TableSource { ProcessRef owner; catalog::Metadata metadata; catalog::Schema schema; };
struct Projection {
    DecoderColumn column; std::vector<std::string> path;
    bool relative = false; ProjectionMode mode = ProjectionMode::Scalar;
    uint16_t text_bytes = 4096, text_steps = 4096;
};
struct DocumentSource {
    DocumentReference reference; std::vector<Projection> projections;
    std::optional<std::vector<std::string>> expand;
};
using Source = std::variant<KvSource, TableSource, DocumentSource>;
struct Budgets { uint64_t pages, segments, result_bytes; };
namespace detail {
inline transit_station_unified_column column(const Column &v) {
    checked_string(v.name);return {v.name.c_str(), &v.type.native(), v.nullable, v.optional};
}
inline transit_station_unified_decoder_column column(const DecoderColumn &v) {
    checked_string(v.name);return {v.name.c_str(), static_cast<transit_station_unified_decoder_type>(v.type)};
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
    transit_station_catalog_metadata metadata{};transit_station_catalog_schema schema{};
    std::vector<transit_station_catalog_column> columns;
    SourceView(const SourceView &) = delete;
    explicit SourceView(const Source &source) {
        std::visit([&](const auto &v) {
            using T = std::decay_t<decltype(v)>;
            if constexpr (std::is_same_v<T, KvSource>) {
                value.kind = TRANSIT_UNIFIED_KV; value.resource = v.resource.native();
                value.source.kv = {bytes_view(v.prefix), {v.key.version, static_cast<transit_station_unified_decoder_type>(v.key.type)}, {v.value.version, static_cast<transit_station_unified_decoder_type>(v.value.type)}};
            } else if constexpr (std::is_same_v<T, TableSource>) {
                value.kind = TRANSIT_UNIFIED_TABLE; value.resource = v.metadata.scope.resource.native();
                const auto &m=v.metadata;metadata.scope=catalog::detail::native(m.scope);metadata.object=m.object;metadata.revision=m.revision;
                catalog::detail::text(m.name,metadata.name);std::copy(m.schema_fingerprint.begin(),m.schema_fingerprint.end(),metadata.schema_fingerprint);
                metadata.principal=m.principal;metadata.operation=m.operation;metadata.admitted_input=m.admitted_input;metadata.commitment.bytes=m.commitment.bytes;
                std::copy(m.commitment.digest.begin(),m.commitment.digest.end(),metadata.commitment.digest);
                if(v.schema.columns.size()>128)throw failure(TRANSIT_SDK_INVALID_ARGUMENT,"query-columns");
                for(const auto &c:v.schema.columns)columns.push_back({c.id,catalog::detail::text(c.name),&c.type.native(),c.nullable,catalog::detail::cell(c.default_value),catalog::detail::characters(c.max_characters)});
                schema={v.schema.object,v.schema.revision,v.schema.next_column,columns.data(),columns.size(),v.schema.primary_key.data(),v.schema.primary_key.size()};
                value.source.table={v.owner.native(),&metadata,&schema};
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
    const detail::SourceView s(source); const detail::PlanView p(plan); transit_station_unified_bundle *out = nullptr;
    check(transit_station_unified_prepare_bundle(&s.value, &p.value, {budgets.pages, budgets.segments, budgets.result_bytes}, directory, &out)); return Bundle(out);
}
using Cell = logical::Cell;
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
            transit_logical_cell_view cell{};check(transit_station_unified_rows_cell(value,row,col,&cell));cells.emplace_back(cell);
        }
        rows.push_back(std::move(cells));
    }
    return rows;
}
struct Connection { ProcessRef source; ResourceRef resource; ProcessRef requester; ResourceRef requests; };
using Description = transit_station_unified_description;
enum class SourceKind { Kv, Table, Document };
enum class InspectionOperator { Scan, Filter, Limit, Project, Count, Sum, CountValues };
struct InspectedState { std::string column; State state; };
struct InspectedComparison { std::string column; Comparison comparison; Type type; };
using InspectedAtom = std::variant<All, InspectedState, InspectedComparison>;
using InspectedInstruction = std::variant<InspectedAtom, PredicateOperator>;
struct InspectedProgram { std::vector<InspectedInstruction> instructions; };
using InspectedPredicate = std::variant<All, InspectedState, InspectedComparison, InspectedProgram>;
namespace detail {
inline InspectedAtom inspected_atom(const transit_station_unified_inspected_atom &v) {
    switch(v.kind){
        case TRANSIT_UNIFIED_ALL: return All{};
        case TRANSIT_UNIFIED_IS_STATE: return InspectedState{v.column,static_cast<State>(v.state)};
        case TRANSIT_UNIFIED_COMPARE: return InspectedComparison{v.column,static_cast<Comparison>(v.comparison),Type(*v.type)};
        default: throw failure(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"inspection-atom");
    }
}
}

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
struct Failure { std::string code, stage, dimension; uint64_t limit, observed; };
struct Status { Phase phase; uint64_t correlation; std::array<uint8_t, 72> reference; std::optional<std::array<uint8_t, 72>> manifest; bool collected; std::optional<Failure> failure; std::optional<std::string> diagnostic; };
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
        checked_string(name); checked_string(sql); const detail::SourceView s(source); transit_station_unified_inspection *raw=nullptr;
        check(transit_station_unified_inspect_sql(value_.get(),&s.value,name.c_str(),sql.c_str(),{budgets.pages,budgets.segments,budgets.result_bytes},&raw));
        std::unique_ptr<transit_station_unified_inspection,decltype(&transit_station_unified_inspection_destroy)> owner(raw,transit_station_unified_inspection_destroy);
        const transit_station_unified_inspection_info *view=nullptr;check(transit_station_unified_inspection_get(raw,&view));const auto &out=*view;
        Inspection result{out.name,ResourceRef(out.resource.realm,out.resource.resource),static_cast<SourceKind>(out.source_kind),{},{},out.resource_revision,out.policy_revision,SourceDescription{}};
        std::copy(std::begin(out.source_digest),std::end(out.source_digest),result.source_digest.begin());
        std::copy(std::begin(out.schema_digest),std::end(out.schema_digest),result.schema_digest.begin());
        auto columns=[](const transit_station_unified_source_description &v) {
            std::vector<Column> values; for(size_t i=0;i<v.column_count;++i)values.push_back({v.columns[i].name,Type(*v.columns[i].type),v.columns[i].nullable,v.columns[i].optional}); return values;
        };
        if(out.kind==TRANSIT_UNIFIED_DESCRIPTION)result.details=SourceDescription{columns(out.details.description)};
        else if(out.kind==TRANSIT_UNIFIED_TABLES){TableListing list;for(size_t i=0;i<out.details.tables.count;++i)list.names.emplace_back(out.details.tables.names[i]);result.details=std::move(list);}
        else {
            const auto &p=out.details.explanation;Explanation plan{{},All{},{},std::nullopt,static_cast<Aggregate>(p.aggregate),columns(p.output),{p.budgets.pages,p.budgets.segments,p.budgets.result_bytes}};
            for(size_t i=0;i<p.operator_count;++i)plan.operators.push_back(static_cast<InspectionOperator>(p.operators[i]));
            for(size_t i=0;i<p.projection_count;++i)plan.projection.emplace_back(p.projection[i]);
            if(p.has_limit)plan.limit=p.limit;
            if(p.predicate==TRANSIT_UNIFIED_IS_STATE)plan.predicate=InspectedState{p.column,static_cast<State>(p.state)};
            else if(p.predicate==TRANSIT_UNIFIED_COMPARE)plan.predicate=InspectedComparison{p.column,static_cast<Comparison>(p.comparison),Type(*p.type)};
            else if(p.predicate==TRANSIT_UNIFIED_PROGRAM){
                InspectedProgram program;
                for(size_t i=0;i<p.instruction_count;++i){
                    const auto &instruction=p.instructions[i];
                    if(instruction.kind==TRANSIT_UNIFIED_ATOM)program.instructions.emplace_back(detail::inspected_atom(instruction.atom));
                    else {
                        switch(instruction.kind){
                            case TRANSIT_UNIFIED_NEGATE: program.instructions.emplace_back(PredicateOperator::Negate);break;
                            case TRANSIT_UNIFIED_CONJUNCTION: program.instructions.emplace_back(PredicateOperator::Conjunction);break;
                            case TRANSIT_UNIFIED_DISJUNCTION: program.instructions.emplace_back(PredicateOperator::Disjunction);break;
                            default: throw failure(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"inspection-instruction");
                        }
                    }
                }
                plan.predicate=std::move(program);
            }
            result.details=std::move(plan);
        }
        return result;
    }
    Bundle compile_sql(const Source &source, const std::string &name, const std::string &sql, Budgets budgets,
                       const std::optional<std::vector<Scalar>> &parameters = std::nullopt) {
        checked_string(name);checked_string(sql);detail::SourceView s(source);std::vector<transit_station_unified_scalar> values;
        if(parameters){if(parameters->size()>65)throw std::invalid_argument("Expected at most 65 parameter atoms");for(const auto &value:*parameters)values.push_back(detail::scalar(value));}
        const transit_station_unified_bindings bindings{values.data(),values.size()};
        transit_station_unified_bundle *out=nullptr;
        check(transit_station_unified_compile_sql(value_.get(),&s.value,name.c_str(),sql.c_str(),{budgets.pages,budgets.segments,budgets.result_bytes},parameters?&bindings:nullptr,&out));
        return Bundle(out);
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
        Status result{static_cast<Phase>(out.phase), out.correlation, {}, {}, out.collected, {}, {}};
        std::copy_n(out.reference, 72, result.reference.begin());
        if (out.has_manifest) { result.manifest.emplace(); std::copy_n(out.manifest, 72, result.manifest->begin()); }
        if (out.has_failure) result.failure = Failure{out.failure.code, out.failure.stage, out.failure.dimension, out.failure.limit, out.failure.observed};
        if (out.diagnostic.size) result.diagnostic = std::string(out.diagnostic.json, out.diagnostic.size);
        return result;
    }
    Page page(uint64_t ns, const Cursor *cursor = nullptr) {
        transit_station_unified_page *out = nullptr; check(transit_station_unified_page_read(value_.get(), ns, cursor ? cursor->native() : nullptr, &out));
        std::unique_ptr<transit_station_unified_page, decltype(&transit_station_unified_page_destroy)> owner(out, transit_station_unified_page_destroy);
        transit_station_unified_page_info info{}; check(transit_station_unified_page_get(out, &info));
        Page result{info.manifest, info.ordinal, info.rows, {}, copy_bytes(info.ipc), {}};
        for (size_t i = 0; i < info.column_count; ++i) result.columns.push_back({info.columns[i].name, Type(*info.columns[i].type),info.columns[i].nullable,info.columns[i].optional});
        transit_station_unified_cursor *next = nullptr; check(transit_station_unified_page_next(out, &next)); if (next) result.next.emplace(next);
        return result;
    }
    void close() { check(transit_station_unified_close(value_.get())); }
};
}
