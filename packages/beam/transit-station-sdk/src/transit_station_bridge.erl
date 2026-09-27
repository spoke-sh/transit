%% Internal host boundary; the shared Zig implementation owns durable transitions.
-module(transit_station_bridge).
-include("transit_station_sdk.hrl").
-export([open/2, local/1, close/1, caps/1, prepare/1, apply/3, finish/3, discard/2,
         pending/2, dispatch/1, confirmation/2, matches/2, frame/3, http_codec/2, http_read/2, grpc_codec/2, grpc_read/2]).
-record(bridge, {port, caps}).
open(#transit_service{client = #transit_config{url = Url, profile = growing_v3, timeout_ms = Timeout, native_host = Override},
    activation = #transit_activation{process = #transit_process{realm = Realm, pid = Pid}, generation = Generation,
    credential = #transit_credential{realm = Realm, principal = Principal, seed_file = Seed} = Credential}, association = Association, query_results = Queries}, Failure) ->
    transit_sdk_value:counter(Realm), transit_sdk_value:counter(Pid), transit_sdk_value:counter(Principal, 0), transit_sdk_value:counter(Generation),
    {ok, _} = transit_client:config(Url, growing_v3, #{timeout_ms => Timeout, native_host => Override}),
    Config = #{<<"url">> => Url, <<"timeout_ms">> => Timeout, <<"seed_file">> => transit_sdk_value:text(Seed, 4096),
        <<"growing_server">> => #{<<"profile">> => <<"growing_v3">>, <<"realm">> => Realm, <<"principal">> => Principal,
        <<"pid">> => Pid, <<"generation">> => Generation, <<"association">> => transit_sdk_value:text(Association, 256),
        <<"timeout_ms">> => Timeout, <<"failure_policy">> => transit_station_value:enum(Failure, [stop, block_input]), <<"query_results">> => transit_sdk_value:boolean(Queries)}},
    Bridge = create(Config, Override),
    try
        Authority = transit_client_impl:capabilities(Bridge#bridge.port, Credential),
        Required = [association_lookup, retained_versions, scoped_retry],
        case lists:all(fun(Key) -> maps:get(Key, Authority) end, Required) andalso (not Queries orelse maps:get(<<"query_results">>, Bridge#bridge.caps)) of
            true -> Bridge;
            false -> transit_sdk_value:fail(unsupported_capability, authority_capabilities)
        end
    catch Class:Reason:Stack -> catch close(Bridge), erlang:raise(Class, Reason, Stack) end;
open(_, _) -> transit_sdk_value:fail(invalid_argument, service_config).
local(Override) -> create(#{<<"local_codec">> => true}, Override).
create(Config, Override) ->
    case application:load(transit_client) of ok -> ok; {error, {already_loaded, transit_client}} -> ok; _ -> transit_sdk_value:fail(incompatible_native, client_package) end,
    case application:get_key(transit_client, vsn) of {ok, "0.2.0"} -> ok; _ -> transit_sdk_value:fail(incompatible_native, client_package_version) end,
    RawContract = transit_sdk_value:contract(transit_client), StationContract = transit_sdk_value:contract(transit_station_sdk),
    Contract = StationContract#{<<"limits">> => maps:get(<<"limits">>, RawContract),
        <<"schemas">> := maps:merge(maps:get(<<"schemas">>, RawContract), maps:get(<<"schemas">>, StationContract))},
    Port = transit_sdk_port:open(transit_native_station, Override, Config, Contract),
    try
        #{<<"host_version">> := 1, <<"station_version">> := 1, <<"transit_version">> := 1} = Hello = transit_sdk_port:request(Port, #{<<"hello">> => #{}}, hello, false, undefined),
        true = map_size(Hello) =:= 3,
        Caps = transit_sdk_port:request(Port, #{<<"growing_capabilities">> => #{}}, capabilities, false, <<"GrowingCapabilities">>),
        #{<<"version">> := 1, <<"profile">> := <<"growing_v3">>} = Caps,
        Required = [<<"gated_dispatch">>, <<"retained_confirmation">>, <<"scoped_turns">>, <<"paged_state">>, <<"tables">>, <<"retained_sources">>],
        case lists:all(fun(Key) -> maps:get(Key, Caps) end, Required) of true -> ok; false -> transit_sdk_value:fail(unsupported_capability, native_capabilities) end,
        #bridge{port = Port, caps = Caps}
    catch
        throw:{transit_sdk, Error} -> catch transit_sdk_port:close(Port), throw({transit_sdk, Error});
        _:_ -> catch transit_sdk_port:close(Port), transit_sdk_value:fail(incompatible_native, native_version)
    end.
caps(#bridge{caps = Caps}) -> Caps.
http_codec(#bridge{port = Port, caps = Caps}, Action) ->
    case maps:get(<<"http_requests">>, Caps) of true -> ok; false -> transit_sdk_value:fail(unsupported_capability, http_requests) end,
    transit_sdk_port:request(Port, #{<<"http_codec">> => Action}, http_codec, false, <<"HttpCodecResult">>).
http_read(#bridge{port = Port, caps = Caps}, Action) ->
    case maps:get(<<"http_replay">>, Caps) of true -> ok; false -> transit_sdk_value:fail(unsupported_capability, http_replay) end,
    transit_sdk_port:request(Port, #{<<"growing_http_read">> => Action}, http_replay, false, <<"HttpReadResult">>).
grpc_codec(#bridge{port = Port, caps = Caps}, Action) ->
    case maps:get(<<"grpc_requests">>, Caps) of true -> ok; false -> transit_sdk_value:fail(unsupported_capability, grpc_requests) end,
    transit_sdk_port:request(Port, #{<<"grpc_codec">> => Action}, grpc_codec, false, <<"GrpcCodecResult">>).
grpc_read(#bridge{port = Port, caps = Caps}, Action) ->
    case maps:get(<<"grpc_replay">>, Caps) of true -> ok; false -> transit_sdk_value:fail(unsupported_capability, grpc_replay) end,
    transit_sdk_port:request(Port, #{<<"growing_grpc_read">> => Action}, grpc_replay, false, <<"GrpcReadResult">>).
close(#bridge{port = Port}) -> transit_sdk_port:close(Port).
prepare(#bridge{port = Port}) -> transit_sdk_port:request(Port, #{<<"growing_prepare">> => erlang:system_time(millisecond) + 30000}, prepare_turn, false, <<"GrowingEvent">>).
apply(#bridge{port = Port}, Scope, Action) -> transit_sdk_port:request(Port, #{<<"growing_apply">> => #{<<"scope">> => Scope, <<"action">> => Action}}, apply, false, <<"GrowingResult">>).
finish(#bridge{port = Port}, Scope, Failed) -> transit_sdk_port:request(Port, #{<<"growing_finish_result">> => #{<<"scope">> => Scope, <<"failed">> => Failed}}, finish, false, undefined).
discard(#bridge{port = Port}, Scope) -> transit_sdk_port:request(Port, #{<<"growing_discard">> => Scope}, discard, false, undefined).
dispatch(#bridge{port = Port}) -> transit_sdk_port:request(Port, #{<<"growing_dispatch">> => #{}}, dispatch, true, <<"GrowingEvent">>).
pending(#bridge{port = Port}, Event) ->
    Purpose = case maps:get(<<"pending_kind">>, Event) of <<"permit">> -> permit; <<"open">> -> open; <<"commit">> -> commit end,
    Bytes = transit_sdk_port:request(Port, #{<<"growing_pending">> => #{}}, pending, false, undefined),
    Operation = transit_client_impl:recover(Port, mutation, Bytes), Info = transit_client:info(Operation),
    Allowed = case Purpose of permit -> [<<"begin_turn">>]; open -> [<<"open_view">>]; commit -> [<<"turn">>, <<"turn_with_versions">>] end,
    case lists:member(maps:get(command, Info), Allowed) of true -> ok; false -> transit_sdk_value:fail(incompatible_native, pending_command) end,
    #transit_frozen{identity = maps:get(identity, Info), purpose = Purpose, input = maps:get(<<"pending_input">>, Event), bytes = transit_client:export(Operation)}.
matches(#{<<"kind">> := Kind, <<"input">> := Input}, #transit_frozen{purpose = Purpose, input = Input}) -> Kind =:= atom_to_binary(Purpose, utf8);
matches(_, _) -> false.
confirmation(#bridge{port = Port}, Pending) ->
    try transit_sdk_port:request(Port, #{<<"growing_confirmation">> => #{}}, observe_confirmation, false, <<"GrowingEvent">>) of
        #{<<"confirmation">> := Value} = Event -> case matches(Value, Pending) of true -> Event; false -> undefined end
    catch throw:{transit_sdk, #transit_error{kind = turn_expired}} -> undefined end.
frame(#bridge{port = Port, caps = Caps}, Value, Codec) ->
    Bound = maps:get(<<"message_bytes">>, Caps), Payload = transit_station_value:encode(Codec, Value, Bound),
    Result = transit_sdk_port:request(Port, #{<<"frame">> => #{<<"kind">> => 1, <<"correlation">> => <<"0">>, <<"payload">> => transit_sdk_value:hex(Payload)}}, frame, false, undefined),
    transit_sdk_value:unhex(Result, Bound + 13).
