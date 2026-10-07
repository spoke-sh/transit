#pragma once
#include <transit/station.h>
#include <transit/internal/support.hpp>
#include <transit_station.h>
#include <atomic>
#include <optional>
#include <thread>

namespace transit::sdk::station_detail {
using namespace internal;
struct Caps { size_t message, value, key, cell, name, page, segment; bool queries, http_requests, http_replay, http_release, http_followup, grpc_requests, grpc_replay, grpc_release, grpc_followup, document_codecs, document_owner, document_reads; };
#define TRANSIT_STATION_FUNCTIONS(X) \
    X(station_abi_definition_matches) X(station_abi_version) X(station_growing_capabilities) X(station_growing_create) X(station_growing_destroy) \
    X(station_growing_prepare) X(station_growing_dispatch) X(station_growing_confirmation) X(station_growing_apply) \
    X(station_growing_finish_result) X(station_growing_discard) X(station_growing_pending) X(station_frame_encode) \
    X(station_buffer_data) X(station_buffer_size) X(station_buffer_destroy) X(station_http_codec) X(station_growing_http_read) X(station_grpc_codec) X(station_growing_grpc_read) X(station_document_codec) X(station_growing_document_read) \
    X(station_unified_query_codec) X(station_unified_query_create) X(station_unified_query_call) X(station_unified_query_destroy) \
    X(station_catalog_create) X(station_catalog_call) X(station_catalog_destroy)
struct Local {
    Raw raw;
    Library library;
#define DECLARE(name) decltype(&::name) name;
    TRANSIT_STATION_FUNCTIONS(DECLARE)
#undef DECLARE
    Caps caps{};
    explicit Local(const char *directory);
    Bytes take(station_buffer *buffer, size_t maximum = TRANSIT_CLIENT_MAX_BODY) const;
    Bytes result(uint32_t status, station_buffer *buffer, const char *phase, bool mutation = false, size_t maximum = TRANSIT_CLIENT_MAX_BODY) const;
};
struct Bridge {
    Local local;
    std::unique_ptr<transit_client, decltype(&::transit_client_destroy)> client;
    std::unique_ptr<station_growing_server, decltype(&::station_growing_destroy)> server;
    explicit Bridge(const transit_station_config &config, transit_station_failure_policy failure);
    Bytes prepare();
    Bytes apply(uint64_t scope, const std::string &action);
    Bytes http_read(const std::string &action);
    Bytes grpc_read(const std::string &action);
    Bytes document_read(const std::string &action);
    void finish(uint64_t scope, bool failed);
    void discard(uint64_t scope);
    std::shared_ptr<const transit_station_mutation> pending(const Bytes &event);
    Bytes dispatch();
    std::optional<Bytes> confirmation(const transit_station_mutation &pending);
};
Bytes document_codec(Local &, const std::string &);
std::string document_dot(transit_station_document_dot);
std::string document_reference(Local &, const transit_station_document_reference &);
transit_station_document_reference document_reference_parse(Local &, uint64_t realm, const std::string &);
transit_station_document_change document_change_parse(const Raw &, const Bytes &, const std::string &);
transit_station_document_field document_field_parse(const Raw &, const Bytes &, const std::string &);
transit_station_document_dot document_dot_parse(const Raw &, const Bytes &, const std::string &);
Bytes document_reader_run(transit_station_document_reader *, uint64_t realm, const std::function<Bytes(Bridge &)> &);
inline transit_sdk_diagnostic diagnostic(const Raw &raw, const Bytes &value, const std::string &path) {
    const auto text = raw.field(value, path);
    require(text.size() <= 32768 && raw.transit_diagnostic_validate(reinterpret_cast<const uint8_t *>(text.data()), text.size()) == 1, "invalid-diagnostic");
    transit_sdk_diagnostic result{};
    result.size = text.size();
    std::copy(text.begin(), text.end(), result.json);
    return result;
}
inline Bytes json(const std::string &text) { return Bytes(text.begin(), text.end()); }
inline std::string decimal(uint64_t value) { return std::to_string(value); }
inline std::string signed_decimal(int64_t value) { return std::to_string(value); }
bool exists(const Raw &raw, const Bytes &value, const std::string &path);
uint64_t wide(const Raw &raw, const Bytes &value, const std::string &path);
int64_t signed_number(const Raw &raw, const Bytes &value, const std::string &path);
void digest(const Raw &raw, const Bytes &value, const std::string &path, uint8_t out[32]);
std::string version(const transit_station_read_version &value);
transit_station_read_version read_version(const Raw &raw, const Bytes &value, const std::string &path);
transit_station_basis basis(const Raw &raw, const Bytes &value, const std::string &path, uint64_t realm);
std::string cursor(const transit_station_cursor *value);
std::optional<std::string> next_cursor(const Raw &raw, const Bytes &value, const std::string &path);
Bytes encode(const transit_station_codec &codec, const void *value, size_t bound);
std::unique_ptr<transit_station_value> decode(const transit_station_codec &codec, const Bytes &bytes, size_t bound);
void codec_contract(const transit_station_codec &codec, size_t bound);
void callback_result(transit_sdk_error error);
transit_station_origin origin(const Raw &raw, const Bytes &event, uint64_t realm);
transit_station_incoming incoming(const Raw &raw, const Bytes &event, uint64_t realm);
std::string application_key(const transit_station_key *key, size_t bound);
Bytes turn_apply(transit_station_turn &turn, const std::string &action);
void peer(const transit_station_turn &turn, transit_sdk_process value);
class TurnGuard {
    std::unique_lock<std::mutex> lock;
public:
    explicit TurnGuard(transit_station_turn *turn);
};
template<class F> transit_sdk_error with_turn(transit_station_turn *turn, bool read, F &&work);
std::unique_ptr<transit_station_table> capture_table(transit_station_turn &turn, const transit_station_table_schema &schema, const transit_station_read_version *version);
std::string cell_wire(transit_station_cell cell, size_t bound);
const char *cell_name(transit_station_cell_kind kind);
void schema_check(const transit_station_table_schema &schema, const Caps &caps);
transit_station_row read_row(const Raw &raw, const Bytes &json, const std::string &path, size_t bound, transit_station_cell_kind type);
transit_station_manifest manifest(transit_station_turn &turn, uint64_t correlation);
}
struct transit_station_mutation {
    transit_station_mutation_info info{};
    transit::sdk::internal::Bytes bytes;
};
struct transit_station_event {
    transit_station_event_info info{};
    std::shared_ptr<const transit_station_mutation> pending;
};
struct transit_station_turn {
    std::atomic<size_t> references{1};
    std::atomic<bool> active{true};
    const std::thread::id thread = std::this_thread::get_id();
    std::mutex operation;
    transit::sdk::station_detail::Bridge *bridge;
    std::atomic<bool> *stop;
    uint64_t scope;
    transit_station_turn_info info;
    transit_station_incoming input;
    transit_sdk_error poison{};
    transit_station_turn(transit::sdk::station_detail::Bridge &bridge_, std::atomic<bool> &stop_, uint64_t scope_, transit_station_turn_info info_, transit_station_incoming input_)
        : bridge(&bridge_), stop(&stop_), scope(scope_), info(info_), input(input_) {}
};
struct transit_station_value {
    transit_station_codec codec;
    void *data;
    bool constructed = false;
    explicit transit_station_value(const transit_station_codec &codec_) : codec(codec_), data(::operator new(codec.object_bytes)) {}
    ~transit_station_value() {
        if (constructed && codec.destroy) { try { codec.destroy(codec.context, data); } catch (...) {} }
        ::operator delete(data);
    }
};
struct transit_station_cursor { std::string value; };
struct transit_station_row {
    int64_t key{};
    transit_station_cell_kind kind = TRANSIT_CELL_NULL;
    int64_t integer{};
    bool boolean{};
    transit::sdk::internal::Bytes bytes;
    transit_station_row_view view() const { return {key, {kind, integer, boolean, transit::sdk::internal::view(bytes)}}; }
};
struct KvEntry { transit::sdk::internal::Bytes key, value; uint64_t revision; };
struct transit_station_page {
    bool table = false;
    std::vector<KvEntry> entries;
    std::vector<transit_station_row> rows;
    std::optional<std::string> next;
    transit_station_basis basis{};
};
struct transit_station_table {
    transit_station_turn *turn;
    uint32_t id;
    transit_station_cell_kind type;
    transit_station_basis basis;
    std::optional<transit_station_read_version> retained;
    transit_station_table(transit_station_turn &turn_, uint32_t id_, transit_station_cell_kind type_, transit_station_basis basis_, const transit_station_read_version *version)
        : turn(&turn_), id(id_), type(type_), basis(basis_) {
        if (version) retained = *version;
        transit_station_turn_retain(turn);
    }
    ~transit_station_table() { transit_station_turn_release(turn); }
};
struct transit_station_segment { transit_station_segment_info info{}; transit::sdk::internal::Bytes ipc; };
struct transit_station_http_request {
    transit_sdk_resource resource{};
    uint64_t namespace_id{};
    transit::sdk::internal::Bytes reference, metadata, body;
};
struct transit_station_grpc_request {
    transit_sdk_resource resource{};
    uint64_t namespace_id{};
    transit::sdk::internal::Bytes reference, metadata, batch;
};
namespace transit::sdk::station_detail {
template<class F> transit_sdk_error with_turn(transit_station_turn *turn, bool read, F &&work) {
    return boundary([&] {
        TurnGuard guard(turn);
        auto error = boundary([&] { work(*turn); });
        if (error.kind != TRANSIT_SDK_OK) {
            if (read && turn->poison.kind == TRANSIT_SDK_OK) turn->poison = error;
            throw Failure{error};
        }
    });
}
}

struct transit_station_document_prepared { uint64_t document; transit::sdk::internal::Bytes bytes; };
