-module(transit_example_table_service).
-behaviour(transit_station_handler).
-include_lib("transit_station_sdk/include/transit_station_sdk.hrl").
-export([initialize/2, handle_message/3]).
initialize(Turn, #{peer := Peer} = Context) ->
    {ok, _} = transit_table:create(Turn, transit_example_keys:table()),
    {ok, ok} = transit_query:allow(Turn, Peer, transit_example_keys:table(), 0, true), {ok, Context}.
handle_message(_, #transit_incoming{kind = cast, value = initialize}, Context) -> {ok, Context};
handle_message(Turn, #transit_incoming{kind = cast, value = {insert, Key, Value}}, Context) ->
    {ok, Table} = transit_table:open(Turn, transit_example_keys:table()),
    {ok, ok} = transit_table:insert(Table, #transit_row{key = Key, value = Value}), {ok, Context};
handle_message(Turn, #transit_incoming{kind = call, value = rows}, Context) ->
    {ok, _} = transit_query:start(Turn, transit_example_keys:table(), #transit_query_plan{limit = 18446744073709551615}), {ok, Context}.
