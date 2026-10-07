-module(transit_example_query_requester).
-behaviour(transit_station_handler).
-include_lib("transit_station_sdk/include/transit_station_sdk.hrl").
-export([handle_message/3, handle_result/3]).
handle_message(Turn,#transit_incoming{kind=reply,value=not_ready,correlation=Correlation}=Input,#{peer:=Peer}=Context) ->
    {ok,State}=transit_turn:state(Turn),{ok,Correlation}=transit_turn:require(State,transit_example_keys:request()),
    {ok,ok}=transit_turn:require_reply(Turn,Input,Peer,Correlation),
    {ok,ok}=transit_turn:put(State,transit_example_keys:not_ready(),Correlation),{ok,Context};
handle_message(Turn, #transit_incoming{kind = cast, value = start}, #{peer := Peer} = Context) ->
    {ok, State} = transit_turn:state(Turn),
    {ok,Previous}=transit_turn:find(State,transit_example_keys:request()),
    {ok,NotReady}=transit_turn:find(State,transit_example_keys:not_ready()),
    true=(Previous=:=missing orelse Previous=:=NotReady),
    {ok, Correlation} = transit_turn:call(Turn, Peer, rows, transit_example_query_service_codec, untimed),
    {ok, ok} = transit_turn:put(State, transit_example_keys:request(), Correlation),
    case NotReady of missing->ok;_-> {ok,ok}=transit_turn:delete(State,transit_example_keys:not_ready()) end,{ok,Context}.
handle_result(Turn, #transit_result_complete{correlation = Correlation}, #{peer := Peer, consume := Consume} = Context) ->
    {ok, State} = transit_turn:state(Turn), {ok, Correlation} = transit_turn:require(State, transit_example_keys:request()),
    {ok, Reader} = transit_query:result(Turn, Correlation),
    {ok, #transit_manifest{source = Peer, correlation = Correlation, segments = Segments, rows = Rows}} = transit_query:manifest(Reader),
    consume(Reader, 0, Segments, Consume), {ok, ok} = transit_turn:put(State, transit_example_keys:observed(), Rows), {ok, Context}.
consume(_, Count, Count, _) -> ok;
consume(Reader, Ordinal, Count, Consume) ->
    {ok, Segment} = transit_query:segment(Reader, Ordinal), ok = Consume(Segment), consume(Reader, Ordinal + 1, Count, Consume).
