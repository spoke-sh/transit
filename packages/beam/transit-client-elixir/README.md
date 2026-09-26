# Transit Elixir client

`Transit.Client` provides structs and tagged outcomes over the independent
[Erlang client](../transit-client/README.md). It owns no second signing or protocol
implementation. Native artifacts remain separate OTP dependencies. Its M11
clean-consumer proof passes on Linux x86_64, OTP 28 and Elixir 1.18. See the
[usage guide](docs/USAGE.md) for installation, outcomes, tasks and supervision. Package loading starts no native or credential work.

Use explicit `open/1` and `close/1`, or the supervisor `child_spec/1` and `handle/1`.
A cancelled task abandons its wait; the bridge retains admitted native work.
Persistent exact retry material and Transit ownership remain application duties.
