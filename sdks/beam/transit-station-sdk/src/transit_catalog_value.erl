%% Strict general Table values at the language/native boundary.
-module(transit_catalog_value).
-include("transit_catalog.hrl").
-export([scope/1,action/1,decode/4,connection/2,supported/1,definition/0,limit/1,basis/1,check_request/3,context/0,with_context/2,save/1,restore/2,prepare_snapshot/3,reference_info/1]).
-export([schema/1,parse_schema/1,parse_scope/1,mutation/1,parse_mutation/1,collation/1]).
positive(V) -> transit_sdk_value:integer(V,1,18446744073709551615).
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
    #{definition=>maps:get(<<"definition">>,Station),limits=>maps:get(<<"limits">>,Station),diagnostic=>maps:get(<<"Diagnostic">>,maps:get(<<"schemas">>,Client)),schemas=>maps:get(<<"schemas">>,Station)}.
with_context(Context,Fun) ->
    Before=put(?MODULE,Context),try Fun() after case Before of undefined->erase(?MODULE); _->put(?MODULE,Before) end end.
context_value(Key) -> case get(?MODULE) of undefined->maps:get(Key,context()); Context->maps:get(Key,Context) end.
definition() -> context_value(definition).
limit(Name) -> maps:get(Name,context_value(limits)).
current(V) -> check(V=:=definition()),V.
fixed(V,N) -> B=transit_sdk_value:bytes(V,N),check(byte_size(B)=:=N),B.
unhex(V,N) -> fixed(transit_sdk_value:unhex(V,N),N).
encodings() -> [plain,bitpacked,rle,dictionary,fsst,comp,comp_3,zoned,ibm_hfp,ebcdic].
collations() -> [none,utf8_binary,ascii_ci,ebcdic_cp037,icu_root,ebcdic_037_pad,ebcdic_1047_nopad].
collation(V) -> enum(V,collations()).
kinds() -> [create,alter,rename,drop,insert,update,delete].

scope(#transit_catalog_scope{resource=#transit_resource{realm=Realm,resource=Resource},catalog=Catalog}) ->
    #{<<"realm">>=>counter(Realm),<<"resource">>=>counter(Resource),<<"catalog">>=>decimal(Catalog)}.
authority(#transit_catalog_authority{database_domain=D,schema_domain=S,table_domain=T,stream_domain=ST,queue_domain=Q,kv_domain=K,database=DO,initial_schema_authority=SO,initial_schema=NS}) ->
    check(length(lists:usort([D,S,T,ST,Q,K]))=:=6 andalso DO=/=SO),
    #{<<"database_domain">>=>counter(D),<<"schema_domain">>=>counter(S),<<"table_domain">>=>counter(T),<<"stream_domain">>=>counter(ST),<<"queue_domain">>=>counter(Q),<<"kv_domain">>=>counter(K),<<"database">>=>counter(DO),<<"initial_schema_authority">>=>counter(SO),<<"initial_schema">>=>counter(NS)}.
column_fields(Name,Type,Nullable,Default,Max,Encoding,Collation) ->
    #{<<"name">>=>identifier(Name),<<"type">>=>transit_logical:type_wire(Type),<<"nullable">>=>transit_sdk_value:boolean(Nullable),<<"default">>=>optional(Default,fun transit_logical:cell_wire/1),<<"max_characters">>=>optional(Max,fun small/1),<<"encoding">>=>enum(Encoding,encodings()),<<"collation">>=>collation(Collation)}.
column(#transit_catalog_column{id=Id,name=Name,type=Type,nullable=Nullable,default=Default,max_characters=Max,encoding=Encoding,collation=Collation}) ->
    (column_fields(Name,Type,Nullable,Default,Max,Encoding,Collation))#{<<"id">>=>decimal(Id)}.
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
change({add,Name,Type,Nullable,Default,Max,Encoding,Collation}) -> #{<<"add">>=>column_fields(Name,Type,Nullable,Default,Max,Encoding,Collation)};
change({physical,Column,Encoding,Collation}) -> #{<<"physical">>=>#{<<"column">>=>decimal(Column),<<"encoding">>=>enum(Encoding,encodings()),<<"collation">>=>enum(Collation,collations())}};
change({drop,Column}) -> #{<<"drop">>=>decimal(Column)};
change({rename,Column,Name}) -> #{<<"rename">>=>#{<<"column">>=>decimal(Column),<<"name">>=>identifier(Name)}};
change({default,Column,Value}) -> #{<<"default">>=>#{<<"column">>=>decimal(Column),<<"value">>=>optional(Value,fun transit_logical:cell_wire/1)}};
change({nullable,Column,Value}) -> #{<<"nullable">>=>#{<<"column">>=>decimal(Column),<<"value">>=>transit_sdk_value:boolean(Value)}};
change({type,Column,Type,Max}) -> #{<<"type">>=>#{<<"column">>=>decimal(Column),<<"type">>=>transit_logical:type_wire(Type),<<"max_characters">>=>optional(Max,fun small/1)}}.
parse_scope(V) ->
    fields(V,[<<"realm">>,<<"resource">>,<<"catalog">>]),#transit_catalog_scope{resource=#transit_resource{realm=counter(maps:get(<<"realm">>,V)),resource=counter(maps:get(<<"resource">>,V))},catalog=wide(maps:get(<<"catalog">>,V))}.
parse_authority(V) ->
    fields(V,[<<"database_domain">>,<<"schema_domain">>,<<"table_domain">>,<<"stream_domain">>,<<"queue_domain">>,<<"kv_domain">>,<<"database">>,<<"initial_schema_authority">>,<<"initial_schema">>]),
    A=#transit_catalog_authority{database_domain=counter(maps:get(<<"database_domain">>,V)),schema_domain=counter(maps:get(<<"schema_domain">>,V)),table_domain=counter(maps:get(<<"table_domain">>,V)),stream_domain=counter(maps:get(<<"stream_domain">>,V)),queue_domain=counter(maps:get(<<"queue_domain">>,V)),kv_domain=counter(maps:get(<<"kv_domain">>,V)),database=counter(maps:get(<<"database">>,V)),initial_schema_authority=counter(maps:get(<<"initial_schema_authority">>,V)),initial_schema=counter(maps:get(<<"initial_schema">>,V))},authority(A),A.
parse_subject(V) ->
    fields(V,[<<"principal">>,<<"login_role">>,<<"role">>,<<"credential_epoch">>,<<"audience">>,<<"context">>]),
    #transit_catalog_subject{principal=zero(maps:get(<<"principal">>,V)),login_role=zero(maps:get(<<"login_role">>,V)),role=zero(maps:get(<<"role">>,V)),credential_epoch=counter(maps:get(<<"credential_epoch">>,V)),audience=counter(maps:get(<<"audience">>,V)),context=transit_station_value:digest(maps:get(<<"context">>,V))}.
parse_schema(V) ->
    fields(V,[<<"definition">>,<<"object">>,<<"revision">>,<<"next_column">>,<<"columns">>,<<"primary_key">>]),current(maps:get(<<"definition">>,V)),
    Columns=[parse_column(C)||C<-list(maps:get(<<"columns">>,V),128)],Keys=[wide(K)||K<-list(maps:get(<<"primary_key">>,V),length(Columns))],
    Out=#transit_catalog_schema{object=wide(maps:get(<<"object">>,V)),revision=wide(maps:get(<<"revision">>,V)),next_column=wide(maps:get(<<"next_column">>,V)),columns=Columns,primary_key=Keys},schema(Out),Out.
parse_column(V) ->
    fields(V,[<<"id">>,<<"name">>,<<"type">>,<<"nullable">>,<<"default">>,<<"max_characters">>,<<"encoding">>,<<"collation">>]),
    #transit_catalog_column{id=wide(maps:get(<<"id">>,V)),name=identifier(maps:get(<<"name">>,V)),type=transit_logical:type_from_wire(maps:get(<<"type">>,V)),nullable=transit_sdk_value:boolean(maps:get(<<"nullable">>,V)),default=parsed(maps:get(<<"default">>,V),fun transit_logical:cell_from_wire/1),max_characters=parsed(maps:get(<<"max_characters">>,V),fun small/1),encoding=known(maps:get(<<"encoding">>,V),encodings()),collation=known(maps:get(<<"collation">>,V),collations())}.
parse_assignments(V) -> [begin
    fields(A,[<<"column">>,<<"value">>]), Cell=maps:get(<<"value">>,A),
    Value=case maps:to_list(Cell) of
        [{<<"default">>,Empty}]->fields(Empty,[]),default;
        [{<<"cell">>,C}]->transit_logical:cell_from_wire(C);
        _->check(false)
    end,
    #transit_catalog_assignment{column=wide(maps:get(<<"column">>,A)),value=Value}
end || A<-list(V,128)].
parse_predicate(V) -> case maps:to_list(V) of
    [{<<"atom">>,Atom}]->case maps:to_list(Atom) of
        [{<<"all">>,Empty}]->fields(Empty,[]),all;
        [{<<"state">>,State}]->fields(State,[<<"column">>,<<"value">>]),
            {state,wide(maps:get(<<"column">>,State)),known(maps:get(<<"value">>,State),[missing,null,type_error,value,conflict])};
        [{<<"compare">>,Compare}]->fields(Compare,[<<"column">>,<<"op">>,<<"value">>]),
            {compare,wide(maps:get(<<"column">>,Compare)),known(maps:get(<<"op">>,Compare),[eq,ne,lt,le,gt,ge]),transit_logical:atom_from_wire(maps:get(<<"value">>,Compare))};
        _->check(false)
    end;
    [{Op,Empty}]->fields(Empty,[]),known(Op,[negate,conjunction,disjunction]);
    _->check(false)
end.
parse_mutation(V) ->
    fields(V,[<<"action">>,<<"predicate">>]),
    Predicate=parsed(maps:get(<<"predicate">>,V),fun(P)->[parse_predicate(I)||I<-list(P,64)] end),
    Result=case maps:to_list(maps:get(<<"action">>,V)) of
        [{<<"insert">>,Rows}]->check(Predicate=:=undefined),{insert,[parse_assignments(R)||R<-list(Rows,1024)]};
        [{<<"update">>,Assignments}]->{update,parse_assignments(Assignments),Predicate};
        [{<<"delete">>,Empty}]->fields(Empty,[]),{delete,Predicate};
        _->check(false)
    end,
    {Encoded,_}=mutation(Result),check(Encoded=:=V),Result.

get(K,V) -> maps:get(atom_to_binary(K),V).
validate(Kind,V) -> transit_sdk_value:require(maps:get(Kind,context_value(schemas)),V).
connection(#transit_catalog_connection{scope=#transit_catalog_scope{resource=#transit_resource{realm=Realm}}}=C,#transit_credential{realm=Realm,principal=P}) -> connection(C,P);
connection(#transit_catalog_connection{scope=S,audience=A,branch=B,role=R},P) when is_integer(P) ->
    #{<<"scope">>=>scope(S),<<"audience">>=>counter(A),<<"branch">>=>decimal(B),<<"role">>=>optional(R,fun zero/1),<<"principal">>=>zero(P)}.
parse_connection(V) ->
    fields(V,[<<"scope">>,<<"audience">>,<<"branch">>,<<"role">>,<<"principal">>]),zero(get(principal,V)),
    #transit_catalog_connection{scope=parse_scope(get(scope,V)),audience=counter(get(audience,V)),branch=wide(get(branch,V)),role=parsed(get(role,V),fun zero/1)}.
position(V) -> fields(V,[<<"partition">>,<<"next_lsn">>]),#transit_catalog_position{partition=wide(get(partition,V)),next_lsn=number(get(next_lsn,V))}.
position_wire(#transit_catalog_position{partition=P,next_lsn=N}) -> #{<<"partition">>=>decimal(P),<<"next_lsn">>=>integer_to_binary(transit_sdk_value:integer(N,0,18446744073709551615))}.
object(V) -> fields(V,[<<"scope">>,<<"branch">>,<<"object">>]),#transit_catalog_object{scope=parse_scope(get(scope,V)),branch=wide(get(branch,V)),object=wide(get(object,V))}.
object_wire(#transit_catalog_object{scope=S,branch=B,object=O}) -> #{<<"scope">>=>scope(S),<<"branch">>=>decimal(B),<<"object">>=>decimal(O)}.
interpretation(V) -> fields(V,[<<"object">>,<<"revision">>,<<"digest">>]),#transit_catalog_interpretation{object=object(get(object,V)),revision=wide(get(revision,V)),digest=unhex(get(digest,V),32)}.
interpretation_wire(#transit_catalog_interpretation{object=O,revision=R,digest=D}) -> #{<<"object">>=>object_wire(O),<<"revision">>=>decimal(R),<<"digest">>=>transit_sdk_value:hex(fixed(D,32))}.
content(V) -> fields(V,[<<"bytes">>,<<"sha256">>]),#transit_catalog_content{bytes=wide(get(bytes,V)),sha256=unhex(get(sha256,V),32)}.
content_wire(#transit_catalog_content{bytes=B,sha256=D}) -> #{<<"bytes">>=>decimal(B),<<"sha256">>=>transit_sdk_value:hex(fixed(D,32))}.
stored(V) ->
    fields(V,[<<"interpretation">>,<<"content">>,<<"schema_fingerprint">>,<<"retired">>]),I=interpretation(get(interpretation,V)),C=content(get(content,V)),
    check(I#transit_catalog_interpretation.digest=:=C#transit_catalog_content.sha256),
    #transit_catalog_stored{interpretation=I,content=C,schema_fingerprint=unhex(get(schema_fingerprint,V),32),retired=transit_sdk_value:boolean(get(retired,V))}.
stored_wire(#transit_catalog_stored{interpretation=I,content=C,schema_fingerprint=F,retired=R}) ->
    #{<<"interpretation">>=>interpretation_wire(I),<<"content">>=>content_wire(C),<<"schema_fingerprint">>=>transit_sdk_value:hex(fixed(F,32)),<<"retired">>=>transit_sdk_value:boolean(R)}.
owns(#transit_catalog_connection{scope=S,branch=B},#transit_catalog_object{scope=S,branch=B}) -> ok;
owns(_,_) -> check(false).
basis(#transit_catalog_metadata{basis=B}) -> B.
basis_wire(#transit_catalog_basis{definition=D,connection=C,principal=P,namespace=N,name=Name,interpretation=I}) ->
    #{<<"definition">>=>current(D),<<"connection">>=>connection(C,P),<<"namespace">>=>counter(N),<<"name">>=>identifier(Name),<<"interpretation">>=>stored_wire(I)}.
parse_basis(V) ->
    validate(<<"CatalogAction">>,#{<<"prepare">>=>#{<<"definition">>=>definition(),<<"namespace">>=>1,<<"operation">>=><<"1">>,<<"name">>=><<"check">>,<<"action">>=>#{<<"drop">>=>#{<<"basis">>=>V,<<"if_exists">>=>false}}}}),
    C=parse_connection(get(connection,V)),I=stored(get(interpretation,V)),owns(C,(I#transit_catalog_stored.interpretation)#transit_catalog_interpretation.object),check(not I#transit_catalog_stored.retired),
    #transit_catalog_basis{definition=current(get(definition,V)),connection=C,principal=zero(get(principal,get(connection,V))),namespace=counter(get(namespace,V)),name=identifier(get(name,V)),interpretation=I}.
check_binding(V,C,P) ->
    current(get(definition,V)),I=get(identity,V),wide(get(operation,I)),check(parse_scope(get(scope,I))=:=C#transit_catalog_connection.scope),check(zero(get(principal,I))=:=P),
    O=object(get(target,V)),owns(C,O),unhex(get(intent,V),32),A=known(get(action,V),kinds()),
    E=parsed(get(expected_definition,V),fun interpretation/1),Data=parsed(get(expected_data,V),fun position/1),
    case A of create->check(E=:=undefined andalso Data=:=undefined); _->check(is_record(E,transit_catalog_interpretation)),check(E#transit_catalog_interpretation.object=:=O) end,V.
check_assertion(V) ->
    current(get(definition,V)),C=parse_connection(get(connection,V)),counter(get(namespace,V)),identifier(get(name,V)),wide(get(operation,V)),unhex(get(intent,V),32),
    Expected=parsed(get(expected,V),fun interpretation/1),case Expected of undefined->ok; I->owns(C,I#transit_catalog_interpretation.object) end,
    case known(get(action,V),[create_if_not_exists,drop_if_exists]) of create_if_not_exists->check(Expected=/=undefined);drop_if_exists->check(Expected=:=undefined) end,V.
parse_saved(V) ->
    validate(<<"CatalogAction">>,#{<<"load">>=>V}),case maps:to_list(V) of
        [{<<"table">>,T}]->current(get(definition,T)),counter(get(namespace,T)),check(byte_size(transit_sdk_value:unhex(get(bytes,T),limit(<<"catalog_intent_bytes">>)))>0);
        [{<<"name_assertion">>,A}]->check_assertion(A)
    end,#transit_catalog_saved_intent{data=transit_sdk_value:encode(V)}.
parse_reference(V) ->
    validate(<<"CatalogAction">>,#{<<"admit">>=>V}),case maps:to_list(V) of
        [{<<"table">>,T}]->current(get(definition,T)),counter(get(namespace,T)),C=get(connection,T),check_binding(get(binding,T),parse_connection(C),zero(get(principal,C))),Content=content(get(content,T)),check(Content#transit_catalog_content.bytes>36 andalso Content#transit_catalog_content.bytes=<limit(<<"catalog_intent_bytes">>));
        [{<<"name_assertion">>,A}]->check_assertion(A)
    end,#transit_catalog_reference{data=transit_sdk_value:encode(V)}.
reference_info(#transit_catalog_reference{data=Data}) ->
    V=saved_json(Data),parse_reference(V),[{Tag,T}]=maps:to_list(V),Kind=known(Tag,[table,name_assertion]),C=get(connection,T),
    B=case Kind of table->get(binding,T);name_assertion->T end,
    Operation=case Kind of table->wide(get(operation,get(identity,B)));name_assertion->wide(get(operation,T)) end,
    {Kind,parse_connection(C),zero(get(principal,C)),#transit_catalog_identity{operation=Operation,namespace=counter(get(namespace,T))},B}.
parse_cursor(V) ->
    Selection=get(selection,V),case maps:to_list(Selection) of
        [{<<"namespaces">>,_}]->validate(<<"CatalogAction">>,#{<<"catalog">>=>#{<<"namespaces">>=>V}}),counter(wide(get('after',V)));
        [{<<"tables">>,N}]->validate(<<"CatalogAction">>,#{<<"catalog">>=>#{<<"tables">>=>#{<<"namespace">>=>counter(N),<<"cursor">>=>V}}}),wide(get('after',V));
        _->check(false)
    end,current(get(definition,V)),parse_connection(get(connection,V)),check((position(get(position,V)))#transit_catalog_position.next_lsn>0),#transit_catalog_cursor{data=transit_sdk_value:encode(V)}.
owner_wire(#transit_catalog_snapshot_owner{definition=D,connection=C,principal=P,object=O,operation=Operation}) ->
    #{<<"definition">>=>current(D),<<"connection">>=>connection(C,P),<<"object">>=>object_wire(O),<<"operation">>=>decimal(Operation)}.
parse_owner(V) ->
    validate(<<"CatalogAction">>,#{<<"retention">>=>#{<<"status">>=>V}}),C=parse_connection(get(connection,V)),O=object(get(object,V)),owns(C,O),
    #transit_catalog_snapshot_owner{definition=current(get(definition,V)),connection=C,principal=zero(get(principal,get(connection,V))),object=O,operation=wide(get(operation,V))}.
acquisition_wire(#transit_catalog_snapshot_acquisition{owner=O,expected=P}) -> #{<<"owner">>=>owner_wire(O),<<"expected">>=>position_wire(P)}.
parse_acquisition(V) -> validate(<<"CatalogAction">>,#{<<"retention">>=>#{<<"acquire">>=>V}}),#transit_catalog_snapshot_acquisition{owner=parse_owner(get(owner,V)),expected=position(get(expected,V))}.
snapshot_wire(#transit_catalog_snapshot{owner=O,content=C}) -> #{<<"owner">>=>owner_wire(O),<<"content">>=>content_wire(C)}.
parse_snapshot(V) -> validate(<<"CatalogAction">>,#{<<"retention">>=>#{<<"metadata">>=>V}}),#transit_catalog_snapshot{owner=parse_owner(get(owner,V)),content=content(get(content,V))}.
prepare_snapshot(#transit_catalog_metadata{basis=#transit_catalog_basis{connection=C,principal=P,interpretation=I},position=Position},Operation,Definition) ->
    #transit_catalog_snapshot_acquisition{owner=#transit_catalog_snapshot_owner{definition=current(Definition),connection=C,principal=P,object=(I#transit_catalog_stored.interpretation)#transit_catalog_interpretation.object,operation=positive(Operation)},expected=Position}.
saved_json(Data) -> transit_sdk_value:json(transit_sdk_value:text(Data,limit(<<"catalog_action_bytes">>)),96).
wire(#transit_catalog_basis{}=V)->B=basis_wire(V),parse_basis(B),B;
wire(#transit_catalog_saved_intent{data=D})->V=saved_json(D),parse_saved(V),V;
wire(#transit_catalog_reference{data=D})->V=saved_json(D),parse_reference(V),V;
wire(#transit_catalog_cursor{data=D})->V=saved_json(D),parse_cursor(V),V;
wire(#transit_catalog_snapshot_owner{}=V)->B=owner_wire(V),parse_owner(B),B;
wire(#transit_catalog_snapshot_acquisition{}=V)->B=acquisition_wire(V),parse_acquisition(B),B;
wire(#transit_catalog_snapshot{}=V)->B=snapshot_wire(V),parse_snapshot(B),B.
save(V) -> transit_sdk_value:encode(wire(V)).
restore(Kind,Data) -> V=saved_json(Data),case Kind of
    basis->parse_basis(V);intent->parse_saved(V);reference->parse_reference(V);cursor->parse_cursor(V);snapshot_owner->parse_owner(V);snapshot_acquisition->parse_acquisition(V);snapshot->parse_snapshot(V)
end.

operation({create,Schema,If}) -> #{<<"create">>=>#{<<"schema">>=>schema(Schema),<<"if_not_exists">>=>transit_sdk_value:boolean(If)}};
operation({alter,Basis,Change}) -> #{<<"alter">>=>#{<<"basis">>=>wire(Basis),<<"change">>=>change(Change)}};
operation({rename,Basis,Name}) -> #{<<"rename">>=>#{<<"basis">>=>wire(Basis),<<"name">>=>identifier(Name)}};
operation({drop,Basis,If}) -> #{<<"drop">>=>#{<<"basis">>=>optional(Basis,fun wire/1),<<"if_exists">>=>transit_sdk_value:boolean(If)}};
operation({mutate,Basis,Mutation,Ingestion}) -> {M,_}=mutation(Mutation),#{<<"mutate">>=>#{<<"basis">>=>wire(Basis),<<"mutation">>=>M,<<"ingestion">>=>enum(Ingestion,[point,bulk])}}.
work(Action,Path,Check,Original) -> validate(<<"CatalogAction">>,Action),check(byte_size(transit_sdk_value:encode(Action))=<limit(<<"catalog_action_bytes">>)),{Action,Path,Check,Original}.
action(capabilities) -> work(#{<<"catalog">>=>#{<<"capabilities">>=>#{}}},[<<"catalog">>,<<"capabilities">>],capabilities,undefined);
action(describe) -> work(#{<<"catalog">>=>#{<<"describe">>=>#{}}},[<<"catalog">>,<<"description">>],description,undefined);
action({namespace,N}) -> work(#{<<"catalog">>=>#{<<"namespace">>=>counter(N)}},[<<"catalog">>,<<"namespace">>],{namespace,N},undefined);
action({namespaces,Cursor}) -> work(#{<<"catalog">>=>#{<<"namespaces">>=>optional(Cursor,fun wire/1)}},[<<"catalog">>,<<"namespaces">>],{page,namespaces,Cursor},undefined);
action({tables,N,Cursor}) -> work(#{<<"catalog">>=>#{<<"tables">>=>#{<<"namespace">>=>counter(N),<<"cursor">>=>optional(Cursor,fun wire/1)}}},[<<"catalog">>,<<"tables">>],{page,{tables,N},Cursor},undefined);
action({lookup,Name,N}) -> work(#{<<"lookup">>=>#{<<"namespace">>=>counter(N),<<"name">>=>identifier(Name)}},[<<"metadata">>],{lookup,Name,N},undefined);
action({compile,Sql,#transit_catalog_identity{operation=O,namespace=N}=I,Create,Dialect,Ingestion}) ->
    S=transit_sdk_value:text(Sql,4096),check(byte_size(S)>0),work(#{<<"compile">>=>#{<<"sql">>=>S,<<"namespace">>=>counter(N),<<"operation">>=>decimal(O),<<"create_object">>=>optional(Create,fun decimal/1),<<"dialect">>=>enum(Dialect,[transit,mysql]),<<"ingestion">>=>enum(Ingestion,[point,bulk])}},[<<"compiled">>],{compiled,I},undefined);
action({prepare,Name,#transit_catalog_identity{operation=O,namespace=N}=I,Operation}) ->
    work(#{<<"prepare">>=>#{<<"definition">>=>definition(),<<"namespace">>=>counter(N),<<"operation">>=>decimal(O),<<"name">>=>identifier(Name),<<"action">>=>operation(Operation)}},[<<"compiled">>],{compiled,I},undefined);
action({load,Saved}) -> work(#{<<"load">>=>wire(Saved)},[<<"loaded">>],{loaded,Saved},undefined);
action({forget,#transit_catalog_intent{id=Id}}) -> work(#{<<"forget">>=>Id},[<<"forgotten">>],empty,undefined);
action({preview,#transit_catalog_intent{id=Id}=I}) -> work(#{<<"preview">>=>Id},[<<"preview">>],{preview,I},undefined);
action({stage,#transit_catalog_intent{id=Id,saved=Saved}=I}) -> wire(Saved),work(#{<<"stage">>=>Id},[<<"staged">>],{staged,I},Saved);
action({admit,Reference}) -> work(#{<<"admit">>=>wire(Reference)},[<<"observation">>],{observation,Reference},Reference);
action({operation,Reference,Command,Steps}) ->
    Original=case Command of inspect->undefined;_->Reference end,
    work(#{<<"operation">>=>#{<<"reference">>=>wire(Reference),<<"command">>=>enum(Command,[inspect,execute,cancel]),<<"steps">>=>transit_sdk_value:integer(Steps,1,65535)}},[<<"observation">>],{observation,Reference},Original);
action({retention,Command,Value}) ->
    {Field,Original}=case Command of acquire->{<<"acquired">>,Value};release->{<<"released">>,Value};status->{<<"status">>,undefined};metadata->{<<"metadata">>,undefined} end,
    work(#{<<"retention">>=>#{enum(Command,[acquire,release,status,metadata])=>wire(Value)}},[<<"retention">>,Field],{retention,Command,Value},Original).
selection(namespaces) -> #{<<"namespaces">>=>#{}};
selection({tables,N}) -> #{<<"tables">>=>counter(N)}.
check_request({page,Selection,#transit_catalog_cursor{}=Cursor},C,P) -> V=wire(Cursor),check(get(connection,V)=:=connection(C,P)),check(get(selection,V)=:=selection(Selection));
check_request({observation,R},C,P) -> {_,RC,RP,_,_}=reference_info(R),check(RC=:=C andalso RP=:=P);
check_request({retention,_,V},C,P) -> O=case V of #transit_catalog_snapshot_owner{}->V;#transit_catalog_snapshot_acquisition{owner=A}->A;#transit_catalog_snapshot{owner=A}->A end,
    check(O#transit_catalog_snapshot_owner.connection=:=C andalso O#transit_catalog_snapshot_owner.principal=:=P);
check_request(_,_,_) -> ok.
reasons() -> [none,name_conflict,object_conflict,stale_definition,stale_data,dependency,constraint,definition_changed,data_changed,duplicate_key,missing_row,invalid_rows,work_limit,condition_changed].
capabilities(V) ->
    current(get(definition,V)),#transit_catalog_capabilities{version=small(get(version,V)),definition=definition(),max_columns=small(get(max_columns,V)),max_rows=small(get(max_rows,V)),max_sql_bytes=small(get(max_sql_bytes,V)),max_intent_bytes=small(get(max_intent_bytes,V)),max_action_bytes=small(get(max_action_bytes,V)),metadata_page_entries=small(get(metadata_page_entries,V)),resident_intents=small(get(resident_intents,V))}.
supported(#transit_catalog_capabilities{version=1,max_columns=128,max_rows=1024,max_sql_bytes=4096,max_intent_bytes=I,max_action_bytes=A,metadata_page_entries=8,resident_intents=1}) -> I=:=limit(<<"catalog_intent_bytes">>) andalso A=:=limit(<<"catalog_action_bytes">>);
supported(_) -> false.
parse_configuration(V) -> #transit_catalog_configuration{scope=parse_scope(get(scope,V)),branch=wide(get(branch,V)),partition=wide(get(partition,V)),audience=counter(get(audience,V)),authority=parse_authority(get(authority,V)),database_name=identifier(get(database_name,V)),initial_schema_name=identifier(get(initial_schema_name,V))}.
namespace(V) -> #transit_catalog_namespace{scope=parse_scope(get(scope,V)),id=counter(get(id,V)),authorization=counter(get(authorization,V)),name=identifier(get(name,V)),revision=counter(get(revision,V)),retired=transit_sdk_value:boolean(get(retired,V))}.
summary(V,Saved,C,P,Expected) ->
    Id=get(id,V),current(get(definition,Id)),unhex(get(digest,Id),32),[{Tag,Binding}]=maps:to_list(get(binding,V)),Kind=known(Tag,[table,name_assertion]),N=counter(get(namespace,V)),
    O=case Kind of table->check_binding(Binding,C,P),wide(get(operation,get(identity,Binding)));name_assertion->check_assertion(Binding),check(get(connection,Binding)=:=connection(C,P)),check(get(namespace,Binding)=:=N),wide(get(operation,Binding)) end,
    Identity=#transit_catalog_identity{operation=O,namespace=N},check(Expected=:=undefined orelse Expected=:=Identity),Raw=maps:get(Tag,wire(Saved)),check(get(namespace,Raw)=:=N),check(Kind=:=table orelse Raw=:=Binding),
    #transit_catalog_intent{id=Id,binding=Binding,kind=Kind,identity=Identity,saved=Saved}.
expected_kind(name_assertion,_) -> name_assertion;
expected_kind(table,B) -> case get(action,B) of <<"insert">>->rows;<<"update">>->rows;<<"delete">>->rows;_->ddl end.
observation(V,R) ->
    {Work,_,_,_,Binding}=reference_info(R),[{Tag,State}]=maps:to_list(V),Kind=known(Tag,[ddl,rows,name_assertion]),check(Kind=:=expected_kind(Work,Binding)),[{StateTag,Raw}]=maps:to_list(State),
    Out=#transit_catalog_observation{kind=Kind,reference=R},case StateTag of
        <<"not_observed">>->fields(Raw,[]),Out#transit_catalog_observation{state=not_observed};
        _->check(get(binding,Raw)=:=Binding),case Kind of
            name_assertion->check(StateTag=:= <<"outcome">>),Out#transit_catalog_observation{state=known(get(state,Raw),[unchanged,rejected]),reason=known(get(reason,Raw),reasons()),position=position(get(position,Raw))};
            _->case StateTag of
                <<"committed">>->I=stored(get(resulting,Raw)),O=get(outcome,Raw),M=number(get(matched,O)),A=number(get(affected,O)),check(A=<M),check((I#transit_catalog_stored.interpretation)#transit_catalog_interpretation.object=:=object(get(target,Binding))),
                    Out#transit_catalog_observation{state=committed,commit=#transit_catalog_commit{definition=I,position=position(get(position,O)),matched=M,affected=A,live_rows=number(get(live_rows,O))}};
                _->StateName=known(StateTag,[admitted,rejected,cancelled]),Phase=known(get(phase,Raw),[admitted,ready,settled,rejected,cancelled]),
                    case StateName of admitted->check(lists:member(Phase,[admitted,ready,settled]));_->check(Phase=:=StateName) end,content(get(intent,Raw)),
                    case Kind of rows->Basis=get(basis,Raw),interpretation(get(interpretation,Basis)),position(get(position,Basis)),number(get(changed_lsn,Basis));_->ok end,
                    Out#transit_catalog_observation{state=StateName,phase=Phase,reason=known(get(reason,Raw),reasons())}
            end
        end
    end.
current_basis(V) -> #transit_catalog_current{definition=stored(get(interpretation,V)),position=position(get(position,V)),changed_lsn=number(get(changed_lsn,V)),row_count=number(get(row_count,V))}.
preview(V,#transit_catalog_intent{kind=Work,binding=B}=I) ->
    [{Tag,Raw}]=maps:to_list(V),Kind=known(Tag,[ddl,rows,name_assertion]),check(Kind=:=expected_kind(Work,B) andalso get(binding,Raw)=:=B),Out=#transit_catalog_preview{kind=Kind,intent=I},
    case Kind of name_assertion->Out#transit_catalog_preview{position=position(get(position,Raw)),current=parsed(get(current,Raw),fun interpretation/1),matches=transit_sdk_value:boolean(get(matches,Raw))};
        _->Base=Out#transit_catalog_preview{position=position(get(directory_position,Raw)),current=parsed(get(current,Raw),fun current_basis/1),reason=known(get(reason,Raw),reasons())},
            case Kind of rows->Base;ddl->Base#transit_catalog_preview{work=parsed(get(work,Raw),fun(W)->known(W,[metadata,validate_rows,rewrite_rows]) end),rebuild_key=transit_sdk_value:boolean(get(rebuild_key,Raw)),schema_fingerprint=parsed(get(schema_fingerprint,Raw),fun(F)->unhex(F,32) end)} end
    end.
read_authority(V) -> D=counter(get(database,V)),S=counter(get(schema,V)),T=counter(get(table,V)),check(D=/=S andalso D=/=T andalso S=/=T),#transit_catalog_read_authority{database=D,schema=S,table=T}.
page(V,Selection,Previous,C,P) ->
    Position=position(get(position,V)),Slots=get(entries,V),check(is_list(Slots) andalso length(Slots)=:=8),
    Before=case Previous of undefined->0;_->PV=wire(Previous),check(position(get(position,PV))=:=Position),wide(get('after',PV)) end,
    {Entries,Last,_}=lists:foldl(fun(null,{Items,After,_})->{Items,After,true};(Raw,{Items,After,false})->
        {Id,Entry}=case Selection of namespaces->N=namespace(Raw),check(N#transit_catalog_namespace.scope=:=C#transit_catalog_connection.scope),{N#transit_catalog_namespace.id,N};
            {tables,Ns}->I=interpretation(get(interpretation,Raw)),O=I#transit_catalog_interpretation.object,owns(C,O),check(counter(get(namespace,Raw))=:=Ns),{O#transit_catalog_object.object,#transit_catalog_entry{interpretation=I,namespace=Ns,name=identifier(get(name,Raw)),position=position(get(position,Raw)),changed_lsn=number(get(changed_lsn,Raw))}}
        end,check(Id>After),{[Entry|Items],Id,false};(_,_) -> check(false)
    end,{[],Before,false},Slots),
    Next=parsed(get(next,V),fun parse_cursor/1),case Next of undefined->ok;_->check_request({page,Selection,Next},C,P),NV=wire(Next),check(position(get(position,NV))=:=Position andalso wide(get('after',NV))>=Last andalso wide(get('after',NV))>Before) end,
    Consistency=case Selection of namespaces->undefined;_->known(get(consistency,V),[independent]) end,#transit_catalog_page{position=Position,entries=lists:reverse(Entries),next=Next,consistency=Consistency}.
decode(capabilities,V,_,_) -> capabilities(V);
decode(description,V,#transit_catalog_connection{scope=S,branch=B,audience=A,role=Role},P) ->
    Config=parse_configuration(get(configuration,V)),Subject=parse_subject(get(subject,V)),
    check(Config#transit_catalog_configuration.scope=:=S andalso Config#transit_catalog_configuration.branch=:=B andalso Config#transit_catalog_configuration.audience=:=A),
    check(Subject#transit_catalog_subject.principal=:=P andalso Subject#transit_catalog_subject.audience=:=A andalso (Role=:=undefined orelse Role=:=Subject#transit_catalog_subject.role)),
    #transit_catalog_description{configuration=Config,subject=Subject,policy_revision=zero(get(policy_revision,V))};
decode({namespace,N},V,C,_) -> parsed(V,fun(Raw)->Out=namespace(Raw),check(Out#transit_catalog_namespace.id=:=N andalso Out#transit_catalog_namespace.scope=:=C#transit_catalog_connection.scope),Out end);
decode({page,Selection,Previous},V,C,P) -> page(V,Selection,Previous,C,P);
decode({lookup,Name,N},V,C,P) -> parsed(V,fun(Raw)->B=parse_basis(get(binding,Raw)),Schema=parse_schema(get(schema,Raw)),
    check(B#transit_catalog_basis.connection=:=C andalso B#transit_catalog_basis.principal=:=P andalso B#transit_catalog_basis.namespace=:=N andalso B#transit_catalog_basis.name=:=Name),
    check(((B#transit_catalog_basis.interpretation)#transit_catalog_stored.interpretation)#transit_catalog_interpretation.object=:=#transit_catalog_object{scope=C#transit_catalog_connection.scope,branch=C#transit_catalog_connection.branch,object=Schema#transit_catalog_schema.object}),
    #transit_catalog_metadata{basis=B,authorization=counter(get(authorization,Raw)),position=position(get(position,Raw)),changed_lsn=number(get(changed_lsn,Raw)),row_count=number(get(row_count,Raw)),schema=Schema} end);
decode({compiled,I},V,C,P) -> Saved=parse_saved(get(saved,V)),#transit_catalog_compiled{intent=summary(get(summary,V),Saved,C,P,I),saved=Saved};
decode({loaded,Saved},V,C,P) -> summary(V,Saved,C,P,undefined);
decode(empty,V,_,_) -> fields(V,[]),ok;
decode({preview,I},V,_,_) -> preview(V,I);
decode({staged,#transit_catalog_intent{kind=Kind,binding=B,identity=Identity}},V,C,P) -> R=parse_reference(V),{Kind,C,P,Identity,B}=reference_info(R),R;
decode({observation,R},V,_,_) -> observation(V,R);
decode({retention,acquire,#transit_catalog_snapshot_acquisition{owner=O}},V,_,_) -> S=parse_snapshot(V),check(S#transit_catalog_snapshot.owner=:=O),S;
decode({retention,release,S},V,_,_) -> check(V=:=wire(S)),S;
decode({retention,status,O},V,_,_) ->
    check(get(owner,V)=:=owner_wire(O)),I=interpretation(get(current_interpretation,V)),check(I#transit_catalog_interpretation.object=:=O#transit_catalog_snapshot_owner.object),S=parsed(get(snapshot,V),fun parse_snapshot/1),
    check(S=:=undefined orelse S#transit_catalog_snapshot.owner=:=O),#transit_catalog_snapshot_status{owner=O,current_interpretation=I,current_position=position(get(current_position,V)),retired=transit_sdk_value:boolean(get(retired,V)),snapshot=S,released=transit_sdk_value:boolean(get(released,V)),authority=read_authority(get(authority,V))};
decode({retention,metadata,S},V,_,_) ->
    check(get(snapshot,V)=:=wire(S)),I=stored(get(interpretation,V)),Schema=parse_schema(get(schema,V)),O=(S#transit_catalog_snapshot.owner)#transit_catalog_snapshot_owner.object,
    check((I#transit_catalog_stored.interpretation)#transit_catalog_interpretation.object=:=O andalso Schema#transit_catalog_schema.object=:=O#transit_catalog_object.object),
    #transit_catalog_snapshot_metadata{snapshot=S,interpretation=I,accepted=position(get(accepted,V)),changed_lsn=number(get(changed_lsn,V)),row_count=number(get(row_count,V)),schema=Schema,authority=read_authority(get(authority,V))}.
