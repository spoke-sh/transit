-module(transit_example_table_queue_codec).
-behaviour(transit_station_codec).
-export([type_id/0,version/0,max_encoded_bytes/0,encode/1,decode/1]).
type_id()-><<"transit.examples.table.queue">>.
version()->1.
max_encoded_bytes()->21.
encode(Value)->transit_example_table_work:encode(queue,Value).
decode(Bytes)->transit_example_table_work:decode(queue,Bytes).
