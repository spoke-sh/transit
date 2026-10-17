#include <transit/client.hpp>
#include <cassert>
#include <type_traits>
using namespace transit::sdk;
static_assert(!std::is_copy_constructible_v<Client>);
static_assert(!std::is_copy_constructible_v<PendingSend>);
static_assert(!std::is_copy_constructible_v<PendingMutation>);
static_assert(std::is_nothrow_move_constructible_v<Client>);
static_assert(!std::is_convertible_v<ResourceRef, ProcessRef>);
int main() {
    try { ProcessRef invalid(72, 0); return 1; } catch (const Error &error) { assert(error.detail().kind == TRANSIT_SDK_INVALID_ARGUMENT); }
    ProcessRef valid(72, 65536); assert(valid.pid() == 65536);
    try { auto invalid = ClientConfig::growing(std::string("http://local\0hidden", 19)); return 1; }
    catch (const Error &error) { assert(error.detail().kind == TRANSIT_SDK_INVALID_ARGUMENT); }
}
