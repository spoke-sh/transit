#include <transit/station.hpp>
#include <transit/unified_query.hpp>
#include <transit/catalog.hpp>
#include <transit/logical.hpp>
#include <cassert>
#include <iostream>
using namespace transit::sdk;
using namespace transit::sdk::station;
static_assert(!std::is_copy_constructible_v<Runner<uint64_t>>);
static_assert(!std::is_copy_constructible_v<Table>);
static_assert(!std::is_copy_constructible_v<unified::Client>);
static_assert(!std::is_copy_constructible_v<unified::Prepared>);
static_assert(std::is_move_constructible_v<unified::Page>);
static_assert(!std::is_copy_constructible_v<catalog::Client>);
static_assert(!std::is_copy_constructible_v<catalog::Compiled>);
static_assert(!std::is_copy_constructible_v<catalog::SnapshotAcquisition>);
static_assert(std::is_move_constructible_v<catalog::SnapshotAcquisition>);
static_assert(!std::is_copy_constructible_v<TableMutation>);
static_assert(std::is_move_constructible_v<TableMutation>);
static_assert(std::is_copy_constructible_v<TableMutationReference>);
static_assert(std::is_copy_constructible_v<Row>);
static_assert(std::is_copy_constructible_v<Turn>); // Copies retain scope checks, not native authority.
static_assert(std::is_copy_constructible_v<logical::Type>);
static_assert(std::is_copy_constructible_v<logical::Cell>);
template class transit::sdk::station::Runner<uint64_t>;
int main() {
    auto options = RunnerOptions::fresh_ownership(); assert(!options.store);
    auto descriptor = logical::Type::structure({{"value", logical::Type::scalar(TRANSIT_LOGICAL_INT128), true, false}});
    assert(logical::Type::decode(descriptor.encode()).fields()[0].type.kind() == TRANSIT_LOGICAL_INT128);
    auto nested = logical::Cell::list({logical::Cell::atom(logical::Atom::unsigned_integer(UINT64_MAX)), logical::Cell::null()});
    assert(logical::Cell::decode(nested.encode()).children().size() == 2);
    TableSchema schema{UINT64_MAX, 1, 5, {
        {1, "id", logical::Type::scalar(TRANSIT_LOGICAL_INT128), false, {}, {}},
        {2, "name", logical::Type::scalar(TRANSIT_LOGICAL_UTF8), true, logical::Cell::null(), 23},
        {3, "amount", logical::Type::decimal(18, 2), true, {}, {}},
        {4, "tags", logical::Type::list(logical::Type::scalar(TRANSIT_LOGICAL_BINARY)), true, {}, {}}
    }, {1}};
    TableMutationSpec insert = TableInsert{{{{1, logical::Cell::atom(logical::Atom::signed_integer(7))}, {2, std::nullopt}, {4, nested}}}};
    auto saved = TableMutation::prepare(ResourceRef(46, 7), 0, UINT64_MAX, schema, insert);
    const auto bytes = saved.save(); schema.columns[0].name = "changed"; std::get<TableInsert>(insert).rows.clear();
    assert(saved.schema().columns[0].name == "id" && saved.schema().columns.size() == 4 && saved.save() == bytes);
    auto restored = TableMutation::recover(bytes); auto retained_schema = restored.schema();
    assert(restored.save() == bytes && retained_schema.object == UINT64_MAX && retained_schema.columns[1].default_value->state() == TRANSIT_LOGICAL_NULL);
    const auto update = TableUpdate{{{2, std::nullopt}}, catalog::Predicate{catalog::Compare{1, catalog::CompareOp::Eq, logical::Atom::signed_integer(7)}, catalog::Negate{}}};
    assert(!TableMutation::prepare(ResourceRef(46, 7), 0, 2, retained_schema, update).save().empty());
    assert(!TableMutation::prepare(ResourceRef(46, 7), 0, 3, retained_schema, TableDelete{}).save().empty());
    auto rejects = [](auto work) { bool failed = false; try { work(); } catch (const Error &) { failed = true; } assert(failed); };
    rejects([&] { TableMutation::prepare(ResourceRef(46, 7), 0, 0, retained_schema, TableDelete{}); });
    rejects([&] { TableMutation::prepare(ResourceRef(46, 7), 0, 4, retained_schema, TableInsert{}); });
    rejects([&] { TableMutation::prepare(ResourceRef(46, 7), 0, 4, retained_schema, TableDelete{catalog::Predicate{catalog::Conjunction{}}}); });
    auto foreign = bytes; const std::string definition = TRANSIT_SDK_STATION_DEFINITION;
    const auto at = std::search(foreign.begin(), foreign.end(), definition.begin(), definition.end()); assert(at != foreign.end()); std::fill_n(at, 64, '0');
    rejects([&] { TableMutation::recover(foreign); });
    unified::Plan plan{{0, 1, 2, 3}, unified::Compare{0, Comparison::Eq, logical::Atom::signed_integer(7)}, Aggregate::Rows, UINT64_MAX, {}};
    const QueryPlan frozen(plan); plan.projection.clear(); plan.limit = 0;
    const unified::detail::PlanView view(frozen.value()); assert(view.value.projection_count == 4 && view.value.limit == UINT64_MAX && view.value.column == 0);

    std::cout << "C++ handler Table ownership, saved recovery, general plan and malformed input checks pass\n";
}
