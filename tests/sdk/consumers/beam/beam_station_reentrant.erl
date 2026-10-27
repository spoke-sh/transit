-module(beam_station_reentrant).
-behaviour(transit_station_codec).
-export([type_id/0,version/0,max_encoded_bytes/0,encode/1,decode/1]).
type_id() -> <<"transit.examples.u64">>.
version() -> 1.
max_encoded_bytes() -> 12.
encode(V) -> transit_example_u64_codec:encode(V).
decode(B) -> {A,T} = erlang:get(proof_turn), beam_station_controller:expect(A,busy,A:budgets(T)), transit_example_u64_codec:decode(B).
