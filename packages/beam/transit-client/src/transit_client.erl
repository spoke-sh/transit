%% Public raw Transit API. Local bridge PIDs are not durable process references.
-module(transit_client).
-include("transit_client.hrl").
-export([config/2, config/3, process/2, resource/2, credential/3, open/1, start_link/1,
         child_spec/1, handle/1, close/1, capabilities/2, prepare_send/5,
         recover_send/2, recover_mutation/2, dispatch/2, dispatch_mutation/2,
         export/1, info/1, evidence/1]).
-export_type([client/0, pending/0, error/0]).
-opaque client() :: transit_sdk_worker:handle().
-opaque pending() :: {transit_pending, send | mutation, map(), binary()}.
-type error() :: #transit_error{}.
-spec config(binary(), native_v1) -> {ok, #transit_config{}} | {error, error()}.
-spec config(binary(), native_v1, map()) -> {ok, #transit_config{}} | {error, error()}.
-spec process(transit_counter(), transit_counter()) -> {ok, #transit_process{}} | {error, error()}.
-spec resource(transit_counter(), transit_counter()) -> {ok, #transit_resource{}} | {error, error()}.
-spec credential(transit_counter(), 0..9007199254740991, binary()) -> {ok, #transit_credential{}} | {error, error()}.
-spec open(#transit_config{}) -> {ok, client()} | {error, error()}.
-spec start_link(#transit_config{}) -> {ok, pid()} | {error, term()}.
-spec child_spec(#transit_config{}) -> supervisor:child_spec().
-spec handle(pid()) -> {ok, client()} | {error, error()}.
-spec close(client()) -> {ok, #transit_shutdown{}} | {error, error()} | {error, error(), #transit_shutdown{} | undefined}.
-spec capabilities(client(), #transit_credential{}) -> {ok, map()} | {error, error()}.
-spec prepare_send(client(), #transit_process{}, binary(), #transit_credential{}, transit_counter()) -> {ok, pending()} | {error, error()}.
-spec recover_send(client(), binary()) -> {ok, pending()} | {error, error()}.
-spec recover_mutation(client(), binary()) -> {ok, pending()} | {error, error()}.
-spec dispatch(client(), pending()) -> {admitted, #transit_admission{}} | {rejected, error()} | {uncertain, binary(), error()} | {error, error()}.
-spec dispatch_mutation(client(), pending()) -> {confirmed, #transit_receipt{}} | {rejected, error()} | {uncertain, binary(), error()} | {error, error()}.
-spec export(pending()) -> binary().
-spec info(pending()) -> map().
-spec evidence(client()) -> {ok, #transit_shutdown{}} | {error, error()}.
config(Url, Profile) -> config(Url, Profile, #{}).
config(Url, Profile, Options) -> validate(fun() ->
    true = is_map(Options), true = Profile =:= native_v1,
    Text = transit_sdk_value:text(Url, 2048), Parsed = uri_string:parse(Text),
    true = lists:member(maps:get(scheme, Parsed), [<<"http">>, <<"https">>]),
    true = byte_size(maps:get(host, Parsed)) > 0,
    true = lists:all(fun(Key) -> not maps:is_key(Key, Parsed) end, [userinfo, query, fragment]),
    Timeout = transit_sdk_value:integer(maps:get(timeout_ms, Options, 5000), 1, 60000),
    #transit_config{url = Text, profile = native_v1, timeout_ms = Timeout, native_host = maps:get(native_host, Options, undefined)}
end).
process(Realm, Pid) -> validate(fun() -> #transit_process{realm = transit_sdk_value:counter(Realm), pid = transit_sdk_value:counter(Pid)} end).
resource(Realm, Id) -> validate(fun() -> #transit_resource{realm = transit_sdk_value:counter(Realm), resource = transit_sdk_value:counter(Id)} end).
credential(Realm, Principal, SeedFile) -> validate(fun() ->
    #transit_credential{realm = transit_sdk_value:counter(Realm), principal = transit_sdk_value:counter(Principal, 0), seed_file = transit_sdk_value:text(SeedFile, 4096)}
end).
validate(Fun) ->
    try {ok, Fun()} catch throw:{transit_sdk, Error} -> {error, Error}; _:_ -> {error, transit_sdk_value:error(invalid_argument, configuration)} end.
open(Config) -> transit_sdk_worker:open(transit_client_impl, Config, false).
start_link(Config) -> transit_sdk_worker:start_link(transit_client_impl, Config).
child_spec(Config) -> #{id => ?MODULE, start => {?MODULE, start_link, [Config]}, restart => transient, shutdown => 70000, type => worker, modules => [transit_sdk_worker]}.
handle(Pid) -> transit_sdk_worker:handle(Pid).
close(Client) -> transit_sdk_worker:close(Client).
capabilities(Client, Credential) -> transit_sdk_worker:invoke(Client, {capabilities, Credential}).
prepare_send(Client, Peer, Value, Credential, Sequence) -> transit_sdk_worker:invoke(Client, {prepare_send, Peer, Value, Credential, Sequence}).
recover_send(Client, Bytes) -> transit_sdk_worker:invoke(Client, {recover, send, Bytes}).
recover_mutation(Client, Bytes) -> transit_sdk_worker:invoke(Client, {recover, mutation, Bytes}).
dispatch(Client, Pending) -> transit_sdk_worker:invoke(Client, {dispatch, send, Pending}).
dispatch_mutation(Client, Pending) -> transit_sdk_worker:invoke(Client, {dispatch, mutation, Pending}).
evidence(Client) -> transit_sdk_worker:invoke(Client, evidence).
export({transit_pending, _, _, Bytes}) -> Bytes.
info({transit_pending, _, Info, _}) -> Info.
