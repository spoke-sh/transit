-module(transit_example_query_requester_codec).
-behaviour(transit_station_codec).
-export([type_id/0, version/0, max_encoded_bytes/0, encode/1, decode/1]).
type_id() -> <<"transit.examples.query">>.
version() -> 1.
max_encoded_bytes() -> 22.
encode(Value) -> case transit_example_codec:allowed(query_requester, Value) of true -> transit_example_codec:encode(query, Value); false -> {error, unsupported_role} end.
decode(Bytes) -> case transit_example_codec:decode(query, Bytes) of {ok, Value} -> case transit_example_codec:allowed(query_requester, Value) of true -> {ok, Value}; false -> {error, unsupported_role} end; Error -> Error end.
