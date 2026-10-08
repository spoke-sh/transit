#pragma once
#include <transit/station_values.hpp>
#include <transit/catalog_values.hpp>
#include <transit/table.h>

namespace transit::sdk::station {
class Turn;
using TableSchema = catalog::Schema;
using TableLimits = catalog::Limits;
struct RowIdentity { std::array<uint8_t, 20> bytes; };
struct Row { RowIdentity identity; std::vector<logical::Cell> cells; };
struct TableBasis { ResourceRef resource; uint64_t revision, object; std::array<uint8_t, 32> head; };
enum class TableCreationState { Building, Applied };
struct TableCreation { TableCreationState state; uint64_t admitted_input; std::optional<uint64_t> completed_input; };
enum class TableMutationState { Building, Applied, Rejected, Cancelled };
enum class TableMutationRoute { Point, Statement, Alter };
enum class TableRejection { None, RowExists, RowIdentityExists, NullNotAllowed, MissingRequiredField, CharacterLimitExceeded, Overflow, Inexact };
enum class TableWitnessSource { Input, Stored, Withheld };
struct TableWitness { TableWitnessSource source; std::optional<RowIdentity> row; uint64_t column; std::string text; bool truncated; };
struct TableInsert { std::vector<std::vector<catalog::Assignment>> rows; };
struct TableUpdate { std::vector<catalog::Assignment> assignments; std::optional<catalog::Predicate> predicate; };
struct TableDelete { std::optional<catalog::Predicate> predicate; };
using TableMutationSpec = std::variant<TableInsert, TableUpdate, TableDelete>;
struct TableMutationStatus;
class TableMutationReference {
    transit_station_table_reference value_;
public:
    explicit TableMutationReference(transit_station_table_reference value) : value_(value) {
        transit_sdk_buffer validated{}; check(transit_station_table_reference_export(&value_, &validated)); Buffer owner(validated);
    }
    const transit_station_table_reference &native() const { return value_; }
    static TableMutationReference recover(const Bytes &bytes) { transit_station_table_reference out{}; check(transit_station_table_reference_import(bytes_view(bytes), &out)); return TableMutationReference(out); }
    Bytes save() const { transit_sdk_buffer out{}; check(transit_station_table_reference_export(&value_, &out)); return Buffer(out).copy(); }
    std::optional<TableMutationStatus> status(const Turn &) const;
    TableMutationStatus cancel(const Turn &) const;
};
struct TableMutationStatus {
    TableMutationReference reference;
    TableMutationState state;
    TableMutationRoute route;
    uint64_t admitted_input;
    std::optional<uint64_t> completed_input;
    std::optional<catalog::Counts> counts;
    TableRejection rejection;
    std::optional<TableWitness> witness;
};
namespace table_detail {
inline RowIdentity from(transit_station_row_identity v) { RowIdentity out{}; std::copy_n(v.bytes, 20, out.bytes.begin()); return out; }
inline Row from(transit_station_row_view v) {
    Row out{from(v.identity), {}}; out.cells.reserve(v.cell_count);
    for (size_t i = 0; i < v.cell_count; ++i) out.cells.emplace_back(v.cells[i]); return out;
}
inline TableCreation from(transit_station_table_creation v) {
    TableCreation out{static_cast<TableCreationState>(v.state), v.admitted_input, {}};
    if (v.has_completed_input) out.completed_input = v.completed_input; return out;
}
inline TableMutationStatus from(const transit_station_table_status &v) {
    TableMutationStatus out{TableMutationReference(v.reference), static_cast<TableMutationState>(v.state), static_cast<TableMutationRoute>(v.route), v.admitted_input, {}, {}, static_cast<TableRejection>(v.rejection), {}};
    if (v.has_completed_input) out.completed_input = v.completed_input;
    if (v.has_counts) out.counts = catalog::Counts{v.counts.matched, v.counts.changed};
    if (v.has_witness) {
        const auto &w = v.witness; out.witness = TableWitness{static_cast<TableWitnessSource>(w.source), {}, w.column, std::string(w.text, w.text_bytes), w.truncated};
        if (w.has_row) out.witness->row = from(w.row);
    }
    return out;
}
// Views borrow their input only through the synchronous C call. They cannot
// move because native array pointers address their own bounded vectors.
struct SchemaView {
    std::vector<transit_station_catalog_column> columns;
    transit_station_catalog_schema value{};
    explicit SchemaView(const TableSchema &s) {
        catalog::detail::require(!s.columns.empty() && s.columns.size() <= 128 && s.primary_key.size() <= s.columns.size());
        columns.reserve(s.columns.size());
        for (const auto &c : s.columns) columns.push_back({c.id, catalog::detail::text(c.name), &c.type.native(), c.nullable, catalog::detail::cell(c.default_value), catalog::detail::characters(c.max_characters)});
        value = {s.object, s.revision, s.next_column, columns.data(), columns.size(), s.primary_key.data(), s.primary_key.size()};
    }
    SchemaView(const SchemaView &) = delete;
};
class MutationView {
    std::vector<std::vector<transit_station_catalog_assignment>> assignments_;
    std::vector<transit_station_catalog_assignments> rows_;
    std::vector<transit_station_catalog_predicate_term> terms_;
    transit_station_catalog_assignments assignments(const std::vector<catalog::Assignment> &values) {
        catalog::detail::require(values.size() <= 128); assignments_.emplace_back(); auto &out = assignments_.back(); out.reserve(values.size());
        for (const auto &a : values) out.push_back({a.column, catalog::detail::cell(a.value)}); return {out.data(), out.size()};
    }
    transit_station_catalog_predicate predicate(const std::optional<catalog::Predicate> &value) {
        if (!value) return {}; catalog::detail::require(!value->empty() && value->size() <= 64); terms_.reserve(value->size());
        for (const auto &term : *value) {
            transit_station_catalog_predicate_term out{};
            std::visit([&](const auto &v) {
                using T = std::decay_t<decltype(v)>;
                if constexpr (std::is_same_v<T, catalog::All>) out.kind = TRANSIT_CATALOG_ALL;
                else if constexpr (std::is_same_v<T, catalog::IsState>) { out.kind = TRANSIT_CATALOG_STATE; out.column = v.column; out.as.state = v.state; }
                else if constexpr (std::is_same_v<T, catalog::Compare>) { out.kind = TRANSIT_CATALOG_COMPARE; out.column = v.column; out.as.compare = {static_cast<uint32_t>(v.op), v.value.native()}; }
                else if constexpr (std::is_same_v<T, catalog::Negate>) out.kind = TRANSIT_CATALOG_NOT;
                else if constexpr (std::is_same_v<T, catalog::Conjunction>) out.kind = TRANSIT_CATALOG_AND;
                else out.kind = TRANSIT_CATALOG_OR;
            }, term); terms_.push_back(out);
        }
        return {terms_.data(), terms_.size()};
    }
public:
    transit_station_table_mutation_spec value{};
    explicit MutationView(const TableMutationSpec &spec) {
        std::visit([&](const auto &v) {
            using T = std::decay_t<decltype(v)>;
            if constexpr (std::is_same_v<T, TableInsert>) {
                catalog::detail::require(!v.rows.empty() && v.rows.size() <= 1024); assignments_.reserve(v.rows.size()); rows_.reserve(v.rows.size());
                for (const auto &row : v.rows) rows_.push_back(assignments(row)); value.kind = TRANSIT_TABLE_INSERT; value.as.insert = {rows_.data(), rows_.size()};
            } else if constexpr (std::is_same_v<T, TableUpdate>) { value.kind = TRANSIT_TABLE_UPDATE; value.as.update = {assignments(v.assignments), predicate(v.predicate)}; }
            else { value.kind = TRANSIT_TABLE_DELETE; value.as.remove = predicate(v.predicate); }
        }, spec);
    }
    MutationView(const MutationView &) = delete;
};
}
class TableMutation {
    std::unique_ptr<transit_station_table_mutation, decltype(&transit_station_table_mutation_destroy)> value_;
public:
    explicit TableMutation(transit_station_table_mutation *value) : value_(value, transit_station_table_mutation_destroy) {}
    TableMutation(TableMutation &&) noexcept = default;
    TableMutation &operator=(TableMutation &&) noexcept = default;
    static TableMutation prepare(ResourceRef resource, uint64_t principal, uint64_t operation, const TableSchema &schema, const TableMutationSpec &spec) {
        const table_detail::SchemaView s(schema); const table_detail::MutationView m(spec); transit_station_table_mutation *out = nullptr;
        check(transit_station_table_mutation_prepare(resource.native(), principal, operation, &s.value, &m.value, &out)); return TableMutation(out);
    }
    static TableMutation recover(const Bytes &bytes) { transit_station_table_mutation *out = nullptr; check(transit_station_table_mutation_import(bytes_view(bytes), &out)); return TableMutation(out); }
    Bytes save() const { transit_sdk_bytes out{}; check(transit_station_table_mutation_bytes(value_.get(), &out)); return copy_bytes(out); }
    TableSchema schema() const { const transit_station_catalog_schema *out = nullptr; check(transit_station_table_mutation_schema(value_.get(), &out)); return catalog::detail::from(*out); }
    TableMutationStatus step(const Turn &) const;
};
}
