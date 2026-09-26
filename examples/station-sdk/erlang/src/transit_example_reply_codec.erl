-module(transit_example_reply_codec).
-behaviour(transit_station_codec).
-export([type_id/0, version/0, max_encoded_bytes/0, encode/1, decode/1]).
type_id() -> <<"transit.examples.counter">>.
version() -> 1.
max_encoded_bytes() -> 13.
encode(Value) -> case transit_example_codec:allowed(reply, Value) of true -> transit_example_codec:encode(counter, Value); false -> {error, unsupported_role} end.
decode(Bytes) -> case transit_example_codec:decode(counter, Bytes) of {ok, Value} -> case transit_example_codec:allowed(reply, Value) of true -> {ok, Value}; false -> {error, unsupported_role} end; Error -> Error end.
