-module(transit_example_table_work_codec).
-behaviour(transit_station_codec).
-export([type_id/0,version/0,max_encoded_bytes/0,encode/1,decode/1]).
type_id()-><<"transit.examples.table.work">>.
version()->1.
max_encoded_bytes()->34.
encode(Value)->transit_example_table_work:encode(work,Value).
decode(Bytes)->transit_example_table_work:decode(work,Bytes).
