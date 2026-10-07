#include "../src/table_internal.hpp"
#include <transit/unified_query.h>
#include <cassert>
#include <cstring>
#include <iostream>
using namespace transit::sdk::internal;
namespace t = transit::sdk::table_detail;
namespace l = transit::sdk::logical_detail;
using J = l::Json;
static J &field(J &v, const char *key) { for (auto &entry : v.members) if (entry.first == key) return entry.second; std::abort(); }
static unsigned rejected = 0;
template<class F> static void reject(F f) { bool caught = false; try { f(); } catch (const Failure &) { caught = true; } assert(caught); ++rejected; }
static transit_sdk_bytes bytes(const std::string &v) { return {reinterpret_cast<const uint8_t *>(v.data()), v.size()}; }
extern "C" void transit_test_table_c11(void);
int main() try {
    transit_test_table_c11();
    transit_logical_type_view integer{}; integer.kind = TRANSIT_LOGICAL_INT128;
    transit_logical_type_view string{}; string.kind = TRANSIT_LOGICAL_UTF8;
    transit_logical_cell_view nil{}; nil.state = TRANSIT_LOGICAL_NULL;
    char name[] = "id";
    transit_station_catalog_column columns[] = {{1, name, &integer, false, nullptr, 0}, {2, "name", &string, true, &nil, 23}};
    const uint64_t key[] = {1}; transit_station_catalog_schema schema{UINT64_MAX, 1, 3, columns, 2, key, 1};
    transit_station_catalog_assignment assignments[] = {{1, &nil}, {2, nullptr}};
    const transit_station_catalog_assignments row{assignments, 2};
    transit_station_table_mutation_spec insert{}; insert.kind = TRANSIT_TABLE_INSERT; insert.as.insert = {&row, 1};
    transit_station_table_mutation *raw = nullptr;
    assert(transit_station_table_mutation_prepare({46, 7}, 0, UINT64_MAX, &schema, &insert, &raw).kind == TRANSIT_SDK_OK);
    std::unique_ptr<transit_station_table_mutation, decltype(&transit_station_table_mutation_destroy)> saved(raw, transit_station_table_mutation_destroy);
    transit_sdk_bytes data{}; assert(transit_station_table_mutation_bytes(saved.get(), &data).kind == TRANSIT_SDK_OK);
    const std::string original(reinterpret_cast<const char *>(data.data), data.size);
    name[0] = 'x'; columns[0].id = 99; assignments[0].column = 99;
    const transit_station_catalog_schema *owned_schema = nullptr; assert(transit_station_table_mutation_schema(saved.get(), &owned_schema).kind == TRANSIT_SDK_OK);
    assert(owned_schema->object == UINT64_MAX && owned_schema->columns[0].id == 1 && std::strcmp(owned_schema->columns[0].name, "id") == 0);
    auto value = t::parse(original);
    auto loaded = t::load(bytes(original)); assert(loaded->bytes == original && loaded->operation == UINT64_MAX);
    saved.reset(); assert(loaded->schema.columns[1].default_value->state == TRANSIT_LOGICAL_NULL);
    auto bad = [&](auto change) { auto v = value; change(v); const auto text = l::encode(v); reject([&] { t::load(bytes(text)); }); };
    bad([](J &v) { v.members.erase(v.members.begin()); });
    bad([](J &v) { v.members.emplace_back("extra", J{}); });
    bad([](J &v) { field(v, "operation") = J::string("0"); });
    bad([](J &v) { field(v, "operation") = J::string("01"); });
    bad([](J &v) { field(v, "operation") = J::string("18446744073709551616"); });
    bad([](J &v) { field(v, "principal") = J::integer(TRANSIT_CLIENT_MAX_COUNTER + 1); });
    bad([](J &v) { field(v, "realm") = J::integer(0); });
    bad([](J &v) { field(field(v, "schema"), "definition") = J::string(std::string(64, '0')); });
    bad([](J &v) { field(v, "schema").members.erase(field(v, "schema").members.begin()); });
    bad([](J &v) { field(field(v, "schema"), "columns").items.clear(); });
    bad([](J &v) { auto &c = field(field(v, "schema"), "columns"); c.items.resize(129, c.items.front()); });
    bad([](J &v) { field(field(field(v, "schema"), "columns").items[0], "type") = J::object({{"unknown", J::object()}}); });
    bad([](J &v) { field(field(v, "mutation"), "predicate") = J::array(); });
    bad([](J &v) { field(field(v, "mutation"), "action") = J::object({{"upsert", J::object()}}); });
    bad([](J &v) { field(field(field(v, "mutation"), "action"), "insert").items.clear(); });
    bad([](J &v) { auto &r = field(field(field(v, "mutation"), "action"), "insert"); r.items.resize(1025, r.items.front()); });
    bad([](J &v) { auto &r = field(field(field(v, "mutation"), "action"), "insert").items[0]; r.items.resize(129, r.items.front()); });
    bad([](J &v) { auto &a = field(field(field(v, "mutation"), "action"), "insert").items[0].items[0]; field(a, "column") = J::string("0"); });
    bad([](J &v) { auto &a = field(field(field(v, "mutation"), "action"), "insert").items[0].items[1]; field(a, "value") = J::object({{"default", J::object({{"extra", J{}}})}}); });
    reject([&] { t::load(bytes(original + " ")); });
    reject([&] { t::load(bytes("{\"realm\":46," + original.substr(1))); });
    reject([&] { t::action("mutate", std::string(t::bound, ' ')); });
    assert(t::action("mutate", std::string(t::bound - 21, ' ')).size() == t::bound);
    reject([&] { t::action("mutate", std::string(t::bound - 20, ' ')); });
    // A logical map adds several JSON wrappers per level. Fifteen maps fit the
    // logical depth contract but require the complete 96-level transport parser.
    auto nested = J::object({{"value", J::object({{"atom", J::object({{"utf8", J::string("leaf")}})}})}});
    const auto key_cell = J::object({{"signed", J::string("1")}});
    for (int i = 0; i < 15; ++i) { auto entries = J::array(); entries.items.push_back(J::object({{"key", key_cell}, {"value", nested}})); nested = J::object({{"value", J::object({{"map", entries}})}}); }
    auto deep = value; auto &a = field(field(field(deep, "mutation"), "action"), "insert").items[0].items[0]; field(a, "value") = J::object({{"cell", nested}});
    const auto deep_bytes = l::encode(deep); reject([&] { l::JsonParser(deep_bytes, t::bound, 64).parse(); });
    assert(t::load(bytes(deep_bytes))->bytes == deep_bytes);
    auto update = value; auto &m = field(update, "mutation"); field(m, "action") = J::object({{"update", J::array()}});
    field(m, "predicate") = J::array(); field(m, "predicate").items.push_back(J::object({{"atom", J::object({{"all", J::object()}})}}));
    assert(t::load(bytes(l::encode(update))));
    field(m, "predicate").items.push_back(J::object({{"negate", J::object()}})); assert(t::load(bytes(l::encode(update))));
    field(m, "predicate").items.push_back(J::object({{"conjunction", J::object()}})); reject([&] { t::load(bytes(l::encode(update))); });
    transit_station_table_reference reference{}; std::strcpy(reference.definition, STATION_ABI_DEFINITION); reference.resource = {46, 7}; reference.object = reference.operation = UINT64_MAX;
    const auto r = t::reference_wire(reference); assert(t::same_reference(reference, t::reference(r)));
    transit_sdk_buffer exported{}; assert(transit_station_table_reference_export(&reference, &exported).kind == TRANSIT_SDK_OK);
    transit_station_table_reference imported{}; assert(transit_station_table_reference_import({exported.data, exported.size}, &imported).kind == TRANSIT_SDK_OK); transit_sdk_buffer_release(&exported);
    assert(t::same_reference(reference, imported)); reference.definition[0] = '0'; reject([&] { t::reference_wire(reference); });
    J status = J::object({{"reference", r}, {"state", J::string("applied")}, {"route", J::string("statement")}, {"admitted_input", J::integer(9)}, {"completed_input", J::integer(10)},
        {"counts", J::object({{"matched", J::string("3")}, {"changed", J::string("2")}})}, {"rejection", J::string("none")}, {"witness", J{}}});
    assert(t::status(status).counts.changed == 2);
    auto invalid_status = [&](auto change) { auto v = status; change(v); reject([&] { t::status(v); }); };
    invalid_status([](J &v) { field(v, "counts") = J{}; });
    invalid_status([](J &v) { field(v, "completed_input") = J{}; });
    invalid_status([](J &v) { field(v, "completed_input") = J::integer(8); });
    invalid_status([](J &v) { field(field(v, "counts"), "changed") = J::string("4"); });
    invalid_status([](J &v) { field(v, "state") = J::string("building"); });
    invalid_status([](J &v) { field(v, "rejection") = J::string("row_exists"); });
    const auto creation = J::object({{"state", J::string("building")}, {"admitted_input", J::integer(9)}, {"completed_input", J::integer(0)}});
    assert(!t::creation(creation).has_completed_input); auto wrong_creation = creation; field(wrong_creation, "completed_input") = J::integer(9); reject([&] { t::creation(wrong_creation); });
    auto cells = J::array(); cells.items.push_back(nested); const auto row_value = J::object({{"identity", J::string(std::string(40, 'a'))}, {"cells", cells}});
    auto owned_row = t::row(row_value, 1); transit_station_row_view row_view{}; assert(transit_station_row_inspect(owned_row.get(), &row_view).kind == TRANSIT_SDK_OK && row_view.cell_count == 1 && row_view.identity.bytes[0] == 0xaa);
    reject([&] { t::row(row_value, 2); });
    transit_station_table_mutation *cleared = reinterpret_cast<transit_station_table_mutation *>(1);
    assert(transit_station_table_mutation_import({nullptr, 5}, &cleared).kind != TRANSIT_SDK_OK && !cleared);
    transit_station_table_status cleared_status{}; cleared_status.admitted_input = 99;
    assert(transit_station_table_mutation_step(nullptr, loaded.get(), &cleared_status).kind != TRANSIT_SDK_OK && !cleared_status.admitted_input);
    // Scope/thread/poison guards are local SDK state. No transport is supplied:
    // these cases must terminate before issuing a native action.
    std::atomic<bool> stop{false}; transit_station_turn_info info{}; info.resource = {46, 7}; info.process = {46, 3};
    auto scope = std::unique_ptr<transit_station_turn, decltype(&transit_station_turn_release)>(new transit_station_turn(nullptr, stop, 1, info, {}), transit_station_turn_release);
    auto table = std::make_unique<transit_station_table>(*scope); table->schema = loaded->schema; table->basis.resource = info.resource;
    const transit_station_catalog_schema *captured = nullptr;
    assert(transit_station_table_schema(table.get(), &captured).kind == TRANSIT_SDK_OK && captured->object == UINT64_MAX);
    transit_sdk_error foreign_thread{};
    std::thread other([&] { transit_station_table_basis b{}; foreign_thread = transit_station_table_read_basis(table.get(), &b); }); other.join();
    assert(foreign_thread.kind == TRANSIT_SDK_BUSY && scope->poison.kind == TRANSIT_SDK_OK);
    table->retained = transit_station_read_version{3, 9, 0};
    assert(transit_station_table_prepare(table.get(), 0, 1, &insert, &cleared).kind != TRANSIT_SDK_OK && !cleared && scope->poison.kind == TRANSIT_SDK_OK);
    transit_sdk_error conversion{}; conversion.kind = TRANSIT_SDK_OUT_OF_MEMORY;
    assert(transit_station_table_fail_read(table.get(), conversion).kind == TRANSIT_SDK_OUT_OF_MEMORY && scope->poison.kind == TRANSIT_SDK_OUT_OF_MEMORY);
    captured = &loaded->schema;
    assert(transit_station_table_schema(table.get(), &captured).kind == TRANSIT_SDK_OUT_OF_MEMORY && !captured);
    scope->active = false;
    assert(transit_station_table_schema(table.get(), &captured).kind == TRANSIT_SDK_TURN_EXPIRED && !captured);
    auto scope2 = std::unique_ptr<transit_station_turn, decltype(&transit_station_turn_release)>(new transit_station_turn(nullptr, stop, 2, info, {}), transit_station_turn_release);
    bool found = true; auto wrong_resource = imported; wrong_resource.resource.resource = 8;
    assert(transit_station_table_status_read(scope2.get(), &wrong_resource, &found, &cleared_status).kind != TRANSIT_SDK_OK && !found && scope2->poison.kind != TRANSIT_SDK_OK);
    assert(transit_station_table_mutation_step(scope2.get(), loaded.get(), &cleared_status).kind == scope2->poison.kind);
    std::cout << "C handler Table ownership and " << rejected << " rejection cases pass\n";
}

catch (const Failure &e) { std::cerr << e.value.phase << "\n"; return 1; }
