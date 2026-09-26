-module(transit_example_counter).
-behaviour(transit_station_handler).
-include_lib("transit_station_sdk/include/transit_station_sdk.hrl").
-export([initialize/2, handle_message/3]).
initialize(Turn, Context) -> {ok, State} = transit_turn:state(Turn), {ok, ok} = transit_turn:put(State, transit_example_keys:total(), 0), {ok, Context}.
handle_message(Turn, #transit_incoming{kind = cast, value = {add, Value}}, Context) ->
    {ok, State} = transit_turn:state(Turn), {ok, Total} = transit_turn:require(State, transit_example_keys:total()),
    {ok, ok} = transit_turn:put(State, transit_example_keys:total(), Total + Value), {ok, Context};
handle_message(Turn, #transit_incoming{kind = call, value = read}, Context) ->
    {ok, State} = transit_turn:state(Turn), {ok, Total} = transit_turn:require(State, transit_example_keys:total()),
    {ok, ok} = transit_turn:reply(Turn, {total, Total}, transit_example_reply_codec), {ok, Context}.
