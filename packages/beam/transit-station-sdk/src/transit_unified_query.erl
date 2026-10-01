%% Public immutable query values; the native worker owns signed protocol work.
-module(transit_unified_query).
-include("transit_unified_query.hrl").
-export([prepare/3,prepare/4,decode_arrow/3,decode_arrow/4,open/3,close/1,describe/2,inspect_sql/5,
         prepare_next/3,prepare_control/3,submit/2,observe/2,status/2,page/2,page/3]).
%% Internal bounded-worker callbacks, not an application wire interface.
-export([open/2,execute/2,evidence/1]).
-export_type([client/0,source/0,scalar/0,cell/0,predicate/0,predicate_atom/0,predicate_instruction/0,inspection/0]).
-opaque client() :: {transit_unified_client,transit_sdk_worker:handle()}.
-type source() :: #transit_unified_kv{} | #transit_unified_table{} | #transit_unified_document{}.
-type scalar() :: {int64,integer()} | {uint64,non_neg_integer()} | {float64,float()} | {boolean,boolean()} | {utf8,binary()} | {binary,binary()}.
-type cell() :: missing | null | {type_error,atom()} | {value,scalar()} | {conflict,[#transit_unified_alternative{}]}.
-type predicate_atom() :: all | {state,0..7,missing | null | type_error | value | conflict} | {compare,0..7,eq | ne | lt | le | gt | ge,scalar()}.
-type predicate_instruction() :: {atom,predicate_atom()} | negate | conjunction | disjunction.
-type predicate() :: predicate_atom() | #transit_unified_predicate_program{}.
-type inspection() :: #transit_unified_inspection{}.
-record(state,{bridge,connection=undefined}).
u64(V) -> transit_sdk_value:integer(V,0,18446744073709551615).
positive(V) -> transit_sdk_value:integer(V,1,18446744073709551615).
decimal(V) -> integer_to_binary(u64(V)).
wide(V) -> transit_sdk_value:wide(V).
array(V,N) when is_list(V),length(V)=<N -> V;
array(_,_) -> transit_sdk_value:fail(invalid_argument,query_array).
known(V,Allowed) -> case [A || A<-Allowed,atom_to_binary(A,utf8)=:=V] of [A]->A; _->transit_sdk_value:fail(incompatible_native,query_variant) end.
enum(V,A) -> transit_station_value:enum(V,A).
type(V) -> enum(V,[int64,uint64,float64,boolean,utf8,binary]).
resource(#transit_resource{realm=Realm,resource=Resource}) -> transit_sdk_value:counter(Realm),transit_sdk_value:counter(Resource).
source_resource(#transit_unified_kv{resource=R}) -> R;
source_resource(#transit_unified_table{resource=R}) -> R;
source_resource(#transit_unified_document{reference=#transit_document_reference{resource=R}}) -> R.
column(#transit_unified_column{name=N,type=T}) -> #{<<"name">>=>transit_sdk_value:text(N,64),<<"type">>=>type(T)}.
parsed_column(#{<<"name">>:=N,<<"type">>:=T}) -> #transit_unified_column{name=transit_sdk_value:text(N,64),type=known(T,[int64,uint64,float64,boolean,utf8,binary])}.
path(V) -> [transit_sdk_value:text(N,64) || N<-array(V,8)].
decoder(#transit_unified_decoder{type=T,version=V}) -> #{<<"type">>=>type(T),<<"version">>=>transit_sdk_value:integer(V,0,255)}.
projection(#transit_unified_projection{column=C,path=P,relative=R,mode=M,text_bytes=B,text_steps=S}) ->
    #{<<"column">>=>column(C),<<"path">>=>path(P),<<"relative">>=>transit_sdk_value:boolean(R),<<"mode">>=>enum(M,[scalar,text,element_counter,element_replica]),
      <<"text_bytes">>=>transit_sdk_value:integer(B,0,65535),<<"text_steps">>=>transit_sdk_value:integer(S,0,65535)}.
source(S) -> #{<<"version">>=>1,<<"resource">>=>resource(source_resource(S)),<<"source">>=>definition(S)}.
definition(#transit_unified_kv{prefix=P,key=K,value=V}) -> #{<<"kv">>=>#{<<"prefix">>=>transit_sdk_value:hex(transit_sdk_value:bytes(P,32)),<<"key">>=>decoder(K),<<"value">>=>decoder(V)}};
definition(#transit_unified_table{id=Id,names=Names,value_type=T}) -> true=length(Names)=:=2,#{<<"table">>=>#{<<"id">>=>transit_sdk_value:integer(Id,1,4294967295),<<"names">>=>path(Names),<<"value_type">>=>type(T)}};
definition(#transit_unified_document{reference=#transit_document_reference{resource=Resource,document=D,epoch=E,type_revision=T,revision=R},projections=P,expand=X}) ->
    true=P=/=[],positive(D),positive(E),
    #{<<"document">>=>#{<<"reference">>=>#{<<"resource">>=>resource(Resource),<<"document">>=>decimal(D),<<"epoch">>=>decimal(E),<<"type_revision">>=>transit_sdk_value:integer(T,1,4294967295),<<"revision">>=>decimal(R)},
      <<"change_format">>=>1,<<"expand">>=>optional(X,fun path/1),<<"projections">>=>[projection(V)||V<-array(P,8)]}}.
scalar({int64,V}) -> #{<<"int64">>=>transit_station_value:signed(V)};
scalar({uint64,V}) -> #{<<"uint64">>=>decimal(V)};
scalar({float64,V}) when is_float(V) -> #{<<"float_bits">>=>transit_sdk_value:hex(<<V:64/float-little>>)};
scalar({boolean,V}) -> #{<<"boolean">>=>transit_sdk_value:boolean(V)};
scalar({utf8,V}) -> #{<<"utf8">>=>transit_sdk_value:text(V,4096)};
scalar({binary,V}) -> #{<<"binary">>=>transit_sdk_value:hex(transit_sdk_value:bytes(V,4096))}.
parsed_scalar(V) when is_map(V),map_size(V)=:=1 ->
    case maps:to_list(V) of
        [{<<"int64">>,B}]->{int64,transit_sdk_value:signed(B)};
        [{<<"uint64">>,B}]->{uint64,wide(B)};
        [{<<"float_bits">>,B}]-> <<F:64/float-little>>=transit_sdk_value:unhex(B,8),{float64,F};
        [{<<"boolean">>,B}]->{boolean,transit_sdk_value:boolean(B)};
        [{<<"utf8">>,B}]->{utf8,transit_sdk_value:text(B,4096)};
        [{<<"binary">>,B}]->{binary,transit_sdk_value:unhex(B,4096)}
    end.
predicate(#transit_unified_predicate_program{instructions=Instructions}) ->
    true=Instructions=/=[],#{<<"program">>=>[predicate_instruction(I)||I<-array(Instructions,64)]};
predicate(Atom) -> predicate_atom(Atom).
predicate_instruction({atom,Atom}) -> #{<<"atom">>=>predicate_atom(Atom)};
predicate_instruction(Operator) -> #{enum(Operator,[negate,conjunction,disjunction])=>#{}}.
predicate_atom(all) -> #{<<"all">>=>#{}};
predicate_atom({state,C,V}) -> #{<<"state">>=>#{<<"column">>=>transit_sdk_value:integer(C,0,7),<<"value">>=>enum(V,[missing,null,type_error,value,conflict])}};
predicate_atom({compare,C,Op,V}) -> #{<<"compare">>=>#{<<"column">>=>transit_sdk_value:integer(C,0,7),<<"op">>=>enum(Op,[eq,ne,lt,le,gt,ge]),<<"value">>=>scalar(V)}};
predicate_atom(_) -> transit_sdk_value:fail(invalid_argument,predicate_atom).
plan(#transit_unified_plan{projection=P,predicate=F,aggregate=A,limit=L,output_names=N}) -> true=P=/=[],
    Names=optional(N,fun(Values)->true=length(Values)=:=length(P),[optional(V,fun(Name)->transit_sdk_value:text(Name,32) end)||V<-array(Values,8)] end),
    #{<<"version">>=>1,<<"projection">>=>[transit_sdk_value:integer(I,0,7)||I<-array(P,8)],<<"output_names">>=>Names,<<"predicate">>=>predicate(F),<<"aggregate">>=>enum(A,[rows,count,sum,count_values]),<<"limit">>=>optional(L,fun decimal/1)}.
budgets(#transit_unified_budgets{pages=P,segments=S,result_bytes=B}) -> positive(P),positive(S),positive(B),#{<<"pages">>=>decimal(P),<<"segments">>=>decimal(S),<<"result_bytes">>=>decimal(B)}.
parsed_budgets(#{<<"pages">>:=P,<<"segments">>:=S,<<"result_bytes">>:=B}) -> V=#transit_unified_budgets{pages=wide(P),segments=wide(S),result_bytes=wide(B)},budgets(V),V.
optional(undefined,_) -> null;
optional(V,F) -> F(V).
parsed_optional(null,_) -> undefined;
parsed_optional(V,F) -> F(V).
fixed(V,N) -> B=transit_sdk_value:unhex(V,N),true=byte_size(B)=:=N,B.
local(Action,Override) ->
    case transit_sdk_worker:open(?MODULE,{local,Override},false) of
        {ok,Worker} -> try case transit_sdk_worker:invoke(Worker,{codec,Action}) of {ok,V}->V; {error,E}->throw({transit_sdk,E}) end after transit_sdk_worker:close(Worker) end;
        {error,E} -> throw({transit_sdk,E})
    end.
-spec prepare(source(),#transit_unified_plan{},#transit_unified_budgets{}) -> {ok,#transit_unified_bundle{}} | {error,#transit_error{}}.
prepare(Source,Plan,Budgets) -> prepare(Source,Plan,Budgets,undefined).
prepare(Source,Plan,Budgets,Override) -> transit_sdk_value:protect(fun() ->
    #{<<"prepared">>:=#{<<"bytes">>:=B}}=local(#{<<"prepare">>=>#{<<"source">>=>source(Source),<<"plan">>=>plan(Plan),<<"limits">>=>budgets(Budgets)}},Override),#transit_unified_bundle{bytes=transit_sdk_value:unhex(B,16384)} end).
parsed_cell(V) when is_map(V),map_size(V)=:=1 ->
    case maps:to_list(V) of
        [{<<"missing">>,_}]->missing;
        [{<<"null">>,_}]->null;
        [{<<"type_error">>,T}]->{type_error,known(T,[unknown,int64,uint64,float64,boolean,utf8,binary,null_value,map,list,text,character])};
        [{<<"value">>,S}]->{value,parsed_scalar(S)};
        [{<<"conflict">>,Alternatives}]-> A=[alternative(X)||X<-array(Alternatives,8)],true=length(A)>=2,{conflict,A}
    end.
alternative(#{<<"counter">>:=C,<<"replica">>:=R,<<"value">>:=V}) ->
    Cell=parsed_cell(V),true=Cell=/=missing,true=element_or_atom(Cell)=/=conflict,
    #transit_unified_alternative{counter=positive(wide(C)),replica=positive(wide(R)),value=Cell}.
element_or_atom(V) when is_tuple(V)->element(1,V);
element_or_atom(V)->V.
decode_arrow(Columns,Ipc,Rows) -> decode_arrow(Columns,Ipc,Rows,undefined).
decode_arrow(Columns,Ipc,Rows,Override) -> transit_sdk_value:protect(fun() ->
    true=Columns=/=[],transit_sdk_value:integer(Rows,0,8),
    #{<<"rows">>:=Values}=local(#{<<"inspect_arrow">>=>#{<<"columns">>=>[column(C)||C<-array(Columns,8)],<<"rows">>=>Rows,<<"ipc">>=>transit_sdk_value:hex(transit_sdk_value:bytes(Ipc,65536))}},Override),
    Out=[[parsed_cell(C)||C<-array(Row,8)]||Row<-array(Values,8)],true=length(Out)=:=Rows,true=lists:all(fun(Row)->length(Row)=:=length(Columns) end,Out),Out end).
connection(#transit_unified_connection{source=#transit_process{realm=Realm,pid=Source},resource=#transit_resource{realm=Realm,resource=Resource},requester=#transit_process{realm=Realm,pid=Requester},requests=#transit_resource{realm=Realm,resource=Requests}},#transit_credential{realm=Realm,principal=Principal}) ->
    #{<<"realm">>=>transit_sdk_value:counter(Realm),<<"principal">>=>transit_sdk_value:counter(Principal,0),<<"source">>=>transit_sdk_value:counter(Source),<<"resource">>=>transit_sdk_value:counter(Resource),<<"requester">>=>transit_sdk_value:counter(Requester),<<"requests">>=>transit_sdk_value:counter(Requests)}.
open(Config,Credential,Connection) -> case transit_sdk_worker:open(?MODULE,{query,Config,Credential,Connection},false) of {ok,Worker}->{ok,{transit_unified_client,Worker}}; Error->Error end.
open({local,Override},_) -> #state{bridge=transit_station_bridge:local(Override)};
open({query,Config,Credential,Connection},_) ->
    Bridge=transit_station_bridge:query(Config,Credential,connection(Connection,Credential)),
    try
        #{<<"capabilities">>:=#{<<"version">>:=1,<<"kv">>:=true,<<"table">>:=true,<<"document">>:=true}}=transit_station_bridge:unified_query(Bridge,#{<<"capabilities">>=>#{}},false),
        #state{bridge=Bridge,connection=Connection}
    catch C:R:S -> catch transit_station_bridge:close(Bridge),erlang:raise(C,R,S) end.
close({transit_unified_client,Worker}) -> transit_sdk_worker:close(Worker);
close(#state{bridge=Bridge}) -> transit_station_bridge:close(Bridge).
evidence(_) -> undefined.
call({transit_unified_client,Worker},Request) -> transit_sdk_worker:invoke(Worker,Request).
describe(Client,Source) -> call(Client,{describe,Source}).
inspect_sql(Client,Source,Name,Sql,Budgets) -> call(Client,{inspect,Source,Name,Sql,Budgets}).
prepare_next(Client,Namespace,Bundle) -> call(Client,{next,Namespace,Bundle}).
prepare_control(Client,Control,Namespace) -> call(Client,{control,Control,Namespace}).
submit(Client,Prepared) -> case call(Client,{submit,Prepared}) of {error,#transit_error{kind=unknown_outcome}=E}->{uncertain,Prepared,E}; Other->Other end.
observe(Client,Position) -> call(Client,{observe,Position}).
status(Client,Namespace) -> call(Client,{status,Namespace}).
page(Client,Namespace) -> page(Client,Namespace,undefined).
page(Client,Namespace,Cursor) -> call(Client,{page,Namespace,Cursor}).
execute({codec,Action},#state{bridge=B}=State) -> {{ok,transit_station_bridge:unified_codec(B,Action)},State};
execute(Request,#state{bridge=B,connection=Connection}=State) -> {{ok,operation(B,Connection,Request)},State}.
request(B,A) -> transit_station_bridge:unified_query(B,A,false).
prepared(null) -> undefined;
prepared(V) -> #transit_unified_prepared{bytes=transit_sdk_value:text(V,8192)}.
cursor(null) -> undefined;
cursor(V) -> #transit_unified_cursor{opaque=transit_sdk_value:text(V,4096)}.
operation(B,#transit_unified_connection{resource=R},{describe,S}) ->
    true=source_resource(S)=:=R,#{<<"description">>:=V}=request(B,#{<<"describe">>=>source(S)}),Caps=maps:get(<<"capabilities">>,V),
    #transit_unified_description{resource_revision=transit_sdk_value:counter(maps:get(<<"resource_revision">>,V),0),policy_revision=wide(maps:get(<<"policy_revision">>,V)),budgets=parsed_budgets(maps:get(<<"limits">>,V)),active=parsed_optional(maps:get(<<"active">>,V),fun wide/1),bundle_bytes=maps:get(<<"bundle_bytes">>,Caps),segment_bytes=maps:get(<<"segment_bytes">>,Caps),batch_rows=maps:get(<<"batch_rows">>,Caps)};
operation(B,#transit_unified_connection{resource=R},{inspect,S,Name,Sql,Budgets}) ->
    true=source_resource(S)=:=R,
    #{<<"inspection">>:=V}=request(B,#{<<"inspect">>=>#{<<"scope">>=>#{<<"source">>=>source(S),<<"name">>=>transit_sdk_value:text(Name,32),<<"limits">>=>budgets(Budgets)},<<"sql">>=>transit_sdk_value:text(Sql,4096)}}),
    #{<<"version">>:=1,<<"scope">>:=<<"configured_source">>,<<"resource">>:=Id}=V,true=Id=:=R#transit_resource.resource,
    #transit_unified_inspection{name=transit_sdk_value:text(maps:get(<<"name">>,V),32),resource=R,source_kind=known(maps:get(<<"source_kind">>,V),[kv,table,document]),
        source_digest=transit_station_value:digest(maps:get(<<"contract">>,V)),schema_digest=transit_station_value:digest(maps:get(<<"schema">>,V)),
        resource_revision=transit_sdk_value:counter(maps:get(<<"resource_revision">>,V),0),policy_revision=positive(wide(maps:get(<<"policy_revision">>,V))),details=inspection_details(maps:get(<<"details">>,V))};
operation(B,_,{next,N,#transit_unified_bundle{bytes=Bundle}}) ->
    #{<<"prepared">>:=V}=request(B,#{<<"next">>=>#{<<"namespace">>=>decimal(positive(N)),<<"bundle">>=>transit_sdk_value:hex(transit_sdk_value:bytes(Bundle,16384))}}),prepared(V);
operation(B,_,{control,Control,N}) -> #{<<"prepared">>:=V}=request(B,#{<<"prepare">>=>#{enum(Control,[cancel,retire,collect])=>decimal(positive(N))}}),prepared(V);
operation(B,_,{submit,#transit_unified_prepared{bytes=Bytes}}) ->
    Result=transit_station_bridge:unified_query(B,#{<<"submit">>=>transit_sdk_value:text(Bytes,8192)},true),
    try #{<<"receipt">>:=#{<<"position">>:=Position}}=Result,#transit_admission{position=transit_sdk_value:counter(Position)}
    catch _:_ -> throw({transit_sdk,#transit_error{kind=unknown_outcome,phase=query_receipt,status=6}}) end;
operation(B,_,{observe,Position}) ->
    #{<<"observation">>:=V}=request(B,#{<<"observe">>=>transit_sdk_value:counter(Position)}),
    case V of #{<<"pending">>:=_}->#transit_unified_observation{state=pending}; #{<<"committed">>:=_}->#transit_unified_observation{state=committed}; #{<<"rejected">>:=Reason}->#transit_unified_observation{state=rejected,reason=transit_sdk_value:unhex(Reason,256)} end;
operation(B,_,{status,N}) ->
    #{<<"status">>:=V}=request(B,#{<<"status">>=>decimal(positive(N))}),parsed_optional(V,fun status_value/1);
operation(B,#transit_unified_connection{source=#transit_process{realm=Realm}},{page,N,Cursor}) ->
    C=optional(Cursor,fun(#transit_unified_cursor{opaque=Opaque})->transit_sdk_value:text(Opaque,4096) end),
    #{<<"page">>:=V}=request(B,#{<<"page">>=>#{<<"namespace">>=>decimal(positive(N)),<<"cursor">>=>C}}),
    #transit_unified_page{manifest=manifest(maps:get(<<"manifest">>,V),Realm),columns=[parsed_column(X)||X<-array(maps:get(<<"columns">>,V),8)],ordinal=wide(maps:get(<<"ordinal">>,V)),rows=transit_sdk_value:integer(maps:get(<<"rows">>,V),0,8),ipc=transit_sdk_value:unhex(maps:get(<<"ipc">>,V),65536),next=cursor(maps:get(<<"next">>,V))}.
status_value(V) -> #transit_unified_status{phase=known(maps:get(<<"phase">>,V),[uploading,sealed,admitted,complete,cancelled,denied,rejected,retired]),correlation=wide(maps:get(<<"correlation">>,V)),reference=fixed(maps:get(<<"reference">>,V),72),manifest=parsed_optional(maps:get(<<"manifest">>,V),fun(X)->fixed(X,72) end),collected=transit_sdk_value:boolean(maps:get(<<"collected">>,V))}.
inspection_details(V) when map_size(V)=:=1 ->
    case V of
        #{<<"description">>:=#{<<"columns">>:=Columns}} -> #transit_unified_source_description{columns=[parsed_column(C)||C<-array(Columns,8)]};
        #{<<"tables">>:=Names} -> #transit_unified_table_listing{names=[transit_sdk_value:text(N,32)||N<-array(Names,1)]};
        #{<<"explanation">>:=Plan} ->
            Operators=[known(O,[scan,filter,limit,project,count,sum,count_values])||O<-array(maps:get(<<"operators">>,Plan),4)],true=length(Operators)>=2,
            #transit_unified_explanation{operators=Operators,predicate=inspection_predicate(maps:get(<<"predicate">>,Plan)),projection=[transit_sdk_value:text(N,32)||N<-array(maps:get(<<"projection">>,Plan),8)],
                limit=parsed_optional(maps:get(<<"limit">>,Plan),fun wide/1),aggregate=known(maps:get(<<"aggregate">>,Plan),[rows,count,sum,count_values]),
                columns=[parsed_column(C)||C<-array(maps:get(<<"columns">>,Plan),8)],budgets=parsed_budgets(maps:get(<<"budgets">>,Plan))}
    end.
inspection_predicate(#{<<"program">>:=Instructions}=V) when map_size(V)=:=1 ->
    Program=array(Instructions,64),
    case lists:mapfoldl(fun inspection_instruction/2,0,Program) of
        {Parsed,1} -> #transit_unified_predicate_program{instructions=Parsed};
        _ -> transit_sdk_value:fail(incompatible_native,inspection_program_shape)
    end;
inspection_predicate(V) -> inspection_atom(V).
inspection_instruction(#{<<"atom">>:=Atom}=V,Depth) when map_size(V)=:=1 -> {{atom,inspection_atom(Atom)},Depth+1};
inspection_instruction(V,Depth) when is_map(V),map_size(V)=:=1 ->
    [{Name,Payload}]=maps:to_list(V),Operator=known(Name,[negate,conjunction,disjunction]),
    Needed=case Operator of negate->1; _->2 end,
    case is_map(Payload) andalso map_size(Payload)=:=0 andalso Depth>=Needed of
        true -> {Operator,Depth-Needed+1};
        false -> transit_sdk_value:fail(incompatible_native,inspection_program_shape)
    end;
inspection_instruction(_,_) -> transit_sdk_value:fail(incompatible_native,inspection_instruction).
inspection_atom(V) when is_map(V),map_size(V)=:=1 ->
    case V of
        #{<<"all">>:=Empty} when is_map(Empty),map_size(Empty)=:=0 -> all;
        #{<<"state">>:=#{<<"column">>:=Column,<<"value">>:=State}} -> {state,transit_sdk_value:text(Column,32),known(State,[missing,null,type_error,value,conflict])};
        #{<<"compare">>:=#{<<"column">>:=Column,<<"op">>:=Op,<<"type">>:=Type}} -> {compare,transit_sdk_value:text(Column,32),known(Op,[eq,ne,lt,le,gt,ge]),known(Type,[int64,uint64,float64,boolean,utf8,binary])};
        _ -> transit_sdk_value:fail(incompatible_native,inspection_atom)
    end;
inspection_atom(_) -> transit_sdk_value:fail(incompatible_native,inspection_atom).
manifest(V,Realm) ->
    Basis=maps:get(<<"basis">>,V),
    #transit_unified_manifest{job=maps:get(<<"job">>,V),source=transit_station_value:version(maps:get(<<"source">>,V)),requester=#transit_process{realm=Realm,pid=maps:get(<<"requester">>,V)},correlation=wide(maps:get(<<"correlation">>,V)),policy_revision=wide(maps:get(<<"policy_revision">>,V)),request=fixed(maps:get(<<"request">>,V),72),
        kind=known(maps:get(<<"kind">>,Basis),[kv,table,document]),resource=#transit_resource{realm=Realm,resource=maps:get(<<"resource">>,Basis)},revision=maps:get(<<"revision">>,Basis),source_digest=transit_station_value:digest(maps:get(<<"contract">>,Basis)),schema_digest=transit_station_value:digest(maps:get(<<"schema">>,Basis)),plan_digest=transit_station_value:digest(maps:get(<<"plan">>,V)),
        pages=wide(maps:get(<<"pages">>,V)),scanned=wide(maps:get(<<"scanned">>,V)),selected=wide(maps:get(<<"selected">>,V)),value_count=wide(maps:get(<<"value_count">>,V)),segments=wide(maps:get(<<"segments">>,V)),rows=wide(maps:get(<<"rows">>,V)),byte_count=wide(maps:get(<<"bytes">>,V)),sum=parsed_optional(maps:get(<<"sum">>,V),fun transit_sdk_value:signed/1),finished=known(maps:get(<<"finished">>,V),[source_end,limit]),chain=transit_station_value:digest(maps:get(<<"chain">>,V))}.
