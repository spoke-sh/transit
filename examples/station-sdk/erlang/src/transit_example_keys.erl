-module(transit_example_keys).
-include_lib("transit_station_sdk/include/transit_station_sdk.hrl").
-export([total/0, request/0, observed/0, table/0]).
total() -> #transit_key{name = <<"total">>, codec = transit_example_u64_codec}.
request() -> #transit_key{name = <<"request">>, codec = transit_example_u64_codec}.
observed() -> #transit_key{name = <<"observed">>, codec = transit_example_u64_codec}.
table() -> #transit_table_schema{id = 1, cell = int64}.
