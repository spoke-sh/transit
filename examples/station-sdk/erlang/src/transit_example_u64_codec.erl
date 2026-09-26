-module(transit_example_u64_codec).
-behaviour(transit_station_codec).
-export([type_id/0, version/0, max_encoded_bytes/0, encode/1, decode/1]).
type_id() -> <<"transit.examples.u64">>.
version() -> 1.
max_encoded_bytes() -> 12.
encode(Value) -> case transit_example_codec:allowed(u64, Value) of true -> transit_example_codec:encode(u64, Value); false -> {error, unsupported_role} end.
decode(Bytes) -> case transit_example_codec:decode(u64, Bytes) of {ok, Value} -> case transit_example_codec:allowed(u64, Value) of true -> {ok, Value}; false -> {error, unsupported_role} end; Error -> Error end.
