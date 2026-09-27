%% Public bounded Document records; shared Zig owns codecs and merge semantics.
-module(transit_document).
-include("transit_station_sdk.hrl").
-export([prepare/1,prepare/2,decode/1,decode/2,encode_reference/1,encode_reference/2,decode_reference/2,decode_reference/3,
         create/3,create/4,stage/4,stage/5,checkpoint/3,merge_window/3,reject/4,collect/5,retire/2,
         describe/3,path/3,sequence/3,sequence/4,resynchronize/4,accepted_change/2,read_result/3]).
-export_type([scalar/0,operation/0]).
-type scalar() :: null_value | map | list | text | {boolean,boolean()} | {signed,integer()} | {unsigned,non_neg_integer()} |
                  {float,float()} | {string,binary()} | {binary,binary()} | {character,non_neg_integer()}.
-type operation() :: {assign,#transit_document_dot{},binary(),[#transit_document_dot{}],scalar()} |
                     {remove,#transit_document_dot{},binary(),[#transit_document_dot{}]} |
                     {insert,#transit_document_dot{},#transit_document_dot{},scalar()} |
                     {set_element,#transit_document_dot{},#transit_document_dot{},[#transit_document_dot{}],scalar()} |
                     {delete_element,#transit_document_dot{},#transit_document_dot{}}.
u64(V) -> transit_sdk_value:integer(V,0,18446744073709551615).
positive(V) -> transit_sdk_value:integer(V,1,18446744073709551615).
u32(V) -> transit_sdk_value:integer(V,0,4294967295).
decimal(V) -> integer_to_binary(u64(V)).
wide(V) -> transit_sdk_value:wide(V).
array(V,N) when is_list(V) -> true=length(V)=<N, V;
array(_,_) -> transit_sdk_value:fail(invalid_argument,document_array).
known(V,Allowed) -> case [A || A <- Allowed, atom_to_binary(A,utf8)=:=V] of [A] -> A; _ -> transit_sdk_value:fail(incompatible_native,document_enum) end.
dot(#transit_document_dot{counter=C,replica=R}) -> u64(C),u64(R),true=((C=:=0)=:=(R=:=0)),#{<<"counter">>=>decimal(C),<<"replica">>=>decimal(R)}.
parsed_dot(#{<<"counter">>:=C,<<"replica">>:=R}) -> V=#transit_document_dot{counter=wide(C),replica=wide(R)}, dot(V), V.
scalar(V) when V=:=null_value; V=:=map; V=:=list; V=:=text -> #{atom_to_binary(V,utf8)=>#{}};
scalar({boolean,V}) -> #{<<"boolean">>=>transit_sdk_value:boolean(V)};
scalar({signed,V}) -> #{<<"signed">>=>integer_to_binary(transit_sdk_value:integer(V,-9223372036854775808,9223372036854775807))};
scalar({unsigned,V}) -> #{<<"unsigned">>=>decimal(V)};
scalar({float,V}) when is_float(V) -> #{<<"float_bits">>=>transit_sdk_value:hex(<<V:64/float-little>>)};
scalar({string,V}) -> #{<<"string">>=>transit_sdk_value:text(V,96)};
scalar({binary,V}) -> #{<<"binary">>=>transit_sdk_value:hex(transit_sdk_value:bytes(V,96))};
scalar({character,V}) when is_integer(V),V>=0,V=<16#10ffff,(V<16#d800 orelse V>16#dfff) -> #{<<"character">>=><<V/utf8>>};
scalar(_) -> transit_sdk_value:fail(invalid_argument,document_scalar).
parsed_scalar(V) when is_map(V),map_size(V)=:=1 ->
    case maps:to_list(V) of
        [{<<"null_value">>,_}] -> null_value; [{<<"map">>,_}] -> map; [{<<"list">>,_}] -> list; [{<<"text">>,_}] -> text;
        [{<<"boolean">>,B}] -> {boolean,transit_sdk_value:boolean(B)};
        [{<<"signed">>,B}] -> I=binary_to_integer(B), true=integer_to_binary(I)=:=B, {signed,transit_sdk_value:integer(I,-9223372036854775808,9223372036854775807)};
        [{<<"unsigned">>,B}] -> {unsigned,wide(B)};
        [{<<"float_bits">>,B}] -> <<F:64/float-little>>=transit_sdk_value:unhex(B,8), {float,F};
        [{<<"string">>,B}] -> {string,transit_sdk_value:text(B,96)};
        [{<<"binary">>,B}] -> {binary,transit_sdk_value:unhex(B,96)};
        [{<<"character">>,B}] -> <<C/utf8>>=transit_sdk_value:text(B,4), {character,C}
    end.
observed(V) -> [dot(D) || D <- array(V,8)].
parsed_observed(V) -> [parsed_dot(D) || D <- array(V,8)].
operation({assign,O,F,Observed,V}) -> #{<<"assign">>=>#{<<"object">>=>dot(O),<<"field">>=>transit_sdk_value:text(F,64),<<"observed">>=>observed(Observed),<<"value">>=>scalar(V)}};
operation({remove,O,F,Observed}) -> #{<<"remove">>=>#{<<"object">>=>dot(O),<<"field">>=>transit_sdk_value:text(F,64),<<"observed">>=>observed(Observed)}};
operation({insert,O,A,V}) -> #{<<"insert">>=>#{<<"object">>=>dot(O),<<"after">>=>dot(A),<<"value">>=>scalar(V)}};
operation({set_element,O,E,Observed,V}) -> #{<<"set_element">>=>#{<<"object">>=>dot(O),<<"element">>=>dot(E),<<"observed">>=>observed(Observed),<<"value">>=>scalar(V)}};
operation({delete_element,O,E}) -> #{<<"delete_element">>=>#{<<"object">>=>dot(O),<<"element">>=>dot(E)}};
operation(_) -> transit_sdk_value:fail(invalid_argument,document_operation).
parsed_operation(Value) when is_map(Value),map_size(Value)=:=1 ->
    [{Kind,V}]=maps:to_list(Value), O=parsed_dot(maps:get(<<"object">>,V)),
    case Kind of
        <<"assign">> -> {assign,O,transit_sdk_value:text(maps:get(<<"field">>,V),64),parsed_observed(maps:get(<<"observed">>,V)),parsed_scalar(maps:get(<<"value">>,V))};
        <<"remove">> -> {remove,O,transit_sdk_value:text(maps:get(<<"field">>,V),64),parsed_observed(maps:get(<<"observed">>,V))};
        <<"insert">> -> {insert,O,parsed_dot(maps:get(<<"after">>,V)),parsed_scalar(maps:get(<<"value">>,V))};
        <<"set_element">> -> {set_element,O,parsed_dot(maps:get(<<"element">>,V)),parsed_observed(maps:get(<<"observed">>,V)),parsed_scalar(maps:get(<<"value">>,V))};
        <<"delete_element">> -> {delete_element,O,parsed_dot(maps:get(<<"element">>,V))}
    end.
change(#transit_document_change{document=D,epoch=E,type_revision=T,replica=R,previous=P,first=F,operations=Ops}) ->
    positive(D),positive(E),positive(R),positive(F),true=Ops=/=[],
    #{<<"document">>=>decimal(D),<<"epoch">>=>decimal(E),<<"type_revision">>=>u32(T),<<"replica">>=>decimal(R),<<"previous">>=>decimal(P),<<"first">>=>decimal(F),<<"operations">>=>[operation(Op)||Op<-array(Ops,8)]}.
parsed_change(V) ->
    Out=#transit_document_change{document=wide(maps:get(<<"document">>,V)),epoch=wide(maps:get(<<"epoch">>,V)),type_revision=u32(maps:get(<<"type_revision">>,V)),replica=wide(maps:get(<<"replica">>,V)),previous=wide(maps:get(<<"previous">>,V)),first=wide(maps:get(<<"first">>,V)),operations=[parsed_operation(Op)||Op<-array(maps:get(<<"operations">>,V),8)]},
    change(Out), Out.
local(Action,Override) ->
    case transit_sdk_worker:open(transit_station_runner,{local,Override},false) of
        {ok,Worker} -> try case transit_sdk_worker:invoke(Worker,{document_codec,Action,<<"document_codecs">>}) of {ok,Result}->Result; {error,E}->throw({transit_sdk,E}) end after transit_sdk_worker:close(Worker) end;
        {error,E} -> throw({transit_sdk,E})
    end.
prepare(Change) -> prepare(Change,undefined).
prepare(Change,Override) -> transit_sdk_value:protect(fun() ->
    #{<<"prepared">>:=V}=local(#{<<"prepare">>=>change(Change)},Override),
    #transit_document_prepared{document=Change#transit_document_change.document,bytes=transit_sdk_value:unhex(maps:get(<<"bytes">>,V),4096)} end).
decode(Bytes) -> decode(Bytes,undefined).
decode(Bytes,Override) -> transit_sdk_value:protect(fun() -> #{<<"change">>:=V}=local(#{<<"decode">>=>transit_sdk_value:hex(transit_sdk_value:bytes(Bytes,4096))},Override),parsed_change(V) end).
reference(#transit_document_reference{resource=#transit_resource{realm=Realm,resource=Resource},document=D,epoch=E,type_revision=T,revision=R}) ->
    transit_sdk_value:counter(Realm),transit_sdk_value:counter(Resource),
    #{<<"resource">>=>Resource,<<"document">>=>decimal(D),<<"epoch">>=>decimal(E),<<"type_revision">>=>u32(T),<<"revision">>=>decimal(R)}.
parsed_reference(Realm,V) -> #transit_document_reference{resource=#transit_resource{realm=Realm,resource=transit_sdk_value:counter(maps:get(<<"resource">>,V))},document=wide(maps:get(<<"document">>,V)),epoch=wide(maps:get(<<"epoch">>,V)),type_revision=u32(maps:get(<<"type_revision">>,V)),revision=wide(maps:get(<<"revision">>,V))}.
encode_reference(Ref) -> encode_reference(Ref,undefined).
encode_reference(Ref,Override) -> transit_sdk_value:protect(fun() -> #{<<"reference">>:=V}=local(#{<<"reference">>=>reference(Ref)},Override),Bytes=transit_sdk_value:unhex(V,40),true=byte_size(Bytes)=:=40,Bytes end).
decode_reference(Realm,Bytes) -> decode_reference(Realm,Bytes,undefined).
decode_reference(Realm,Bytes,Override) -> transit_sdk_value:protect(fun() -> transit_sdk_value:counter(Realm),#{<<"inspected_reference">>:=V}=local(#{<<"inspect_reference">>=>transit_sdk_value:hex(transit_sdk_value:bytes(Bytes,40))},Override),parsed_reference(Realm,V) end).
apply_owner(Turn,Action) -> transit_turn:access(Turn,false,fun() ->
    Bridge=maps:get(bridge,transit_turn:data(Turn)),case maps:get(<<"document_owner">>,transit_station_bridge:caps(Bridge),false) of true->ok; false->transit_sdk_value:fail(unsupported_capability,document_owner) end,
    Result=maps:get(<<"document">>,transit_turn:raw(Turn,#{<<"document">>=>Action})),
    case Result of
        #{<<"none">>:=_}->ok;
        #{<<"collected">>:=Done}->transit_sdk_value:boolean(Done);
        #{<<"progress">>:=#{<<"phase">>:=Kind,<<"revision">>:=Revision}}->
            Phase=known(Kind,[progress,accepted,duplicate,checkpoint_complete]),true=((Phase=:=progress)=:=(Revision=:=null)),
            #transit_document_progress{phase=Phase,revision=case Revision of null->undefined; _->wide(Revision) end}
    end end).
create(Turn,Document,Type) -> create(Turn,Document,Type,#{record_bytes=>4096,staging_bytes=>8192,staging_records=>2}).
create(Turn,Document,Type,Limits) -> guarded(fun() -> apply_owner(Turn,#{<<"create">>=>#{<<"document">>=>decimal(positive(Document)),<<"type_revision">>=>u32(Type),<<"record_bytes">>=>u32(maps:get(record_bytes,Limits)),<<"staging_bytes">>=>decimal(maps:get(staging_bytes,Limits)),<<"staging_records">>=>u32(maps:get(staging_records,Limits))}}) end).
job(D,J) -> #{<<"document">>=>decimal(positive(D)),<<"job">>=>decimal(positive(J))}.
stage(Turn,D,J,Change) -> stage(Turn,D,J,Change,512).
stage(Turn,D,J,Change,Limit) -> guarded(fun() -> #transit_document_prepared{document=D,bytes=Bytes}=Change,apply_owner(Turn,#{<<"stage">>=>(job(D,J))#{<<"change">>=>transit_sdk_value:hex(transit_sdk_value:bytes(Bytes,4096)),<<"node_limit">>=>u32(Limit)}}) end).
checkpoint(Turn,D,J) -> guarded(fun() -> apply_owner(Turn,#{<<"checkpoint">>=>job(D,J)}) end).
merge_window(Turn,D,N) -> guarded(fun() -> apply_owner(Turn,#{<<"merge_window">>=>#{<<"document">>=>decimal(positive(D)),<<"revisions">>=>decimal(N)}}) end).
reject(Turn,D,J,Checkpoint) -> guarded(fun() -> apply_owner(Turn,#{<<"reject">>=>(job(D,J))#{<<"checkpoint">>=>transit_sdk_value:boolean(Checkpoint)}}) end).
collect(Turn,D,J,Checkpoint,Retired) -> guarded(fun() -> apply_owner(Turn,#{<<"collect">>=>(job(D,J))#{<<"checkpoint">>=>transit_sdk_value:boolean(Checkpoint),<<"retired">>=>transit_sdk_value:boolean(Retired)}}) end).
retire(Turn,D) -> guarded(fun() -> apply_owner(Turn,#{<<"retire">>=>decimal(positive(D))}) end).
guarded(Fun) -> case transit_sdk_value:protect(Fun) of {ok,Result}->Result; Error->Error end.
describe(Runner,Resource,Document) -> transit_sdk_worker:invoke(Runner,{document,{describe,Resource,Document}}).
path(Runner,Reference,Names) -> transit_sdk_worker:invoke(Runner,{document,{path,Reference,Names}}).
sequence(Runner,Reference,Object) -> sequence(Runner,Reference,Object,undefined).
sequence(Runner,Reference,Object,Cursor) -> transit_sdk_worker:invoke(Runner,{document,{sequence,Reference,Object,Cursor}}).
resynchronize(Runner,Resource,Document,Replica) -> transit_sdk_worker:invoke(Runner,{document,{resynchronize,Resource,Document,Replica}}).
accepted_change(Runner,Reference) -> transit_sdk_worker:invoke(Runner,{document,{accepted_change,Reference}}).
identity(Realm,#transit_resource{realm=Realm,resource=Resource},D) -> #{<<"resource">>=>transit_sdk_value:counter(Resource),<<"document">>=>decimal(positive(D))};
identity(_,_,_) -> transit_sdk_value:fail(invalid_argument,document_realm).
encoded(Bridge,Realm,#transit_document_reference{resource=#transit_resource{realm=Realm}}=Ref) -> #{<<"reference">>:=Encoded}=transit_station_bridge:document_codec(Bridge,#{<<"reference">>=>reference(Ref)}),Encoded;
encoded(_,_,_) -> transit_sdk_value:fail(invalid_argument,document_realm).
decoded(Bridge,Realm,Bytes) -> #{<<"inspected_reference">>:=Value}=transit_station_bridge:document_codec(Bridge,#{<<"inspect_reference">>=>Bytes}),parsed_reference(Realm,Value).
field(#{<<"status">>:=S,<<"assignments">>:=A}) ->
    Status=known(S,[missing,null_value,scalar,object,conflict]),Values=array(A,8),true=((Status=:=missing)=:=(Values=:=[])),true=((Status=:=conflict)=:=(length(Values)>1)),
    #transit_document_field{status=Status,assignments=[#transit_document_assignment{id=parsed_dot(maps:get(<<"id">>,V)),value=parsed_scalar(maps:get(<<"value">>,V))}||V<-Values]}.
read_result(Bridge,Realm,{describe,Resource,Document}) ->
    #{<<"description">>:=V}=transit_station_bridge:document_read(Bridge,#{<<"describe">>=>identity(Realm,Resource,Document)}),
    #transit_document_description{reference=decoded(Bridge,Realm,maps:get(<<"reference">>,V)),source_revision=transit_sdk_value:counter(maps:get(<<"source_revision">>,V),0),floor=wide(maps:get(<<"floor">>,V)),merge_window=wide(maps:get(<<"merge_window">>,V)),active_job=wide(maps:get(<<"active_job">>,V)),retired=transit_sdk_value:boolean(maps:get(<<"retired">>,V)),change_format=u32(maps:get(<<"change_format">>,V))};
read_result(Bridge,Realm,{path,Ref,Names}) ->
    Encoded=encoded(Bridge,Realm,Ref),true=Names=/=[],Path=[transit_sdk_value:text(N,64)||N<-array(Names,16)],
    #{<<"field">>:=#{<<"reference">>:=Encoded,<<"source_revision">>:=Source,<<"value">>:=Value}}=transit_station_bridge:document_read(Bridge,#{<<"path">>=>#{<<"reference">>=>Encoded,<<"names">>=>Path}}),
    #transit_document_path{reference=Ref,source_revision=transit_sdk_value:counter(Source,0),field=field(Value)};
read_result(Bridge,Realm,{sequence,Ref,Object,Cursor}) ->
    Encoded=encoded(Bridge,Realm,Ref),Continuation=case Cursor of undefined->null; _->transit_sdk_value:text(Cursor,1024) end,
    #{<<"page">>:=#{<<"reference">>:=Encoded,<<"source_revision">>:=Source,<<"items">>:=Items,<<"next">>:=Next}}=transit_station_bridge:document_read(Bridge,#{<<"sequence">>=>#{<<"reference">>=>Encoded,<<"object">>=>dot(Object),<<"cursor">>=>Continuation}}),
    #transit_document_page{reference=Ref,source_revision=transit_sdk_value:counter(Source,0),items=[#transit_document_item{id=parsed_dot(maps:get(<<"id">>,V)),field=field(maps:get(<<"values">>,V))}||V<-array(Items,8)],next=case Next of null->undefined; _->transit_sdk_value:text(Next,1024) end};
read_result(Bridge,Realm,{resynchronize,Resource,D,Replica}) ->
    #{<<"resynchronization">>:=V}=transit_station_bridge:document_read(Bridge,#{<<"resynchronize">>=>#{<<"identity">>=>identity(Realm,Resource,D),<<"replica">>=>decimal(positive(Replica))}}),
    #transit_document_resynchronization{reference=decoded(Bridge,Realm,maps:get(<<"reference">>,V)),floor=wide(maps:get(<<"floor">>,V)),replica=wide(maps:get(<<"replica">>,V)),previous_counter=wide(maps:get(<<"previous_counter">>,V)),clock=wide(maps:get(<<"clock">>,V))};
read_result(Bridge,Realm,{accepted_change,Ref}) ->
    #{<<"change">>:=V}=transit_station_bridge:document_read(Bridge,#{<<"accepted_change">>=>encoded(Bridge,Realm,Ref)}),parsed_change(V).
