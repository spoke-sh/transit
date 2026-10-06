%% Strict general Table values at the language/native boundary.
-module(transit_catalog_value).
-include("transit_catalog.hrl").
-export([scope/1,commitment/1,action/1,decode/4,connection/2,supported/1,definition/0,limit/1,basis/1,check_request/2,context/0,with_context/2]).
positive(V) -> transit_sdk_value:integer(V,1,18446744073709551615).
u64(V) -> transit_sdk_value:integer(V,0,18446744073709551615).
small(V) -> transit_sdk_value:integer(V,1,4294967295).
counter(V) -> transit_sdk_value:counter(V).
zero(V) -> transit_sdk_value:counter(V,0).
wide(V) -> positive(transit_sdk_value:wide(V)).
number(V) -> transit_sdk_value:wide(V).
decimal(V) -> integer_to_binary(positive(V)).
check(true) -> ok;
check(_) -> transit_sdk_value:fail(invalid_argument,catalog_value).
identifier(V) -> B=transit_sdk_value:text(V,255),check(byte_size(B)>0 andalso binary:match(B,<<0>>)=:=nomatch),B.
list(V,N) when is_list(V),length(V)=<N -> V;
list(_,_) -> check(false).
fields(V,Names) when is_map(V),map_size(V)=:=length(Names) -> check(lists:all(fun(K)->maps:is_key(K,V) end,Names)),V;
fields(_,_) -> check(false).
known(V,Allowed) -> case [A || A<-Allowed,atom_to_binary(A,utf8)=:=V] of [A]->A; _->check(false) end.
enum(V,Allowed) -> check(lists:member(V,Allowed)),atom_to_binary(V,utf8).
optional(undefined,_) -> null;
optional(V,F) -> F(V).
parsed(null,_) -> undefined;
parsed(V,F) -> F(V).
%% Only immutable package metadata is cached. Runtime grants and source cuts
%% are always read through the native caller. Scoped installation is restored
%% after every operation, including failed encoding and decoding.
context() ->
    Station=transit_sdk_value:contract(transit_station_sdk),Client=transit_sdk_value:contract(transit_client),
    #{definition=>maps:get(<<"definition">>,Station),limits=>maps:get(<<"limits">>,Station),diagnostic=>maps:get(<<"Diagnostic">>,maps:get(<<"schemas">>,Client))}.
with_context(Context,Fun) ->
    Before=put(?MODULE,Context),try Fun() after case Before of undefined->erase(?MODULE); _->put(?MODULE,Before) end end.
context_value(Key) -> case get(?MODULE) of undefined->maps:get(Key,context()); Context->maps:get(Key,Context) end.
definition() -> context_value(definition).
limit(Name) -> maps:get(Name,context_value(limits)).
current(V) -> check(V=:=definition()),V.
fixed(V,N) -> B=transit_sdk_value:bytes(V,N),check(byte_size(B)=:=N),B.
unhex(V,N) -> fixed(transit_sdk_value:unhex(V,N),N).
kinds() -> [create,alter,rename,drop,insert,update,delete].

scope(#transit_catalog_scope{resource=#transit_resource{realm=Realm,resource=Resource},catalog=Catalog}) ->
    #{<<"realm">>=>counter(Realm),<<"resource">>=>counter(Resource),<<"catalog">>=>decimal(Catalog)}.
connection(#transit_catalog_connection{owner=#transit_process{realm=Realm,pid=Owner},scope=#transit_catalog_scope{resource=#transit_resource{realm=Realm}}=Scope},#transit_credential{realm=Realm,principal=Principal}) ->
    #{<<"scope">>=>scope(Scope),<<"owner">>=>counter(Owner),<<"principal">>=>zero(Principal)}.
configuration(#transit_catalog_configuration{scope=#transit_catalog_scope{resource=#transit_resource{realm=Realm}}=Scope,owner=#transit_process{realm=Realm,pid=Owner},administrator=Admin,table_limits=#transit_catalog_limits{record_bytes=Record,staging_bytes=Staging,staging_records=Records}}) ->
    check(Staging>=Record),#{<<"scope">>=>scope(Scope),<<"owner">>=>counter(Owner),<<"administrator">>=>counter(Admin),<<"table_limits">>=>#{<<"record_bytes">>=>small(Record),<<"staging_bytes">>=>decimal(Staging),<<"staging_records">>=>small(Records)}}.
rights(#transit_catalog_rights{inspect=I,create=C,read=R,insert=In,update=U,delete=D,alter=A,drop=Dr}) ->
    maps:from_list([{atom_to_binary(K,utf8),transit_sdk_value:boolean(V)} || {K,V}<-lists:zip([inspect,create,read,insert,update,delete,alter,drop],[I,C,R,In,U,D,A,Dr])]).
policy(#transit_catalog_policy{scope=Scope,principal=P,revision=R,rights=Rights}) ->
    (rights(Rights))#{<<"scope">>=>scope(Scope),<<"principal">>=>zero(P),<<"revision">>=>decimal(R)}.
policy_change(#transit_catalog_policy_change{expected_revision=Expected,policy=#transit_catalog_policy{revision=Revision}=Policy}) ->
    check(u64(Expected)<18446744073709551615 andalso Revision=:=Expected+1),#{<<"expected_revision">>=>integer_to_binary(Expected),<<"policy">>=>policy(Policy)}.
column_fields(Name,Type,Nullable,Default,Max) ->
    #{<<"name">>=>identifier(Name),<<"type">>=>transit_logical:type_wire(Type),<<"nullable">>=>transit_sdk_value:boolean(Nullable),<<"default">>=>optional(Default,fun transit_logical:cell_wire/1),<<"max_characters">>=>optional(Max,fun small/1)}.
column(#transit_catalog_column{id=Id,name=Name,type=Type,nullable=Nullable,default=Default,max_characters=Max}) ->
    (column_fields(Name,Type,Nullable,Default,Max))#{<<"id">>=>decimal(Id)}.
%% Retain only a bounded prefix plus one individually bounded conversion.
wire_map(F,Values,Remaining) -> lists:mapfoldl(fun(V,Left)->
    Wire=F(V),Next=Left-byte_size(transit_sdk_value:encode(Wire)),
    case Next>=0 of true->{Wire,Next}; false->transit_sdk_value:fail(invalid_argument,catalog_wire_budget) end
end,Remaining,Values).
schema(#transit_catalog_schema{object=Object,revision=Revision,next_column=Next,columns=Columns,primary_key=Keys}) ->
    list(Columns,128),check(Columns=/=[]),list(Keys,length(Columns)),
    {Encoded,_}=wire_map(fun column/1,Columns,2097152),
    V=#{<<"definition">>=>definition(),<<"object">>=>decimal(Object),<<"revision">>=>decimal(Revision),<<"next_column">>=>decimal(Next),<<"columns">>=>Encoded,<<"primary_key">>=>[decimal(K)||K<-Keys]},
    check(byte_size(transit_sdk_value:encode(V))=<2097152),V.
identity(#transit_catalog_identity{operation=Operation,namespace=Namespace}) -> #{<<"operation">>=>decimal(Operation),<<"namespace">>=>decimal(Namespace)}.
basis(#transit_catalog_metadata{object=O,revision=R,schema_fingerprint=F}) -> #transit_catalog_basis{object=O,revision=R,schema_fingerprint=F}.
basis_wire(#transit_catalog_basis{object=O,revision=R,schema_fingerprint=F}) -> #{<<"object">>=>decimal(O),<<"revision">>=>decimal(R),<<"schema_fingerprint">>=>transit_sdk_value:hex(fixed(F,32))}.
cursor(undefined) -> null;
cursor(#transit_catalog_cursor{definition=Definition,scope=Scope,resource_revision=Revision,after_object=After}) ->
    #{<<"definition">>=>current(Definition),<<"scope">>=>scope(Scope),<<"resource_revision">>=>zero(Revision),<<"after_object">>=>decimal(After)}.
reference(#transit_catalog_reference{definition=Definition,digest=Digest}) -> #{<<"definition">>=>current(Definition),<<"digest">>=>transit_sdk_value:hex(fixed(Digest,32))}.
saved_intent(#transit_catalog_saved_intent{definition=Definition,bytes=Bytes}) ->
    B=transit_sdk_value:bytes(Bytes,limit(<<"catalog_intent_bytes">>)),check(byte_size(B)>0),#{<<"definition">>=>current(Definition),<<"bytes">>=>transit_sdk_value:hex(B)}.
saved(#transit_catalog_prepared{bytes=Bytes}) -> B=transit_sdk_value:text(Bytes,limit(<<"catalog_prepared_bytes">>)),check(byte_size(B)>0),B.
dependency(#transit_catalog_dependency{scope=#transit_catalog_scope{resource=#transit_resource{realm=Realm}}=Scope,object=O,identity=I,owner=#transit_process{realm=Realm,pid=Owner},kind=Kind},Present) ->
    #{<<"scope">>=>scope(Scope),<<"object">>=>decimal(O),<<"identity">>=>decimal(I),<<"owner">>=>counter(Owner),<<"kind">>=>enum(Kind,[query_source,writer,watch,maintained_relation,history]),<<"present">>=>transit_sdk_value:boolean(Present)}.
assignments(Values,Budget) -> wire_map(fun assignment/1,list(Values,128),Budget).
assignment(#transit_catalog_assignment{column=Column,value=Value}) ->
    V=case Value of default->#{<<"default">>=>#{}}; _->#{<<"cell">>=>transit_logical:cell_wire(Value)} end,#{<<"column">>=>decimal(Column),<<"value">>=>V}.
predicates(undefined,Budget) -> {null,Budget};
predicates(Values,Budget) -> wire_map(fun predicate/1,list(Values,64),Budget).
predicate(all) -> #{<<"atom">>=>#{<<"all">>=>#{}}};
predicate({state,Column,State}) -> #{<<"atom">>=>#{<<"state">>=>#{<<"column">>=>decimal(Column),<<"value">>=>enum(State,[missing,null,type_error,value,conflict])}}};
predicate({compare,Column,Op,Value}) -> #{<<"atom">>=>#{<<"compare">>=>#{<<"column">>=>decimal(Column),<<"op">>=>enum(Op,[eq,ne,lt,le,gt,ge]),<<"value">>=>transit_logical:atom_wire(Value)}}};
predicate(Op) -> #{enum(Op,[negate,conjunction,disjunction])=>#{}}.
mutation({insert,Rows}) -> list(Rows,1024),check(Rows=/=[]),
    {Encoded,_}=lists:mapfoldl(fun assignments/2,limit(<<"catalog_action_bytes">>),Rows),
    {#{<<"action">>=>#{<<"insert">>=>Encoded},<<"predicate">>=>null},insert};
mutation({update,Assignments,Predicate}) ->
    {Encoded,Left}=assignments(Assignments,limit(<<"catalog_action_bytes">>)),{P,_}=predicates(Predicate,Left),
    {#{<<"action">>=>#{<<"update">>=>Encoded},<<"predicate">>=>P},update};
mutation({delete,Predicate}) -> {P,_}=predicates(Predicate,limit(<<"catalog_action_bytes">>)),
    {#{<<"action">>=>#{<<"delete">>=>#{}},<<"predicate">>=>P},delete}.
change({add,Name,Type,Nullable,Default,Max}) -> #{<<"add">>=>column_fields(Name,Type,Nullable,Default,Max)};
change({drop,Column}) -> #{<<"drop">>=>decimal(Column)};
change({rename,Column,Name}) -> #{<<"rename">>=>#{<<"column">>=>decimal(Column),<<"name">>=>identifier(Name)}};
change({default,Column,Value}) -> #{<<"default">>=>#{<<"column">>=>decimal(Column),<<"value">>=>optional(Value,fun transit_logical:cell_wire/1)}};
change({nullable,Column,Value}) -> #{<<"nullable">>=>#{<<"column">>=>decimal(Column),<<"value">>=>transit_sdk_value:boolean(Value)}};
change({type,Column,Type,Max}) -> #{<<"type">>=>#{<<"column">>=>decimal(Column),<<"type">>=>transit_logical:type_wire(Type),<<"max_characters">>=>optional(Max,fun small/1)}}.
operation({create,#transit_catalog_schema{object=Object}=Schema,IfNotExists}) -> {#{<<"create">>=>#{<<"schema">>=>schema(Schema),<<"if_not_exists">>=>transit_sdk_value:boolean(IfNotExists)}},create,Object};
operation({alter,#transit_catalog_basis{object=Object}=Basis,Change}) -> {#{<<"alter">>=>#{<<"basis">>=>basis_wire(Basis),<<"change">>=>change(Change)}},alter,Object};
operation({rename,#transit_catalog_basis{object=Object}=Basis,Name}) -> {#{<<"rename">>=>#{<<"basis">>=>basis_wire(Basis),<<"name">>=>identifier(Name)}},rename,Object};
operation({drop,Basis,IfExists}) ->
    Object=case Basis of undefined->0; #transit_catalog_basis{object=O}->O end,
    {#{<<"drop">>=>#{<<"basis">>=>optional(Basis,fun basis_wire/1),<<"if_exists">>=>transit_sdk_value:boolean(IfExists)}},drop,Object};
operation({mutate,#transit_catalog_basis{object=Object}=Basis,Mutation}) ->
    {M,Kind}=mutation(Mutation),{#{<<"mutate">>=>#{<<"basis">>=>basis_wire(Basis),<<"mutation">>=>M}},Kind,Object}.
input(Prepared,Input) -> #{<<"prepared">>=>saved(Prepared),<<"input">>=>counter(Input)}.
action(capabilities) -> {#{<<"capabilities">>=>#{}},<<"capabilities">>,capabilities};
action(describe) -> {#{<<"describe">>=>#{}},<<"description">>,description};
action({lookup,Name}) -> N=identifier(Name),{#{<<"lookup">>=>N},<<"definition">>,{lookup,N}};
action({definition,Object,Revision}) -> {#{<<"definition">>=>#{<<"object">>=>decimal(Object),<<"revision">>=>decimal(Revision)}},<<"historical">>,{historical,Object,Revision}};
action({list,Cursor}) -> {#{<<"list">>=>cursor(Cursor)},<<"page">>,{page,Cursor}};
action({compile,Sql,Identity,CreateObject}) ->
    S=transit_sdk_value:text(Sql,4096),check(byte_size(S)>0),Kind=case CreateObject of undefined->undefined; _->create end,
    {#{<<"compile">>=>#{<<"sql">>=>S,<<"identity">>=>identity(Identity),<<"create_object">>=>optional(CreateObject,fun decimal/1)}},<<"compiled">>,{compiled,Identity,Kind,CreateObject}};
action({prepare,Name,Identity,Operation}) ->
    {A,Kind,Object}=operation(Operation),{#{<<"prepare">>=>#{<<"definition">>=>definition(),<<"name">>=>identifier(Name),<<"identity">>=>identity(Identity),<<"action">>=>A}},<<"compiled">>,{compiled,Identity,Kind,Object}};
action({load,Saved}) -> {#{<<"load">>=>saved_intent(Saved)},<<"loaded">>,intent};
action({forget,Reference}) -> {#{<<"forget">>=>reference(Reference)},<<"forgotten">>,empty};
action({next,Reference}) -> {#{<<"next">>=>reference(Reference)},<<"next">>,next};
action({status,Reference}) -> {#{<<"status">>=>reference(Reference)},<<"state">>,state};
action({prepare_resume,Reference}) -> {#{<<"prepare_resume">>=>reference(Reference)},<<"prepared">>,prepared};
action({prepare_control,Reference,Control}) -> {#{<<"prepare_control">>=>#{<<"intent">>=>reference(Reference),<<"control">>=>enum(Control,[cancel_operation,cleanup_operation,cancel_upload,collect_upload])}},<<"prepared">>,prepared};
action({prepare_initialize,Configuration}) -> {#{<<"prepare_initialize">>=>configuration(Configuration)},<<"prepared">>,prepared};
action({prepare_policy,Change}) -> {#{<<"prepare_policy">>=>policy_change(Change)},<<"prepared">>,prepared};
action({prepare_dependency,Dependency,Present}) -> {#{<<"prepare_dependency">>=>dependency(Dependency,Present)},<<"prepared">>,prepared};
action({submit,Prepared}) -> {#{<<"submit">>=>saved(Prepared)},<<"receipt">>,admission};
action({observe,Prepared,Input,Wait}) -> Tag=case Wait of true-> <<"wait_observe">>; false-> <<"observe">> end,{#{Tag=>input(Prepared,Input)},<<"observation">>,observation};
action({input_disposition,Prepared,Input}) -> {#{<<"input_disposition">>=>input(Prepared,Input)},<<"disposition">>,disposition};
action({progress,Reference,Prepared,Input,Wait}) ->
    Tag=case Wait of true-> <<"wait_progress">>; false-> <<"progress">> end,{#{Tag=>(input(Prepared,Input))#{<<"intent">>=>reference(Reference)}},<<"progress">>,progress}.
check_request({page,#transit_catalog_cursor{scope=Scope}},#transit_catalog_connection{scope=Scope}) -> ok;
check_request({page,undefined},_) -> ok;
check_request({page,_},_) -> check(false);
check_request(_,_) -> ok.

decode(admission,V,_,_) ->
    try fields(V,[<<"position">>]),#transit_admission{position=counter(maps:get(<<"position">>,V))}
    catch _:_ -> transit_sdk_value:fail(unknown_outcome,catalog_receipt) end;
decode(Kind,V,Connection,Principal) ->
    try decode_value(Kind,V,Connection,Principal)
    catch _:_ -> transit_sdk_value:fail(incompatible_native,catalog_response) end.
parse_scope(V) ->
    fields(V,[<<"realm">>,<<"resource">>,<<"catalog">>]),#transit_catalog_scope{resource=#transit_resource{realm=counter(maps:get(<<"realm">>,V)),resource=counter(maps:get(<<"resource">>,V))},catalog=wide(maps:get(<<"catalog">>,V))}.
parse_configuration(V) ->
    fields(V,[<<"scope">>,<<"owner">>,<<"administrator">>,<<"table_limits">>]),Scope=parse_scope(maps:get(<<"scope">>,V)),
    L=fields(maps:get(<<"table_limits">>,V),[<<"record_bytes">>,<<"staging_bytes">>,<<"staging_records">>]),
    Out=#transit_catalog_configuration{scope=Scope,owner=#transit_process{realm=(Scope#transit_catalog_scope.resource)#transit_resource.realm,pid=counter(maps:get(<<"owner">>,V))},administrator=counter(maps:get(<<"administrator">>,V)),table_limits=#transit_catalog_limits{record_bytes=small(maps:get(<<"record_bytes">>,L)),staging_bytes=wide(maps:get(<<"staging_bytes">>,L)),staging_records=small(maps:get(<<"staging_records">>,L))}},
    configuration(Out),Out.
parse_policy(V) ->
    fields(V,[<<"scope">>,<<"principal">>,<<"revision">>,<<"inspect">>,<<"create">>,<<"read">>,<<"insert">>,<<"update">>,<<"delete">>,<<"alter">>,<<"drop">>]),
    [I,C,R,In,U,D,A,Dr]=[transit_sdk_value:boolean(maps:get(atom_to_binary(K,utf8),V))||K<-[inspect,create,read,insert,update,delete,alter,drop]],
    #transit_catalog_policy{scope=parse_scope(maps:get(<<"scope">>,V)),principal=zero(maps:get(<<"principal">>,V)),revision=wide(maps:get(<<"revision">>,V)),rights=#transit_catalog_rights{inspect=I,create=C,read=R,insert=In,update=U,delete=D,alter=A,drop=Dr}}.
parse_schema(V) ->
    fields(V,[<<"definition">>,<<"object">>,<<"revision">>,<<"next_column">>,<<"columns">>,<<"primary_key">>]),current(maps:get(<<"definition">>,V)),
    Columns=[parse_column(C)||C<-list(maps:get(<<"columns">>,V),128)],Keys=[wide(K)||K<-list(maps:get(<<"primary_key">>,V),length(Columns))],
    Out=#transit_catalog_schema{object=wide(maps:get(<<"object">>,V)),revision=wide(maps:get(<<"revision">>,V)),next_column=wide(maps:get(<<"next_column">>,V)),columns=Columns,primary_key=Keys},schema(Out),Out.
parse_column(V) ->
    fields(V,[<<"id">>,<<"name">>,<<"type">>,<<"nullable">>,<<"default">>,<<"max_characters">>]),
    #transit_catalog_column{id=wide(maps:get(<<"id">>,V)),name=identifier(maps:get(<<"name">>,V)),type=transit_logical:type_from_wire(maps:get(<<"type">>,V)),nullable=transit_sdk_value:boolean(maps:get(<<"nullable">>,V)),default=parsed(maps:get(<<"default">>,V),fun transit_logical:cell_from_wire/1),max_characters=parsed(maps:get(<<"max_characters">>,V),fun small/1)}.
commitment(#transit_catalog_metadata_commitment{bytes=Bytes,digest=Digest}) ->
    #{<<"format">>=>16#54434d01,<<"length">>=>transit_sdk_value:integer(Bytes,1,436),<<"digest">>=>binary_to_list(fixed(Digest,32))}.
parse_commitment(V) ->
    fields(V,[<<"format">>,<<"length">>,<<"digest">>]),check(maps:get(<<"format">>,V)=:=16#54434d01),
    #transit_catalog_metadata_commitment{bytes=transit_sdk_value:integer(maps:get(<<"length">>,V),1,436),digest=transit_station_value:digest(maps:get(<<"digest">>,V))}.
metadata(V) ->
    fields(V,[<<"scope">>,<<"object">>,<<"revision">>,<<"name">>,<<"schema_fingerprint">>,<<"principal">>,<<"operation">>,<<"admitted_input">>,<<"commitment">>]),
    #transit_catalog_metadata{scope=parse_scope(maps:get(<<"scope">>,V)),object=wide(maps:get(<<"object">>,V)),revision=wide(maps:get(<<"revision">>,V)),name=identifier(maps:get(<<"name">>,V)),schema_fingerprint=unhex(maps:get(<<"schema_fingerprint">>,V),32),principal=zero(maps:get(<<"principal">>,V)),operation=wide(maps:get(<<"operation">>,V)),admitted_input=counter(maps:get(<<"admitted_input">>,V)),commitment=parse_commitment(maps:get(<<"commitment">>,V))}.
head(V) -> fields(V,[<<"revision">>,<<"rows">>,<<"pending">>]),#transit_catalog_head{revision=wide(maps:get(<<"revision">>,V)),rows=number(maps:get(<<"rows">>,V)),pending=number(maps:get(<<"pending">>,V))}.
resolved(null,_,_) -> undefined;
resolved(V,Scope,Name) ->
    fields(V,[<<"metadata">>,<<"head">>,<<"schema">>]),#transit_catalog_metadata{scope=Scope,name=Name,object=Object}=M=metadata(maps:get(<<"metadata">>,V)),#transit_catalog_schema{object=Object}=S=parse_schema(maps:get(<<"schema">>,V)),
    #transit_catalog_definition{metadata=M,head=head(maps:get(<<"head">>,V)),schema=S}.
historical(null,_,_,_) -> undefined;
historical(V,Scope,Object,Revision) ->
    fields(V,[<<"metadata">>,<<"schema">>]),#transit_catalog_metadata{scope=Scope,object=Object,revision=Revision}=M=metadata(maps:get(<<"metadata">>,V)),#transit_catalog_schema{object=Object}=S=parse_schema(maps:get(<<"schema">>,V)),
    #transit_catalog_historical_definition{metadata=M,schema=S}.
parse_cursor(V) ->
    fields(V,[<<"definition">>,<<"scope">>,<<"resource_revision">>,<<"after_object">>]),#transit_catalog_cursor{definition=current(maps:get(<<"definition">>,V)),scope=parse_scope(maps:get(<<"scope">>,V)),resource_revision=zero(maps:get(<<"resource_revision">>,V)),after_object=wide(maps:get(<<"after_object">>,V))}.
page_entries([],_,_,Acc) -> lists:reverse(Acc);
page_entries([null|Rest],Scope,_,Acc) -> page_entries(Rest,Scope,true,Acc);
page_entries([V|Rest],Scope,false,Acc) ->
    fields(V,[<<"metadata">>,<<"head">>]),#transit_catalog_metadata{scope=Scope,object=Object}=M=metadata(maps:get(<<"metadata">>,V)),
    case Acc of []->ok; [#transit_catalog_entry{metadata=#transit_catalog_metadata{object=Before}}|_]->check(Before<Object) end,
    page_entries(Rest,Scope,false,[#transit_catalog_entry{metadata=M,head=head(maps:get(<<"head">>,V))}|Acc]).
page(V,Scope,Previous) ->
    fields(V,[<<"resource_revision">>,<<"entries">>,<<"next">>]),Revision=zero(maps:get(<<"resource_revision">>,V)),Slots=list(maps:get(<<"entries">>,V),8),8=length(Slots),
    Entries=page_entries(Slots,Scope,false,[]),Next=parsed(maps:get(<<"next">>,V),fun parse_cursor/1),
    case Next of undefined->ok; #transit_catalog_cursor{scope=Scope,resource_revision=Revision,after_object=After}->
        case Entries of []->ok; _->#transit_catalog_entry{metadata=#transit_catalog_metadata{object=Last}}=lists:last(Entries),check(After>=Last) end end,
    case Previous of undefined->ok; #transit_catalog_cursor{scope=Scope,resource_revision=Revision,after_object=Before}->
        case Entries of []->ok; [#transit_catalog_entry{metadata=#transit_catalog_metadata{object=First}}|_]->check(First>Before) end,
        case Next of undefined->ok; #transit_catalog_cursor{after_object=End}->check(End>Before) end end,
    #transit_catalog_page{resource_revision=Revision,entries=Entries,next=Next}.
intent(V,#transit_catalog_connection{scope=Scope,owner=Owner},Principal) ->
    fields(V,[<<"reference">>,<<"scope">>,<<"owner">>,<<"principal">>,<<"operation">>,<<"namespace">>,<<"object">>,<<"kind">>]),
    R=fields(maps:get(<<"reference">>,V),[<<"definition">>,<<"digest">>]),Scope=parse_scope(maps:get(<<"scope">>,V)),
    Owner=#transit_process{realm=(Scope#transit_catalog_scope.resource)#transit_resource.realm,pid=counter(maps:get(<<"owner">>,V))},Principal=zero(maps:get(<<"principal">>,V)),
    #transit_catalog_intent{reference=#transit_catalog_reference{definition=current(maps:get(<<"definition">>,R)),digest=unhex(maps:get(<<"digest">>,R),32)},scope=Scope,owner=Owner,principal=Principal,
        identity=#transit_catalog_identity{operation=wide(maps:get(<<"operation">>,V)),namespace=wide(maps:get(<<"namespace">>,V))},object=number(maps:get(<<"object">>,V)),kind=known(maps:get(<<"kind">>,V),kinds())}.
compiled(V,Connection,Principal,Identity,Kind,Object) ->
    fields(V,[<<"intent">>,<<"saved">>]),#transit_catalog_intent{identity=Identity,kind=K,object=O}=Intent=intent(maps:get(<<"intent">>,V),Connection,Principal),
    check(Kind=:=undefined orelse K=:=Kind),check(Object=:=undefined orelse O=:=Object),S=fields(maps:get(<<"saved">>,V),[<<"definition">>,<<"bytes">>]),
    Saved=#transit_catalog_saved_intent{definition=current(maps:get(<<"definition">>,S)),bytes=transit_sdk_value:unhex(maps:get(<<"bytes">>,S),limit(<<"catalog_intent_bytes">>))},check(byte_size(Saved#transit_catalog_saved_intent.bytes)>0),#transit_catalog_compiled{intent=Intent,saved=Saved}.
diagnostic(V) ->
    Bytes=transit_sdk_value:encode(V),check(byte_size(Bytes)=<32768),Schema=context_value(diagnostic),
    transit_sdk_value:require(Schema,V),transit_sdk_value:json(Bytes).
outcome(null) -> undefined;
outcome(V) ->
    fields(V,[<<"kind">>,<<"operation">>,<<"object">>,<<"actual_object">>,<<"phase">>,<<"terminal">>,<<"counts">>,<<"admitted_input">>,<<"completed_input">>,<<"diagnostic">>]),
    Kind=known(maps:get(<<"kind">>,V),kinds()),Phase=known(maps:get(<<"phase">>,V),[preparing,delegated,building,applied,unchanged,rejected,cancelled]),Terminal=transit_sdk_value:boolean(maps:get(<<"terminal">>,V)),
    Counts=parsed(maps:get(<<"counts">>,V),fun(C)->fields(C,[<<"matched">>,<<"changed">>]),M=number(maps:get(<<"matched">>,C)),Ch=number(maps:get(<<"changed">>,C)),check(Ch=<M),#transit_catalog_counts{matched=M,changed=Ch} end),
    check(Terminal=:=lists:member(Phase,[applied,unchanged,rejected,cancelled])),check((Counts=/=undefined)=:=(Phase=:=applied andalso lists:member(Kind,[insert,update,delete]))),
    #transit_catalog_outcome{kind=Kind,operation=wide(maps:get(<<"operation">>,V)),object=number(maps:get(<<"object">>,V)),actual_object=parsed(maps:get(<<"actual_object">>,V),fun number/1),phase=Phase,terminal=Terminal,counts=Counts,admitted_input=counter(maps:get(<<"admitted_input">>,V)),completed_input=parsed(maps:get(<<"completed_input">>,V),fun counter/1),diagnostic=diagnostic(maps:get(<<"diagnostic">>,V))}.
upload(null) -> undefined;
upload(V) ->
    fields(V,[<<"phase">>,<<"received">>,<<"total">>]),Received=zero(maps:get(<<"received">>,V)),Total=small(maps:get(<<"total">>,V)),check(Received=<Total andalso Total=<limit(<<"catalog_intent_bytes">>)),
    #transit_catalog_upload{phase=known(maps:get(<<"phase">>,V),[uploading,sealed,ready,cancelled]),received=Received,total=Total}.
disposition(null) -> undefined;
disposition(V) ->
    fields(V,[<<"input">>,<<"outcome">>,<<"diagnostic">>]),#transit_catalog_disposition{input=counter(maps:get(<<"input">>,V)),outcome=known(maps:get(<<"outcome">>,V),[initialized,policy_applied,dependency_applied,invalid_command,blocked,denied,identity_conflict,stale_policy]),diagnostic=diagnostic(maps:get(<<"diagnostic">>,V))}.
prepared(V) -> P=#transit_catalog_prepared{bytes=V},#transit_catalog_prepared{bytes=saved(P)}.
next(V) when is_map(V),map_size(V)=:=1 ->
    case maps:to_list(V) of
        [{<<"send">>,P}]->#transit_catalog_next{kind=send,prepared=prepared(P)};
        [{<<"terminal">>,O}]->#transit_catalog_outcome{terminal=true}=Out=outcome(O),#transit_catalog_next{kind=terminal,outcome=Out};
        [{Tag,E}] when Tag=:= <<"running">>; Tag=:= <<"upload_cancelled">> -> fields(E,[]),#transit_catalog_next{kind=known(Tag,[running,upload_cancelled])}
    end.
progress(#{<<"pending">>:=V}=All) when map_size(All)=:=1 -> fields(V,[]),#transit_catalog_progress{observation=pending};
progress(#{<<"processed">>:=V}=All) when map_size(All)=:=1 ->
    fields(V,[<<"disposition">>,<<"outcome">>,<<"upload">>]),#transit_catalog_progress{observation=processed,disposition=disposition(maps:get(<<"disposition">>,V)),outcome=outcome(maps:get(<<"outcome">>,V)),upload=upload(maps:get(<<"upload">>,V))}.
capabilities(V) ->
    fields(V,[<<"version">>,<<"definition">>,<<"max_columns">>,<<"max_rows">>,<<"max_sql_bytes">>,<<"max_intent_bytes">>,<<"max_action_bytes">>,<<"max_prepared_bytes">>,<<"resident_intents">>]),
    #transit_catalog_capabilities{version=small(maps:get(<<"version">>,V)),definition=current(maps:get(<<"definition">>,V)),max_columns=small(maps:get(<<"max_columns">>,V)),max_rows=small(maps:get(<<"max_rows">>,V)),max_sql_bytes=small(maps:get(<<"max_sql_bytes">>,V)),max_intent_bytes=small(maps:get(<<"max_intent_bytes">>,V)),max_action_bytes=small(maps:get(<<"max_action_bytes">>,V)),max_prepared_bytes=small(maps:get(<<"max_prepared_bytes">>,V)),resident_intents=small(maps:get(<<"resident_intents">>,V))}.
supported(#transit_catalog_capabilities{version=1,max_columns=128,max_rows=1024,max_sql_bytes=4096,max_intent_bytes=I,max_action_bytes=A,max_prepared_bytes=P,resident_intents=1}) ->
    I=:=limit(<<"catalog_intent_bytes">>) andalso A=:=limit(<<"catalog_action_bytes">>) andalso P=:=limit(<<"catalog_prepared_bytes">>);
supported(_) -> false.
decode_value(capabilities,V,_,_) -> capabilities(V);
decode_value(description,V,#transit_catalog_connection{scope=Scope,owner=Owner},Principal) ->
    fields(V,[<<"configuration">>,<<"policy">>,<<"resource_revision">>]),#transit_catalog_configuration{scope=Scope,owner=Owner}=C=parse_configuration(maps:get(<<"configuration">>,V)),#transit_catalog_policy{scope=Scope,principal=Principal}=P=parse_policy(maps:get(<<"policy">>,V)),#transit_catalog_description{configuration=C,policy=P,resource_revision=zero(maps:get(<<"resource_revision">>,V))};
decode_value({lookup,Name},V,#transit_catalog_connection{scope=Scope},_) -> resolved(V,Scope,Name);
decode_value({historical,Object,Revision},V,#transit_catalog_connection{scope=Scope},_) -> historical(V,Scope,Object,Revision);
decode_value({page,Previous},V,#transit_catalog_connection{scope=Scope},_) -> page(V,Scope,Previous);
decode_value({compiled,Identity,Kind,Object},V,C,P) -> compiled(V,C,P,Identity,Kind,Object);
decode_value(intent,V,C,P) -> intent(V,C,P);
decode_value(empty,V,_,_) -> fields(V,[]),ok;
decode_value(next,V,_,_) -> next(V);
decode_value(state,V,_,_) -> fields(V,[<<"outcome">>,<<"upload">>]),#transit_catalog_state{outcome=outcome(maps:get(<<"outcome">>,V)),upload=upload(maps:get(<<"upload">>,V))};
decode_value(prepared,V,_,_) -> prepared(V);
decode_value(observation,V,_,_) -> known(V,[pending,processed]);
decode_value(disposition,V,_,_) -> disposition(V);
decode_value(progress,V,_,_) -> progress(V).
