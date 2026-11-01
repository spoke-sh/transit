# Language consumers

Each directory contains programs copied or compiled into private installations,
plus the Python builder that connects them to a shared SDK schedule.

| Language | Directory |
| --- | --- |
| Public Zig SDK performance | [zig/](zig/) |
| Python | [python/](python/) |
| TypeScript/Node | [node/](node/) |
| Rust | [rust/](rust/) |
| Go raw client | [go/](go/) |
| Ruby | [ruby/](ruby/) |
| C and shared C callback implementations | [c/](c/) |
| C++ | [cpp/](cpp/) |
| Java | [java/](java/) |
| .NET | [dotnet/](dotnet/) |
| Erlang and shared OTP controllers | [beam/](beam/) |
| Elixir | [elixir/](elixir/) |

The [shared SDK index](../README.md) and
[binding task module](../../../tasks/bindings.just) identify the schedules,
package inputs and required checks. A language directory is not an additional
test run: C/C++ and Erlang/Elixir share builders while preserving distinct callers.
