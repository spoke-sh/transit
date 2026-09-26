-module(transit_example_query_requester).
-behaviour(transit_station_handler).
-include_lib("transit_station_sdk/include/transit_station_sdk.hrl").
-export([handle_message/3, handle_result/3]).
handle_message(Turn, #transit_incoming{kind = cast, value = start}, #{peer := Peer} = Context) ->
    {ok, State} = transit_turn:state(Turn), {ok, missing} = transit_turn:find(State, transit_example_keys:request()),
    {ok, Correlation} = transit_turn:call(Turn, Peer, rows, transit_example_query_service_codec, untimed),
    {ok, ok} = transit_turn:put(State, transit_example_keys:request(), Correlation), {ok, Context}.
handle_result(Turn, #transit_result_complete{correlation = Correlation}, #{peer := Peer, consume := Consume} = Context) ->
    {ok, State} = transit_turn:state(Turn), {ok, Correlation} = transit_turn:require(State, transit_example_keys:request()),
    {ok, Reader} = transit_query:result(Turn, Correlation),
    {ok, #transit_manifest{source = Peer, correlation = Correlation, segments = Segments, rows = Rows}} = transit_query:manifest(Reader),
    consume(Reader, 0, Segments, Consume), {ok, ok} = transit_turn:put(State, transit_example_keys:observed(), Rows), {ok, Context}.
consume(_, Count, Count, _) -> ok;
consume(Reader, Ordinal, Count, Consume) ->
    {ok, Segment} = transit_query:segment(Reader, Ordinal), ok = Consume(Segment), consume(Reader, Ordinal + 1, Count, Consume).
