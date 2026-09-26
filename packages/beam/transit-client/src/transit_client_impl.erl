%% Internal worker-owned raw implementation; signing and classification stay Zig.
-module(transit_client_impl).
-include("transit_client.hrl").
-export([open/2, execute/2, evidence/1, close/1, recover/3, prepare/4, capabilities/2]).
-record(state, {port, evidence = #transit_shutdown{}}).
open(#transit_config{url = Url, profile = growing_v3, timeout_ms = Timeout, native_host = Override}, _) ->
    %% Revalidate host values even if a caller constructed records directly.
    {ok, _} = transit_client:config(Url, growing_v3, #{timeout_ms => Timeout, native_host => Override}),
    Contract = transit_sdk_value:contract(transit_client),
    Port = transit_sdk_port:open(transit_native_client, Override, #{<<"url">> => Url, <<"timeout_ms">> => Timeout}, Contract),
    try
        #{<<"host_version">> := 1, <<"transit_version">> := 1} = Hello = transit_sdk_port:request(Port, #{<<"hello">> => #{}}, hello, false, undefined),
        true = map_size(Hello) =:= 2,
        Caps = transit_sdk_port:request(Port, #{<<"capabilities">> => #{}}, capabilities, false, <<"ClientCapabilities">>),
        true = maps:get(<<"version">>, Caps) =:= 1,
        true = lists:all(fun(Key) -> maps:get(Key, Caps) =:= true end, [<<"operation_metadata">>, <<"opaque_retry">>, <<"growing_v3">>]),
        #state{port = Port}
    catch _:_ -> catch transit_sdk_port:close(Port), transit_sdk_value:fail(incompatible_native, native_version) end;
open(_, _) -> transit_sdk_value:fail(invalid_argument, client_config).
execute(evidence, State) -> {{ok, evidence(State)}, State};
execute({capabilities, Credential}, #state{port = Port} = State) -> {{ok, capabilities(Port, Credential)}, State};
execute({prepare_send, #transit_process{realm = Realm, pid = Pid}, Value,
         #transit_credential{realm = Realm, principal = Principal} = Credential, Sequence}, #state{port = Port} = State) ->
    Payload = transit_sdk_value:bytes(Value, transit_sdk_port:limit(Port, <<"value_bytes">>)),
    Document = #{<<"realm">> => transit_sdk_value:counter(Realm), <<"principal">> => transit_sdk_value:counter(Principal, 0),
        <<"sequence">> => transit_sdk_value:counter(Sequence), <<"command">> => #{<<"send">> => #{<<"pid">> => transit_sdk_value:counter(Pid), <<"value">> => transit_sdk_value:hex(Payload)}}},
    Frozen = prepare(Port, 6, Credential, Document), {{ok, recover(Port, send, Frozen)}, State};
execute({recover, Kind, Bytes}, #state{port = Port} = State) -> {{ok, recover(Port, Kind, Bytes)}, State};
execute({dispatch, Kind, {transit_pending, Kind, _, Bytes}}, #state{port = Port, evidence = Old} = State) ->
    recover(Port, Kind, Bytes),
    Cleared = case Kind of send -> Old#transit_shutdown{last_admission = undefined}; mutation -> Old#transit_shutdown{last_mutation = undefined} end,
    try transit_sdk_port:request(Port, #{<<"call">> => Bytes}, dispatch, true, undefined) of
        #{<<"position">> := Position} ->
            try transit_sdk_value:counter(Position) of
                Number ->
                    case Kind of
                        send -> Receipt = #transit_admission{position = Number}, {{admitted, Receipt}, State#state{evidence = Cleared#transit_shutdown{last_admission = Receipt}}};
                        mutation -> Receipt = #transit_receipt{position = Number}, {{confirmed, Receipt}, State#state{evidence = Cleared#transit_shutdown{last_mutation = Receipt}}}
                    end
            catch _:_ -> unknown(State#state{evidence = Cleared}, Bytes, transit_sdk_value:error(unknown_outcome, receipt)) end;
        _ -> unknown(State#state{evidence = Cleared}, Bytes, transit_sdk_value:error(unknown_outcome, receipt))
    catch throw:{transit_sdk, Error} ->
        case Error#transit_error.kind of
            authority_rejected -> {{rejected, Error}, State#state{evidence = Cleared}};
            access_denied -> {{rejected, Error}, State#state{evidence = Cleared}};
            _ -> unknown(State#state{evidence = Cleared}, Bytes, Error#transit_error{kind = unknown_outcome})
        end
    end;
execute(_, _) -> transit_sdk_value:fail(invalid_argument, raw_operation).
unknown(State, Bytes, Error) -> {{uncertain, Bytes, Error}, State}.
evidence(#state{evidence = Evidence}) -> Evidence.
close(#state{port = Port}) -> transit_sdk_port:close(Port).
prepare(Port, Kind, #transit_credential{realm = Realm, principal = Principal, seed_file = Seed}, Document) ->
    transit_sdk_value:counter(Realm), transit_sdk_value:counter(Principal, 0), transit_sdk_value:text(Seed, 4096),
    transit_sdk_value:bytes(transit_sdk_port:request(Port, #{<<"prepare">> => #{<<"kind">> => Kind, <<"seed_file">> => Seed,
        <<"document">> => transit_sdk_value:encode(Document)}}, prepare, false, undefined), transit_sdk_port:limit(Port, <<"max_body">>)).
recover(Port, Kind, Bytes) when Kind =:= send; Kind =:= mutation ->
    Frozen = transit_sdk_value:text(Bytes, transit_sdk_port:limit(Port, <<"max_body">>)),
    Meta = transit_sdk_port:request(Port, #{<<"metadata">> => Frozen}, metadata, false, <<"OperationMetadata">>),
    case maps:get(<<"version">>, Meta) =:= 1 andalso maps:get(<<"profile">>, Meta) =:= <<"growing_v3">>
        andalso maps:get(<<"kind">>, Meta) =:= <<"growing_command">> andalso is_binary(maps:get(<<"command">>, Meta))
        andalso (Kind =/= send orelse maps:get(<<"command">>, Meta) =:= <<"send">>) of
        true -> ok;
        false -> transit_sdk_value:fail(unsupported_capability, recovery_kind)
    end,
    Realm = transit_sdk_value:counter(maps:get(<<"realm">>, Meta)), Principal = transit_sdk_value:counter(maps:get(<<"principal">>, Meta), 0),
    Identity = #transit_identity{sha256 = maps:get(<<"identity">>, Meta)},
    Sequence = transit_sdk_value:counter(transit_sdk_value:wide(maps:get(<<"sequence">>, Meta))),
    Info = case Kind of
        send -> #{identity => Identity, peer => #transit_process{realm = Realm, pid = transit_sdk_value:counter(maps:get(<<"destination">>, Meta))}, principal => Principal, sequence => Sequence};
        mutation -> #{identity => Identity, realm => Realm, principal => Principal, sequence => Sequence, command => maps:get(<<"command">>, Meta)}
    end,
    {transit_pending, Kind, Info, Frozen}.
capabilities(Port, #transit_credential{realm = Realm, principal = Principal} = Credential) ->
    Frozen = prepare(Port, 7, Credential, #{<<"realm">> => Realm, <<"principal">> => Principal, <<"kind">> => #{<<"capabilities">> => #{}}}),
    Value = transit_sdk_port:request(Port, #{<<"call">> => Frozen}, authority_capabilities, false, undefined),
    #{<<"version">> := 3, <<"body">> := #{<<"capabilities">> := Caps}} = Value,
    #{<<"version">> := 3, <<"profile">> := <<"growing_v1">>} = Caps,
    #{realm => transit_sdk_value:counter(maps:get(<<"realm">>, Value)), observed_at => transit_sdk_value:counter(maps:get(<<"position">>, Value), 0),
        principal_sequence => transit_sdk_value:counter(maps:get(<<"principal_sequence">>, Value), 0),
        page_size => transit_sdk_value:counter(maps:get(<<"page_entries">>, Caps)), mutations_per_turn => transit_sdk_value:counter(maps:get(<<"mutation_budget">>, Caps)),
        outputs_per_turn => transit_sdk_value:counter(maps:get(<<"output_budget">>, Caps)),
        retained_versions => transit_sdk_value:boolean(maps:get(<<"retained_read_versions">>, Caps)),
        association_lookup => transit_sdk_value:boolean(maps:get(<<"association_lookup">>, Caps)),
        scoped_retry => transit_sdk_value:boolean(maps:get(<<"scoped_retry">>, Caps)), station => transit_sdk_value:boolean(maps:get(<<"station">>, Caps))}.
