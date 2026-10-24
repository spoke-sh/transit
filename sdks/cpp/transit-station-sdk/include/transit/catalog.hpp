#pragma once
#include <transit/catalog_values.hpp>

namespace transit::sdk::station::catalog {
using Recovery = std::variant<SavedIntent, Reference, SnapshotAcquisition, Snapshot>;
// Construct recovery before dispatch. Throwing this exception needs no copying
// or allocation of the original, even if receipt publication failed.
class Uncertain : public std::exception {
    transit_sdk_error failure_;
    Recovery original_;
public:
    Uncertain(transit_sdk_error failure, Recovery original) noexcept : failure_(failure), original_(std::move(original)) {}
    const char *what() const noexcept override { return "Transit catalog outcome is unknown; inspect the original recovery value"; }
    const transit_sdk_error &failure() const noexcept { return failure_; }
    const Recovery &original() const noexcept { return original_; }
};
class Client {
    std::unique_ptr<transit_station_catalog_client, decltype(&transit_station_catalog_client_destroy)> value_;
    explicit Client(transit_station_catalog_client *value) noexcept : value_(value, transit_station_catalog_client_destroy) {}
    static void dispatched(transit_sdk_error result, Recovery original) {
        if (result.kind == TRANSIT_SDK_UNKNOWN_OUTCOME) throw Uncertain(result, std::move(original));
        check(result);
    }
public:
    Client(Client &&) noexcept = default;
    Client &operator=(Client &&) noexcept = default;
    static Client open(const ClientConfig &config, const Credential &credential, const Connection &connection, const std::optional<std::string> &service_url = {}) {
        const auto settings = config.native(); const auto identity = credential.native(); transit_station_catalog_client *out = nullptr;
        check(transit_station_catalog_open(&settings, &identity, detail::native(connection), service_url ? detail::text(*service_url) : nullptr, &out)); return Client(out);
    }
    Capabilities capabilities() { Capabilities out{}; check(transit_station_catalog_capabilities_read(value_.get(), &out)); return out; }
    Description describe() { Description out{}; check(transit_station_catalog_describe(value_.get(), &out)); return out; }
    std::optional<Namespace> namespace_read(uint64_t id) { Namespace out{}; bool found = false; check(transit_station_catalog_namespace_read(value_.get(), id, &found, &out)); return found ? std::optional<Namespace>(out) : std::nullopt; }
    NamespacePage namespaces(const Cursor *cursor = nullptr) { transit_station_catalog_namespace_page *out = nullptr; check(transit_station_catalog_namespaces(value_.get(), cursor ? cursor->native() : nullptr, &out)); return NamespacePage(out); }
    TablePage tables(uint64_t namespace_id = 1, const Cursor *cursor = nullptr) { transit_station_catalog_table_page *out = nullptr; check(transit_station_catalog_tables(value_.get(), namespace_id, cursor ? cursor->native() : nullptr, &out)); return TablePage(out); }
    std::optional<Metadata> lookup(const std::string &name, uint64_t namespace_id = 1) {
        transit_station_catalog_metadata *out = nullptr; check(transit_station_catalog_lookup(value_.get(), detail::text(name), namespace_id, &out)); return out ? std::optional<Metadata>(Metadata(out)) : std::nullopt;
    }
    Compiled compile_sql(const std::string &sql, Identity identity, std::optional<uint64_t> create_object = {}, Dialect dialect = Dialect::Transit, Ingestion ingestion = Ingestion::Point) {
        transit_station_catalog_compiled *out = nullptr;
        check(transit_station_catalog_compile_sql(value_.get(), detail::text(sql), detail::native(identity), create_object ? &*create_object : nullptr, static_cast<uint32_t>(dialect), static_cast<uint32_t>(ingestion), &out)); return Compiled(out);
    }
    Compiled prepare(const std::string &name, Identity identity, const Action &action) { detail::RequestView request(name, identity, action); transit_station_catalog_compiled *out = nullptr; check(transit_station_catalog_prepare(value_.get(), &request.value, &out)); return Compiled(out); }
    Intent load(const SavedIntent &saved) { transit_station_catalog_intent *out = nullptr; check(transit_station_catalog_load(value_.get(), saved.native(), &out)); return Intent(out); }
    void forget(const Intent &intent) { check(transit_station_catalog_forget(value_.get(), intent.native())); }
    Preview preview(const Intent &intent) { transit_station_catalog_preview *out = nullptr; check(transit_station_catalog_preview_read(value_.get(), intent.native(), &out)); return Preview(out); }
    Reference stage(const Intent &intent) {
        Recovery original(intent.saved()); transit_station_catalog_reference *out = nullptr;
        dispatched(transit_station_catalog_stage(value_.get(), intent.native(), &out), std::move(original)); return Reference(out);
    }
    Observation admit(const Reference &reference) {
        Recovery original(Reference::copy(reference.native())); transit_station_catalog_observation *out = nullptr;
        dispatched(transit_station_catalog_admit(value_.get(), reference.native(), &out), std::move(original)); return Observation(out);
    }
    Observation inspect(const Reference &reference) { transit_station_catalog_observation *out = nullptr; check(transit_station_catalog_inspect(value_.get(), reference.native(), &out)); return Observation(out); }
    Observation execute(const Reference &reference, uint16_t steps = 256) {
        Recovery original(Reference::copy(reference.native())); transit_station_catalog_observation *out = nullptr;
        dispatched(transit_station_catalog_execute(value_.get(), reference.native(), steps, &out), std::move(original)); return Observation(out);
    }
    Observation cancel(const Reference &reference) {
        Recovery original(Reference::copy(reference.native())); transit_station_catalog_observation *out = nullptr;
        dispatched(transit_station_catalog_cancel(value_.get(), reference.native(), &out), std::move(original)); return Observation(out);
    }
    static SnapshotAcquisition prepare_snapshot(const Metadata &metadata, uint64_t operation) { transit_station_catalog_snapshot_acquisition *out = nullptr; check(transit_station_catalog_prepare_snapshot(metadata.native(), operation, &out)); return SnapshotAcquisition(out); }
    Snapshot acquire_snapshot(const SnapshotAcquisition &acquisition) {
        Recovery original(SnapshotAcquisition::copy(acquisition.native())); transit_station_catalog_snapshot *out = nullptr;
        dispatched(transit_station_catalog_acquire_snapshot(value_.get(), acquisition.native(), &out), std::move(original)); return Snapshot(out);
    }
    SnapshotStatus snapshot_status(const SnapshotOwner &owner) { transit_station_catalog_snapshot_status *out = nullptr; check(transit_station_catalog_snapshot_status_read(value_.get(), owner.native(), &out)); return SnapshotStatus(out); }
    SnapshotMetadata snapshot_metadata(const Snapshot &snapshot) { transit_station_catalog_snapshot_metadata *out = nullptr; check(transit_station_catalog_snapshot_metadata_read(value_.get(), snapshot.native(), &out)); return SnapshotMetadata(out); }
    void release_snapshot(const Snapshot &snapshot) { Recovery original(Snapshot::copy(snapshot.native())); dispatched(transit_station_catalog_release_snapshot(value_.get(), snapshot.native()), std::move(original)); }
    void close() { check(transit_station_catalog_close(value_.get())); }
};
}
