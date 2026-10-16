%% Internal worker callback. Local callback state never becomes durable state.
-module(transit_station_runner).
-include("transit_station_sdk.hrl").
-export([open/2, execute/2, evidence/1, close/1]).
-record(state, {bridge, handler, context, codec, failure, recovery, stop, process,
                pending = undefined, confirmed = undefined, paused = undefined,
                attempted = false, last_event = undefined, readers = #{}, closed_readers = #{}}).
open({local, Override}, _) -> {local, transit_station_bridge:local(Override)};
open({#transit_service{activation = #transit_activation{process = Process}} = Service, Handler, Initial, Codec, Failure, Recovery}, Stop) ->
    true = is_atom(Handler), {module, Handler} = code:ensure_loaded(Handler),
    true = erlang:function_exported(Handler, handle_message, 3),
    case Recovery of
        fresh_ownership -> ok;
        {persist_before_dispatch, Store, _} -> {module, Store} = code:ensure_loaded(Store),
            true = erlang:function_exported(Store, before_dispatch, 2), true = erlang:function_exported(Store, confirmed, 3)
    end,
    Bridge = transit_station_bridge:open(Service, Failure),
    try
        transit_station_value:bound(Codec, maps:get(<<"message_bytes">>, transit_station_bridge:caps(Bridge))),
        #state{bridge = Bridge, handler = Handler, context = Initial, codec = Codec, failure = Failure, recovery = Recovery, stop = Stop, process = Process}
    catch Class:Reason:Stack -> catch transit_station_bridge:close(Bridge), erlang:raise(Class, Reason, Stack) end.
execute({encode_cast, Value, Codec}, {local, Bridge} = State) -> {{ok, transit_station_bridge:frame(Bridge, Value, Codec)}, State};
execute({http_codec, Action}, {local, Bridge} = State) -> {{ok, transit_station_bridge:http_codec(Bridge, Action)}, State};
execute({Codec, Action, Capability}, {local, Bridge} = State) when Codec =:= http_codec; Codec =:= grpc_codec; Codec =:= document_codec ->
    case maps:get(Capability, transit_station_bridge:caps(Bridge), false) of
        true -> {{ok, transit_station_bridge:Codec(Bridge, Action)}, State};
        false -> transit_sdk_value:fail(unsupported_capability, Codec)
    end;
execute({Protocol, _}, #state{pending = Pending}) when Pending =/= undefined, (Protocol =:= http orelse Protocol =:= grpc) -> transit_sdk_value:fail(busy, pending_mutation);
execute({Protocol, Action}, State) when Protocol =:= http; Protocol =:= grpc -> replay(Protocol, Action, State);
execute({document, _}, #state{pending = Pending}) when Pending =/= undefined -> transit_sdk_value:fail(busy, pending_mutation);
execute({document, Action}, #state{bridge = Bridge, process = #transit_process{realm = Realm}} = State) ->
    {{ok, transit_document:read_result(Bridge, Realm, Action)}, State};
execute(evidence, State) -> {{ok, evidence(State)}, State};
execute(next, State) -> next(State, 16);
execute(reconcile, #state{pending = undefined}) -> transit_sdk_value:fail(closed, no_pending_mutation);
execute(reconcile, State) -> attempt(State).
replay(Protocol, {diagnostic, Realm, Resource, Exchange, Kind}, #state{process = #transit_process{realm = Realm}, bridge = Bridge} = State) ->
    Result = replay_read(Protocol, Bridge, #{<<"diagnostic">> => #{<<"identity">> => #{<<"resource">> => Resource,
        <<"exchange">> => integer_to_binary(Exchange)}, <<"kind">> => Kind}}),
    {{ok, maps:get(<<"diagnostic">>, Result)}, State};
replay(_, {diagnostic, _, _, _, _}, _) -> transit_sdk_value:fail(invalid_argument, diagnostic_realm);
replay(Protocol, {open, Realm, Reference, Policy}, #state{process = #transit_process{realm = Realm}, bridge = Bridge, readers = Readers} = State) ->
    Result = replay_read(Protocol, Bridge, #{<<"open">> => #{<<"reference">> => transit_sdk_value:hex(Reference), <<"policy">> => Policy}}),
    Id = transit_sdk_value:counter(maps:get(<<"opened">>, Result)),
    {{ok, {Id, 0}}, State#state{readers = Readers#{Protocol => {Id, 0, false, false}}}};
replay(_, {open, _, _, _}, _) -> transit_sdk_value:fail(invalid_argument, replay_realm);
replay(Protocol, {next, Id, Step}, #state{readers = Readers} = State) ->
    case maps:get(Protocol, Readers, undefined) of
        {Id, Step, Complete, false} ->
            %% Advance even on failure: an abandoned wait cannot reuse an old
            %% immutable token to skip an undisclosed native part.
            Next = transit_sdk_value:counter(Step + 1),
            Result = transit_sdk_value:protect(fun() ->
                Value = replay_read(Protocol, State#state.bridge, #{<<"next">> => Id}),
                case Protocol of http -> transit_http:part(Value, Complete); grpc -> transit_grpc:part(Value, Complete) end
            end),
            case Result of
                {ok, {Part, Done}} -> {{ok, {Part, Next, Done}}, State#state{readers = Readers#{Protocol => {Id, Next, Done, false}}}};
                {error, Error} -> {{error, Error}, State#state{readers = Readers#{Protocol => {Id, Next, Complete, true}}}}
            end;
        {Id, _, _, _} ->
            Code = case Protocol of http -> <<"HttpReplayFailed">>; grpc -> <<"GrpcReplayFailed">> end,
            throw({transit_sdk, #transit_error{kind = read_failed, phase = replay_reader, code = Code}});
        _ -> transit_sdk_value:fail(closed, replay_reader)
    end;
replay(Protocol, {close, Id}, #state{readers = Readers, closed_readers = Closed} = State) ->
    case {maps:get(Protocol, Closed, undefined), maps:get(Protocol, Readers, undefined)} of
        {Id, _} -> {{ok, ok}, State};
        {_, {Id, _, _, _}} ->
            #{<<"closed">> := true} = replay_read(Protocol, State#state.bridge, #{<<"close">> => Id}),
            {{ok, ok}, State#state{readers = maps:remove(Protocol, Readers), closed_readers = Closed#{Protocol => Id}}};
        _ -> transit_sdk_value:fail(closed, replay_reader)
    end.
replay_read(http, Bridge, Action) -> transit_station_bridge:http_read(Bridge, Action);
replay_read(grpc, Bridge, Action) -> transit_station_bridge:grpc_read(Bridge, Action).
evidence({local, _}) -> undefined;
evidence(#state{pending = Pending, last_event = Event}) -> #transit_runner_shutdown{pending = Pending, last_event = Event}.
close({local, Bridge}) -> transit_station_bridge:close(Bridge);
close(#state{bridge = Bridge}) -> transit_station_bridge:close(Bridge).
record(Event, State) -> {{ok, Event}, State#state{last_event = Event}}.
normalize({transit_sdk, #transit_error{} = Error}, _) -> Error;
normalize(_, Phase) -> transit_sdk_value:error(handler, Phase).
pause(Error, Phase, Receipt, State) ->
    Event = #transit_needs_recovery{mutation = State#state.pending, phase = Phase, error = Error, receipt = Receipt},
    record(Event, State#state{paused = Event}).
next(#state{paused = Paused} = State, _) when Paused =/= undefined -> record(Paused, State);
next(State, Budget) ->
    case transit_sdk_worker:stopped(State#state.stop) of
        true -> record(stopped, State);
        false when State#state.pending =/= undefined -> attempt(State);
        false when Budget =:= 0 -> record(progress, State);
        false ->
            Event = transit_station_bridge:prepare(State#state.bridge),
            case maps:get(<<"event">>, Event) of
                <<"pending">> -> attempt(State#state{pending = transit_station_bridge:pending(State#state.bridge, Event)});
                <<"idle">> -> record(idle, State);
                <<"blocked">> -> record(#transit_blocked{}, State);
                <<"ready">> -> next(handle(Event, State), Budget - 1);
                <<"progress">> -> next(State, Budget - 1)
            end
    end.
attempt(#state{confirmed = Confirmed} = State) when Confirmed =/= undefined -> accept(Confirmed, State);
attempt(#state{attempted = true} = State) ->
    case transit_sdk_value:protect(fun() -> transit_station_bridge:confirmation(State#state.bridge, State#state.pending) end) of
        {ok, undefined} -> persist(State);
        {ok, Known} -> accept(Known, State);
        {error, Error} -> pause(Error, observe_confirmation, undefined, State)
    end;
attempt(State) -> persist(State).
persist(State) ->
    case transit_sdk_worker:stopped(State#state.stop) of
        true -> record(stopped, State);
        false ->
            Saved = transit_sdk_value:protect(fun() ->
                case State#state.recovery of fresh_ownership -> ok;
                    {persist_before_dispatch, Store, Options} -> ok = Store:before_dispatch(State#state.pending, Options) end
            end),
            case Saved of
                {error, Error} -> pause(Error, persist, undefined, State);
                {ok, _} ->
                    case transit_sdk_worker:stopped(State#state.stop) of
                        true -> record(stopped, State);
                        false ->
                            Attempted = State#state{attempted = true},
                            case transit_sdk_value:protect(fun() -> transit_station_bridge:dispatch(State#state.bridge) end) of
                                {ok, Event} -> accept(Event, Attempted);
                                {error, Error} -> pause(Error, dispatch, undefined, Attempted)
                            end
                    end
            end
    end.
accept(Event, State) ->
    Known = State#state{confirmed = Event}, Pending = State#state.pending,
    Checked = transit_sdk_value:protect(fun() ->
        Confirmation = maps:get(<<"confirmation">>, Event),
        true = transit_station_bridge:matches(Confirmation, Pending),
        #transit_receipt{position = transit_sdk_value:counter(maps:get(<<"position">>, maps:get(<<"receipt">>, Confirmation)))} end),
    case Checked of
        {error, Error} -> pause(Error, confirm, undefined, Known);
        {ok, Receipt} ->
            Recorded = transit_sdk_value:protect(fun() -> case State#state.recovery of fresh_ownership -> ok;
                {persist_before_dispatch, Store, Options} -> ok = Store:confirmed(Pending#transit_frozen.identity, Receipt, Options) end end),
            case Recorded of
                {error, Error} -> pause(Error, confirm, Receipt, Known);
                {ok, _} ->
                    Result = case {maps:get(<<"event">>, Event), Pending#transit_frozen.purpose} of
                        {<<"blocked">>, _} -> #transit_blocked{input = Pending#transit_frozen.input, receipt = Receipt};
                        {_, commit} -> #transit_committed{input = Pending#transit_frozen.input, receipt = Receipt};
                        _ -> progress
                    end,
                    record(Result, Known#state{pending = undefined, confirmed = undefined, paused = undefined, attempted = false})
            end
    end.
handle(Event, State) ->
    Turn = transit_turn:open_scope(State#state.bridge, Event, State#state.process, State#state.stop),
    Result = try
        %% Decode before initialization can stage any private mutation.
        Input = maps:get(<<"input">>, Event),
        {Callback, Message} = input(State, Input),
        Context = case maps:get(<<"initializing">>, Event) andalso not transit_sdk_worker:stopped(State#state.stop) of
            true -> callback(State#state.handler, initialize, [Turn, State#state.context], State#state.context);
            false -> State#state.context
        end,
        Next = case transit_sdk_worker:stopped(State#state.stop) of
            true -> Context;
            false -> callback(State#state.handler, Callback, [Turn, Message, Context], Context)
        end,
        {ok, Next}
    catch _:Reason -> {error, normalize(Reason, handler)} end,
    Poison = transit_turn:end_scope(Turn), Scope = maps:get(<<"scope">>, Event),
    case {transit_sdk_worker:stopped(State#state.stop), Poison} of
        {true, _} -> transit_station_bridge:discard(State#state.bridge, Scope), State;
        {false, Error} when Error =/= undefined -> catch transit_station_bridge:discard(State#state.bridge, Scope), throw({transit_sdk, Error});
        _ ->
            Failed = case Result of {error, _} -> true; _ -> false end,
            try transit_station_bridge:finish(State#state.bridge, Scope, Failed)
            catch throw:{transit_sdk, #transit_error{code = <<"ForeignHandlerFailure">>}} when State#state.failure =:= stop ->
                case Result of {error, Original} -> throw({transit_sdk, Original}); _ -> transit_sdk_value:fail(handler, finish) end
            end,
            case Result of {ok, NewContext} -> State#state{context = NewContext}; _ -> State end
    end.
callback(Handler, initialize, Args, Context) ->
    case erlang:function_exported(Handler, initialize, 2) of true -> callback_result(erlang:apply(Handler, initialize, Args)); false -> Context end;
callback(Handler, Name, Args, _) -> callback_result(erlang:apply(Handler, Name, Args)).
callback_result({ok, Context}) -> Context;
callback_result(_) -> transit_sdk_value:fail(handler, callback_result).
input(State, Input) ->
    Kind = maps:get(<<"kind">>, Input), Position = maps:get(<<"position">>, Input),
    #transit_process{realm = Realm} = State#state.process, Origin = transit_station_value:origin(maps:get(<<"origin">>, Input), Realm),
    case Kind of
        K when K =:= <<"cast">>; K =:= <<"call">>; K =:= <<"reply">> ->
            Bound = maps:get(<<"message_bytes">>, transit_station_bridge:caps(State#state.bridge)),
            Value = transit_station_value:decode(State#state.codec, transit_sdk_value:unhex(maps:get(<<"payload">>, Input), Bound), Bound),
            Tag = case K of <<"cast">> -> cast; <<"call">> -> call; <<"reply">> -> reply end,
            Correlation = case Tag of cast -> undefined; _ -> transit_sdk_value:wide(maps:get(<<"correlation">>, Input)) end,
            {handle_message, #transit_incoming{kind = Tag, value = Value, position = Position, origin = Origin, correlation = Correlation}};
        <<"result_failed">> ->
            Failed = maps:get(<<"query_failure">>, Input),
            Reason = case maps:get(<<"reason">>, Failed) of
                <<"result_too_large">> -> result_too_large;
                <<"workspace_exceeded">> -> workspace_exceeded;
                <<"overflow">> -> overflow;
                <<"cancelled">> -> cancelled;
                <<"denied">> -> denied
            end,
            {handle_query_failure, #transit_query_failure{position = Position, origin = Origin,
                correlation = transit_sdk_value:wide(maps:get(<<"correlation">>, Input)),
                result = maps:get(<<"result">>, Failed), reason = Reason}};
        <<"result_complete">> -> {handle_result, #transit_result_complete{position = Position, origin = Origin, correlation = transit_sdk_value:wide(maps:get(<<"correlation">>, Input))}};
        K when K =:= <<"cancel">>; K =:= <<"timeout">> ->
            Tag = case K of <<"cancel">> -> cancel; _ -> timeout end,
            {handle_control, #transit_control{kind = Tag, position = Position, origin = Origin, correlation = transit_sdk_value:wide(maps:get(<<"correlation">>, Input))}}
    end.
