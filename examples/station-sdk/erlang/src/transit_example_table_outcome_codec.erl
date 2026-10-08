-module(transit_example_table_outcome_codec).
-behaviour(transit_station_codec).
-export([type_id/0,version/0,max_encoded_bytes/0,encode/1,decode/1]).
type_id()-><<"transit.examples.table.outcome">>.
version()->1.
max_encoded_bytes()->38.
encode(Value)->transit_example_table_work:encode(outcome,Value).
decode(Bytes)->transit_example_table_work:decode(outcome,Bytes).
