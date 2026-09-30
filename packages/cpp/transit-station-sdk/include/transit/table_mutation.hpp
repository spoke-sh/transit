#pragma once
#include <transit/station.hpp>
#include <transit/table_mutation.h>

namespace transit::sdk::station::mutations {
using Reference = std::array<uint8_t, 72>;
enum class Permission : uint8_t { Insert = 1, Update = 2, Delete = 4 };
struct Permissions {
    uint8_t bits;
    bool contains(Permission p) const { return (bits & static_cast<uint8_t>(p)) != 0; }
};
enum class Type { Int64, Boolean, Utf8, Binary };
enum class Phase { Uploading, Sealed, Applied, Rejected, Cancelled };
enum class Reason { None, RowExists, SourceChanged, InvalidRequest, Denied, Budget };
enum class Observation { Pending, Processed };
enum class Rejection { InvalidCommand, Denied, IdentityConflict, Busy, NotFound, NotActive, UploadClosed, NotSealed, InvalidPart, IncompleteUpload, SourceChanged, StalePolicy };
enum class Control { Apply, Cancel };
struct Connection { ProcessRef writer; ResourceRef resource; uint32_t table; };
struct Description {
    ResourceRef resource; uint32_t table; std::array<std::string, 2> names; Type value_type;
    uint64_t resource_revision, policy_revision; std::array<uint8_t, 32> declaration;
    Permissions permissions; std::optional<uint64_t> active;
};
struct Status {
    Reference reference; uint64_t principal; uint32_t table; std::array<uint8_t, 32> declaration;
    uint64_t policy_revision; Phase phase; uint8_t affected_rows; Reason reason; uint64_t input;
};
namespace detail {
inline transit_station_table_mutation_reference native(const Reference &reference) {
    transit_station_table_mutation_reference out{}; std::copy(reference.begin(), reference.end(), out.bytes); return out;
}
}
class Compiled {
    std::unique_ptr<transit_station_table_mutation_compiled, decltype(&transit_station_table_mutation_compiled_destroy)> value_;
public:
    explicit Compiled(transit_station_table_mutation_compiled *v) : value_(v, transit_station_table_mutation_compiled_destroy) {}
    Compiled(Compiled &&) noexcept = default;
    Compiled &operator=(Compiled &&) noexcept = default;
    static Compiled recover(const Bytes &request, const Reference &reference) {
        transit_station_table_mutation_compiled *out = nullptr;
        check(transit_station_table_mutation_compiled_import(bytes_view(request), detail::native(reference), &out)); return Compiled(out);
    }
    Bytes request() const {
        transit_sdk_bytes data{}; transit_station_table_mutation_reference ref{};
        check(transit_station_table_mutation_compiled_get(value_.get(), &data, &ref)); return copy_bytes(data);
    }
    Reference reference() const {
        transit_sdk_bytes data{}; transit_station_table_mutation_reference ref{}; Reference result{};
        check(transit_station_table_mutation_compiled_get(value_.get(), &data, &ref)); std::copy_n(ref.bytes, 72, result.begin()); return result;
    }
    const transit_station_table_mutation_compiled *native() const { return value_.get(); }
};
class Prepared {
    std::unique_ptr<transit_station_table_mutation_prepared, decltype(&transit_station_table_mutation_prepared_destroy)> value_;
public:
    explicit Prepared(transit_station_table_mutation_prepared *v) : value_(v, transit_station_table_mutation_prepared_destroy) {}
    Prepared(Prepared &&) noexcept = default;
    Prepared &operator=(Prepared &&) noexcept = default;
    static Prepared recover(const Bytes &data) {
        transit_station_table_mutation_prepared *out = nullptr;
        check(transit_station_table_mutation_prepared_import(bytes_view(data), &out)); return Prepared(out);
    }
    Bytes data() const {
        transit_sdk_bytes out{}; check(transit_station_table_mutation_prepared_bytes(value_.get(), &out)); return copy_bytes(out);
    }
    const transit_station_table_mutation_prepared *native() const { return value_.get(); }
};
class Client {
    std::unique_ptr<transit_station_table_mutation_client, decltype(&transit_station_table_mutation_client_destroy)> value_;
    explicit Client(transit_station_table_mutation_client *v) : value_(v, transit_station_table_mutation_client_destroy) {}
public:
    Client(Client &&) noexcept = default;
    Client &operator=(Client &&) noexcept = default;
    static Client open(const ClientConfig &config, const Credential &credential, const Connection &connection) {
        const auto cfg = config.native(); const auto identity = credential.native(); transit_station_table_mutation_client *out = nullptr;
        check(transit_station_table_mutation_open(&cfg, &identity, {connection.writer.native(), connection.resource.native(), connection.table}, &out)); return Client(out);
    }
    Description describe() {
        transit_station_table_mutation_description out{}; check(transit_station_table_mutation_describe(value_.get(), &out));
        Description result{ResourceRef(out.resource.realm, out.resource.resource), out.table, {out.names[0], out.names[1]}, static_cast<Type>(out.value_type - 1), out.resource_revision, out.policy_revision, {}, {out.permissions}, {}};
        std::copy_n(out.declaration, 32, result.declaration.begin()); if (out.has_active) result.active = out.active; return result;
    }
    Compiled compile_sql(const std::string &name, const std::string &sql, uint64_t ns) {
        checked_string(name); checked_string(sql); transit_station_table_mutation_compiled *out = nullptr;
        check(transit_station_table_mutation_compile_sql(value_.get(), name.c_str(), sql.c_str(), ns, &out)); return Compiled(out);
    }
    std::optional<Prepared> prepare_next(const Compiled &compiled) {
        transit_station_table_mutation_prepared *out = nullptr;
        check(transit_station_table_mutation_prepare_next(value_.get(), compiled.native(), &out));
        if (out) return Prepared(out);
        return {};
    }
    Prepared prepare_control(Control command, const Reference &reference) {
        transit_station_table_mutation_prepared *out = nullptr;
        check(transit_station_table_mutation_prepare_control(value_.get(), static_cast<transit_station_table_mutation_control>(command), detail::native(reference), &out)); return Prepared(out);
    }
    uint64_t submit(const Prepared &prepared) {
        uint64_t out = 0; check(transit_station_table_mutation_submit(value_.get(), prepared.native(), &out)); return out;
    }
    Observation observe(const Prepared &prepared, uint64_t input) {
        transit_station_table_mutation_observation out{}; check(transit_station_table_mutation_observe(value_.get(), prepared.native(), input, &out)); return static_cast<Observation>(out);
    }
    std::optional<Rejection> rejection(const Prepared &prepared, uint64_t input) {
        bool found = false; transit_station_table_mutation_rejection out{};
        check(transit_station_table_mutation_input_rejection(value_.get(), prepared.native(), input, &found, &out));
        if (found) return static_cast<Rejection>(out);
        return {};
    }
    std::optional<Status> status(const Reference &reference) {
        transit_station_table_mutation_status out{}; check(transit_station_table_mutation_status_read(value_.get(), detail::native(reference), &out));
        if (!out.found) return {};
        Status result{{}, out.principal, out.table, {}, out.policy_revision, static_cast<Phase>(out.phase), out.affected_rows, static_cast<Reason>(out.reason), out.input};
        std::copy_n(out.reference.bytes, 72, result.reference.begin()); std::copy_n(out.declaration, 32, result.declaration.begin()); return result;
    }
    void close() { check(transit_station_table_mutation_close(value_.get())); }
};
}
