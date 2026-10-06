#pragma once
#include <transit/client.hpp>
#include <transit/logical.hpp>
#include <transit/catalog.h>
#include <array>
#include <optional>

namespace transit::sdk::station::catalog {
enum class Kind : uint32_t { Create, Alter, Rename, Drop, Insert, Update, Delete };
enum class Phase : uint32_t { Preparing, Delegated, Building, Applied, Unchanged, Rejected, Cancelled };
enum class Observation : uint32_t { Pending, Processed };
enum class UploadPhase : uint32_t { Uploading, Sealed, Ready, Cancelled };
enum class DispositionKind : uint32_t { Initialized, PolicyApplied, DependencyApplied, InvalidCommand, Blocked, Denied, IdentityConflict, StalePolicy };
enum class Control : uint32_t { CancelOperation, CleanupOperation, CancelUpload, CollectUpload };
enum class DependencyKind : uint32_t { QuerySource, Writer, Watch, MaintainedRelation, History };
enum class CompareOp : uint32_t { Eq, Ne, Lt, Le, Gt, Ge };
enum class NextKind : uint32_t { Send, Running, Terminal, UploadCancelled };
struct Scope { ResourceRef resource; uint64_t catalog; };
struct Connection { ProcessRef owner; Scope scope; };
struct Limits { uint32_t record_bytes; uint64_t staging_bytes; uint32_t staging_records; };
struct Configuration { Scope scope; ProcessRef owner; uint64_t administrator; Limits table_limits; };
struct Rights { bool inspect = false, create = false, read = false, insert = false, update = false, remove = false, alter = false, drop = false; };
struct Policy { Scope scope; uint64_t principal, revision; Rights rights; };
struct PolicyChange { uint64_t expected_revision; Policy policy; };
struct Identity { uint64_t operation, namespace_id; };
struct Basis { uint64_t object, revision; std::array<uint8_t, 32> schema_fingerprint; };
struct Column { uint64_t id; std::string name; logical::Type type; bool nullable = true; std::optional<logical::Cell> default_value; std::optional<uint32_t> max_characters; };
struct Schema { uint64_t object, revision, next_column; std::vector<Column> columns; std::vector<uint64_t> primary_key; };
struct Assignment { uint64_t column; std::optional<logical::Cell> value; }; // absent means DEFAULT
struct All {};
struct IsState { uint64_t column; logical::State state; };
struct Compare { uint64_t column; CompareOp op; logical::Atom value; };
struct Negate {};
struct Conjunction {};
struct Disjunction {};
using PredicateTerm = std::variant<All, IsState, Compare, Negate, Conjunction, Disjunction>;
using Predicate = std::vector<PredicateTerm>;
struct AddColumn { std::string name; logical::Type type; bool nullable = true; std::optional<logical::Cell> default_value; std::optional<uint32_t> max_characters; };
struct DropColumn { uint64_t column; };
struct RenameColumn { uint64_t column; std::string name; };
struct SetDefault { uint64_t column; std::optional<logical::Cell> value; };
struct SetNullable { uint64_t column; bool value; };
struct ChangeType { uint64_t column; logical::Type type; std::optional<uint32_t> max_characters; };
using Change = std::variant<AddColumn, DropColumn, RenameColumn, SetDefault, SetNullable, ChangeType>;
struct Create { Schema schema; bool if_not_exists = false; };
struct Alter { Basis basis; Change change; };
struct Rename { Basis basis; std::string name; };
struct Drop { std::optional<Basis> basis; bool if_exists = false; };
struct Insert { Basis basis; std::vector<std::vector<Assignment>> rows; };
struct Update { Basis basis; std::vector<Assignment> assignments; std::optional<Predicate> predicate; };
struct Delete { Basis basis; std::optional<Predicate> predicate; };
using Action = std::variant<Create, Alter, Rename, Drop, Insert, Update, Delete>;
struct Dependency { Scope scope; uint64_t object, identity; ProcessRef owner; DependencyKind kind; };
struct Metadata { Scope scope; uint64_t object, revision; std::string name; std::array<uint8_t, 32> schema_fingerprint; uint64_t principal, operation, admitted_input; };
inline Basis basis(const Metadata &v) { return {v.object, v.revision, v.schema_fingerprint}; }
struct Head { uint64_t revision, rows, pending; };
struct Entry { Metadata metadata; Head head; };
struct Definition { Metadata metadata; Head head; Schema schema; };
struct HistoricalDefinition { Metadata metadata; Schema schema; };
struct Cursor { std::string definition; Scope scope; uint64_t resource_revision, after_object; };
struct Page { uint64_t resource_revision; std::vector<Entry> entries; std::optional<Cursor> next; };
struct Reference { std::string definition; std::array<uint8_t, 32> digest; };
struct Intent { Reference reference; Scope scope; ProcessRef owner; uint64_t principal; Identity identity; uint64_t object; Kind kind; };
struct Counts { uint64_t matched, changed; };
struct Outcome { Kind kind; uint64_t operation, object; std::optional<uint64_t> actual_object; Phase phase; bool terminal; std::optional<Counts> counts; uint64_t admitted_input; std::optional<uint64_t> completed_input; std::string diagnostic; };
struct Upload { UploadPhase phase; uint32_t received, total; };
struct State { std::optional<Outcome> outcome; std::optional<Upload> upload; };
struct Disposition { uint64_t input; DispositionKind outcome; std::string diagnostic; };
struct Progress { Observation observation; std::optional<Disposition> disposition; State state; };
struct Capabilities { uint8_t version; std::string definition; uint16_t max_columns, max_rows, max_sql_bytes; uint32_t max_intent_bytes, max_action_bytes; uint16_t max_prepared_bytes; uint8_t resident_intents; };
struct Description { Configuration configuration; Policy policy; uint64_t resource_revision; };
namespace detail {
inline void require(bool yes) { if (!yes) { transit_sdk_error e{}; e.kind = TRANSIT_SDK_INVALID_ARGUMENT; throw Error(e); } }
inline Bytes copy(transit_sdk_bytes v) { return v.size ? Bytes(v.data, v.data + v.size) : Bytes{}; }
inline const char *text(const std::string &v) { require(v.find('\0') == std::string::npos); return v.c_str(); }
template<size_t N> void text(const std::string &v, char (&out)[N]) { require(v.size() < N); text(v); std::copy(v.begin(), v.end(), out); out[v.size()] = 0; }
inline uint32_t characters(const std::optional<uint32_t> &v) { require(!v || *v); return v.value_or(0); }
inline const transit_logical_cell_view *cell(const std::optional<logical::Cell> &v) { return v ? &v->native() : nullptr; }
inline transit_station_catalog_scope native(const Scope &v) { return {v.resource.native(), v.catalog}; }
inline Scope from(transit_station_catalog_scope v) { return {ResourceRef(v.resource.realm, v.resource.resource), v.catalog}; }
inline transit_station_catalog_identity native(Identity v) { return {v.operation, v.namespace_id}; }
inline transit_station_catalog_basis native(const Basis &v) { transit_station_catalog_basis out{v.object, v.revision, {}}; std::copy(v.schema_fingerprint.begin(), v.schema_fingerprint.end(), out.schema_fingerprint); return out; }
inline transit_station_catalog_reference native(const Reference &v) { transit_station_catalog_reference out{}; text(v.definition, out.definition); std::copy(v.digest.begin(), v.digest.end(), out.digest); return out; }
inline transit_station_catalog_cursor native(const Cursor &v) { transit_station_catalog_cursor out{}; text(v.definition, out.definition); out.scope = native(v.scope); out.resource_revision = v.resource_revision; out.after_object = v.after_object; return out; }
inline transit_station_catalog_rights native(const Rights &v) { return {v.inspect, v.create, v.read, v.insert, v.update, v.remove, v.alter, v.drop}; }
inline transit_station_catalog_policy native(const Policy &v) { return {native(v.scope), v.principal, v.revision, native(v.rights)}; }
inline transit_station_catalog_configuration native(const Configuration &v) { return {native(v.scope), v.owner.native(), v.administrator, {v.table_limits.record_bytes, v.table_limits.staging_bytes, v.table_limits.staging_records}}; }
inline transit_station_catalog_dependency native(const Dependency &v) { return {native(v.scope), v.object, v.identity, v.owner.native(), static_cast<uint32_t>(v.kind)}; }
inline Configuration from(const transit_station_catalog_configuration &v) { return {from(v.scope), ProcessRef(v.owner.realm, v.owner.pid), v.administrator, {v.table_limits.record_bytes, v.table_limits.staging_bytes, v.table_limits.staging_records}}; }
inline Policy from(const transit_station_catalog_policy &v) { const auto &r = v.rights; return {from(v.scope), v.principal, v.revision, {r.inspect, r.create, r.read, r.insert, r.update, r.remove, r.alter, r.drop}}; }
inline Cursor from(const transit_station_catalog_cursor &v) { return {v.definition, from(v.scope), v.resource_revision, v.after_object}; }
inline Metadata from(const transit_station_catalog_metadata &v) {
    Metadata out{from(v.scope), v.object, v.revision, v.name, {}, v.principal, v.operation, v.admitted_input}; std::copy_n(v.schema_fingerprint, 32, out.schema_fingerprint.begin()); return out;
}
inline Head from(transit_station_catalog_head v) { return {v.revision, v.rows, v.pending}; }
inline Schema from(const transit_station_catalog_schema &v) {
    Schema out{v.object, v.revision, v.next_column, {}, {}};
    if (v.primary_key_count) out.primary_key.assign(v.primary_key, v.primary_key + v.primary_key_count);
    for (size_t i = 0; i < v.column_count; ++i) {
        const auto &c = v.columns[i]; Column value{c.id, c.name, logical::Type(*c.type), c.nullable, {}, {}};
        if (c.default_value) value.default_value = logical::Cell(*c.default_value); if (c.max_characters) value.max_characters = c.max_characters; out.columns.push_back(std::move(value));
    }
    return out;
}
inline Reference from(const transit_station_catalog_reference &v) { Reference out{v.definition, {}}; std::copy_n(v.digest, 32, out.digest.begin()); return out; }
inline Intent from(const transit_station_catalog_intent &v) { return {from(v.reference), from(v.scope), ProcessRef(v.owner.realm, v.owner.pid), v.principal, {v.identity.operation, v.identity.namespace_id}, v.object, static_cast<Kind>(v.kind)}; }
inline std::string from(const transit_sdk_diagnostic &v) { return std::string(v.json, v.size); }
inline Outcome from(const transit_station_catalog_outcome &v) {
    Outcome out{static_cast<Kind>(v.kind), v.operation, v.object, {}, static_cast<Phase>(v.phase), v.terminal, {}, v.admitted_input, {}, from(v.diagnostic)};
    if (v.has_actual_object) out.actual_object = v.actual_object; if (v.has_counts) out.counts = Counts{v.counts.matched, v.counts.changed}; if (v.has_completed_input) out.completed_input = v.completed_input; return out;
}
inline State from(const transit_station_catalog_state &v) {
    State out; if (v.has_outcome) out.outcome = from(v.outcome); if (v.has_upload) out.upload = Upload{static_cast<UploadPhase>(v.upload.phase), v.upload.received, v.upload.total}; return out;
}
inline std::optional<Disposition> from(const transit_station_catalog_disposition &v) { if (!v.found) return {}; return Disposition{v.input, static_cast<DispositionKind>(v.outcome), from(v.diagnostic)}; }
// Short-lived C construction views point into the caller's owned values and
// these bounded vectors. The synchronous C call validates/copies before dispatch.
class RequestView {
    transit_station_catalog_schema schema_{};
    std::vector<transit_station_catalog_column> columns_;
    std::vector<transit_station_catalog_assignments> rows_;
    std::vector<std::vector<transit_station_catalog_assignment>> assignments_;
    std::vector<transit_station_catalog_predicate_term> predicate_;
    std::optional<transit_station_catalog_basis> drop_basis_;
    transit_station_catalog_assignments assignments(const std::vector<Assignment> &values) {
        require(values.size() <= 128); assignments_.emplace_back(); auto &out = assignments_.back(); out.reserve(values.size());
        for (const auto &v : values) out.push_back({v.column, cell(v.value)}); return {out.data(), out.size()};
    }
    transit_station_catalog_predicate predicate(const std::optional<Predicate> &value) {
        if (!value) return {}; require(!value->empty() && value->size() <= 64);
        for (const auto &term : *value) {
            transit_station_catalog_predicate_term out{};
            std::visit([&](const auto &v) {
                using T = std::decay_t<decltype(v)>;
                if constexpr (std::is_same_v<T, All>) out.kind = TRANSIT_CATALOG_ALL;
                else if constexpr (std::is_same_v<T, IsState>) { out.kind = TRANSIT_CATALOG_STATE; out.column = v.column; out.as.state = v.state; }
                else if constexpr (std::is_same_v<T, Compare>) { out.kind = TRANSIT_CATALOG_COMPARE; out.column = v.column; out.as.compare = {static_cast<uint32_t>(v.op), v.value.native()}; }
                else if constexpr (std::is_same_v<T, Negate>) out.kind = TRANSIT_CATALOG_NOT;
                else if constexpr (std::is_same_v<T, Conjunction>) out.kind = TRANSIT_CATALOG_AND;
                else out.kind = TRANSIT_CATALOG_OR;
            }, term); predicate_.push_back(out);
        }
        return {predicate_.data(), predicate_.size()};
    }
    transit_station_catalog_change change(const Change &change) {
        transit_station_catalog_change out{};
        std::visit([&](const auto &v) {
            using T = std::decay_t<decltype(v)>;
            if constexpr (std::is_same_v<T, AddColumn>) { out.kind = TRANSIT_CATALOG_ADD_COLUMN; out.as.add = {text(v.name), &v.type.native(), v.nullable, cell(v.default_value), characters(v.max_characters)}; }
            else {
                out.column = v.column;
                if constexpr (std::is_same_v<T, DropColumn>) out.kind = TRANSIT_CATALOG_DROP_COLUMN;
                else if constexpr (std::is_same_v<T, RenameColumn>) { out.kind = TRANSIT_CATALOG_RENAME_COLUMN; out.as.name = text(v.name); }
                else if constexpr (std::is_same_v<T, SetDefault>) { out.kind = TRANSIT_CATALOG_DEFAULT; out.as.default_value = cell(v.value); }
                else if constexpr (std::is_same_v<T, SetNullable>) { out.kind = TRANSIT_CATALOG_NULLABLE; out.as.nullable = v.value; }
                else { out.kind = TRANSIT_CATALOG_TYPE; out.as.type = {&v.type.native(), characters(v.max_characters)}; }
            }
        }, change); return out;
    }
public:
    transit_station_catalog_request value{};
    RequestView(const std::string &name, Identity id, const Action &action) {
        value.name = text(name); value.identity = native(id);
        std::visit([&](const auto &v) {
            using T = std::decay_t<decltype(v)>; auto &out = value.action;
            if constexpr (std::is_same_v<T, Create>) {
                out.kind = TRANSIT_CATALOG_CREATE; const auto &s = v.schema; require(!s.columns.empty() && s.columns.size() <= 128 && s.primary_key.size() <= s.columns.size());
                for (const auto &c : s.columns) columns_.push_back({c.id, text(c.name), &c.type.native(), c.nullable, cell(c.default_value), characters(c.max_characters)});
                schema_ = {s.object, s.revision, s.next_column, columns_.data(), columns_.size(), s.primary_key.data(), s.primary_key.size()}; out.as.create = {&schema_, v.if_not_exists};
            } else if constexpr (std::is_same_v<T, Alter>) { out.kind = TRANSIT_CATALOG_ALTER; out.as.alter = {native(v.basis), change(v.change)}; }
            else if constexpr (std::is_same_v<T, Rename>) { out.kind = TRANSIT_CATALOG_RENAME; out.as.rename = {native(v.basis), text(v.name)}; }
            else if constexpr (std::is_same_v<T, Drop>) { out.kind = TRANSIT_CATALOG_DROP; if (v.basis) drop_basis_ = native(*v.basis); out.as.drop = {drop_basis_ ? &*drop_basis_ : nullptr, v.if_exists}; }
            else if constexpr (std::is_same_v<T, Insert>) {
                out.kind = TRANSIT_CATALOG_INSERT; require(!v.rows.empty() && v.rows.size() <= 1024); assignments_.reserve(v.rows.size()); rows_.reserve(v.rows.size());
                for (const auto &row : v.rows) rows_.push_back(assignments(row)); out.as.insert = {native(v.basis), rows_.data(), rows_.size()};
            } else if constexpr (std::is_same_v<T, Update>) { out.kind = TRANSIT_CATALOG_UPDATE; out.as.update = {native(v.basis), assignments(v.assignments), predicate(v.predicate)}; }
            else { out.kind = TRANSIT_CATALOG_DELETE; out.as.remove = {native(v.basis), predicate(v.predicate)}; }
        }, action);
    }
    RequestView(const RequestView &) = delete;
    RequestView(RequestView &&) = delete;
};
}
class SavedIntent {
    std::unique_ptr<transit_station_catalog_saved_intent, decltype(&transit_station_catalog_saved_destroy)> value_;
    explicit SavedIntent(transit_station_catalog_saved_intent *value) : value_(value, transit_station_catalog_saved_destroy) {}
public:
    SavedIntent(SavedIntent &&) noexcept = default;
    SavedIntent &operator=(SavedIntent &&) noexcept = default;
    static SavedIntent recover(const std::string &definition, const Bytes &bytes) {
        transit_station_catalog_saved_intent *out = nullptr; check(transit_station_catalog_saved_import(detail::text(definition), bytes_view(bytes), &out)); return SavedIntent(out);
    }
    static SavedIntent copy(const transit_station_catalog_saved_intent *value) {
        const char *definition = nullptr; transit_sdk_bytes bytes{}; check(transit_station_catalog_saved_get(value, &definition, &bytes));
        transit_station_catalog_saved_intent *out = nullptr; check(transit_station_catalog_saved_import(definition, bytes, &out)); return SavedIntent(out);
    }
    std::string definition() const { const char *definition = nullptr; transit_sdk_bytes bytes{}; check(transit_station_catalog_saved_get(value_.get(), &definition, &bytes)); return definition; }
    Bytes data() const { const char *definition = nullptr; transit_sdk_bytes bytes{}; check(transit_station_catalog_saved_get(value_.get(), &definition, &bytes)); return detail::copy(bytes); }
    const transit_station_catalog_saved_intent *native() const { return value_.get(); }
};
class Compiled {
    std::unique_ptr<transit_station_catalog_compiled, decltype(&transit_station_catalog_compiled_destroy)> value_;
public:
    explicit Compiled(transit_station_catalog_compiled *value) : value_(value, transit_station_catalog_compiled_destroy) {}
    Compiled(Compiled &&) noexcept = default;
    Compiled &operator=(Compiled &&) noexcept = default;
    Intent intent() const { transit_station_catalog_intent out{}; const transit_station_catalog_saved_intent *saved = nullptr; check(transit_station_catalog_compiled_get(value_.get(), &out, &saved)); return detail::from(out); }
    SavedIntent saved() const { transit_station_catalog_intent out{}; const transit_station_catalog_saved_intent *saved = nullptr; check(transit_station_catalog_compiled_get(value_.get(), &out, &saved)); return SavedIntent::copy(saved); }
};
class Prepared {
    std::unique_ptr<transit_station_catalog_prepared, decltype(&transit_station_catalog_prepared_destroy)> value_;
public:
    explicit Prepared(transit_station_catalog_prepared *value) : value_(value, transit_station_catalog_prepared_destroy) {}
    Prepared(Prepared &&) noexcept = default;
    Prepared &operator=(Prepared &&) noexcept = default;
    static Prepared recover(const Bytes &bytes) { transit_station_catalog_prepared *out = nullptr; check(transit_station_catalog_prepared_import(bytes_view(bytes), &out)); return Prepared(out); }
    static Prepared copy(const transit_station_catalog_prepared *value) {
        transit_sdk_bytes bytes{}; check(transit_station_catalog_prepared_bytes(value, &bytes)); transit_station_catalog_prepared *out = nullptr; check(transit_station_catalog_prepared_import(bytes, &out)); return Prepared(out);
    }
    Bytes data() const { transit_sdk_bytes out{}; check(transit_station_catalog_prepared_bytes(value_.get(), &out)); return detail::copy(out); }
    const transit_station_catalog_prepared *native() const { return value_.get(); }
};
struct Next { NextKind kind; std::optional<Prepared> prepared; std::optional<Outcome> outcome; };
}
