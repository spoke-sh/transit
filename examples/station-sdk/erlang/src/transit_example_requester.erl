-module(transit_example_requester).
-behaviour(transit_station_handler).
-include_lib("transit_station_sdk/include/transit_station_sdk.hrl").
-export([handle_message/3]).
handle_message(Turn, #transit_incoming{kind = cast, value = start}, #{peer := Peer} = Context) ->
    {ok, State} = transit_turn:state(Turn), {ok, missing} = transit_turn:find(State, transit_example_keys:request()),
    {ok, Correlation} = transit_turn:call(Turn, Peer, read, transit_example_counter_codec, untimed),
    {ok, ok} = transit_turn:put(State, transit_example_keys:request(), Correlation), {ok, Context};
handle_message(Turn, #transit_incoming{kind = reply, value = {total, Value}} = Input, #{peer := Peer} = Context) ->
    {ok, State} = transit_turn:state(Turn), {ok, Correlation} = transit_turn:require(State, transit_example_keys:request()),
    {ok, ok} = transit_turn:require_reply(Turn, Input, Peer, Correlation),
    {ok, ok} = transit_turn:put(State, transit_example_keys:observed(), Value), {ok, Context}.
