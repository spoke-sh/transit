%% Application queue records, independent of native Table storage.
-module(transit_example_table_work).
-include_lib("transit_station_sdk/include/transit_station_sdk.hrl").
-export([encode/2,decode/2,metadata/0,work_key/1,outcome_key/1,initial/0]).
-define(MAX, 9007199254740991).
-define(INITIAL, 18446744073709551615).
initial() -> ?INITIAL.
metadata() -> #transit_key{name= <<"table.queue">>,codec=transit_example_table_queue_codec}.
work_key(Id) when is_integer(Id), Id > 0, Id =< ?INITIAL ->
    #transit_key{name=key(<<"table.work.">>,Id),codec=transit_example_table_work_codec}.
outcome_key(Id) when is_integer(Id), Id > 0, Id =< ?INITIAL ->
    #transit_key{name=key(<<"table.done.">>,Id),codec=transit_example_table_outcome_codec}.
key(Prefix,Id) -> Hex=string:lowercase(integer_to_binary(Id,16)),
    <<Prefix/binary,(binary:copy(<<"0">>,16-byte_size(Hex)))/binary,Hex/binary>>.
encode(queue,{Head,Tail,Ready}) when is_integer(Head),is_integer(Tail),is_boolean(Ready),
    Head>=0,Head=< ?INITIAL,Tail>=0,Tail=< ?MAX,
    (Head=:=0)=:=(Tail=:=0), (Head=:= ?INITIAL orelse Head=<Tail),
    (Head=/= ?INITIAL orelse Ready=:=false) ->
    Flag=case Ready of true->1;false->0 end,{ok,<<"TQM",1,Head:64/little,Tail:64/little,Flag>>};
encode(work,{Next,Command}) when is_integer(Next),Next>=0,Next=< ?MAX ->
    case command(Command) of
        true -> case transit_example_query_service_codec:encode(Command) of
            {ok,Bytes}->{ok,<<"TQW",1,Next:64/little,Bytes/binary>>}; Error->Error end;
        false -> {error,invalid_table_work}
    end;
encode(outcome,{State,Admitted,Completed,Matched,Changed,Rejection}) when
    is_integer(State),State>=0,State=<3,is_integer(Admitted),Admitted>0,
    is_integer(Completed),Completed>=Admitted,Completed=< ?MAX,
    is_integer(Matched),Matched>=0,Matched=< ?INITIAL,is_integer(Changed),Changed>=0,Changed=<Matched,
    is_integer(Rejection),Rejection>=0,Rejection=<7,
    (State=:=1 orelse (Matched=:=0 andalso Changed=:=0)), (State=:=2)=:=(Rejection=/=0) ->
    {ok,<<"TQO",1,State,Admitted:64/little,Completed:64/little,Matched:64/little,Changed:64/little,Rejection>>};
encode(_,_) -> {error,invalid_table_record}.
decode(queue,<<"TQM",1,Head:64/little,Tail:64/little,Flag>>) when Flag=<1 -> checked(queue,{Head,Tail,Flag=:=1});
decode(work,<<"TQW",1,Next:64/little,Bytes/binary>>) when byte_size(Bytes)=:=5;byte_size(Bytes)=:=13;byte_size(Bytes)=:=14;byte_size(Bytes)=:=22 ->
    case transit_example_query_service_codec:decode(Bytes) of {ok,Command}->checked(work,{Next,Command}); Error->Error end;
decode(outcome,<<"TQO",1,State,Admitted:64/little,Completed:64/little,Matched:64/little,Changed:64/little,Rejection>>) ->
    checked(outcome,{State,Admitted,Completed,Matched,Changed,Rejection});
decode(_,_) -> {error,malformed_table_record}.
checked(Kind,Value) -> case encode(Kind,Value) of {ok,_}->{ok,Value};Error->Error end.
command(initialize)->true;command({insert,_,_})->true;command({update,_,_})->true;command({delete,_})->true;command(_)->false.
