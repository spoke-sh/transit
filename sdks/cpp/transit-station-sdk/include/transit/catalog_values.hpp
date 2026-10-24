#pragma once
#include <transit/client.hpp>
#include <transit/logical.hpp>
#include <transit/catalog.h>
#include <array>
#include <optional>

namespace transit::sdk::station::catalog {
enum class Encoding : uint32_t { Plain, Bitpacked, Rle, Dictionary, Fsst, Comp, Comp3, Zoned, IbmHfp, Ebcdic };
enum class Collation : uint32_t { None, Utf8Binary, AsciiCi, EbcdicCp037, IcuRoot };
enum class Kind : uint32_t { Create, Alter, Rename, Drop, Insert, Update, Delete };
enum class CompareOp : uint32_t { Eq, Ne, Lt, Le, Gt, Ge };
enum class Ingestion : uint32_t { Point, Bulk };
enum class Dialect : uint32_t { Transit, Mysql };
enum class WorkKind : uint32_t { Table, NameAssertion };
enum class ObservationKind : uint32_t { Ddl, Rows, NameAssertion };
enum class OperationState : uint32_t { NotObserved, Admitted, Rejected, Cancelled, Committed, Unchanged };
enum class Phase : uint32_t { Admitted, Ready, Settled, Rejected, Cancelled };
enum class Reason : uint32_t { None, NameConflict, ObjectConflict, StaleDefinition, StaleData, Dependency, Constraint, DefinitionChanged, DataChanged, DuplicateKey, MissingRow, InvalidRows, WorkLimit, ConditionChanged };
struct Scope { ResourceRef resource; uint64_t catalog; };
struct Connection { Scope scope; uint64_t audience; uint64_t branch = 1; std::optional<uint64_t> role = {}; };
struct Identity { uint64_t operation; uint64_t namespace_id = 1; };
struct Limits { uint32_t record_bytes; uint64_t staging_bytes; uint32_t staging_records; };
struct Counts { uint64_t matched, changed; };
using Position = transit_station_catalog_position;
using ObjectIdentity = transit_station_catalog_object;
using Interpretation = transit_station_catalog_interpretation;
using Content = transit_station_catalog_content;
using StoredDefinition = transit_station_catalog_stored;
using ReadAuthority = transit_station_catalog_read_authority;
using Capabilities = transit_station_catalog_capabilities;
using Description = transit_station_catalog_description;
using Namespace = transit_station_catalog_namespace;
using Entry = transit_station_catalog_entry;
using Commit = transit_station_catalog_commit;
struct Column { uint64_t id; std::string name; logical::Type type; bool nullable = true; std::optional<logical::Cell> default_value; std::optional<uint32_t> max_characters; Encoding encoding = Encoding::Plain; Collation collation = Collation::None; };
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
struct AddColumn { std::string name; logical::Type type; bool nullable = true; std::optional<logical::Cell> default_value; std::optional<uint32_t> max_characters; Encoding encoding = Encoding::Plain; Collation collation = Collation::None; };
struct DropColumn { uint64_t column; };
struct RenameColumn { uint64_t column; std::string name; };
struct SetDefault { uint64_t column; std::optional<logical::Cell> value; };
struct SetNullable { uint64_t column; bool value; };
struct ChangeType { uint64_t column; logical::Type type; std::optional<uint32_t> max_characters; };
struct SetPhysical { uint64_t column; Encoding encoding; Collation collation; };
using Change = std::variant<AddColumn, DropColumn, RenameColumn, SetDefault, SetNullable, ChangeType, SetPhysical>;

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
inline Schema from(const transit_station_catalog_schema &v) {
    Schema out{v.object, v.revision, v.next_column, {}, {}};
    if (v.primary_key_count) out.primary_key.assign(v.primary_key, v.primary_key + v.primary_key_count);
    for (size_t i = 0; i < v.column_count; ++i) {
        const auto &c = v.columns[i]; Column value{c.id, c.name, logical::Type(*c.type), c.nullable, {}, {}, static_cast<Encoding>(c.encoding), static_cast<Collation>(c.collation)};
        if (c.default_value) value.default_value = logical::Cell(*c.default_value); if (c.max_characters) value.max_characters = c.max_characters; out.columns.push_back(std::move(value));
    }
    return out;
}

inline transit_station_catalog_connection native(const Connection &v) { return {native(v.scope), v.audience, v.branch, v.role.has_value(), v.role.value_or(0)}; }
inline Connection from(transit_station_catalog_connection v) { return {from(v.scope), v.audience, v.branch, v.has_role ? std::optional<uint64_t>(v.role) : std::nullopt}; }
template<class T, void (*Destroy)(T *)> class Owned {
    std::unique_ptr<T, decltype(Destroy)> value_;
public:
    explicit Owned(T *value) noexcept : value_(value, Destroy) {}
    Owned(Owned &&) noexcept = default;
    Owned &operator=(Owned &&) noexcept = default;
    Owned(const Owned &) = delete;
    Owned &operator=(const Owned &) = delete;
    const T *native() const noexcept { return value_.get(); }
};
}
class Basis : public detail::Owned<transit_station_catalog_basis, transit_station_catalog_basis_destroy> {
    using Base = detail::Owned<transit_station_catalog_basis, transit_station_catalog_basis_destroy>;
public:
    using Base::Base;
    static Basis restore(const Bytes &bytes) { transit_station_catalog_basis *out = nullptr; check(transit_station_catalog_basis_restore(bytes_view(bytes), &out)); return Basis(out); }
    static Basis copy(const transit_station_catalog_basis *v) { transit_sdk_bytes bytes{}; check(transit_station_catalog_basis_export(v, &bytes)); transit_station_catalog_basis *out = nullptr; check(transit_station_catalog_basis_restore(bytes, &out)); return Basis(out); }
    Bytes save() const { transit_sdk_bytes out{}; check(transit_station_catalog_basis_export(native(), &out)); return detail::copy(out); }
    const transit_station_catalog_basis_view &view() const { const transit_station_catalog_basis_view *out = nullptr; check(transit_station_catalog_basis_get(native(), &out)); return *out; }
    Connection connection() const { return detail::from(view().connection); }
    uint64_t principal() const { return view().principal; }
    uint64_t namespace_id() const { return view().namespace_id; }
    std::string name() const { return view().name; }
    StoredDefinition interpretation() const { return view().interpretation; }
};
class SavedIntent : public detail::Owned<transit_station_catalog_saved_intent, transit_station_catalog_saved_intent_destroy> {
    using Base = detail::Owned<transit_station_catalog_saved_intent, transit_station_catalog_saved_intent_destroy>;
public:
    using Base::Base;
    static SavedIntent restore(const Bytes &bytes) { transit_station_catalog_saved_intent *out = nullptr; check(transit_station_catalog_saved_intent_restore(bytes_view(bytes), &out)); return SavedIntent(out); }
    static SavedIntent copy(const transit_station_catalog_saved_intent *v) { transit_sdk_bytes bytes{}; check(transit_station_catalog_saved_intent_export(v, &bytes)); transit_station_catalog_saved_intent *out = nullptr; check(transit_station_catalog_saved_intent_restore(bytes, &out)); return SavedIntent(out); }
    Bytes save() const { transit_sdk_bytes out{}; check(transit_station_catalog_saved_intent_export(native(), &out)); return detail::copy(out); }
};
class Reference : public detail::Owned<transit_station_catalog_reference, transit_station_catalog_reference_destroy> {
    using Base = detail::Owned<transit_station_catalog_reference, transit_station_catalog_reference_destroy>;
public:
    using Base::Base;
    static Reference restore(const Bytes &bytes) { transit_station_catalog_reference *out = nullptr; check(transit_station_catalog_reference_restore(bytes_view(bytes), &out)); return Reference(out); }
    static Reference copy(const transit_station_catalog_reference *v) { transit_sdk_bytes bytes{}; check(transit_station_catalog_reference_export(v, &bytes)); transit_station_catalog_reference *out = nullptr; check(transit_station_catalog_reference_restore(bytes, &out)); return Reference(out); }
    Bytes save() const { transit_sdk_bytes out{}; check(transit_station_catalog_reference_export(native(), &out)); return detail::copy(out); }
    const transit_station_catalog_reference_view &view() const { const transit_station_catalog_reference_view *out = nullptr; check(transit_station_catalog_reference_get(native(), &out)); return *out; }
    WorkKind kind() const { return static_cast<WorkKind>(view().kind); }
    Identity identity() const { return {view().identity.operation, view().identity.namespace_id}; }
};
class Cursor : public detail::Owned<transit_station_catalog_cursor, transit_station_catalog_cursor_destroy> {
    using Base = detail::Owned<transit_station_catalog_cursor, transit_station_catalog_cursor_destroy>;
public:
    using Base::Base;
    static Cursor restore(const Bytes &bytes) { transit_station_catalog_cursor *out = nullptr; check(transit_station_catalog_cursor_restore(bytes_view(bytes), &out)); return Cursor(out); }
    static Cursor copy(const transit_station_catalog_cursor *v) { transit_sdk_bytes bytes{}; check(transit_station_catalog_cursor_export(v, &bytes)); transit_station_catalog_cursor *out = nullptr; check(transit_station_catalog_cursor_restore(bytes, &out)); return Cursor(out); }
    Bytes save() const { transit_sdk_bytes out{}; check(transit_station_catalog_cursor_export(native(), &out)); return detail::copy(out); }
    const transit_station_catalog_cursor_view &view() const { const transit_station_catalog_cursor_view *out = nullptr; check(transit_station_catalog_cursor_get(native(), &out)); return *out; }
    Position position() const { return view().position; }
    uint64_t after() const { return view().after; }
};
class SnapshotOwner : public detail::Owned<transit_station_catalog_snapshot_owner, transit_station_catalog_snapshot_owner_destroy> {
    using Base = detail::Owned<transit_station_catalog_snapshot_owner, transit_station_catalog_snapshot_owner_destroy>;
public:
    using Base::Base;
    static SnapshotOwner restore(const Bytes &bytes) { transit_station_catalog_snapshot_owner *out = nullptr; check(transit_station_catalog_snapshot_owner_restore(bytes_view(bytes), &out)); return SnapshotOwner(out); }
    static SnapshotOwner copy(const transit_station_catalog_snapshot_owner *v) { transit_sdk_bytes bytes{}; check(transit_station_catalog_snapshot_owner_export(v, &bytes)); transit_station_catalog_snapshot_owner *out = nullptr; check(transit_station_catalog_snapshot_owner_restore(bytes, &out)); return SnapshotOwner(out); }
    Bytes save() const { transit_sdk_bytes out{}; check(transit_station_catalog_snapshot_owner_export(native(), &out)); return detail::copy(out); }
    const transit_station_catalog_snapshot_owner_view &view() const { const transit_station_catalog_snapshot_owner_view *out = nullptr; check(transit_station_catalog_snapshot_owner_get(native(), &out)); return *out; }
    ObjectIdentity object() const { return view().object; }
    uint64_t operation() const { return view().operation; }
};
class SnapshotAcquisition : public detail::Owned<transit_station_catalog_snapshot_acquisition, transit_station_catalog_snapshot_acquisition_destroy> {
    using Base = detail::Owned<transit_station_catalog_snapshot_acquisition, transit_station_catalog_snapshot_acquisition_destroy>;
public:
    using Base::Base;
    static SnapshotAcquisition restore(const Bytes &bytes) { transit_station_catalog_snapshot_acquisition *out = nullptr; check(transit_station_catalog_snapshot_acquisition_restore(bytes_view(bytes), &out)); return SnapshotAcquisition(out); }
    static SnapshotAcquisition copy(const transit_station_catalog_snapshot_acquisition *v) { transit_sdk_bytes bytes{}; check(transit_station_catalog_snapshot_acquisition_export(v, &bytes)); transit_station_catalog_snapshot_acquisition *out = nullptr; check(transit_station_catalog_snapshot_acquisition_restore(bytes, &out)); return SnapshotAcquisition(out); }
    Bytes save() const { transit_sdk_bytes out{}; check(transit_station_catalog_snapshot_acquisition_export(native(), &out)); return detail::copy(out); }
    const transit_station_catalog_snapshot_acquisition_view &view() const { const transit_station_catalog_snapshot_acquisition_view *out = nullptr; check(transit_station_catalog_snapshot_acquisition_get(native(), &out)); return *out; }
    SnapshotOwner owner() const { return SnapshotOwner::copy(view().owner); }
    Position expected() const { return view().expected; }
};
class Snapshot : public detail::Owned<transit_station_catalog_snapshot, transit_station_catalog_snapshot_destroy> {
    using Base = detail::Owned<transit_station_catalog_snapshot, transit_station_catalog_snapshot_destroy>;
public:
    using Base::Base;
    static Snapshot restore(const Bytes &bytes) { transit_station_catalog_snapshot *out = nullptr; check(transit_station_catalog_snapshot_restore(bytes_view(bytes), &out)); return Snapshot(out); }
    static Snapshot copy(const transit_station_catalog_snapshot *v) { transit_sdk_bytes bytes{}; check(transit_station_catalog_snapshot_export(v, &bytes)); transit_station_catalog_snapshot *out = nullptr; check(transit_station_catalog_snapshot_restore(bytes, &out)); return Snapshot(out); }
    Bytes save() const { transit_sdk_bytes out{}; check(transit_station_catalog_snapshot_export(native(), &out)); return detail::copy(out); }
    const transit_station_catalog_snapshot_view &view() const { const transit_station_catalog_snapshot_view *out = nullptr; check(transit_station_catalog_snapshot_get(native(), &out)); return *out; }
    SnapshotOwner owner() const { return SnapshotOwner::copy(view().owner); }
    Content content() const { return view().content; }
};
class Intent {
    std::shared_ptr<const transit_station_catalog_intent> value_;
    explicit Intent(std::shared_ptr<const transit_station_catalog_intent> value) noexcept : value_(std::move(value)) {}
    friend class Compiled;
public:
    explicit Intent(transit_station_catalog_intent *value) : value_(value, transit_station_catalog_intent_destroy) {}
    const transit_station_catalog_intent *native() const noexcept { return value_.get(); }
    const transit_station_catalog_intent_view &view() const { const transit_station_catalog_intent_view *out = nullptr; check(transit_station_catalog_intent_get(native(), &out)); return *out; }
    WorkKind kind() const { return static_cast<WorkKind>(view().kind); }
    Identity identity() const { return {view().identity.operation, view().identity.namespace_id}; }
    SavedIntent saved() const { return SavedIntent::copy(view().saved); }
};
class Compiled {
    std::shared_ptr<const transit_station_catalog_compiled> value_;
public:
    explicit Compiled(transit_station_catalog_compiled *value) : value_(value, transit_station_catalog_compiled_destroy) {}
    Compiled(Compiled &&) noexcept = default;
    Compiled &operator=(Compiled &&) noexcept = default;
    Compiled(const Compiled &) = delete;
    Compiled &operator=(const Compiled &) = delete;
    Intent intent() const { const transit_station_catalog_intent *i = nullptr; const transit_station_catalog_saved_intent *s = nullptr; check(transit_station_catalog_compiled_get(value_.get(), &i, &s)); return Intent(std::shared_ptr<const transit_station_catalog_intent>(value_, i)); }
    SavedIntent saved() const { return intent().saved(); }
};
class Metadata : public detail::Owned<transit_station_catalog_metadata, transit_station_catalog_metadata_destroy> {
    using Base = detail::Owned<transit_station_catalog_metadata, transit_station_catalog_metadata_destroy>;
public:
    using Base::Base;
    const transit_station_catalog_metadata_view &view() const { const transit_station_catalog_metadata_view *out = nullptr; check(transit_station_catalog_metadata_get(native(), &out)); return *out; }
    Basis basis() const { return Basis::copy(view().basis); }
    Schema schema() const { return detail::from(view().schema); }
    Position position() const { return view().position; }
    uint64_t row_count() const { return view().row_count; }
};
class NamespacePage : public detail::Owned<transit_station_catalog_namespace_page, transit_station_catalog_namespace_page_destroy> {
    using Base = detail::Owned<transit_station_catalog_namespace_page, transit_station_catalog_namespace_page_destroy>;
public:
    using Base::Base;
    const transit_station_catalog_namespace_page_view &view() const { const transit_station_catalog_namespace_page_view *out = nullptr; check(transit_station_catalog_namespace_page_get(native(), &out)); return *out; }
    std::vector<Namespace> entries() const { const auto &v = view(); return {v.entries, v.entries + v.count}; }
    Position position() const { return view().position; }
    std::optional<Cursor> next() const { return view().next ? std::optional<Cursor>(Cursor::copy(view().next)) : std::nullopt; }
};
class TablePage : public detail::Owned<transit_station_catalog_table_page, transit_station_catalog_table_page_destroy> {
    using Base = detail::Owned<transit_station_catalog_table_page, transit_station_catalog_table_page_destroy>;
public:
    using Base::Base;
    const transit_station_catalog_table_page_view &view() const { const transit_station_catalog_table_page_view *out = nullptr; check(transit_station_catalog_table_page_get(native(), &out)); return *out; }
    std::vector<Entry> entries() const { const auto &v = view(); return {v.entries, v.entries + v.count}; }
    Position position() const { return view().position; }
    std::optional<Cursor> next() const { return view().next ? std::optional<Cursor>(Cursor::copy(view().next)) : std::nullopt; }
};
class Observation : public detail::Owned<transit_station_catalog_observation, transit_station_catalog_observation_destroy> {
    using Base = detail::Owned<transit_station_catalog_observation, transit_station_catalog_observation_destroy>;
public:
    using Base::Base;
    const transit_station_catalog_observation_view &view() const { const transit_station_catalog_observation_view *out = nullptr; check(transit_station_catalog_observation_get(native(), &out)); return *out; }
    ObservationKind kind() const { return static_cast<ObservationKind>(view().kind); }
    OperationState state() const { return static_cast<OperationState>(view().state); }
    Reference reference() const { return Reference::copy(view().reference); }
    std::optional<Commit> commit() const { return view().has_commit ? std::optional<Commit>(view().commit) : std::nullopt; }
    std::optional<Reason> reason() const { return view().has_reason ? std::optional<Reason>(static_cast<Reason>(view().reason)) : std::nullopt; }
};
class Preview : public detail::Owned<transit_station_catalog_preview, transit_station_catalog_preview_destroy> {
    using Base = detail::Owned<transit_station_catalog_preview, transit_station_catalog_preview_destroy>;
public:
    using Base::Base;
    const transit_station_catalog_preview_view &view() const { const transit_station_catalog_preview_view *out = nullptr; check(transit_station_catalog_preview_get(native(), &out)); return *out; }
    ObservationKind kind() const { return static_cast<ObservationKind>(view().kind); }
    std::optional<Reason> reason() const { return view().has_reason ? std::optional<Reason>(static_cast<Reason>(view().reason)) : std::nullopt; }
};
class SnapshotStatus : public detail::Owned<transit_station_catalog_snapshot_status, transit_station_catalog_snapshot_status_destroy> {
    using Base = detail::Owned<transit_station_catalog_snapshot_status, transit_station_catalog_snapshot_status_destroy>;
public:
    using Base::Base;
    const transit_station_catalog_snapshot_status_view &view() const { const transit_station_catalog_snapshot_status_view *out = nullptr; check(transit_station_catalog_snapshot_status_get(native(), &out)); return *out; }
    SnapshotOwner owner() const { return SnapshotOwner::copy(view().owner); }
    std::optional<Snapshot> snapshot() const { return view().snapshot ? std::optional<Snapshot>(Snapshot::copy(view().snapshot)) : std::nullopt; }
    bool released() const { return view().released; }
};
class SnapshotMetadata : public detail::Owned<transit_station_catalog_snapshot_metadata, transit_station_catalog_snapshot_metadata_destroy> {
    using Base = detail::Owned<transit_station_catalog_snapshot_metadata, transit_station_catalog_snapshot_metadata_destroy>;
public:
    using Base::Base;
    const transit_station_catalog_snapshot_metadata_view &view() const { const transit_station_catalog_snapshot_metadata_view *out = nullptr; check(transit_station_catalog_snapshot_metadata_get(native(), &out)); return *out; }
    Snapshot snapshot() const { return Snapshot::copy(view().snapshot); }
    Schema schema() const { return detail::from(view().schema); }
    StoredDefinition interpretation() const { return view().interpretation; }
    Position accepted() const { return view().accepted; }
    uint64_t row_count() const { return view().row_count; }
};
struct Create { Schema schema; bool if_not_exists = false; };
struct Alter { Basis basis; Change change; };
struct Rename { Basis basis; std::string name; };
struct Drop { std::optional<Basis> basis; bool if_exists = false; };
struct Insert { Basis basis; std::vector<std::vector<Assignment>> rows; Ingestion ingestion = Ingestion::Point; };
struct Update { Basis basis; std::vector<Assignment> assignments; std::optional<Predicate> predicate; Ingestion ingestion = Ingestion::Point; };
struct Delete { Basis basis; std::optional<Predicate> predicate; Ingestion ingestion = Ingestion::Point; };
using Action = std::variant<Create, Alter, Rename, Drop, Insert, Update, Delete>;
namespace detail {
class RequestView {
    transit_station_catalog_schema schema_{};
    std::vector<transit_station_catalog_column> columns_;
    std::vector<transit_station_catalog_assignments> rows_;
    std::vector<std::vector<transit_station_catalog_assignment>> assignments_;
    std::vector<transit_station_catalog_predicate_term> predicate_;
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
            if constexpr (std::is_same_v<T, AddColumn>) { out.kind = TRANSIT_CATALOG_ADD_COLUMN; out.as.add = {text(v.name), &v.type.native(), v.nullable, cell(v.default_value), characters(v.max_characters), static_cast<uint32_t>(v.encoding), static_cast<uint32_t>(v.collation)}; }
            else {
                out.column = v.column;
                if constexpr (std::is_same_v<T, DropColumn>) out.kind = TRANSIT_CATALOG_DROP_COLUMN;
                else if constexpr (std::is_same_v<T, RenameColumn>) { out.kind = TRANSIT_CATALOG_RENAME_COLUMN; out.as.name = text(v.name); }
                else if constexpr (std::is_same_v<T, SetDefault>) { out.kind = TRANSIT_CATALOG_DEFAULT; out.as.default_value = cell(v.value); }
                else if constexpr (std::is_same_v<T, SetNullable>) { out.kind = TRANSIT_CATALOG_NULLABLE; out.as.nullable = v.value; }
                else if constexpr (std::is_same_v<T, SetPhysical>) { out.kind = TRANSIT_CATALOG_PHYSICAL; out.as.physical = {static_cast<uint32_t>(v.encoding), static_cast<uint32_t>(v.collation)}; }
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
                for (const auto &c : s.columns) columns_.push_back({c.id, text(c.name), &c.type.native(), c.nullable, cell(c.default_value), characters(c.max_characters), static_cast<uint32_t>(c.encoding), static_cast<uint32_t>(c.collation)});
                schema_ = {s.object, s.revision, s.next_column, columns_.data(), columns_.size(), s.primary_key.data(), s.primary_key.size()}; out.as.create = {&schema_, v.if_not_exists};
            } else if constexpr (std::is_same_v<T, Alter>) { out.kind = TRANSIT_CATALOG_ALTER; out.as.alter = {v.basis.native(), change(v.change)}; }
            else if constexpr (std::is_same_v<T, Rename>) { out.kind = TRANSIT_CATALOG_RENAME; out.as.rename = {v.basis.native(), text(v.name)}; }
            else if constexpr (std::is_same_v<T, Drop>) { out.kind = TRANSIT_CATALOG_DROP; out.as.drop = {v.basis ? v.basis->native() : nullptr, v.if_exists}; }
            else if constexpr (std::is_same_v<T, Insert>) {
                out.kind = TRANSIT_CATALOG_INSERT; out.ingestion = static_cast<uint32_t>(v.ingestion); require(!v.rows.empty() && v.rows.size() <= 1024); assignments_.reserve(v.rows.size()); rows_.reserve(v.rows.size());
                for (const auto &row : v.rows) rows_.push_back(assignments(row)); out.as.insert = {v.basis.native(), rows_.data(), rows_.size()};
            } else if constexpr (std::is_same_v<T, Update>) { out.kind = TRANSIT_CATALOG_UPDATE; out.ingestion = static_cast<uint32_t>(v.ingestion); out.as.update = {v.basis.native(), assignments(v.assignments), predicate(v.predicate)}; }
            else { out.kind = TRANSIT_CATALOG_DELETE; out.ingestion = static_cast<uint32_t>(v.ingestion); out.as.remove = {v.basis.native(), predicate(v.predicate)}; }
        }, action);
    }
    RequestView(const RequestView &) = delete;
    RequestView(RequestView &&) = delete;
};
}
}
