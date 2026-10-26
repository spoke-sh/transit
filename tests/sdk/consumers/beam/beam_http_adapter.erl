-module(beam_http_adapter).
-include_lib("transit_station_sdk/include/transit_station_sdk.hrl").
-behaviour(transit_station_codec).
-behaviour(transit_station_handler).
-export([diagnostics/2, diagnostic_denied/2, replay_error/0, prepare/1, open/3, next/1, close/1, stop/1, stage/2, open_capture/2, read/1, close_capture/1,
         complete/1, decode/1, outcome/1, view/1, event/1, golden/1, release_expired/1, followup_expired/2,
         type_id/0, version/0, max_encoded_bytes/0, encode/1, handle_message/3]).
%% The application codec owns ordinary bytes. Decode HTTP only on an authenticated reply.
type_id() -> <<"test.http-control">>.
version() -> 1.
max_encoded_bytes() -> 243.
encode(Bytes) -> {ok, Bytes}.
decode(Bytes) -> {ok, Bytes}.
request() -> #transit_http_request{method = post, target = [{literal, <<"/items/">>}, {variable, <<"id">>, <<"λ /"/utf8>>}],
    headers = [{<<"X-Tag">>, [{literal, <<"one">>}]}, {<<"X-Tag">>, [{literal, <<"two">>}]},
        {<<"Authorization">>, [{literal, <<"Bearer ">>}, {secret, <<"api">>, 7}]}]}.
prepare(Cfg) -> transit_http:prepare(#transit_resource{realm = 72, resource = maps:get(<<"resource">>, Cfg)}, 18446744073709551615,
    request(), binary:decode_hex(maps:get(<<"body">>, Cfg)), #{endpoint_revision => 7, reconcile_before_ms => maps:get(<<"deadline">>, Cfg)}).
open(Cfg, S, Request) ->
    {ok, Client} = transit_client:config(maps:get(<<"url">>, Cfg), native_v1),
    Service = #transit_service{client = Client, activation = #transit_activation{process = #transit_process{realm = 72, pid = maps:get(<<"pid">>, Cfg)},
        generation = maps:get(<<"generation">>, Cfg), credential = #transit_credential{realm = 72, principal = maps:get(<<"principal">>, Cfg), seed_file = maps:get(<<"seed_file">>, Cfg)}}},
    Disposal = case maps:find(<<"outcome">>, Cfg) of
        {ok, Bytes} -> {ok, Value} = transit_http:decode_reply(72, binary:decode_hex(Bytes)), Value;
        error -> undefined end,
    Reason = case maps:get(<<"followup_reason">>, Cfg, <<"retry">>) of <<"retry">> -> retry; <<"redirect">> -> redirect; <<"reconcile">> -> reconcile; <<"cancel">> -> cancel end,
    transit_station_sdk:open(Service, ?MODULE, {S, #transit_process{realm = 72, pid = maps:get(<<"peer">>, Cfg)}, Request, Disposal, Reason}, ?MODULE, stop, fresh_ownership).
handle_message(Turn, Input, {S, Peer, Request, Disposal, Reason} = Context) ->
    beam_exchange_controller:put(S, escaped, Turn), {ok, State} = transit_turn:state(Turn), {ok, Key} = transit_turn:key(<<"http-correlation">>, transit_example_u64_codec),
    {ok, ReleaseKey} = transit_turn:key(<<"http-release-correlation">>, transit_example_u64_codec),
    {ok, FollowupKey} = transit_turn:key(<<"http-followup-correlation">>, transit_example_u64_codec),
    Result = case Input#transit_incoming.kind of
        cast when Input#transit_incoming.value =:= <<"followup">> ->
            Capture = Disposal#transit_http_outcome.resource,
            Wrong = Disposal#transit_http_outcome{resource = Capture#transit_resource{realm = 73}},
            {error, #transit_error{kind = invalid_argument}} = transit_http:followup(Turn, Peer, Wrong, Reason, Request),
            {error, #transit_error{kind = invalid_argument}} = transit_http:followup(Turn, Peer, Disposal, automatic, Request),
            {ok, Correlation} = transit_http:followup(Turn, Peer, Disposal, Reason, Request),
            {ok, ok} = transit_turn:put(State, FollowupKey, Correlation), #{followup => false};
        cast when Input#transit_incoming.value =:= <<"dispose">> ->
            #transit_http_outcome{resource = Capture, exchange = Exchange} = Disposal,
            {error, #transit_error{kind = invalid_argument}} = transit_http:release(Turn, Peer, Capture#transit_resource{realm = 73}, Exchange),
            {ok, Correlation} = transit_http:release(Turn, Peer, Capture, Exchange),
            {ok, ok} = transit_turn:put(State, ReleaseKey, Correlation), #{released => false};
        cast ->
            Called = case transit_turn:find(State, Key) of
                {ok, {found, _}} -> true;
                {ok, missing} ->
                    {ok, Ready} = transit_http:stage(Turn, Request),
                    case Ready of true -> {ok, Correlation} = transit_http:call(Turn, Peer, Request), {ok, ok} = transit_turn:put(State, Key, Correlation); false -> ok end,
                    Ready
            end,
            #{called => Called};
        reply ->
            case Input#transit_incoming.value of
                <<"HTF1", _/binary>> ->
                    {ok, Correlation} = transit_turn:require(State, FollowupKey), {ok, ok} = transit_turn:require_reply(Turn, Input, Peer, Correlation),
                    {ok, #transit_http_rejected{reason = denied, diagnostic = Detail}} = transit_http:decode_reply(72, Input#transit_incoming.value),
                    Facts = maps:from_list([{maps:get(<<"field">>, F), F} || F <- maps:get(<<"facts">>, Detail), is_map(F)]),
                    <<"provided">> = maps:get(<<"availability">>, maps:get(<<"field_path">>, Facts)),
                    #{<<"unsigned">> := NativeInput} = maps:get(<<"value">>, maps:get(<<"native_input">>, Facts)),
                    true = binary_to_integer(NativeInput) > 0,
                    #{<<"digest">> := Digest} = maps:get(<<"value">>, maps:get(<<"proposal">>, Facts)),
                    32 = length(Digest),
                    {ok, Denied} = transit_turn:key(<<"http-followup-denied">>, transit_example_u64_codec),
                    {ok, ok} = transit_turn:put(State, Denied, Correlation), #{followup => true};
                <<"HTK1", _/binary>> ->
                    {ok, Correlation} = transit_turn:require(State, ReleaseKey), {ok, ok} = transit_turn:require_reply(Turn, Input, Peer, Correlation),
                    #transit_http_outcome{resource = Capture, exchange = Exchange} = Disposal,
                    {ok, #transit_http_released{resource = Capture, exchange = Exchange}} = transit_http:decode_reply(72, Input#transit_incoming.value),
                    {ok, Disposed} = transit_turn:key(<<"http-disposed">>, transit_example_u64_codec),
                    {ok, ok} = transit_turn:put(State, Disposed, Exchange), #{released => true};
                _ ->
                    {ok, Correlation} = transit_turn:require(State, Key), {ok, ok} = transit_turn:require_reply(Turn, Input, Peer, Correlation),
                    {ok, #transit_http_outcome{phase = observed, status = 200}} = transit_http:decode_reply(72, Input#transit_incoming.value),
                    {ok, Status} = transit_turn:key(<<"http-status">>, transit_example_u64_codec), {ok, ok} = transit_turn:put(State, Status, 200), #{observed => true}
            end
    end,
    beam_exchange_controller:put(S, result, Result), {ok, Context}.
next(R) -> transit_station_sdk:next(R).
close(R) -> transit_station_sdk:close(R).
stop(R) -> transit_station_sdk:stop(R).
stage(T, Request) -> transit_http:stage(T, Request).
release_expired(T) -> transit_http:release(T, #transit_process{realm = 72, pid = 1}, #transit_resource{realm = 72, resource = 1}, 1).
followup_expired(T, Request) -> transit_http:followup(T, #transit_process{realm = 72, pid = 1}, #transit_http_outcome{resource = #transit_resource{realm = 72, resource = 1}, exchange = 1}, retry, Request).
outcome(Bytes) -> transit_http:decode_reply(72, Bytes).
open_capture(R, Outcome) -> transit_http:open(R, Outcome).
read(Reader) -> case transit_http:read(Reader) of
    {ok, {#transit_http_part{kind = K, bytes = B, complete = C}, Next}} -> {ok, {#{kind => K, bytes => B, complete => C}, Next}};
    Other -> Other end.
close_capture(R) -> transit_http:close(R).
complete(R) -> transit_http:complete(R).
view(#transit_error{kind = Kind, code = Code, phase = Phase}) -> #{kind => Kind, code => Code, phase => Phase}.
event(#transit_committed{}) -> committed;
event(Value) -> Value.
golden(Fixture) ->
    {ok, Prepared} = transit_http:prepare(#transit_resource{realm = 72, resource = 8}, 18446744073709551615,
        #transit_http_request{method = post, target = [{literal, <<"/write">>}]}, binary:decode_hex(maps:get(<<"body">>, Fixture)),
        #{endpoint_revision => 7, reconcile_before_ms => 9000, max_attempts => 2}),
    true = Prepared#transit_http_prepared.reference =:= binary:decode_hex(maps:get(<<"reference">>, Fixture)),
    true = Prepared#transit_http_prepared.metadata =:= maps:get(<<"metadata">>, Fixture),
    Bytes = binary:decode_hex(maps:get(<<"outcome">>, Fixture)),
    {ok, #transit_http_outcome{phase = observed, status = 200, exchange = 18446744073709551615, reference = Ref, diagnostic = #{<<"code">> := <<"http.response_observed">>, <<"outcome">> := <<"completed">>}}} = transit_http:decode_reply(72, Bytes), true = is_binary(Ref),
    {ok, #transit_http_rejected{reason = denied, diagnostic = #{<<"code">> := <<"http.request_denied">>}}} = transit_http:decode_reply(72, binary:decode_hex(maps:get(<<"rejection">>, Fixture))),
    {error, _} = transit_http:decode_reply(72, binary:part(Bytes, 0, 70)),
    Released = binary:decode_hex(maps:get(<<"released">>, Fixture)),
    {ok, #transit_http_released{resource = #transit_resource{realm = 72, resource = 7}, exchange = 18446744073709551615}} = transit_http:decode_reply(72, Released),
    {error, _} = transit_http:decode_reply(72, binary:part(Released, 0, 19)),
    {error, _} = transit_http:prepare(#transit_resource{realm = 72, resource = 8}, 1,
        #transit_http_request{method = get, target = [{literal, <<"//other/">>}]}, <<>>, #{endpoint_revision => 1, reconcile_before_ms => 9000}), ok.

replay_error() -> <<"HttpReplayFailed">>.

diagnostics(R, Outcome = #transit_http_outcome{effect = Effect}) ->
    {ok, null} = transit_http:diagnostic(R, Outcome),
    {ok, #{<<"code">> := <<"effect.result_recorded">>, <<"outcome">> := <<"completed">>, <<"identity">> := #{<<"id">> := Id}}} = transit_http:diagnostic(R, Outcome, native_effect),
    Effect = binary_to_integer(Id), ok.
diagnostic_denied(R, Outcome) ->
    {error, #transit_error{kind = access_denied}} = transit_http:diagnostic(R, Outcome),
    {error, #transit_error{kind = access_denied}} = transit_http:diagnostic(R, Outcome, native_effect), ok.
