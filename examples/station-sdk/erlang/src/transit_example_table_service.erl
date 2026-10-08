-module(transit_example_table_service).
-behaviour(transit_station_handler).
-include_lib("transit_station_sdk/include/transit_unified_query.hrl").
-export([handle_message/3]).
-define(INITIAL, 18446744073709551615).
handle_message(Turn,#transit_incoming{kind=cast,value=advance,origin={process,#{process:=Process}}},Context) ->
    {ok,Process}=transit_turn:process(Turn), drive(Turn,Context), {ok,Context};
handle_message(Turn,#transit_incoming{kind=cast,value=Command,position=Id},Context) ->
    true=case Command of initialize->true;{insert,_,_}->true;{update,_,_}->true;{delete,_}->true;_->false end,
    enqueue(Turn,Id,Command),{ok,Context};
handle_message(Turn,#transit_incoming{kind=call,value=rows},Context) ->
    {ok,State}=transit_turn:state(Turn),
    case queue(State) of
        {0,0,true}->{ok,_}=transit_query:start(Turn,1,#transit_unified_plan{projection=[0,1,2,3],limit=18446744073709551615});
        _->{ok,ok}=transit_turn:reply(Turn,not_ready,transit_example_query_requester_codec)
    end,{ok,Context}.
queue(State) -> case transit_turn:find(State,transit_example_table_work:metadata()) of
    {ok,missing}->{0,0,false}; {ok,{found,Value}}->Value end.
wake(Turn) -> {ok,Process}=transit_turn:process(Turn),{ok,ok}=transit_turn:cast(Turn,Process,advance,transit_example_query_service_codec).
enqueue(Turn,Id,Command) ->
    true=is_integer(Id) andalso Id>0 andalso Id=<9007199254740991,
    {ok,State}=transit_turn:state(Turn),{Head,Tail,Ready}=queue(State),
    {ok,missing}=transit_turn:find(State,transit_example_table_work:work_key(Id)),
    {ok,missing}=transit_turn:find(State,transit_example_table_work:outcome_key(Id)),
    NewHead=case Tail of
        0 when not Ready, Command=/=initialize ->
            {ok,ok}=transit_turn:put(State,transit_example_table_work:work_key(?INITIAL),{Id,initialize}),?INITIAL;
        0->Id;
        _->true=Id>Tail,{ok,{0,Previous}}=transit_turn:require(State,transit_example_table_work:work_key(Tail)),
            {ok,ok}=transit_turn:put(State,transit_example_table_work:work_key(Tail),{Id,Previous}),Head
    end,
    {ok,ok}=transit_turn:put(State,transit_example_table_work:work_key(Id),{0,Command}),
    {ok,ok}=transit_turn:put(State,transit_example_table_work:metadata(),{NewHead,Id,Ready}),
    case Head of 0->wake(Turn);_->ok end.
drive(Turn,#{peer:=Peer}) ->
    {ok,State}=transit_turn:state(Turn),
    case queue(State) of
        {0,0,_}->ok;
        {Head,Tail,Ready}->
            {ok,{Next,Command}}=transit_turn:require(State,transit_example_table_work:work_key(Head)),
            true=((Next=:=0)=:=(Head=:=Tail)),true=(Next=:=0 orelse Head=:= ?INITIAL orelse Next>Head),
            Outcome=step(Turn,Head,Ready,Command),Initialize=Command=:=initialize,
            {ok,#{mutations:=Remaining}}=transit_turn:budgets(Turn),
            Required=case Initialize andalso not Ready of true->4;false->3 end,
            case Outcome=:=building orelse Remaining<Required of
                true->wake(Turn);
                false->
                    case Initialize andalso not Ready of true->{ok,ok}=transit_query:allow(Turn,Peer,1,0,true);false->ok end,
                    {ok,ok}=transit_turn:put(State,transit_example_table_work:outcome_key(Head),Outcome),
                    {ok,ok}=transit_turn:delete(State,transit_example_table_work:work_key(Head)),
                    NewTail=case Next of 0->0;_->Tail end,
                    {ok,ok}=transit_turn:put(State,transit_example_table_work:metadata(),{Next,NewTail,Ready orelse Initialize}),
                    case Next of 0->ok;_->wake(Turn) end
            end
    end.
step(Turn,_,_,initialize) ->
    {ok,Status}=transit_table:create(Turn,transit_example_keys:table(),transit_example_keys:limits()),
    case Status of #transit_table_creation{state=building}->building;
        #transit_table_creation{state=applied,admitted_input=A,completed_input=C}->{0,A,C,0,0,0} end;
step(Turn,Id,true,Command) when Id=/= ?INITIAL ->
    {ok,Resource}=transit_turn:resource(Turn),
    {ok,Mutation}=transit_table:prepare(Resource,0,Id,transit_example_keys:table(),mutation(Command)),
    {ok,Status}=transit_table:step(Turn,Mutation),
    case Status of #transit_table_status{state=building}->building;
        #transit_table_status{state=State,admitted_input=A,completed_input=C,counts=Counts,rejection=Rejection}->
            {Matched,Changed}=case Counts of undefined->{0,0};#transit_catalog_counts{matched=M,changed=N}->{M,N} end,
            {case State of applied->1;rejected->2;cancelled->3 end,A,C,Matched,Changed,rejection(Rejection)}
    end.
mutation({insert,Key,Value})->{insert,[[assignment(1,transit_example_keys:signed(Key)),assignment(2,cell(Value))]]};
mutation({update,Key,Value})->{update,[assignment(2,cell(Value))],[{compare,1,eq,{signed,Key}}]};
mutation({delete,Key})->{delete,[{compare,1,eq,{signed,Key}}]}.
assignment(Column,Value)->#transit_catalog_assignment{column=Column,value=Value}.
cell(null)->null;cell(Value)->transit_example_keys:signed(Value).
rejection(none)->0;rejection(row_exists)->1;rejection(row_identity_exists)->2;rejection(null_not_allowed)->3;
rejection(missing_required_field)->4;rejection(character_limit_exceeded)->5;rejection(overflow)->6;rejection(inexact)->7.
