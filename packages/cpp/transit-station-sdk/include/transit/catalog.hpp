#pragma once
#include <transit/catalog_values.hpp>

namespace transit::sdk::station::catalog {
class Client {
    std::unique_ptr<transit_station_catalog_client, decltype(&transit_station_catalog_client_destroy)> value_;
    explicit Client(transit_station_catalog_client *value) : value_(value, transit_station_catalog_client_destroy) {}
    template<class F> Prepared prepare_command(F &&work) {
        transit_station_catalog_prepared *out = nullptr; check(work(&out)); return Prepared(out);
    }
public:
    Client(Client &&) noexcept = default;
    Client &operator=(Client &&) noexcept = default;
    static Client open(const ClientConfig &config, const Credential &credential, const Connection &connection) {
        const auto settings = config.native(); const auto identity = credential.native(); transit_station_catalog_client *out = nullptr;
        check(transit_station_catalog_open(&settings, &identity, {connection.owner.native(), detail::native(connection.scope)}, &out)); return Client(out);
    }
    Capabilities capabilities() {
        transit_station_catalog_capabilities v{}; check(transit_station_catalog_capabilities_read(value_.get(), &v));
        return {v.version, v.definition, v.max_columns, v.max_rows, v.max_sql_bytes, v.max_intent_bytes, v.max_action_bytes, v.max_prepared_bytes, v.resident_intents};
    }
    Description describe() {
        transit_station_catalog_description v{}; check(transit_station_catalog_describe(value_.get(), &v)); return {detail::from(v.configuration), detail::from(v.policy), v.resource_revision};
    }
    std::optional<Definition> lookup(const std::string &name) {
        transit_station_catalog_definition *out = nullptr; check(transit_station_catalog_lookup(value_.get(), detail::text(name), &out));
        std::unique_ptr<transit_station_catalog_definition, decltype(&transit_station_catalog_definition_destroy)> owner(out, transit_station_catalog_definition_destroy);
        if (!out) return {}; const transit_station_catalog_definition_view *v = nullptr; check(transit_station_catalog_definition_get(out, &v));
        return Definition{detail::from(v->metadata), detail::from(v->head), detail::from(v->schema)};
    }
    std::optional<HistoricalDefinition> definition(uint64_t object, uint64_t revision) {
        transit_station_catalog_historical *out = nullptr; check(transit_station_catalog_definition_read(value_.get(), object, revision, &out));
        std::unique_ptr<transit_station_catalog_historical, decltype(&transit_station_catalog_historical_destroy)> owner(out, transit_station_catalog_historical_destroy);
        if (!out) return {}; const transit_station_catalog_historical_view *v = nullptr; check(transit_station_catalog_historical_get(out, &v));
        return HistoricalDefinition{detail::from(v->metadata), detail::from(v->schema)};
    }
    Page list(const std::optional<Cursor> &cursor = {}) {
        transit_station_catalog_cursor before{}; if (cursor) before = detail::native(*cursor);
        transit_station_catalog_page v{}; check(transit_station_catalog_list(value_.get(), cursor ? &before : nullptr, &v)); Page out{v.resource_revision, {}, {}};
        for (size_t i = 0; i < v.count; ++i) out.entries.push_back({detail::from(v.entries[i].metadata), detail::from(v.entries[i].head)});
        if (v.has_next) out.next = detail::from(v.next); return out;
    }
    Compiled compile_sql(const std::string &sql, Identity identity, std::optional<uint64_t> create_object = {}) {
        transit_station_catalog_compiled *out = nullptr;
        check(transit_station_catalog_compile_sql(value_.get(), detail::text(sql), detail::native(identity), create_object ? &*create_object : nullptr, &out)); return Compiled(out);
    }
    Compiled prepare(const std::string &name, Identity identity, const Action &action) {
        detail::RequestView request(name, identity, action); transit_station_catalog_compiled *out = nullptr;
        check(transit_station_catalog_prepare(value_.get(), &request.value, &out)); return Compiled(out);
    }
    Intent load(const SavedIntent &saved) {
        transit_station_catalog_intent out{}; check(transit_station_catalog_load(value_.get(), saved.native(), &out)); return detail::from(out);
    }
    void forget(const Reference &reference) { const auto v = detail::native(reference); check(transit_station_catalog_forget(value_.get(), &v)); }
    Next next(const Reference &reference) {
        const auto ref = detail::native(reference); transit_station_catalog_next *out = nullptr; check(transit_station_catalog_next_read(value_.get(), &ref, &out));
        std::unique_ptr<transit_station_catalog_next, decltype(&transit_station_catalog_next_destroy)> owner(out, transit_station_catalog_next_destroy);
        transit_station_catalog_next_view v{}; check(transit_station_catalog_next_get(out, &v)); Next result{static_cast<NextKind>(v.kind), {}, {}};
        if (v.prepared) result.prepared = Prepared::copy(v.prepared); if (v.outcome) result.outcome = detail::from(*v.outcome); return result;
    }
    State status(const Reference &reference) { const auto v = detail::native(reference); transit_station_catalog_state out{}; check(transit_station_catalog_status_read(value_.get(), &v, &out)); return detail::from(out); }
    Prepared prepare_resume(const Reference &reference) {
        const auto v = detail::native(reference); return prepare_command([&](auto **out) { return transit_station_catalog_prepare_resume(value_.get(), &v, out); });
    }
    Prepared prepare_control(const Reference &reference, Control control) {
        const auto v = detail::native(reference); return prepare_command([&](auto **out) { return transit_station_catalog_prepare_control(value_.get(), &v, static_cast<uint32_t>(control), out); });
    }
    Prepared prepare_initialize(const Configuration &configuration) {
        const auto v = detail::native(configuration); return prepare_command([&](auto **out) { return transit_station_catalog_prepare_initialize(value_.get(), &v, out); });
    }
    Prepared prepare_policy(const PolicyChange &change) {
        const transit_station_catalog_policy_change v{change.expected_revision, detail::native(change.policy)};
        return prepare_command([&](auto **out) { return transit_station_catalog_prepare_policy(value_.get(), &v, out); });
    }
    Prepared prepare_dependency(const Dependency &dependency, bool present) {
        const auto v = detail::native(dependency); return prepare_command([&](auto **out) { return transit_station_catalog_prepare_dependency(value_.get(), &v, present, out); });
    }
    uint64_t submit(const Prepared &prepared) { uint64_t out = 0; check(transit_station_catalog_submit(value_.get(), prepared.native(), &out)); return out; }
    Observation observe(const Prepared &prepared, uint64_t input, bool wait = false) {
        transit_station_catalog_observation out{}; check(transit_station_catalog_observe(value_.get(), prepared.native(), input, wait, &out)); return static_cast<Observation>(out);
    }
    std::optional<Disposition> input_disposition(const Prepared &prepared, uint64_t input) {
        transit_station_catalog_disposition out{}; check(transit_station_catalog_input_disposition(value_.get(), prepared.native(), input, &out)); return detail::from(out);
    }
    Progress progress(const Reference &reference, const Prepared &prepared, uint64_t input, bool wait = false) {
        const auto ref = detail::native(reference); transit_station_catalog_progress out{};
        check(transit_station_catalog_progress_read(value_.get(), &ref, prepared.native(), input, wait, &out)); return {static_cast<Observation>(out.observation), detail::from(out.disposition), detail::from(out.state)};
    }
    void close() { check(transit_station_catalog_close(value_.get())); }
};
}
