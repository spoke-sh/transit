-module(beam_document_adapter).
-include_lib("transit_station_sdk/include/transit_station_sdk.hrl").
-behaviour(transit_station_codec).
-behaviour(transit_station_handler).
-export([golden/2,prepare/1,open/3,next/1,close/1,expired/1,describe/2,path/3,sequence/2,accepted/2,resynchronize/2,revision/1,view/1,event/1,
         type_id/0,version/0,max_encoded_bytes/0,encode/1,decode/1,initialize/2,handle_message/3]).
-define(MAX,18446744073709551615).
type_id()-><<"test.document-control">>.
version()->1.
max_encoded_bytes()->243.
encode(B)->{ok,B}.
decode(B)->{ok,B}.
golden(F,Cfg)->
    lists:foreach(fun(V)->
        Bytes=binary:decode_hex(maps:get(<<"wire_hex">>,V)),{ok,Change}=transit_document:decode(Bytes),{ok,#transit_document_prepared{bytes=Bytes}}=transit_document:prepare(Change),
        lists:foreach(fun(N)->{error,_}=transit_document:decode(binary:part(Bytes,0,N)) end,[0,1,byte_size(Bytes)-1])
    end,maps:get(<<"changes">>,F)),
    Reference=binary:decode_hex(maps:get(<<"reference_hex">>,F)),{ok,#transit_document_reference{document=?MAX,revision=?MAX}=Ref}=transit_document:decode_reference(72,Reference),{ok,Reference}=transit_document:encode_reference(Ref),
    Root=#transit_document_dot{},Change=#transit_document_change{document=?MAX,replica=?MAX,first=1,operations=[
        {assign,Root,<<"value">>,[],{signed,-9223372036854775808}},{assign,Root,<<"body">>,[],text},
        {insert,#transit_document_dot{counter=2,replica=?MAX},Root,{character,16#1f642}}]},
    Expected=binary:decode_hex(hd(maps:get(<<"changes">>,Cfg))),{ok,#transit_document_prepared{bytes=Expected}}=transit_document:prepare(Change),
    {error,_}=transit_document:prepare(Change#transit_document_change{operations=[{assign,Root,<<"x">>,[],{string,<<16#ed,16#a0,16#80>>}}]}),ok.
prepare(Cfg)->[begin {ok,C}=transit_document:decode(binary:decode_hex(B)),{ok,P}=transit_document:prepare(C),P end||B<-maps:get(<<"changes">>,Cfg)].
open(Cfg,S,Changes)->
    {ok,Client}=transit_client:config(maps:get(<<"url">>,Cfg),native_v1,#{timeout_ms=>15000}),
    Service=#transit_service{client=Client,activation=#transit_activation{process=#transit_process{realm=72,pid=maps:get(<<"pid">>,Cfg)},generation=maps:get(<<"generation">>,Cfg),credential=#transit_credential{realm=72,principal=maps:get(<<"principal">>,Cfg),seed_file=maps:get(<<"seed_file">>,Cfg)}}},
    transit_station_sdk:open(Service,?MODULE,{S,Changes},?MODULE,stop,fresh_ownership).
initialize(Turn,Context)->{ok,ok}=transit_document:create(Turn,?MAX,1),{ok,Context}.
handle_message(Turn,#transit_incoming{kind=cast,value=Command},{S,Changes}=Context)->
    beam_document_controller:put(S,escaped,Turn),
    Result=case Command of
        <<"initialize">>->none;
        <<"checkpoint">>->{ok,P}=transit_document:checkpoint(Turn,?MAX,90),P;
        <<"window">>->{ok,ok}=transit_document:merge_window(Turn,?MAX,2),none;
        <<"retire">>->{ok,ok}=transit_document:retire(Turn,?MAX),none;
        N when N=:=<<"0">>;N=:=<<"1">>->Index=binary_to_integer(N)+1,{ok,P}=transit_document:stage(Turn,?MAX,Index,lists:nth(Index,Changes),256),P
    end,
    Phase=case Result of none->null; #transit_document_progress{phase=Name}->atom_to_binary(Name,utf8) end,
    beam_document_controller:put(S,phase,Phase),{ok,Context}.
next(R)->transit_station_sdk:next(R).
close(R)->transit_station_sdk:close(R).
expired(T)->transit_document:merge_window(T,?MAX,0).
resource(Cfg)->#transit_resource{realm=72,resource=maps:get(<<"resource">>,Cfg)}.
map_result({ok,V},F)->{ok,F(V)};map_result(E,_)->E.
describe(R,Cfg)->map_result(transit_document:describe(R,resource(Cfg),?MAX),fun(#transit_document_description{reference=Ref,floor=Floor,merge_window=W,retired=Retired})->#{reference=>Ref,floor=>Floor,merge_window=>W,retired=>Retired} end).
assignments(Values)->[{Id,V}||#transit_document_assignment{id=Id,value=V}<-Values].
path(R,Ref,Names)->map_result(transit_document:path(R,Ref,Names),fun(#transit_document_path{field=#transit_document_field{status=S,assignments=A}})->#{status=>S,assignments=>assignments(A)} end).
sequence(R,Ref)->map_result(transit_document:sequence(R,Ref,#transit_document_dot{counter=2,replica=?MAX}),fun(#transit_document_page{items=Items,next=N})->#{items=>[{I,assignments(A)}||#transit_document_item{id=I,field=#transit_document_field{assignments=A}}<-Items],next=>N} end).
accepted(R,Ref)->case transit_document:accepted_change(R,Ref) of {ok,C}->{ok,#transit_document_prepared{bytes=B}}=transit_document:prepare(C),{ok,B}; E->E end.
resynchronize(R,Cfg)->map_result(transit_document:resynchronize(R,resource(Cfg),?MAX,?MAX),fun(#transit_document_resynchronization{reference=#transit_document_reference{revision=3},previous_counter=P,clock=C})->#{previous_counter=>P,clock=>C} end).
revision(#transit_document_reference{revision=R})->R.
view(#transit_error{kind=K,code=C,phase=P})->#{kind=>K,code=>C,phase=>P}.
event(#transit_committed{})->committed;event(progress)->progress;event(V)->V.
