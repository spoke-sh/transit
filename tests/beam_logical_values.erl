%% Independent all-family fixtures against installed Station and client artifacts.
-module(beam_logical_values).
-include_lib("transit_station_sdk/include/transit_logical.hrl").
-export([run/0,main/0]).
main() -> ok=beam_schema_values:run(),ok=run(),io:format("Erlang logical values and recursive schema checks passed.~n"),halt(0).
round(Kind,V) -> {ok,W}=transit_logical:encode(Kind,V),{ok,V}=transit_logical:decode(Kind,W),ok.
reject(Kind,V) -> {error,_}=transit_logical:encode(Kind,V),ok.
atom(V) -> {value,{atom,V}}.
run() ->
    Types=[int8,int16,int32,int64,int128,uint8,uint16,uint32,uint64,uint128,float32,float64,boolean,utf8,binary,date,time,interval,uuid,json,
        {decimal,38,2},{timestamp,civil},{timestamp,utc},
        {structure,[#transit_logical_field{name= <<"東京"/utf8>>,type=binary,nullable=true,optional=true}]},
        {tagged_union,[#transit_logical_field{name= <<"amount">>,type={decimal,38,2}}]},
        {list,#transit_logical_element{type=int8}}, {array,#transit_logical_element{type=uuid,nullable=true},2},
        {map,utf8,#transit_logical_element{type={decimal,38,2}}}],
    lists:foreach(fun(V)->round(type,V) end,Types),
    Atoms=[{signed,-(1 bsl 127)},{unsigned,(1 bsl 128)-1},{decimal,123456789012345678901234567890},
        {float32,-0.0},{float64,-0.0},{boolean,false},{utf8,<<"東京"/utf8>>},{binary,<<0,128,255>>},
        {uuid,<<0:128>>},{date_days,-100},{time_nanos,123},{timestamp_micros,-1000},{interval,-1,2,-3000}],
    lists:foreach(fun(V)->round(atom,V),round(cell,atom(V)) end,Atoms),
    Values=[missing,null,{type_error,map},{value,{json,<<"{\"n\":123}">>}},
        {value,{structure,[atom({binary,<<0,128,255>>}),null]}}, {value,{list,[missing]}}, {value,{array,[null]}},
        {value,{map,[{{signed,1},null}]}},{value,{tagged_union,1,null}}],
    lists:foreach(fun(V)->round(cell,V) end,Values),
    lists:foreach(fun(K)->round(cell,{type_error,K}),reject(type,K) end,[unknown,null_value,text,character]),
    {ok,#{<<"float_bits">>:= <<"00000080">>}}=transit_logical:encode(atom,{float32,-0.0}),
    {ok,{float32,Zero}}=transit_logical:decode(atom,#{<<"float_bits">>=> <<"00000080">>}),<<0,0,0,128>>= <<Zero:32/float-little>>,
    lists:foreach(fun(V)->{error,_}=transit_logical:decode(atom,V) end,[#{<<"signed">>=> <<"01">>},#{<<"unsigned">>=> <<"-0">>},#{<<"uuid">>=> <<"00">>},#{<<"float_bits">>=> <<"0000807f">>}]),
    reject(atom,{signed,1 bsl 127}),reject(atom,{unsigned,1 bsl 128}),reject(atom,{date_days,1 bsl 31}),reject(atom,{float32,1.0e300}),
    Alternatives=[#transit_logical_alternative{counter=1,replica=1,value=atom({boolean,true})},#transit_logical_alternative{counter=1,replica=2,value=null}],
    Conflict={conflict,Alternatives},Deep=lists:foldl(fun(_,V)->{value,{list,[V]}} end,Conflict,lists:seq(1,15)),
    round(cell,Deep),reject(cell,{value,{list,[Deep]}}),reject(cell,{conflict,lists:reverse(Alternatives)}),
    reject(cell,{conflict,[#transit_logical_alternative{counter=0,replica=1,value=null},#transit_logical_alternative{counter=1,replica=2,value=null}]}),
    Map={value,{map,lists:duplicate(32767,{{signed,1},null})}},round(cell,Map),reject(cell,{value,{map,lists:duplicate(32768,{{signed,1},null})}}),
    Large={value,{list,lists:duplicate(2,atom({utf8,binary:copy(<<"x">>,600000)}))}},reject(cell,Large),
    Wire=#{<<"value">>=>#{<<"list">>=>lists:duplicate(2,#{<<"value">>=>#{<<"atom">>=>#{<<"utf8">>=>binary:copy(<<"x">>,600000)}}})}},
    {error,_}=transit_logical:decode(cell,Wire),
    reject(type,{structure,lists:duplicate(256,#transit_logical_field{name= <<"n">>,type=int8})}),
    reject(type,{structure,lists:duplicate(2,#transit_logical_field{name=binary:copy(<<"x">>,2100),type=int8})}),
    reject(cell,{value,{list,[atom({utf8,binary:copy(<<"x">>,1048574)}),atom({float32,1.0})]}}),
    round(cell,atom({binary,binary:copy(<<0>>,300000)})),
    %% Extracted sub-binaries must not pin unrelated caller storage.
    Parent=binary:copy(<<"x">>,1000000),Part=binary:part(Parent,100,100),
    {ok,#{<<"utf8">>:=Owned}}=transit_logical:encode(atom,{utf8,Part}),100=binary:referenced_byte_size(Owned),
    ok.
