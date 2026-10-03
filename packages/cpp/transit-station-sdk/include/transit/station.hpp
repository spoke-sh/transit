#pragma once
#include <array>
#include <transit/client.hpp>
#include <transit/station.h>
#include <algorithm>
#include <cstddef>
#include <cstring>
#include <optional>
#include <type_traits>

namespace transit::sdk::station {
using ReadVersion = transit_station_read_version;
using Basis = transit_station_basis;
using Budgets = transit_station_budgets;
using TurnInfo = transit_station_turn_info;
using Origin = transit_station_origin;
using Manifest = transit_station_manifest;
using QueryJob = transit_station_query_job;
using InputKind = transit_station_input_kind;
inline transit_sdk_error error_value(transit_sdk_error_kind kind, const char *phase) noexcept {
    transit_sdk_error value{}; value.kind = kind; std::strncpy(value.phase, phase, sizeof(value.phase) - 1); return value;
}
inline Error failure(transit_sdk_error_kind kind, const char *phase) { return Error(error_value(kind, phase)); }
template<class F> transit_sdk_error callback(F &&work) noexcept {
    try { work(); return {}; }
    catch (const Error &error) { return error.detail(); }
    catch (const std::bad_alloc &) { return error_value(TRANSIT_SDK_OUT_OF_MEMORY, "allocation"); }
    catch (...) { return error_value(TRANSIT_SDK_HANDLER_ERROR, "callback-exception"); }
}
inline Bytes copy_bytes(transit_sdk_bytes bytes) { return bytes.size ? Bytes(bytes.data, bytes.data + bytes.size) : Bytes{}; }
template<class T> class Codec {
public:
    virtual ~Codec() = default;
    virtual const char *type_id() const noexcept = 0;
    virtual uint32_t version() const noexcept = 0;
    virtual size_t max_encoded_bytes() const noexcept = 0;
    virtual Bytes encode(const T &value) const = 0;
    virtual T decode(const Bytes &value) const = 0;
    transit_station_codec native() const {
        static_assert(alignof(T) <= alignof(std::max_align_t));
        static_assert(std::is_nothrow_destructible_v<T>);
        return {type_id(), version(), max_encoded_bytes(), sizeof(T), const_cast<Codec *>(this),
            [](void *context, const void *value, uint8_t *out, size_t capacity, size_t *written) {
                return callback([&] { const auto bytes = static_cast<Codec *>(context)->encode(*static_cast<const T *>(value));
                    if (bytes.size() > capacity) throw failure(TRANSIT_SDK_CODEC_ERROR, "encode-bound");
                    std::copy(bytes.begin(), bytes.end(), out); *written = bytes.size(); });
            },
            [](void *context, transit_sdk_bytes bytes, void *out) {
                return callback([&] { new(out) T(static_cast<Codec *>(context)->decode(copy_bytes(bytes))); });
            },
            [](void *, void *value) { static_cast<T *>(value)->~T(); }};
    }
};
template<class T> class Key {
    Bytes name_;
    std::shared_ptr<const Codec<T>> codec_;
public:
    Key(std::string name, std::shared_ptr<const Codec<T>> codec) : name_(name.begin(), name.end()), codec_(std::move(codec)) {
        if (!codec_ || name_.empty() || name_.front() == 0) throw failure(TRANSIT_SDK_INVALID_ARGUMENT, "key");
    }
    transit_station_key native() const { return {bytes_view(name_), codec_->native()}; }
};
class Cursor {
    std::unique_ptr<transit_station_cursor, decltype(&transit_station_cursor_destroy)> value_;
public:
    explicit Cursor(transit_station_cursor *value) : value_(value, transit_station_cursor_destroy) {}
    Cursor(Cursor &&) noexcept = default;
    Cursor &operator=(Cursor &&) noexcept = default;
    static Cursor recover(const Bytes &bytes) { transit_station_cursor *value = nullptr; check(transit_station_cursor_import(bytes_view(bytes), &value)); return Cursor(value); }
    Bytes export_bytes() const { transit_sdk_buffer value{}; check(transit_station_cursor_export(value_.get(), &value)); return Buffer(value).copy(); }
    const transit_station_cursor *native() const { return value_.get(); }
};
template<class T> struct Page { std::vector<T> entries; std::optional<Cursor> next; std::optional<Basis> basis; };
struct KvEntry { Bytes key, value; uint64_t revision; };
template<class T> struct Row { int64_t key; std::optional<T> value; };
using Cell = std::variant<std::monostate, int64_t, bool, std::string, Bytes>;
inline transit_station_cell native_cell(const Cell &value) {
    transit_station_cell cell{};
    std::visit([&](const auto &value) {
        using T = std::decay_t<decltype(value)>;
        if constexpr (std::is_same_v<T, int64_t>) { cell.kind = TRANSIT_CELL_INT64; cell.integer = value; }
        else if constexpr (std::is_same_v<T, bool>) { cell.kind = TRANSIT_CELL_BOOLEAN; cell.boolean = value; }
        else if constexpr (std::is_same_v<T, std::string>) { cell.kind = TRANSIT_CELL_UTF8; cell.bytes = {reinterpret_cast<const uint8_t *>(value.data()), value.size()}; }
        else if constexpr (std::is_same_v<T, Bytes>) { cell.kind = TRANSIT_CELL_BINARY; cell.bytes = bytes_view(value); }
    }, value);
    return cell;
}
template<class T> constexpr transit_station_cell_kind cell_type() {
    static_assert(std::is_same_v<T, int64_t> || std::is_same_v<T, bool> || std::is_same_v<T, std::string> || std::is_same_v<T, Bytes>, "Supported Table cells: int64_t, bool, string and Bytes");
    if constexpr (std::is_same_v<T, int64_t>) return TRANSIT_CELL_INT64;
    else if constexpr (std::is_same_v<T, bool>) return TRANSIT_CELL_BOOLEAN;
    else if constexpr (std::is_same_v<T, std::string>) return TRANSIT_CELL_UTF8;
    else return TRANSIT_CELL_BINARY;
}
template<class T> class TableSchema {
    uint32_t id_;
    std::string key_, value_;
public:
    explicit TableSchema(uint32_t id, std::string key = "id", std::string value = "value")
        : id_(id), key_(checked_string(std::move(key))), value_(checked_string(std::move(value))) {
        if (!id_) throw failure(TRANSIT_SDK_INVALID_ARGUMENT, "table-id");
    }
    uint32_t id() const { return id_; }
    transit_station_table_schema native() const { return {id_, cell_type<T>(), key_.c_str(), value_.c_str()}; }
};
enum class Projection { Both = TRANSIT_PROJECT_BOTH, Key = TRANSIT_PROJECT_KEY, Value = TRANSIT_PROJECT_VALUE };
enum class Aggregate { Rows = TRANSIT_AGGREGATE_ROWS, Count = TRANSIT_AGGREGATE_COUNT, Sum = TRANSIT_AGGREGATE_SUM, CountValues = TRANSIT_AGGREGATE_COUNT_VALUES };
enum class Column { Key = TRANSIT_COLUMN_KEY, Value = TRANSIT_COLUMN_VALUE };
enum class Comparison { Eq, Ne, Lt, Le, Gt, Ge };
struct All {};
struct IsNull { Column column; };
struct Compare { Column column; Comparison comparison; Cell value; };
struct QueryPlan {
    Projection projection = Projection::Both;
    Aggregate aggregate = Aggregate::Rows;
    std::optional<uint64_t> limit;
    std::variant<All, IsNull, Compare> predicate;
    transit_station_query_plan native() const {
        transit_station_query_plan value{}; value.projection = static_cast<transit_station_projection>(projection); value.aggregate = static_cast<transit_station_aggregate>(aggregate);
        value.has_limit = limit.has_value(); value.limit = limit.value_or(0);
        std::visit([&](const auto &predicate) { using P = std::decay_t<decltype(predicate)>;
            if constexpr (!std::is_same_v<P, All>) value.column = static_cast<transit_station_column>(predicate.column);
            if constexpr (std::is_same_v<P, IsNull>) value.predicate = TRANSIT_PREDICATE_NULL;
            if constexpr (std::is_same_v<P, Compare>) { value.predicate = TRANSIT_PREDICATE_COMPARE; value.comparison = static_cast<transit_station_comparison>(predicate.comparison); value.value = native_cell(predicate.value); }
        }, predicate); return value;
    }
};
struct WaitPolicy {
    transit_station_wait value{};
    static WaitPolicy untimed() { return {}; }
    static WaitPolicy until(uint64_t deadline_ms, uint64_t observer) { return {{true, deadline_ms, observer}}; }
};
class State;
class Source;
class ResultReader;
class DocumentOwner;
class PreparedHttpRequest;
class PreparedGrpcRequest;
class GrpcOutcome;
class HttpOutcome;
enum class HttpFollowupReason { Retry = TRANSIT_HTTP_RETRY, Redirect = TRANSIT_HTTP_REDIRECT, Reconcile = TRANSIT_HTTP_RECONCILE, Cancel = TRANSIT_HTTP_CANCEL };
template<class T> class Table;
class Turn {
    std::shared_ptr<transit_station_turn> value_;
    static transit_station_turn *retain(transit_station_turn *value) { transit_station_turn_retain(value); return value; }
public:
    explicit Turn(transit_station_turn *value) : value_(retain(value), transit_station_turn_release) {}
    transit_station_turn *native() const { return value_.get(); }
    TurnInfo info() const { TurnInfo out{}; check(transit_station_turn_inspect(native(), &out)); return out; }
    Budgets budgets() const { Budgets out{}; check(transit_station_turn_budgets(native(), &out)); return out; }
    State state() const;
    DocumentOwner document(uint64_t identity) const;
    template<class T> Table<T> table(const TableSchema<T> &schema) const;
    template<class T> Table<T> create_table(const TableSchema<T> &schema) const;
    Source source(ReadVersion version) const;
    ReadVersion retain() const { ReadVersion out{}; check(transit_station_turn_retain_source(native(), &out)); return out; }
    void release(ReadVersion version) const { check(transit_station_turn_release_source(native(), version)); }
    template<class T> void cast(ProcessRef peer, const T &value, const Codec<T> &codec) const {
        info(); const auto encoding = codec.native(); check(transit_station_turn_cast(native(), peer.native(), &value, &encoding));
    }
    template<class T> uint64_t call(ProcessRef peer, const T &value, const Codec<T> &codec, WaitPolicy wait = WaitPolicy::untimed()) const {
        info(); const auto encoding = codec.native(); uint64_t correlation = 0;
        check(transit_station_turn_call(native(), peer.native(), &value, &encoding, wait.value, &correlation)); return correlation;
    }
    template<class T> void reply(const T &value, const Codec<T> &codec) const {
        info(); const auto encoding = codec.native(); check(transit_station_turn_reply(native(), &value, &encoding));
    }
    void require_reply(ProcessRef source, uint64_t correlation) const { check(transit_station_turn_require_reply(native(), source.native(), correlation)); }
    bool cancel_call(uint64_t correlation) const { bool cancelled = false; check(transit_station_turn_cancel(native(), correlation, &cancelled)); return cancelled; }
    template<class T> void allow_query(ProcessRef peer, const TableSchema<T> &schema, uint64_t expected_revision, bool allow) const {
        check(transit_station_turn_allow_query(native(), peer.native(), schema.id(), expected_revision, allow));
    }
    void close_query(uint64_t result, transit_station_query_close_reason reason) const { check(transit_station_turn_close_query(native(), result, reason)); }
    ResultReader result(uint64_t correlation) const;
    bool stage_http(const PreparedHttpRequest &request) const;
    uint64_t call_http(ProcessRef peer, const PreparedHttpRequest &request) const;
    uint64_t followup_http(ProcessRef peer, const HttpOutcome &parent, HttpFollowupReason reason, const PreparedHttpRequest &request) const;
    uint64_t release_http(ProcessRef peer, ResourceRef capture, uint64_t exchange) const {
        uint64_t correlation = 0; check(transit_station_turn_http_release(native(), peer.native(), capture.native(), exchange, &correlation)); return correlation;
    }
    bool stage_grpc(const PreparedGrpcRequest &request) const;
    uint64_t call_grpc(ProcessRef peer, const PreparedGrpcRequest &request) const;
    uint64_t retry_grpc(ProcessRef peer, const GrpcOutcome &parent, const PreparedGrpcRequest &request) const;
    uint64_t release_grpc(ProcessRef peer, ResourceRef capture, uint64_t exchange) const {
        uint64_t correlation = 0; check(transit_station_turn_grpc_release(native(), peer.native(), capture.native(), exchange, &correlation)); return correlation;
    }
};
class State {
    Turn turn_;
    std::optional<ReadVersion> version_;
public:
    explicit State(Turn turn, std::optional<ReadVersion> version = {}) : turn_(std::move(turn)), version_(version) {}
    template<class T> std::optional<T> find(const Key<T> &key) const {
        turn_.info(); const auto name = key.native(); transit_station_value *out = nullptr;
        check(transit_station_state_find(turn_.native(), version_ ? &*version_ : nullptr, &name, &out));
        std::unique_ptr<transit_station_value, decltype(&transit_station_value_destroy)> owner(out, transit_station_value_destroy);
        if (!out) return {}; return *static_cast<const T *>(transit_station_value_data(out));
    }
    template<class T> T require(const Key<T> &key) const {
        auto value = find(key); if (!value) throw failure(TRANSIT_SDK_MISSING_VALUE, "state-require"); return std::move(*value);
    }
    template<class T> void put(const Key<T> &key, const T &value) const {
        turn_.info();
        if (version_) throw failure(TRANSIT_SDK_HANDLER_ERROR, "retained-state-write");
        const auto name = key.native(); check(transit_station_state_put(turn_.native(), &name, &value));
    }
    template<class T> void erase(const Key<T> &key) const {
        turn_.info();
        if (version_) throw failure(TRANSIT_SDK_HANDLER_ERROR, "retained-state-write");
        const auto name = key.native(); check(transit_station_state_delete(turn_.native(), &name));
    }
    Page<KvEntry> page(const Cursor *after = nullptr) const {
        transit_station_page *out = nullptr; check(transit_station_state_page(turn_.native(), version_ ? &*version_ : nullptr, after ? after->native() : nullptr, &out));
        std::unique_ptr<transit_station_page, decltype(&transit_station_page_destroy)> owner(out, transit_station_page_destroy);
        Page<KvEntry> page;
        for (size_t i = 0; i < transit_station_page_size(out); ++i) { transit_station_kv_entry entry{}; check(transit_station_page_kv(out, i, &entry)); page.entries.push_back({copy_bytes(entry.key), copy_bytes(entry.value), entry.revision}); }
        transit_station_cursor *next = nullptr; check(transit_station_page_next(out, &next)); if (next) page.next.emplace(next); return page;
    }
};
template<class T> class Table {
    std::unique_ptr<transit_station_table, decltype(&transit_station_table_destroy)> value_;
    static Row<T> decode(transit_station_row_view row) {
        if (row.value.kind == TRANSIT_CELL_NULL) return {row.key, {}};
        if (row.value.kind != cell_type<T>()) throw failure(TRANSIT_SDK_CODEC_ERROR, "table-cell");
        if constexpr (std::is_same_v<T, int64_t>) return {row.key, row.value.integer};
        else if constexpr (std::is_same_v<T, bool>) return {row.key, row.value.boolean};
        else if constexpr (std::is_same_v<T, std::string>) { const auto bytes = copy_bytes(row.value.bytes); return {row.key, std::string(bytes.begin(), bytes.end())}; }
        else return {row.key, copy_bytes(row.value.bytes)};
    }
    void write(transit_station_write_mode mode, const Row<T> &row) const {
        Cell cell; if (row.value) cell = *row.value;
        check(transit_station_table_write(value_.get(), mode, {row.key, native_cell(cell)}));
    }
public:
    explicit Table(transit_station_table *value) : value_(value, transit_station_table_destroy) {}
    Table(Table &&) noexcept = default;
    Table &operator=(Table &&) noexcept = default;
    Basis basis() const { Basis out{}; check(transit_station_table_basis(value_.get(), &out)); return out; }
    std::optional<Row<T>> get(int64_t key) const {
        transit_station_row *out = nullptr; check(transit_station_table_get(value_.get(), key, &out));
        std::unique_ptr<transit_station_row, decltype(&transit_station_row_destroy)> owner(out, transit_station_row_destroy);
        if (!out) return {}; transit_station_row_view row{}; check(transit_station_row_inspect(out, &row)); return decode(row);
    }
    void insert(const Row<T> &row) const { write(TRANSIT_WRITE_INSERT, row); }
    void update(const Row<T> &row) const { write(TRANSIT_WRITE_UPDATE, row); }
    void upsert(const Row<T> &row) const { write(TRANSIT_WRITE_UPSERT, row); }
    void erase(int64_t key) const { check(transit_station_table_delete(value_.get(), key)); }
    Page<Row<T>> page(const Cursor *after = nullptr) const {
        transit_station_page *out = nullptr; check(transit_station_table_page(value_.get(), after ? after->native() : nullptr, &out));
        std::unique_ptr<transit_station_page, decltype(&transit_station_page_destroy)> owner(out, transit_station_page_destroy);
        Page<Row<T>> page;
        for (size_t i = 0; i < transit_station_page_size(out); ++i) { transit_station_row_view row{}; check(transit_station_page_row(out, i, &row)); page.entries.push_back(decode(row)); }
        Basis basis{}; check(transit_station_page_basis(out, &basis)); page.basis = basis;
        transit_station_cursor *next = nullptr; check(transit_station_page_next(out, &next)); if (next) page.next.emplace(next); return page;
    }
    QueryJob start_query(const QueryPlan &plan = {}) const { const auto native = plan.native(); QueryJob job{}; check(transit_station_table_start_query(value_.get(), &native, &job)); return job; }
};
class Source {
    Turn turn_;
    ReadVersion version_;
public:
    Source(Turn turn, ReadVersion version) : turn_(std::move(turn)), version_(version) {}
    ReadVersion identity() const { return version_; }
    State state() const { return State(turn_, version_); }
    template<class T> Table<T> table(const TableSchema<T> &schema) const {
        const auto description = schema.native(); transit_station_table *value = nullptr;
        check(transit_station_table_open(turn_.native(), &description, &version_, &value)); return Table<T>(value);
    }
};
class IpcSegment {
    std::shared_ptr<transit_station_segment> value_;
public:
    explicit IpcSegment(transit_station_segment *value) : value_(value, transit_station_segment_destroy) {}
    transit_station_segment_info info() const { transit_station_segment_info out{}; check(transit_station_segment_inspect(value_.get(), &out)); return out; }
    Bytes ipc() const { transit_sdk_buffer out{}; check(transit_station_segment_ipc(value_.get(), &out)); return Buffer(out).copy(); }
};
class ResultReader {
    Turn turn_;
    uint64_t correlation_;
public:
    ResultReader(Turn turn, uint64_t correlation) : turn_(std::move(turn)), correlation_(correlation) {}
    Manifest manifest() const { Manifest out{}; check(transit_station_result_manifest(turn_.native(), correlation_, &out)); return out; }
    IpcSegment segment(uint64_t ordinal) const { transit_station_segment *out = nullptr; check(transit_station_result_segment(turn_.native(), correlation_, ordinal, &out)); return IpcSegment(out); }
};
inline State Turn::state() const { return State(*this); }
inline Source Turn::source(ReadVersion version) const { info(); return Source(*this, version); }
inline ResultReader Turn::result(uint64_t correlation) const { info(); return ResultReader(*this, correlation); }
template<class T> Table<T> Turn::table(const TableSchema<T> &schema) const {
    const auto description = schema.native(); transit_station_table *value = nullptr;
    check(transit_station_table_open(native(), &description, nullptr, &value)); return Table<T>(value);
}
template<class T> Table<T> Turn::create_table(const TableSchema<T> &schema) const {
    const auto description = schema.native(); transit_station_table *value = nullptr;
    check(transit_station_table_create(native(), &description, &value)); return Table<T>(value);
}
template<class T> Bytes encode_cast(const T &value, const Codec<T> &codec, const char *native_directory = nullptr) {
    const auto encoding = codec.native(); transit_sdk_buffer out{}; check(transit_station_encode_cast(&value, &encoding, native_directory, &out)); return Buffer(out).copy();
}
}
namespace transit::sdk::station {
enum class HttpMethod { Get = TRANSIT_HTTP_GET, Head = TRANSIT_HTTP_HEAD, Post = TRANSIT_HTTP_POST, Put = TRANSIT_HTTP_PUT, Patch = TRANSIT_HTTP_PATCH, Delete = TRANSIT_HTTP_DELETE, Options = TRANSIT_HTTP_OPTIONS };
struct HttpLiteral { std::string value; };
struct HttpVariable { std::string name, value; };
struct HttpSecretRef { std::string binding; uint64_t version; };
using HttpPiece = std::variant<HttpLiteral, HttpVariable, HttpSecretRef>;
struct HttpHeader { std::string name; std::vector<HttpPiece> value; };
struct HttpRequest { HttpMethod method; std::vector<HttpPiece> target; std::vector<HttpHeader> headers; };
struct HttpRequestOptions { uint64_t endpoint_revision, reconcile_before_ms; uint32_t max_attempts = 1; };
class PreparedHttpRequest {
    std::shared_ptr<transit_station_http_request> value_;
public:
    explicit PreparedHttpRequest(transit_station_http_request *value) : value_(value, transit_station_http_request_destroy) {
        if (!value) throw failure(TRANSIT_SDK_INVALID_ARGUMENT, "http-request");
    }
    const transit_station_http_request *native() const { return value_.get(); }
    transit_station_http_request_view info() const { transit_station_http_request_view out{}; check(transit_station_http_request_inspect(native(), &out)); return out; }
    Bytes reference() const { return copy_bytes(info().reference); }
    Bytes metadata() const { return copy_bytes(info().metadata); }
    Bytes body() const { return copy_bytes(info().body); }
};
inline std::vector<transit_station_http_piece> native_http_pieces(const std::vector<HttpPiece> &pieces) {
    if (pieces.size() > 128) throw failure(TRANSIT_SDK_INVALID_ARGUMENT, "http-pieces");
    const auto bytes = [](const std::string &value) { return transit_sdk_bytes{reinterpret_cast<const uint8_t *>(value.data()), value.size()}; };
    std::vector<transit_station_http_piece> out; out.reserve(pieces.size());
    for (const auto &piece : pieces) {
        transit_station_http_piece value{};
        std::visit([&](const auto &item) {
            using T = std::decay_t<decltype(item)>;
            if constexpr (std::is_same_v<T, HttpLiteral>) { value.kind = TRANSIT_HTTP_LITERAL; value.value = bytes(item.value); }
            else if constexpr (std::is_same_v<T, HttpVariable>) { value.kind = TRANSIT_HTTP_VARIABLE; value.name = bytes(item.name); value.value = bytes(item.value); }
            else { value.kind = TRANSIT_HTTP_SECRET; value.name = bytes(item.binding); value.version = item.version; }
        }, piece);
        out.push_back(value);
    }
    return out;
}
inline PreparedHttpRequest prepare_http(ResourceRef resource, uint64_t namespace_id, const HttpRequest &request,
    const Bytes &body, HttpRequestOptions options, const char *native_directory = nullptr) {
    if (request.headers.size() > 64) throw failure(TRANSIT_SDK_INVALID_ARGUMENT, "http-headers");
    const auto target = native_http_pieces(request.target);
    std::vector<std::vector<transit_station_http_piece>> fields; fields.reserve(request.headers.size());
    std::vector<transit_station_http_header> headers; headers.reserve(request.headers.size());
    for (const auto &header : request.headers) {
        fields.push_back(native_http_pieces(header.value));
        // Embedded NUL is never silently truncated by the C string boundary.
        checked_string(header.name);
        headers.push_back({header.name.c_str(), fields.back().data(), fields.back().size()});
    }
    const transit_station_http_template description{static_cast<transit_station_http_method>(request.method), target.data(), target.size(), headers.data(), headers.size()};
    const transit_station_http_options settings{resource.native(), namespace_id, options.endpoint_revision, options.reconcile_before_ms, options.max_attempts};
    transit_station_http_request *out = nullptr;
    check(transit_station_http_prepare(&description, bytes_view(body), &settings, native_directory, &out));
    return PreparedHttpRequest(out);
}
class HttpOutcome {
    transit_station_http_outcome value_{};
public:
    explicit HttpOutcome(transit_station_http_outcome value) : value_(value) {}
    const transit_station_http_outcome &native() const { return value_; }
    bool rejected() const { return value_.rejected; }
    transit_station_http_rejection rejection() const { if (!rejected()) throw failure(TRANSIT_SDK_INVALID_ARGUMENT, "http-not-rejected"); return value_.rejection; }
    std::string diagnostic() const { return std::string(value_.diagnostic.json, value_.diagnostic.size); }
    transit_station_http_phase phase() const { if (rejected()) throw failure(TRANSIT_SDK_INVALID_ARGUMENT, "http-rejected"); return value_.phase; }
    uint64_t exchange() const { return value_.exchange; }
    ResourceRef resource() const { return ResourceRef(value_.resource.realm, value_.resource.resource); }
    uint64_t effect() const { return value_.effect; }
    uint64_t attempt() const { return value_.attempt; }
    std::optional<uint16_t> status() const { return value_.status ? std::optional<uint16_t>(value_.status) : std::nullopt; }
    std::optional<Bytes> reference() const {
        if (value_.reference_size > sizeof(value_.reference)) throw failure(TRANSIT_SDK_INVALID_ARGUMENT, "http-reference");
        return value_.reference_size ? std::optional<Bytes>(Bytes(value_.reference, value_.reference + value_.reference_size)) : std::nullopt;
    }
};
inline uint64_t Turn::followup_http(ProcessRef peer, const HttpOutcome &parent, HttpFollowupReason reason, const PreparedHttpRequest &request) const {
    uint64_t correlation = 0; check(transit_station_turn_http_followup(native(), peer.native(), &parent.native(), static_cast<transit_station_http_followup_reason>(reason), request.native(), &correlation)); return correlation;
}
inline HttpOutcome decode_http_reply(uint64_t realm, const Bytes &bytes, const char *native_directory = nullptr) {
    transit_station_http_outcome out{}; check(transit_station_http_decode(realm, bytes_view(bytes), native_directory, &out)); return HttpOutcome(out);
}
class HttpReleased {
    transit_station_http_released value_{};
public:
    explicit HttpReleased(transit_station_http_released value) : value_(value) {}
    ResourceRef resource() const { return ResourceRef(value_.resource.realm, value_.resource.resource); }
    uint64_t exchange() const { return value_.exchange; }
};
inline HttpReleased decode_http_released(uint64_t realm, const Bytes &bytes, const char *native_directory = nullptr) {
    transit_station_http_released out{}; check(transit_station_http_decode_released(realm, bytes_view(bytes), native_directory, &out)); return HttpReleased(out);
}
template<class T> using HttpMessage = std::variant<T, HttpOutcome, HttpReleased>;
template<class T> class HttpReplyCodec : public Codec<HttpMessage<T>> {
    std::shared_ptr<const Codec<T>> application_;
    uint64_t realm_;
    std::optional<std::string> directory_;
    std::string type_;
public:
    HttpReplyCodec(std::shared_ptr<const Codec<T>> application, uint64_t realm, std::optional<std::string> native_directory = {})
        : application_(std::move(application)), realm_(realm), directory_(std::move(native_directory)) {
        if (!application_) throw failure(TRANSIT_SDK_INVALID_ARGUMENT, "http-application-codec");
        type_ = "transit.http.reply+" + checked_string(application_->type_id());
        if (directory_) checked_string(*directory_);
    }
    const char *type_id() const noexcept override { return type_.c_str(); }
    uint32_t version() const noexcept override { return 1; }
    size_t max_encoded_bytes() const noexcept override { return std::max<size_t>(71, application_->max_encoded_bytes()); }
    Bytes encode(const HttpMessage<T> &message) const override {
        if (!std::holds_alternative<T>(message)) throw failure(TRANSIT_SDK_CODEC_ERROR, "receive-only-http-outcome");
        return application_->encode(std::get<T>(message));
    }
    HttpMessage<T> decode(const Bytes &bytes) const override {
        if (bytes.size() >= 4 && !std::memcmp(bytes.data(), "HTK1", 4))
            return decode_http_released(realm_, bytes, directory_ ? directory_->c_str() : nullptr);
        if (bytes.size() >= 4 && (!std::memcmp(bytes.data(), "HTR1", 4) || !std::memcmp(bytes.data(), "HTF1", 4)))
            return decode_http_reply(realm_, bytes, directory_ ? directory_->c_str() : nullptr);
        return application_->decode(bytes);
    }
};
enum class HttpReplayPolicy { Captured = TRANSIT_HTTP_CAPTURED, RequireUnredacted = TRANSIT_HTTP_REQUIRE_UNREDACTED };
struct HttpPart { transit_station_http_part_kind kind; Bytes data; bool complete; };
class HttpReader {
    std::unique_ptr<transit_station_http_reader, decltype(&transit_station_http_reader_destroy)> value_;
    bool complete_ = false, failed_ = false;
public:
    explicit HttpReader(transit_station_http_reader *value) : value_(value, transit_station_http_reader_destroy) {}
    HttpReader(HttpReader &&) noexcept = default;
    HttpReader &operator=(HttpReader &&) noexcept = default;
    bool complete() const { return complete_; }
    std::optional<HttpPart> read() {
        if (failed_) throw failure(TRANSIT_SDK_READ_FAILED, "http-reader-failed");
        transit_station_http_part out{}; check(transit_station_http_read(value_.get(), &out));
        try {
            std::optional<HttpPart> result;
            if (out.present) result = HttpPart{out.kind, Bytes(out.bytes, out.bytes + out.size), out.complete};
            complete_ = out.complete; return result;
        } catch (...) { failed_ = true; throw; }
    }
    void close() { check(transit_station_http_close(value_.get())); }
};
inline bool Turn::stage_http(const PreparedHttpRequest &request) const {
    bool ready = false; check(transit_station_turn_http_stage(native(), request.native(), &ready)); return ready;
}
inline uint64_t Turn::call_http(ProcessRef peer, const PreparedHttpRequest &request) const {
    uint64_t correlation = 0; check(transit_station_turn_http_call(native(), peer.native(), request.native(), &correlation)); return correlation;
}
enum class GrpcShape { Unary = TRANSIT_GRPC_UNARY, ServerStreaming = TRANSIT_GRPC_SERVER_STREAMING, ClientStreaming = TRANSIT_GRPC_CLIENT_STREAMING, Bidi = TRANSIT_GRPC_BIDI };
struct GrpcMethod { std::string path; GrpcShape shape; std::array<uint8_t,32> descriptor_digest; };
struct GrpcSecretRef { std::string binding; uint64_t version; };
using GrpcMetadataValue = std::variant<Bytes, GrpcSecretRef>;
struct GrpcMetadata { std::string name; GrpcMetadataValue value; };
struct GrpcRequest { GrpcMethod method; std::vector<GrpcMetadata> metadata; };
inline GrpcMethod grpc_method(const Bytes &descriptor, const std::string &path, const char *native_directory = nullptr) {
    checked_string(path); transit_station_grpc_method method{};
    check(transit_station_grpc_method_bind(bytes_view(descriptor), path.c_str(), native_directory, &method));
    GrpcMethod result{method.path, static_cast<GrpcShape>(method.shape), {}};
    std::copy(std::begin(method.descriptor_digest), std::end(method.descriptor_digest), result.descriptor_digest.begin());
    return result;
}
struct GrpcRequestOptions { uint64_t endpoint_revision, reconcile_before_ms; uint32_t max_attempts = 1; };
class PreparedGrpcRequest {
    std::shared_ptr<transit_station_grpc_request> value_;
public:
    explicit PreparedGrpcRequest(transit_station_grpc_request *value) : value_(value, transit_station_grpc_request_destroy) {
        if (!value) throw failure(TRANSIT_SDK_INVALID_ARGUMENT, "grpc-request");
    }
    const transit_station_grpc_request *native() const { return value_.get(); }
    transit_station_grpc_request_view info() const { transit_station_grpc_request_view out{}; check(transit_station_grpc_request_inspect(native(), &out)); return out; }
    Bytes reference() const { return copy_bytes(info().reference); }
    Bytes metadata() const { return copy_bytes(info().metadata); }
    Bytes batch() const { return copy_bytes(info().batch); }
};
inline PreparedGrpcRequest prepare_grpc(ResourceRef resource, uint64_t namespace_id, const GrpcRequest &request,
    const std::vector<Bytes> &messages, GrpcRequestOptions options, const char *native_directory = nullptr) {
    if (request.metadata.size() > 64 || messages.size() > 64) throw failure(TRANSIT_SDK_INVALID_ARGUMENT, "grpc-batch");
    transit_station_grpc_template description{};
    const auto &method = checked_string(request.method.path);
    if (method.size() > 512) throw failure(TRANSIT_SDK_INVALID_ARGUMENT, "grpc-method");
    std::copy(method.begin(),method.end(),description.method.path);
    description.method.shape = static_cast<transit_station_grpc_shape>(request.method.shape);
    std::copy(request.method.descriptor_digest.begin(),request.method.descriptor_digest.end(),description.method.descriptor_digest);
    std::vector<transit_station_grpc_metadata> fields; fields.reserve(request.metadata.size());
    for (const auto &entry : request.metadata) {
        checked_string(entry.name); transit_station_grpc_metadata field{}; field.name = entry.name.c_str();
        if (const auto *bytes = std::get_if<Bytes>(&entry.value)) field.bytes = bytes_view(*bytes);
        else { const auto &secret = std::get<GrpcSecretRef>(entry.value); checked_string(secret.binding); field.secret = true; field.binding = secret.binding.c_str(); field.version = secret.version; }
        fields.push_back(field);
    }
    description.metadata = fields.data(); description.metadata_count = fields.size();
    std::vector<transit_sdk_bytes> batch; batch.reserve(messages.size());
    for (const auto &message : messages) batch.push_back(bytes_view(message));
    const transit_station_grpc_options settings{resource.native(),namespace_id,options.endpoint_revision,options.reconcile_before_ms,options.max_attempts};
    transit_station_grpc_request *out = nullptr;
    check(transit_station_grpc_prepare(&description,batch.data(),batch.size(),&settings,native_directory,&out));
    return PreparedGrpcRequest(out);
}
class GrpcOutcome {
    transit_station_grpc_outcome value_{};
public:
    explicit GrpcOutcome(transit_station_grpc_outcome value) : value_(value) {}
    const transit_station_grpc_outcome &native() const { return value_; }
    bool rejected() const { return value_.rejected; }
    transit_station_grpc_rejection rejection() const { if (!rejected()) throw failure(TRANSIT_SDK_INVALID_ARGUMENT, "grpc-not-rejected"); return value_.rejection; }
    std::string diagnostic() const { return std::string(value_.diagnostic.json, value_.diagnostic.size); }
    transit_station_grpc_phase phase() const { if (rejected()) throw failure(TRANSIT_SDK_INVALID_ARGUMENT, "grpc-rejected"); return value_.phase; }
    uint64_t exchange() const { return value_.exchange; }
    ResourceRef resource() const { return ResourceRef(value_.resource.realm, value_.resource.resource); }
    uint64_t effect() const { return value_.effect; }
    uint64_t attempt() const { return value_.attempt; }
    std::optional<uint32_t> status() const { return value_.has_status ? std::optional<uint32_t>(value_.status) : std::nullopt; }
    std::optional<Bytes> reference() const {
        if (value_.reference_size > sizeof(value_.reference)) throw failure(TRANSIT_SDK_INVALID_ARGUMENT, "grpc-reference");
        return value_.reference_size ? std::optional<Bytes>(Bytes(value_.reference, value_.reference + value_.reference_size)) : std::nullopt;
    }
};
inline uint64_t Turn::retry_grpc(ProcessRef peer, const GrpcOutcome &parent, const PreparedGrpcRequest &request) const {
    uint64_t correlation = 0; check(transit_station_turn_grpc_retry(native(), peer.native(), &parent.native(), request.native(), &correlation)); return correlation;
}
inline GrpcOutcome decode_grpc_reply(uint64_t realm, const Bytes &bytes, const char *native_directory = nullptr) {
    transit_station_grpc_outcome out{}; check(transit_station_grpc_decode(realm, bytes_view(bytes), native_directory, &out)); return GrpcOutcome(out);
}
class GrpcReleased {
    transit_station_grpc_released value_{};
public:
    explicit GrpcReleased(transit_station_grpc_released value) : value_(value) {}
    ResourceRef resource() const { return ResourceRef(value_.resource.realm, value_.resource.resource); }
    uint64_t exchange() const { return value_.exchange; }
};
inline GrpcReleased decode_grpc_released(uint64_t realm, const Bytes &bytes, const char *native_directory = nullptr) {
    transit_station_grpc_released out{}; check(transit_station_grpc_decode_released(realm, bytes_view(bytes), native_directory, &out)); return GrpcReleased(out);
}
template<class T> using GrpcMessage = std::variant<T, GrpcOutcome, GrpcReleased>;
template<class T> class GrpcReplyCodec : public Codec<GrpcMessage<T>> {
    std::shared_ptr<const Codec<T>> application_;
    uint64_t realm_;
    std::optional<std::string> directory_;
    std::string type_;
public:
    GrpcReplyCodec(std::shared_ptr<const Codec<T>> application, uint64_t realm, std::optional<std::string> native_directory = {})
        : application_(std::move(application)), realm_(realm), directory_(std::move(native_directory)) {
        if (!application_) throw failure(TRANSIT_SDK_INVALID_ARGUMENT, "grpc-application-codec");
        type_ = "transit.grpc.reply+" + checked_string(application_->type_id());
        if (directory_) checked_string(*directory_);
    }
    const char *type_id() const noexcept override { return type_.c_str(); }
    uint32_t version() const noexcept override { return 1; }
    size_t max_encoded_bytes() const noexcept override { return std::max<size_t>(73, application_->max_encoded_bytes()); }
    Bytes encode(const GrpcMessage<T> &message) const override {
        if (!std::holds_alternative<T>(message)) throw failure(TRANSIT_SDK_CODEC_ERROR, "receive-only-grpc-outcome");
        return application_->encode(std::get<T>(message));
    }
    GrpcMessage<T> decode(const Bytes &bytes) const override {
        if (bytes.size() >= 4 && !std::memcmp(bytes.data(), "GRK1", 4))
            return decode_grpc_released(realm_, bytes, directory_ ? directory_->c_str() : nullptr);
        if (bytes.size() >= 4 && (!std::memcmp(bytes.data(), "GRR1", 4) || !std::memcmp(bytes.data(), "GRF1", 4)))
            return decode_grpc_reply(realm_, bytes, directory_ ? directory_->c_str() : nullptr);
        return application_->decode(bytes);
    }
};
enum class GrpcReplayPolicy { Captured = TRANSIT_GRPC_CAPTURED, RequireUnredacted = TRANSIT_GRPC_REQUIRE_UNREDACTED };
struct GrpcPart { transit_station_grpc_part_kind kind; Bytes data; bool complete; };
class GrpcReader {
    std::unique_ptr<transit_station_grpc_reader, decltype(&transit_station_grpc_reader_destroy)> value_;
    bool complete_ = false, failed_ = false;
public:
    explicit GrpcReader(transit_station_grpc_reader *value) : value_(value, transit_station_grpc_reader_destroy) {}
    GrpcReader(GrpcReader &&) noexcept = default;
    GrpcReader &operator=(GrpcReader &&) noexcept = default;
    bool complete() const { return complete_; }
    std::optional<GrpcPart> read() {
        if (failed_) throw failure(TRANSIT_SDK_READ_FAILED, "grpc-reader-failed");
        transit_station_grpc_part out{}; check(transit_station_grpc_read(value_.get(), &out));
        try {
            std::optional<GrpcPart> result;
            if (out.present) result = GrpcPart{out.kind, Bytes(out.bytes, out.bytes + out.size), out.complete};
            complete_ = out.complete; return result;
        } catch (...) { failed_ = true; throw; }
    }
    void close() { check(transit_station_grpc_close(value_.get())); }
};
inline bool Turn::stage_grpc(const PreparedGrpcRequest &request) const {
    bool ready = false; check(transit_station_turn_grpc_stage(native(), request.native(), &ready)); return ready;
}
inline uint64_t Turn::call_grpc(ProcessRef peer, const PreparedGrpcRequest &request) const {
    uint64_t correlation = 0; check(transit_station_turn_grpc_call(native(), peer.native(), request.native(), &correlation)); return correlation;
}
}
namespace transit::sdk::station {
struct DocumentDot {
    uint64_t counter = 0, replica = 0;
    transit_station_document_dot native() const { return {counter, replica}; }
    static DocumentDot from_native(transit_station_document_dot v) { return {v.counter,v.replica}; }
    bool operator==(const DocumentDot &v) const { return counter==v.counter && replica==v.replica; }
};
struct DocumentMap {}; struct DocumentList {}; struct DocumentText {};
using DocumentValue = std::variant<std::monostate, bool, int64_t, uint64_t, double, std::string, Bytes, DocumentMap, DocumentList, DocumentText, char32_t>;
namespace document_detail {
inline void bound(bool valid) { if(!valid) throw failure(TRANSIT_SDK_INVALID_ARGUMENT,"document-value"); }
inline transit_station_document_value native(const DocumentValue &value) {
    transit_station_document_value out{}; out.kind=static_cast<transit_station_document_value_kind>(value.index());
    std::visit([&](const auto &v) {
        using T=std::decay_t<decltype(v)>;
        if constexpr(std::is_same_v<T,bool>) out.boolean=v;
        else if constexpr(std::is_same_v<T,int64_t>) out.signed_value=v;
        else if constexpr(std::is_same_v<T,uint64_t>) out.unsigned_value=v;
        else if constexpr(std::is_same_v<T,double>) out.float_value=v;
        else if constexpr(std::is_same_v<T,std::string> || std::is_same_v<T,Bytes>) { bound(v.size()<=96); out.size=v.size(); std::copy(v.begin(),v.end(),out.bytes); }
        else if constexpr(std::is_same_v<T,char32_t>) {
            const auto n=static_cast<uint32_t>(v); bound(n<=0x10ffff && !(n>=0xd800 && n<=0xdfff));
            if(n<0x80) { out.size=1; out.bytes[0]=static_cast<uint8_t>(n); }
            else if(n<0x800) { out.size=2; out.bytes[0]=0xc0|(n>>6); out.bytes[1]=0x80|(n&63); }
            else if(n<0x10000) { out.size=3; out.bytes[0]=0xe0|(n>>12); out.bytes[1]=0x80|((n>>6)&63); out.bytes[2]=0x80|(n&63); }
            else { out.size=4; out.bytes[0]=0xf0|(n>>18); out.bytes[1]=0x80|((n>>12)&63); out.bytes[2]=0x80|((n>>6)&63); out.bytes[3]=0x80|(n&63); }
        }
    },value); return out;
}
inline DocumentValue from_native(const transit_station_document_value &v) {
    switch(v.kind) {
    case TRANSIT_DOCUMENT_NULL:return std::monostate{};
    case TRANSIT_DOCUMENT_BOOLEAN:return v.boolean;
    case TRANSIT_DOCUMENT_SIGNED:return v.signed_value;
    case TRANSIT_DOCUMENT_UNSIGNED:return v.unsigned_value;
    case TRANSIT_DOCUMENT_FLOAT:return v.float_value;
    case TRANSIT_DOCUMENT_STRING:bound(v.size<=96);return std::string(v.bytes,v.bytes+v.size);
    case TRANSIT_DOCUMENT_BINARY:bound(v.size<=96);return Bytes(v.bytes,v.bytes+v.size);
    case TRANSIT_DOCUMENT_MAP:return DocumentMap{};
    case TRANSIT_DOCUMENT_LIST:return DocumentList{};
    case TRANSIT_DOCUMENT_TEXT:return DocumentText{};
    case TRANSIT_DOCUMENT_CHARACTER: {
        bound(v.size>=1 && v.size<=4); uint32_t n=v.bytes[0] & (v.size==1 ? 0x7f : (1u<<(7-v.size))-1);
        for(size_t i=1;i<v.size;++i) { bound((v.bytes[i]&0xc0)==0x80); n=(n<<6)|(v.bytes[i]&63); }
        const uint32_t minimum[]={0,0,0x80,0x800,0x10000}; bound(n>=minimum[v.size] && n<=0x10ffff && !(n>=0xd800 && n<=0xdfff)); return static_cast<char32_t>(n);
    }
    } throw failure(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"document-value");
}
}
struct DocumentAssign { DocumentDot object; std::string field; std::vector<DocumentDot> observed; DocumentValue value; };
struct DocumentRemove { DocumentDot object; std::string field; std::vector<DocumentDot> observed; };
struct DocumentInsert { DocumentDot object, after; DocumentValue value; };
struct DocumentSetElement { DocumentDot object, element; std::vector<DocumentDot> observed; DocumentValue value; };
struct DocumentDeleteElement { DocumentDot object, element; };
using DocumentOperation=std::variant<DocumentAssign,DocumentRemove,DocumentInsert,DocumentSetElement,DocumentDeleteElement>;
struct DocumentChange {
    uint64_t document, epoch; uint32_t type_revision; uint64_t replica, previous, first;
    std::vector<DocumentOperation> operations;
    transit_station_document_change native() const {
        document_detail::bound(!operations.empty() && operations.size()<=8);
        transit_station_document_change out{}; out.document=document; out.epoch=epoch; out.type_revision=type_revision; out.replica=replica; out.previous=previous; out.first=first; out.operation_count=operations.size();
        for(size_t i=0;i<operations.size();++i) {
            auto &op=out.operations[i]; op.kind=static_cast<transit_station_document_operation_kind>(operations[i].index());
            std::visit([&](const auto &v) {
                using T=std::decay_t<decltype(v)>; op.object=v.object.native();
                if constexpr(std::is_same_v<T,DocumentAssign> || std::is_same_v<T,DocumentRemove>) { document_detail::bound(v.field.size()<=64); op.field_size=v.field.size(); std::copy(v.field.begin(),v.field.end(),op.field); }
                if constexpr(std::is_same_v<T,DocumentInsert>) op.anchor=v.after.native();
                if constexpr(std::is_same_v<T,DocumentSetElement> || std::is_same_v<T,DocumentDeleteElement>) op.anchor=v.element.native();
                if constexpr(std::is_same_v<T,DocumentAssign> || std::is_same_v<T,DocumentRemove> || std::is_same_v<T,DocumentSetElement>) { document_detail::bound(v.observed.size()<=8); op.observed_count=v.observed.size(); for(size_t k=0;k<v.observed.size();++k) op.observed[k]=v.observed[k].native(); }
                if constexpr(std::is_same_v<T,DocumentAssign> || std::is_same_v<T,DocumentInsert> || std::is_same_v<T,DocumentSetElement>) op.value=document_detail::native(v.value);
            },operations[i]);
        } return out;
    }
    static DocumentChange from_native(const transit_station_document_change &v) {
        DocumentChange out{v.document,v.epoch,v.type_revision,v.replica,v.previous,v.first,{}}; document_detail::bound(v.operation_count<=8);
        for(size_t i=0;i<v.operation_count;++i) {
            const auto &op=v.operations[i]; const auto object=DocumentDot::from_native(op.object), anchor=DocumentDot::from_native(op.anchor);
            document_detail::bound(op.field_size<=64 && op.observed_count<=8); const std::string field(op.field,op.field+op.field_size);
            std::vector<DocumentDot> observed; for(size_t k=0;k<op.observed_count;++k) observed.push_back(DocumentDot::from_native(op.observed[k]));
            switch(op.kind) {
            case TRANSIT_DOCUMENT_ASSIGN:out.operations.emplace_back(DocumentAssign{object,field,observed,document_detail::from_native(op.value)});break;
            case TRANSIT_DOCUMENT_REMOVE:out.operations.emplace_back(DocumentRemove{object,field,observed});break;
            case TRANSIT_DOCUMENT_INSERT:out.operations.emplace_back(DocumentInsert{object,anchor,document_detail::from_native(op.value)});break;
            case TRANSIT_DOCUMENT_SET_ELEMENT:out.operations.emplace_back(DocumentSetElement{object,anchor,observed,document_detail::from_native(op.value)});break;
            case TRANSIT_DOCUMENT_DELETE_ELEMENT:out.operations.emplace_back(DocumentDeleteElement{object,anchor});break;
            }
        } return out;
    }
};
class PreparedDocumentChange {
    std::unique_ptr<transit_station_document_prepared,decltype(&transit_station_document_prepared_destroy)> value_;
public:
    explicit PreparedDocumentChange(transit_station_document_prepared *v):value_(v,transit_station_document_prepared_destroy) {}
    const transit_station_document_prepared *native() const { return value_.get(); }
    Bytes data() const { transit_sdk_bytes v{}; check(transit_station_document_prepared_bytes(native(),&v)); return Bytes(v.data,v.data+v.size); }
};
inline PreparedDocumentChange prepare_document(const DocumentChange &change,const char *directory=nullptr) {
    const auto value=change.native(); transit_station_document_prepared *out=nullptr;
    check(transit_station_document_prepare(&value,directory,&out)); return PreparedDocumentChange(out);
}
inline DocumentChange decode_document(const Bytes &data,const char *directory=nullptr) {
    transit_station_document_change out{}; check(transit_station_document_decode(bytes_view(data),directory,&out)); return DocumentChange::from_native(out);
}
struct DocumentReference {
    ResourceRef resource; uint64_t document,epoch; uint32_t type_revision; uint64_t revision;
    transit_station_document_reference native() const { return {resource.native(),document,epoch,type_revision,revision}; }
    static DocumentReference from_native(const transit_station_document_reference &v) { return {ResourceRef(v.resource.realm,v.resource.resource),v.document,v.epoch,v.type_revision,v.revision}; }
    Bytes data(const char *directory=nullptr) const { const auto v=native(); Bytes out(40); check(transit_station_document_reference_encode(&v,directory,out.data())); return out; }
    static DocumentReference decode(uint64_t realm,const Bytes &bytes,const char *directory=nullptr) { transit_station_document_reference out{}; check(transit_station_document_reference_decode(realm,bytes_view(bytes),directory,&out)); return from_native(out); }
};
enum class DocumentPhase { Progress, Accepted, Duplicate, CheckpointComplete };
struct DocumentProgress {
    DocumentPhase phase; std::optional<uint64_t> revision;
    static DocumentProgress from_native(transit_station_document_progress v) { return {static_cast<DocumentPhase>(v.phase),v.has_revision?std::optional<uint64_t>(v.revision):std::nullopt}; }
};
struct DocumentLimits { uint32_t record_bytes=4096; uint64_t staging_bytes=8192; uint32_t staging_records=2; };
class DocumentOwner {
    Turn turn_; uint64_t document_;
public:
    DocumentOwner(Turn turn,uint64_t document):turn_(std::move(turn)),document_(document) { document_detail::bound(document!=0); turn_.info(); }
    void create(uint32_t type_revision,DocumentLimits limits={}) const { check(transit_station_turn_document_create(turn_.native(),document_,type_revision,{limits.record_bytes,limits.staging_bytes,limits.staging_records})); }
    DocumentProgress stage(uint64_t job,const PreparedDocumentChange &change,uint32_t node_limit=512) const { transit_station_document_progress out{}; check(transit_station_turn_document_stage(turn_.native(),document_,job,change.native(),node_limit,&out)); return DocumentProgress::from_native(out); }
    DocumentProgress checkpoint(uint64_t job) const { transit_station_document_progress out{}; check(transit_station_turn_document_checkpoint(turn_.native(),document_,job,&out)); return DocumentProgress::from_native(out); }
    void merge_window(uint64_t revisions) const { check(transit_station_turn_document_merge_window(turn_.native(),document_,revisions)); }
    void reject(uint64_t job,bool checkpoint=false) const { check(transit_station_turn_document_reject(turn_.native(),document_,job,checkpoint)); }
    bool collect(uint64_t job,bool checkpoint=false,bool retired=false) const { bool done=false; check(transit_station_turn_document_collect(turn_.native(),document_,job,checkpoint,retired,&done)); return done; }
    void retire() const { check(transit_station_turn_document_retire(turn_.native(),document_)); }
};
inline DocumentOwner Turn::document(uint64_t identity) const { return DocumentOwner(*this,identity); }
enum class DocumentStatus { Missing, Null, Scalar, Object, Conflict };
struct DocumentAssignment { DocumentDot id; DocumentValue value; };
struct DocumentField {
    DocumentStatus status; std::vector<DocumentAssignment> assignments;
    std::vector<DocumentDot> observed() const { std::vector<DocumentDot> out; for(const auto &v:assignments) out.push_back(v.id); return out; }
    static DocumentField from_native(const transit_station_document_field &v) { DocumentField out{static_cast<DocumentStatus>(v.status),{}}; document_detail::bound(v.count<=8); for(size_t i=0;i<v.count;++i) out.assignments.push_back({DocumentDot::from_native(v.assignments[i].id),document_detail::from_native(v.assignments[i].value)}); return out; }
};
struct DocumentDescription { DocumentReference reference; uint64_t source_revision,floor,merge_window,active_job; bool retired; uint32_t change_format; };
struct DocumentPath { DocumentReference reference; uint64_t source_revision; DocumentField field; };
struct DocumentItem { DocumentDot id; DocumentField field; };
struct DocumentPage { DocumentReference reference; uint64_t source_revision; std::vector<DocumentItem> items; std::optional<std::string> next; };
struct DocumentResynchronization { DocumentReference reference; uint64_t floor,replica,previous_counter,clock; };
class DocumentReader {
    std::unique_ptr<transit_station_document_reader,decltype(&transit_station_document_reader_destroy)> value_;
public:
    explicit DocumentReader(transit_station_document_reader *value):value_(value,transit_station_document_reader_destroy) {}
    DocumentDescription describe(ResourceRef resource,uint64_t document) const { transit_station_document_description out{}; check(transit_station_document_describe(value_.get(),resource.native(),document,&out)); return {DocumentReference::from_native(out.reference),out.source_revision,out.floor,out.merge_window,out.active_job,out.retired,out.change_format}; }
    DocumentPath path(const DocumentReference &reference,const std::vector<std::string> &names) const {
        const auto ref=reference.native(); std::vector<transit_sdk_bytes> path; for(const auto &v:names) path.push_back({reinterpret_cast<const uint8_t *>(v.data()),v.size()});
        transit_station_document_path out{}; check(transit_station_document_path_read(value_.get(),&ref,path.data(),path.size(),&out)); return {reference,out.source_revision,DocumentField::from_native(out.field)};
    }
    DocumentPage sequence(const DocumentReference &reference,DocumentDot object,const std::optional<std::string> &cursor={}) const {
        const auto ref=reference.native(); transit_station_document_page out{}; check(transit_station_document_sequence(value_.get(),&ref,object.native(),cursor?cursor->c_str():nullptr,&out));
        DocumentPage page{reference,out.source_revision,{},out.has_next?std::optional<std::string>(out.next):std::nullopt}; document_detail::bound(out.count<=8);
        for(size_t i=0;i<out.count;++i) page.items.push_back({DocumentDot::from_native(out.items[i].id),DocumentField::from_native(out.items[i].field)}); return page;
    }
    DocumentResynchronization resynchronize(ResourceRef resource,uint64_t document,uint64_t replica) const { transit_station_document_resynchronization out{}; check(transit_station_document_resynchronize(value_.get(),resource.native(),document,replica,&out)); return {DocumentReference::from_native(out.reference),out.floor,out.replica,out.previous_counter,out.clock}; }
    DocumentChange accepted_change(const DocumentReference &reference) const { const auto ref=reference.native(); transit_station_document_change out{}; check(transit_station_document_accepted_change(value_.get(),&ref,&out)); return DocumentChange::from_native(out); }
};
}

#include <transit/station/runner.hpp>
