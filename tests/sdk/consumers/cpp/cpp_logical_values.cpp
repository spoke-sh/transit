#include <transit/logical.hpp>
#include <cassert>
#include <cmath>
#include <cstring>
#include <iostream>
#include <limits>

using namespace transit::sdk;
using namespace transit::sdk::logical;
template<class F> static void invalid(F work) {
    try { work(); assert(false); } catch (const Error &e) { assert(e.detail().kind == TRANSIT_SDK_INVALID_ARGUMENT); }
}
static Bytes bytes(const std::string &text) { return Bytes(text.begin(), text.end()); }
static std::string string(const Bytes &value) { return std::string(value.begin(), value.end()); }
static void round(const Type &value) { assert(Type::decode(value.encode()).encode() == value.encode()); }
static void round(const Cell &value) { assert(Cell::decode(value.encode()).encode() == value.encode()); }
int main() {
    for (int i = TRANSIT_LOGICAL_INT8; i <= TRANSIT_LOGICAL_JSON; ++i) round(Type::scalar(static_cast<Kind>(i)));
    for (const auto kind : {TRANSIT_LOGICAL_UNKNOWN, TRANSIT_LOGICAL_NULL_VALUE, TRANSIT_LOGICAL_TEXT, TRANSIT_LOGICAL_CHARACTER}) {
        round(Cell::type_error(kind)); invalid([&] { Type::scalar(kind); });
    }
    const auto integer = Type::scalar(TRANSIT_LOGICAL_INT128);
    for (const auto &value : {Type::decimal(38, 38), Type::timestamp(TRANSIT_LOGICAL_CIVIL), Type::timestamp(TRANSIT_LOGICAL_UTC),
        Type::structure({{"x", integer, false, true}}), Type::tagged_union({{"x", integer}}),
        Type::list(integer), Type::array(integer, UINT32_MAX), Type::map(integer, Type::scalar(TRANSIT_LOGICAL_UTF8))}) round(value);
    auto nested = integer; for (size_t i = 0; i < 15; ++i) nested = Type::list(nested);
    round(nested); invalid([&] { Type::list(nested); });
    invalid([&] { Type::decimal(39, 0); }); invalid([&] { Type::decimal(2, 3); }); invalid([&] { Type::array(integer, 0); });
    std::vector<Field> fields(255, {"", integer}); round(Type::structure(fields));
    fields.push_back({"", integer}); invalid([&] { Type::structure(fields); });
    round(Type::structure({{std::string(4096, 'x'), integer}}));
    invalid([&] { Type::structure({{std::string(4097, 'x'), integer}}); });
    invalid([&] { Type::structure({{std::string(3000, 'x'), integer}, {std::string(3000, 'x'), integer}}); });
    const auto min = Atom::signed_integer(Int128{0, INT64_MIN});
    const auto max = Atom::signed_integer(Int128{UINT64_MAX, INT64_MAX});
    const auto umax = Atom::unsigned_integer(Uint128{UINT64_MAX, UINT64_MAX});
    assert(string(Cell::atom(min).encode()).find("-170141183460469231731687303715884105728") != std::string::npos);
    assert(string(Cell::atom(max).encode()).find("170141183460469231731687303715884105727") != std::string::npos);
    assert(string(Cell::atom(umax).encode()).find("340282366920938463463374607431768211455") != std::string::npos);
    for (const auto &atom : {min, max, umax, Atom::decimal({UINT64_MAX, INT64_MAX}), Atom::float32(-0.0f), Atom::float64(-0.0),
        Atom::boolean(true), Atom::utf8(std::string("a\0\xc3\xa9", 4)), Atom::binary({0, 255}), Atom::date_days(INT32_MIN),
        Atom::time_nanos(UINT64_MAX), Atom::timestamp_micros(INT64_MIN), Atom::interval(INT32_MIN, INT32_MAX, INT64_MIN), Atom::uuid({})}) round(Cell::atom(atom));
    assert(std::signbit(Cell::decode(Cell::atom(Atom::float64(-0.0)).encode()).atom().native().as.float64));
    invalid([] { Atom::float32(std::numeric_limits<float>::infinity()); });
    invalid([] { Atom::float64(std::numeric_limits<double>::quiet_NaN()); });
    invalid([] { Atom::utf8(std::string("\xc0\xaf", 2)); });
    const auto null = Cell::null(); const auto present = Cell::atom(Atom::signed_integer(7));
    for (const auto &v : {Cell::missing(), null, Cell::type_error(TRANSIT_LOGICAL_MAP), present,
        Cell::structure({null, present}), Cell::list({null, present}), Cell::array({present}),
        Cell::map({{Atom::utf8("x"), present}}), Cell::tagged_union(255, present), Cell::json("{\"x\":1}"),
        Cell::conflict({{1, UINT64_MAX, present}, {UINT64_MAX, 1, null}})}) round(v);
    auto deep = Cell::conflict({{1, 1, present}, {2, 1, null}});
    for (size_t i = 0; i < 15; ++i) deep = Cell::list({deep});
    round(deep); invalid([&] { Cell::list({deep}); });
    auto deep_map = present; for (size_t i = 0; i < 15; ++i) deep_map = Cell::map({{Atom::signed_integer(1), deep_map}});
    round(deep_map);
    invalid([&] { Cell::conflict({{2, 1, present}, {1, 1, null}}); });
    invalid([&] { Cell::conflict({{1, 1, Cell::missing()}, {2, 1, null}}); });
    invalid([&] { Cell::conflict({{0, 1, null}, {2, 1, null}}); });
    std::vector<Cell> cells(65535, null); round(Cell::list(cells));
    cells.push_back(null); invalid([&] { Cell::list(cells); });
    std::vector<std::pair<Atom, Cell>> entries(32767, {Atom::signed_integer(1), null}); round(Cell::map(entries));
    entries.push_back({Atom::signed_integer(1), null}); invalid([&] { Cell::map(entries); });
    round(Cell::atom(Atom::binary(Bytes(1048576, 9))));
    auto big = Cell::atom(Atom::binary(Bytes(600000, 9)));
    invalid([&] { Cell::list({big, big}); });
    auto almost = Cell::atom(Atom::binary(Bytes(1048576 - 4, 9)));
    round(Cell::list({almost, Cell::atom(Atom::float32(0))}));
    invalid([&] { Cell::list({almost, Cell::atom(Atom::float64(0))}); });
    invalid([] { Atom::binary(Bytes(1048577, 0)); });
    const std::vector<std::string> malformed = {
        "", "null", "{}", "{\"null\":{},\"null\":{}}", "{\"null\":{},\"n\\u0075ll\":{}}", "{\"null\":{\"extra\":0}}",
        "{\"null\":{}} true", "{\"value\":{\"atom\":{\"signed\":\"-0\"}}}", "{\"value\":{\"atom\":{\"signed\":\"01\"}}}",
        "{\"value\":{\"atom\":{\"signed\":\"170141183460469231731687303715884105728\"}}}",
        "{\"value\":{\"atom\":{\"unsigned\":\"340282366920938463463374607431768211456\"}}}",
        "{\"value\":{\"atom\":{\"float_bits\":\"0000807f\"}}}", "{\"value\":{\"atom\":{\"binary\":\"FF\"}}}",
        "{\"value\":{\"atom\":{\"utf8\":\"\\ud800\"}}}", "{\"value\":{\"atom\":{\"utf8\":\"\\udc00\"}}}"};
    for (const auto &s : malformed) invalid([&] { Cell::decode(bytes(s)); });
    // The C++ model has the same explicit companion-family refusal as its C
    // owner, including nested descriptors and present cells. Empty cell states
    // remain independent of a descriptor.
    for (const auto &s : {R"({"range":{"int64":{}}})", R"({"multirange":{"int64":{}}})",
                          R"({"vector":{"dimensions":3,"element":"float32"}})"}) {
        invalid([&] { Type::decode(bytes(s)); });
        invalid([&] { Type::decode(bytes(std::string("{\"list\":{\"type\":") + s + ",\"nullable\":true}}")); });
    }
    for (const auto &s : {R"({"value":{"range":{"is_empty":true,"lower":null,"upper":null}}})",
                          R"({"value":{"multirange":[]}})", R"({"value":{"vector":"00000000"}})"}) {
        invalid([&] { Cell::decode(bytes(s)); });
        invalid([&] { Cell::decode(bytes(std::string("{\"value\":{\"list\":[") + s + "]}}")); });
    }
    const auto valid = Cell::map({{Atom::utf8("\xf0\x9f\x98\x80"), present}}).encode();
    for (size_t i = 0; i < valid.size(); ++i) invalid([&] { Cell::decode(Bytes(valid.begin(), valid.begin() + i)); });
    round(Cell::decode(bytes("{\"value\":{\"atom\":{\"utf8\":\"\\ud83d\\ude00\"}}}")));
    auto retained = Cell::decode(valid).entries(); assert(retained[0].second.atom().native().as.signed_value.low == 7);
    std::cout << "C++ logical families, exact values, owned children, recursive budgets and malformed JSON passed.\n";
}
