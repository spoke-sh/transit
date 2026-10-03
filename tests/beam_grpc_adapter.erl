-module(beam_grpc_adapter).
-include_lib("transit_station_sdk/include/transit_station_sdk.hrl").
-behaviour(transit_station_codec).
-behaviour(transit_station_handler).
-export([replay_error/0, prepare/1, open/3, next/1, close/1, stop/1, stage/2, open_capture/2, read/1, close_capture/1,
         complete/1, decode/1, outcome/1, view/1, event/1, golden/1, release_expired/1, followup_expired/2,
         type_id/0, version/0, max_encoded_bytes/0, encode/1, handle_message/3]).
%% The application codec owns ordinary bytes. Decode RPC only on an authenticated reply.
type_id() -> <<"test.grpc-control">>.
version() -> 1.
max_encoded_bytes() -> 243.
encode(Bytes) -> {ok, Bytes}.
decode(Bytes) -> {ok, Bytes}.
prepare(Cfg) ->
    {ok, Method} = transit_grpc:method(binary:decode_hex(maps:get(<<"descriptor">>,Cfg)),<<"/test.Peer/Bidi">>),
    #transit_grpc_method{shape=bidi} = Method,
    transit_grpc:prepare(#transit_resource{realm=72,resource=maps:get(<<"resource">>,Cfg)},18446744073709551615,
        #transit_grpc_request{method=Method,metadata=[{<<"x-tag">>,{literal,<<"one">>}},{<<"x-tag">>,{literal,<<"two">>}},
            {<<"x-data-bin">>,{literal,<<0,255>>}},{<<"authorization">>,{secret,<<"api">>,7}}]},
        [binary:decode_hex(maps:get(<<"body">>,Cfg)),<<>>],#{endpoint_revision=>7,reconcile_before_ms=>maps:get(<<"deadline">>,Cfg)}).
open(Cfg, S, Request) ->
    {ok, Client} = transit_client:config(maps:get(<<"url">>, Cfg), native_v1),
    Service = #transit_service{client = Client, activation = #transit_activation{process = #transit_process{realm = 72, pid = maps:get(<<"pid">>, Cfg)},
        generation = maps:get(<<"generation">>, Cfg), credential = #transit_credential{realm = 72, principal = maps:get(<<"principal">>, Cfg), seed_file = maps:get(<<"seed_file">>, Cfg)}}},
    Disposal = case maps:find(<<"outcome">>, Cfg) of
        {ok, Bytes} -> {ok, Value} = transit_grpc:decode_reply(72, binary:decode_hex(Bytes)), Value;
        error -> undefined end,
    transit_station_sdk:open(Service, ?MODULE, {S, #transit_process{realm = 72, pid = maps:get(<<"peer">>, Cfg)}, Request, Disposal}, ?MODULE, stop, fresh_ownership).
handle_message(Turn, Input, {S, Peer, Request, Disposal} = Context) ->
    beam_exchange_controller:put(S, escaped, Turn), {ok, State} = transit_turn:state(Turn), {ok, Key} = transit_turn:key(<<"grpc-correlation">>, transit_example_u64_codec),
    {ok, ReleaseKey} = transit_turn:key(<<"grpc-release-correlation">>, transit_example_u64_codec),
    {ok, FollowupKey} = transit_turn:key(<<"grpc-followup-correlation">>, transit_example_u64_codec),
    Result = case Input#transit_incoming.kind of
        cast when Input#transit_incoming.value =:= <<"followup">> ->
            Capture = Disposal#transit_grpc_outcome.resource,
            Wrong = Disposal#transit_grpc_outcome{resource = Capture#transit_resource{realm = 73}},
            {error, #transit_error{kind = invalid_argument}} = transit_grpc:retry(Turn, Peer, Wrong, Request),
            {ok, Correlation} = transit_grpc:retry(Turn, Peer, Disposal, Request),
            {ok, ok} = transit_turn:put(State, FollowupKey, Correlation), #{followup => false};
        cast when Input#transit_incoming.value =:= <<"dispose">> ->
            #transit_grpc_outcome{resource = Capture, exchange = Exchange} = Disposal,
            {error, #transit_error{kind = invalid_argument}} = transit_grpc:release(Turn, Peer, Capture#transit_resource{realm = 73}, Exchange),
            {ok, Correlation} = transit_grpc:release(Turn, Peer, Capture, Exchange),
            {ok, ok} = transit_turn:put(State, ReleaseKey, Correlation), #{released => false};
        cast ->
            Called = case transit_turn:find(State, Key) of
                {ok, {found, _}} -> true;
                {ok, missing} ->
                    {ok, Ready} = transit_grpc:stage(Turn, Request),
                    case Ready of true -> {ok, Correlation} = transit_grpc:call(Turn, Peer, Request), {ok, ok} = transit_turn:put(State, Key, Correlation); false -> ok end,
                    Ready
            end,
            #{called => Called};
        reply ->
            case Input#transit_incoming.value of
                <<"GRF1", _/binary>> ->
                    {ok, Correlation} = transit_turn:require(State, FollowupKey), {ok, ok} = transit_turn:require_reply(Turn, Input, Peer, Correlation),
                    {ok, #transit_grpc_rejected{reason = denied}} = transit_grpc:decode_reply(72, Input#transit_incoming.value),
                    {ok, Denied} = transit_turn:key(<<"grpc-followup-denied">>, transit_example_u64_codec),
                    {ok, ok} = transit_turn:put(State, Denied, Correlation), #{followup => true};
                <<"GRK1", _/binary>> ->
                    {ok, Correlation} = transit_turn:require(State, ReleaseKey), {ok, ok} = transit_turn:require_reply(Turn, Input, Peer, Correlation),
                    #transit_grpc_outcome{resource = Capture, exchange = Exchange} = Disposal,
                    {ok, #transit_grpc_released{resource = Capture, exchange = Exchange}} = transit_grpc:decode_reply(72, Input#transit_incoming.value),
                    {ok, Disposed} = transit_turn:key(<<"grpc-disposed">>, transit_example_u64_codec),
                    {ok, ok} = transit_turn:put(State, Disposed, Exchange), #{released => true};
                _ ->
                    {ok, Correlation} = transit_turn:require(State, Key), {ok, ok} = transit_turn:require_reply(Turn, Input, Peer, Correlation),
                    {ok, #transit_grpc_outcome{phase = observed, status = 0}} = transit_grpc:decode_reply(72, Input#transit_incoming.value),
                    {ok, Status} = transit_turn:key(<<"grpc-status">>, transit_example_u64_codec), {ok, ok} = transit_turn:put(State, Status, 0), #{observed => true}
            end
    end,
    beam_exchange_controller:put(S, result, Result), {ok, Context}.
next(R) -> transit_station_sdk:next(R).
close(R) -> transit_station_sdk:close(R).
stop(R) -> transit_station_sdk:stop(R).
stage(T, Request) -> transit_grpc:stage(T, Request).
release_expired(T) -> transit_grpc:release(T, #transit_process{realm = 72, pid = 1}, #transit_resource{realm = 72, resource = 1}, 1).
followup_expired(T, Request) -> transit_grpc:retry(T, #transit_process{realm = 72, pid = 1}, #transit_grpc_outcome{resource = #transit_resource{realm = 72, resource = 1}, exchange = 1}, Request).
outcome(Bytes) -> transit_grpc:decode_reply(72, Bytes).
open_capture(R, Outcome) -> transit_grpc:open(R, Outcome).
read(Reader) -> case transit_grpc:read(Reader) of
    {ok, {#transit_grpc_part{kind = K, bytes = B, complete = C}, Next}} -> {ok, {#{kind => K, bytes => B, complete => C}, Next}};
    Other -> Other end.
close_capture(R) -> transit_grpc:close(R).
complete(R) -> transit_grpc:complete(R).
view(#transit_error{kind = Kind, code = Code, phase = Phase}) -> #{kind => Kind, code => Code, phase => Phase}.
event(#transit_committed{}) -> committed;
event(Value) -> Value.
golden(Fixture) ->
    Bytes = binary:decode_hex(maps:get(<<"outcome_ok_hex">>,Fixture)),
    {ok,#transit_grpc_outcome{phase=observed,status=0,exchange=18446744073709551615,reference=Ref,diagnostic=#{<<"code">> := <<"grpc.ok_observed">>, <<"outcome">> := <<"completed">>}}} = transit_grpc:decode_reply(72,Bytes),
    true = is_binary(Ref),
    {ok,#transit_grpc_outcome{phase=closed_unknown,status=undefined,reference=undefined,diagnostic=#{<<"outcome">> := <<"closed_unknown">>}}} = transit_grpc:decode_reply(72,binary:decode_hex(maps:get(<<"outcome_unknown_hex">>,Fixture))),
    {ok,#transit_grpc_rejected{reason=denied,diagnostic=#{<<"code">> := <<"grpc.request_denied">>}}} = transit_grpc:decode_reply(72,binary:decode_hex(maps:get(<<"rejection_hex">>,Fixture))),
    {ok,#transit_grpc_released{resource=#transit_resource{realm=72,resource=7},exchange=18446744073709551615}} = transit_grpc:decode_reply(72,binary:decode_hex(maps:get(<<"released_hex">>,Fixture))),
    {error,_} = transit_grpc:decode_reply(72,binary:part(Bytes,0,72)),ok.
replay_error() -> <<"GrpcReplayFailed">>.
