%% Public Station runner. Every mutation is gated before shared native dispatch.
-module(transit_station_sdk).
-include("transit_station_sdk.hrl").
-export([open/6, start_link/6, child_spec/6, handle/1, next/1, reconcile/1, evidence/1,
         stop/1, close/1, encode_cast/2, encode_cast/3]).
-export_type([runner/0, recovery/0]).
-opaque runner() :: transit_sdk_worker:handle().
-type recovery() :: fresh_ownership | {persist_before_dispatch, module(), term()}.
-spec open(#transit_service{}, module(), term(), module(), stop | block_input, recovery()) -> {ok, runner()} | {error, #transit_error{}}.
open(Service, Handler, Initial, Codec, Failure, Recovery) -> transit_sdk_worker:open(transit_station_runner, {Service, Handler, Initial, Codec, Failure, Recovery}, false).
start_link(Service, Handler, Initial, Codec, Failure, Recovery) -> transit_sdk_worker:start_link(transit_station_runner, {Service, Handler, Initial, Codec, Failure, Recovery}).
child_spec(Service, Handler, Initial, Codec, Failure, Recovery) ->
    #{id => ?MODULE, start => {?MODULE, start_link, [Service, Handler, Initial, Codec, Failure, Recovery]},
      restart => temporary, shutdown => 70000, type => worker, modules => [transit_sdk_worker]}.
handle(Pid) -> transit_sdk_worker:handle(Pid).
next(Runner) -> transit_sdk_worker:invoke(Runner, next).
reconcile(Runner) -> transit_sdk_worker:invoke(Runner, reconcile).
evidence(Runner) -> transit_sdk_worker:invoke(Runner, evidence).
stop(Runner) -> transit_sdk_worker:stop(Runner).
close(Runner) -> transit_sdk_worker:close(Runner).
encode_cast(Value, Codec) -> encode_cast(Value, Codec, undefined).
encode_cast(Value, Codec, Override) ->
    case transit_sdk_worker:open(transit_station_runner, {local, Override}, false) of
        {ok, Worker} ->
            Result = transit_sdk_worker:invoke(Worker, {encode_cast, Value, Codec}),
            case transit_sdk_worker:close(Worker) of {ok, _} -> Result; {error, Error, _} -> {error, Error}; Error -> Error end;
        Error -> Error
    end.
