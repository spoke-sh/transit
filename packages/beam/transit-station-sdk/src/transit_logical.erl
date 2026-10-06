%% Owned language-native values. Shared Zig owns domain validation and storage.
-module(transit_logical).
-include("transit_logical.hrl").
-export([encode/2,decode/2]).
%% Package boundary used by catalog/query models; throws tagged SDK errors.
-export([type_wire/1,type_from_wire/1,atom_wire/1,atom_from_wire/1,cell_wire/1,cell_from_wire/1]).
-export_type([descriptor/0,atom_value/0,cell/0,value/0]).
-type scalar_type() :: int8 | int16 | int32 | int64 | int128 | uint8 | uint16 | uint32 | uint64 | uint128 |
    float32 | float64 | boolean | utf8 | binary | date | time | interval | uuid | json.
-type descriptor() :: scalar_type() | {decimal,1..38,0..38} | {timestamp,civil | utc} |
    {structure,[#transit_logical_field{}]} | {tagged_union,[#transit_logical_field{}]} |
    {list,#transit_logical_element{}} | {array,#transit_logical_element{},pos_integer()} |
    {map,descriptor(),#transit_logical_element{}}.
-type atom_value() :: {signed,integer()} | {unsigned,non_neg_integer()} | {decimal,integer()} |
    {float32,float()} | {float64,float()} | {boolean,boolean()} | {utf8,binary()} | {binary,binary()} |
    {uuid,binary()} | {date_days,integer()} | {time_nanos,non_neg_integer()} |
    {timestamp_micros,integer()} | {interval,integer(),integer(),integer()}.
-type value() :: {atom,atom_value()} | {structure,[cell()]} | {list,[cell()]} | {array,[cell()]} |
    {map,[{atom_value(),cell()}]} | {tagged_union,0..255,cell()} | {json,binary()}.
-type cell() :: missing | null | {type_error,atom()} | {value,value()} | {conflict,[#transit_logical_alternative{}]}.

encode(Kind, Value) -> transit_sdk_value:protect(fun() ->
    try case Kind of type -> type_wire(Value); atom -> atom_wire(Value); cell -> cell_wire(Value); _ -> invalid() end
    catch _:_ -> invalid() end end).
decode(Kind, Value) -> transit_sdk_value:protect(fun() ->
    try case Kind of type -> type_from_wire(Value); atom -> atom_from_wire(Value); cell -> cell_from_wire(Value); _ -> invalid() end
    catch _:_ -> transit_sdk_value:fail(incompatible_native,logical_value) end end).
invalid() -> transit_sdk_value:fail(invalid_argument,logical_value).
check(true) -> ok;
check(_) -> invalid().
integer(N,Min,Max) -> transit_sdk_value:integer(N,Min,Max).
u64(N) -> integer(N,0,18446744073709551615).
positive(N) -> integer(N,1,18446744073709551615).
i128(N) -> integer(N,-(1 bsl 127),(1 bsl 127)-1).
u128(N) -> integer(N,0,(1 bsl 128)-1).
i32(N) -> integer(N,-2147483648,2147483647).
i64(N) -> integer(N,-9223372036854775808,9223372036854775807).
list(V,N) when is_list(V),length(V)=<N -> V;
list(_,_) -> invalid().
fields(V,Names) when is_map(V),map_size(V)=:=length(Names) -> check(lists:all(fun(K)->maps:is_key(K,V) end,Names)),V;
fields(_,_) -> invalid().
variant(V) when is_map(V),map_size(V)=:=1 -> hd(maps:to_list(V));
variant(_) -> invalid().
known(V,Allowed) -> case [A || A<-Allowed,atom_to_binary(A,utf8)=:=V] of [A]->A; _->invalid() end.
enum(V,Allowed) -> check(lists:member(V,Allowed)),atom_to_binary(V,utf8).
scalars() -> [int8,int16,int32,int64,int128,uint8,uint16,uint32,uint64,uint128,float32,float64,boolean,utf8,binary,date,time,interval,uuid,json].
kinds() -> scalars() ++ [decimal,timestamp,structure,tagged_union,list,array,map].
source_kinds() -> kinds() ++ [unknown,null_value,text,character].
budget(Max) -> {0,0,0,Max}.
enter({Nodes,Data,Names,Max},Depth) -> check(Depth<16 andalso Nodes<Max),{Nodes+1,Data,Names,Max}.
data({Nodes,Data,Names,Max},Size) -> check(Data+Size=<1048576),{Nodes,Data+Size,Names,Max}.
name(Value,{Nodes,Data,Names,Max}) ->
    B=transit_sdk_value:text(Value,4096),check(Names+byte_size(B)=<4096),{B,{Nodes,Data,Names+byte_size(B),Max}}.
text_data(V,B) -> Value=transit_sdk_value:text(V,1048576),{Value,data(B,byte_size(Value))}.
bytes_wire(V,B,Max) -> Value=transit_sdk_value:bytes(V,Max),{transit_sdk_value:hex(Value),data(B,byte_size(Value))}.
bytes_from(V,B,Max) -> Value=transit_sdk_value:unhex(V,Max),{Value,data(B,byte_size(Value))}.
number_text(V,Check) when is_binary(V),byte_size(V)>0,byte_size(V)=<40 ->
    N=binary_to_integer(V),check(integer_to_binary(N)=:=V),Check(N);
number_text(_,_) -> invalid().

-spec type_wire(descriptor()) -> map().
type_wire(V) -> {Out,_}=type_wire(V,budget(256),0),Out.
type_wire(V,B,D) -> type_value(V,enter(B,D),D).
type_value({decimal,P,S},B,_) -> integer(P,1,38),integer(S,0,P),{#{<<"decimal">>=>#{<<"precision">>=>P,<<"scale">>=>S}},B};
type_value({timestamp,Zone},B,_) -> {#{<<"timestamp">>=>enum(Zone,[civil,utc])},B};
type_value({Kind,Fields},B,D) when Kind=:=structure; Kind=:=tagged_union ->
    {Out,Next}=lists:mapfoldl(fun(F,B0)->field_wire(F,B0,D) end,B,list(Fields,256)),{#{atom_to_binary(Kind,utf8)=>Out},Next};
type_value({list,Element},B,D) -> {Out,Next}=element_wire(Element,B,D),{#{<<"list">>=>Out},Next};
type_value({array,Element,Length},B,D) ->
    integer(Length,1,4294967295),{Out,Next}=element_wire(Element,B,D),{#{<<"array">>=>#{<<"element">>=>Out,<<"length">>=>Length}},Next};
type_value({map,Key,Value},B,D) ->
    {K,B1}=type_wire(Key,B,D+1),{V,B2}=element_wire(Value,B1,D),{#{<<"map">>=>#{<<"key">>=>K,<<"value">>=>V}},B2};
type_value(V,B,_) -> {#{enum(V,scalars())=>#{}},B}.
field_wire(#transit_logical_field{name=N,type=T,nullable=Null,optional=Optional},B,D) ->
    {Name,B1}=name(N,B),{Type,B2}=type_wire(T,B1,D+1),
    {#{<<"name">>=>Name,<<"type">>=>Type,<<"nullable">>=>transit_sdk_value:boolean(Null),<<"optional">>=>transit_sdk_value:boolean(Optional)},B2}.
element_wire(#transit_logical_element{type=T,nullable=N},B,D) ->
    {Type,Next}=type_wire(T,B,D+1),{#{<<"type">>=>Type,<<"nullable">>=>transit_sdk_value:boolean(N)},Next}.
-spec type_from_wire(map()) -> descriptor().
type_from_wire(V) -> {Out,_}=type_from(V,budget(256),0),Out.
type_from(V,B,D) -> {Kind,Payload}=variant(V),type_parse(known(Kind,kinds()),Payload,enter(B,D),D).
type_parse(decimal,V,B,_) ->
    fields(V,[<<"precision">>,<<"scale">>]),P=integer(maps:get(<<"precision">>,V),1,38),S=integer(maps:get(<<"scale">>,V),0,P),{{decimal,P,S},B};
type_parse(timestamp,V,B,_) -> {{timestamp,known(V,[civil,utc])},B};
type_parse(Kind,V,B,D) when Kind=:=structure; Kind=:=tagged_union ->
    {Out,Next}=lists:mapfoldl(fun(F,B0)->field_from(F,B0,D) end,B,list(V,256)),{{Kind,Out},Next};
type_parse(list,V,B,D) -> {Out,Next}=element_from(V,B,D),{{list,Out},Next};
type_parse(array,V,B,D) ->
    fields(V,[<<"element">>,<<"length">>]),{Out,Next}=element_from(maps:get(<<"element">>,V),B,D),{{array,Out,integer(maps:get(<<"length">>,V),1,4294967295)},Next};
type_parse(map,V,B,D) ->
    fields(V,[<<"key">>,<<"value">>]),{K,B1}=type_from(maps:get(<<"key">>,V),B,D+1),{Out,B2}=element_from(maps:get(<<"value">>,V),B1,D),{{map,K,Out},B2};
type_parse(Kind,V,B,_) -> fields(V,[]),{Kind,B}.
field_from(V,B,D) ->
    fields(V,[<<"name">>,<<"type">>,<<"nullable">>,<<"optional">>]),{N,B1}=name(maps:get(<<"name">>,V),B),{T,B2}=type_from(maps:get(<<"type">>,V),B1,D+1),
    {#transit_logical_field{name=N,type=T,nullable=transit_sdk_value:boolean(maps:get(<<"nullable">>,V)),optional=transit_sdk_value:boolean(maps:get(<<"optional">>,V))},B2}.
element_from(V,B,D) ->
    fields(V,[<<"type">>,<<"nullable">>]),{T,Next}=type_from(maps:get(<<"type">>,V),B,D+1),{#transit_logical_element{type=T,nullable=transit_sdk_value:boolean(maps:get(<<"nullable">>,V))},Next}.

-spec atom_wire(atom_value()) -> map().
atom_wire(V) -> {Out,_}=atom_wire(V,budget(65536)),Out.
atom_wire({signed,V},B) -> {#{<<"signed">>=>integer_to_binary(i128(V))},B};
atom_wire({unsigned,V},B) -> {#{<<"unsigned">>=>integer_to_binary(u128(V))},B};
atom_wire({decimal,V},B) -> {#{<<"decimal">>=>integer_to_binary(i128(V))},B};
atom_wire({date_days,V},B) -> {#{<<"date_days">>=>integer_to_binary(i32(V))},B};
atom_wire({time_nanos,V},B) -> {#{<<"time_nanos">>=>integer_to_binary(u64(V))},B};
atom_wire({timestamp_micros,V},B) -> {#{<<"timestamp_micros">>=>integer_to_binary(i64(V))},B};
atom_wire({boolean,V},B) -> {#{<<"boolean">>=>transit_sdk_value:boolean(V)},B};
atom_wire({utf8,V},B) -> {Out,Next}=text_data(V,B),{#{<<"utf8">>=>Out},Next};
atom_wire({binary,V},B) -> {Out,Next}=bytes_wire(V,B,1048576),{#{<<"binary">>=>Out},Next};
atom_wire({uuid,V},B) -> check(is_binary(V) andalso byte_size(V)=:=16),{Out,Next}=bytes_wire(V,B,16),{#{<<"uuid">>=>Out},Next};
atom_wire({float32,V},B) when is_float(V) -> float_wire(<<V:32/float-little>>,B);
atom_wire({float64,V},B) when is_float(V) -> float_wire(<<V:64/float-little>>,B);
atom_wire({interval,M,D,N},B) -> {#{<<"interval">>=>#{<<"months">>=>integer_to_binary(i32(M)),<<"days">>=>integer_to_binary(i32(D)),<<"nanos">>=>integer_to_binary(i64(N))}},B};
atom_wire(_,_) -> invalid().
finite(<<Bits:32/unsigned-little>>) -> check(Bits band 16#7f800000 =/= 16#7f800000);
finite(<<Bits:64/unsigned-little>>) -> check(Bits band 16#7ff0000000000000 =/= 16#7ff0000000000000);
finite(_) -> invalid().
float_wire(Bytes,B) -> finite(Bytes),{Out,Next}=bytes_wire(Bytes,B,8),{#{<<"float_bits">>=>Out},Next}.
-spec atom_from_wire(map()) -> atom_value().
atom_from_wire(V) -> {Out,_}=atom_from(V,budget(65536)),Out.
atom_from(V,B) -> {Kind,Payload}=variant(V),atom_parse(Kind,Payload,B).
atom_parse(<<"signed">>,V,B) -> {{signed,number_text(V,fun i128/1)},B};
atom_parse(<<"unsigned">>,V,B) -> {{unsigned,number_text(V,fun u128/1)},B};
atom_parse(<<"decimal">>,V,B) -> {{decimal,number_text(V,fun i128/1)},B};
atom_parse(<<"date_days">>,V,B) -> {{date_days,number_text(V,fun i32/1)},B};
atom_parse(<<"time_nanos">>,V,B) -> {{time_nanos,number_text(V,fun u64/1)},B};
atom_parse(<<"timestamp_micros">>,V,B) -> {{timestamp_micros,number_text(V,fun i64/1)},B};
atom_parse(<<"boolean">>,V,B) -> {{boolean,transit_sdk_value:boolean(V)},B};
atom_parse(<<"utf8">>,V,B) -> {Out,Next}=text_data(V,B),{{utf8,Out},Next};
atom_parse(<<"binary">>,V,B) -> {Out,Next}=bytes_from(V,B,1048576),{{binary,Out},Next};
atom_parse(<<"uuid">>,V,B) -> {Out,Next}=bytes_from(V,B,16),check(byte_size(Out)=:=16),{{uuid,Out},Next};
atom_parse(<<"float_bits">>,V,B) ->
    {Bytes,Next}=bytes_from(V,B,8),finite(Bytes),case Bytes of <<F:32/float-little>>->{{float32,F},Next}; <<F:64/float-little>>->{{float64,F},Next} end;
atom_parse(<<"interval">>,V,B) ->
    fields(V,[<<"months">>,<<"days">>,<<"nanos">>]),{{interval,number_text(maps:get(<<"months">>,V),fun i32/1),number_text(maps:get(<<"days">>,V),fun i32/1),number_text(maps:get(<<"nanos">>,V),fun i64/1)},B};
atom_parse(_,_,_) -> invalid().

-spec cell_wire(cell()) -> map().
cell_wire(V) -> {Out,_}=cell_wire(V,budget(65536),0),Out.
cell_wire(V,B,D) -> cell_value(V,enter(B,D),D).
cell_value(missing,B,_) -> {#{<<"missing">>=>#{}},B};
cell_value(null,B,_) -> {#{<<"null">>=>#{}},B};
cell_value({type_error,Kind},B,_) -> {#{<<"type_error">>=>enum(Kind,source_kinds())},B};
cell_value({value,V},B,D) -> {Out,Next}=value_wire(V,B,D),{#{<<"value">>=>Out},Next};
cell_value({conflict,Alternatives},B,D) ->
    conflict_check(Alternatives),{Out,Next}=lists:mapfoldl(fun(A,B0)->alternative_wire(A,B0,D) end,B,Alternatives),{#{<<"conflict">>=>Out},Next};
cell_value(_,_,_) -> invalid().
conflict_check(Alternatives) ->
    list(Alternatives,8),check(length(Alternatives)>=2),
    lists:foldl(fun(#transit_logical_alternative{counter=C,replica=R,value=V},Before)->
        positive(C),positive(R),check({C,R}>Before),case V of null->ok; {type_error,_}->ok; {value,_}->ok; _->invalid() end,{C,R}
    end,{0,0},Alternatives),ok.
alternative_wire(#transit_logical_alternative{counter=C,replica=R,value=V},B,D) ->
    {Out,Next}=cell_wire(V,B,D),{#{<<"counter">>=>integer_to_binary(C),<<"replica">>=>integer_to_binary(R),<<"value">>=>Out},Next}.
value_wire({atom,A},B,_) -> {Out,Next}=atom_wire(A,B),{#{<<"atom">>=>Out},Next};
value_wire({Kind,Cells},B,D) when Kind=:=structure; Kind=:=list; Kind=:=array ->
    {Out,Next}=lists:mapfoldl(fun(C,B0)->cell_wire(C,B0,D+1) end,B,list(Cells,65536)),{#{atom_to_binary(Kind,utf8)=>Out},Next};
value_wire({map,Entries},B,D) ->
    {Out,Next}=lists:mapfoldl(fun({K,V},B0)->
        {Key,B1}=atom_wire(K,enter(B0,D+1)),{Value,B2}=cell_wire(V,B1,D+1),{#{<<"key">>=>Key,<<"value">>=>Value},B2}
    end,B,list(Entries,32767)),{#{<<"map">>=>Out},Next};
value_wire({tagged_union,Index,V},B,D) ->
    integer(Index,0,255),{Out,Next}=cell_wire(V,B,D+1),{#{<<"tagged_union">>=>#{<<"index">>=>Index,<<"value">>=>Out}},Next};
value_wire({json,V},B,_) -> {Out,Next}=text_data(V,B),{#{<<"json">>=>Out},Next};
value_wire(_,_,_) -> invalid().
-spec cell_from_wire(map()) -> cell().
cell_from_wire(V) -> {Out,_}=cell_from(V,budget(65536),0),Out.
cell_from(V,B,D) -> {Kind,Payload}=variant(V),cell_parse(Kind,Payload,enter(B,D),D).
cell_parse(<<"missing">>,V,B,_) -> fields(V,[]),{missing,B};
cell_parse(<<"null">>,V,B,_) -> fields(V,[]),{null,B};
cell_parse(<<"type_error">>,V,B,_) -> {{type_error,known(V,source_kinds())},B};
cell_parse(<<"value">>,V,B,D) -> {Out,Next}=value_from(V,B,D),{{value,Out},Next};
cell_parse(<<"conflict">>,V,B,D) ->
    list(V,8),check(length(V)>=2),{Out,Next}=lists:mapfoldl(fun(A,B0)->alternative_from(A,B0,D) end,B,V),conflict_check(Out),{{conflict,Out},Next};
cell_parse(_,_,_,_) -> invalid().
alternative_from(V,B,D) ->
    fields(V,[<<"counter">>,<<"replica">>,<<"value">>]),{Out,Next}=cell_from(maps:get(<<"value">>,V),B,D),
    {#transit_logical_alternative{counter=number_text(maps:get(<<"counter">>,V),fun positive/1),replica=number_text(maps:get(<<"replica">>,V),fun positive/1),value=Out},Next}.
value_from(V,B,D) -> {Kind,Payload}=variant(V),value_parse(Kind,Payload,B,D).
value_parse(<<"atom">>,V,B,_) -> {Out,Next}=atom_from(V,B),{{atom,Out},Next};
value_parse(Kind,V,B,D) when Kind=:= <<"structure">>; Kind=:= <<"list">>; Kind=:= <<"array">> ->
    {Out,Next}=lists:mapfoldl(fun(C,B0)->cell_from(C,B0,D+1) end,B,list(V,65536)),{{known(Kind,[structure,list,array]),Out},Next};
value_parse(<<"map">>,V,B,D) ->
    {Out,Next}=lists:mapfoldl(fun(E,B0)->
        fields(E,[<<"key">>,<<"value">>]),{K,B1}=atom_from(maps:get(<<"key">>,E),enter(B0,D+1)),{Cell,B2}=cell_from(maps:get(<<"value">>,E),B1,D+1),{{K,Cell},B2}
    end,B,list(V,32767)),{{map,Out},Next};
value_parse(<<"tagged_union">>,V,B,D) ->
    fields(V,[<<"index">>,<<"value">>]),{Out,Next}=cell_from(maps:get(<<"value">>,V),B,D+1),{{tagged_union,integer(maps:get(<<"index">>,V),0,255),Out},Next};
value_parse(<<"json">>,V,B,_) -> {Out,Next}=text_data(V,B),{{json,Out},Next};
value_parse(_,_,_,_) -> invalid().
