defmodule Transit.Station.Sdk.Codec do
  @callback type_id() :: binary()
  @callback version() :: pos_integer()
  @callback max_encoded_bytes() :: pos_integer()
  @callback encode(term()) :: {:ok, binary()} | {:error, term()}
  @callback decode(binary()) :: {:ok, term()} | {:error, term()}
end

defmodule Transit.Station.Sdk.Handler do
  @callback initialize(Transit.Station.Sdk.Turn.t(), term()) :: {:ok, term()} | {:error, term()}
  @callback handle_message(Transit.Station.Sdk.Turn.t(), Transit.Station.Sdk.Incoming.t(), term()) ::
              {:ok, term()} | {:error, term()}
  @callback handle_control(Transit.Station.Sdk.Turn.t(), Transit.Station.Sdk.Control.t(), term()) ::
              {:ok, term()} | {:error, term()}
  @callback handle_result(
              Transit.Station.Sdk.Turn.t(),
              Transit.Station.Sdk.ResultComplete.t(),
              term()
            ) :: {:ok, term()} | {:error, term()}
  @optional_callbacks initialize: 2, handle_control: 3, handle_result: 3
end

defmodule Transit.Station.Sdk.RecoveryStore do
  @callback before_dispatch(Transit.Station.Sdk.FrozenMutation.t(), term()) ::
              :ok | {:error, term()}
  @callback confirmed(Transit.Client.Identity.t(), Transit.Client.MutationReceipt.t(), term()) ::
              :ok | {:error, term()}
end

defmodule Transit.Station.Sdk.HandlerAdapter do
  @moduledoc false
  alias Transit.Station.Sdk.Value

  def initialize(turn, {handler, state}) do
    if function_exported?(handler, :initialize, 2) do
      wrap(handler, handler.initialize(Value.convert(turn), state))
    else
      {:ok, {handler, state}}
    end
  end

  def handle_message(turn, input, {handler, state}),
    do: wrap(handler, handler.handle_message(Value.convert(turn), Value.convert(input), state))

  def handle_control(turn, input, {handler, state}),
    do: wrap(handler, handler.handle_control(Value.convert(turn), Value.convert(input), state))

  def handle_result(turn, input, {handler, state}),
    do: wrap(handler, handler.handle_result(Value.convert(turn), Value.convert(input), state))

  defp wrap(handler, {:ok, state}), do: {:ok, {handler, state}}
  defp wrap(_, result), do: result
end

defmodule Transit.Station.Sdk.RecoveryAdapter do
  @moduledoc false
  def before_dispatch(mutation, {store, options}),
    do: store.before_dispatch(Transit.Station.Sdk.Value.convert(mutation), options)

  def confirmed(identity, receipt, {store, options}),
    do:
      store.confirmed(Transit.Client.convert(identity), Transit.Client.convert(receipt), options)
end

defmodule Transit.Station.Sdk.Runner do
  alias Transit.Station.Sdk.{Value, HandlerAdapter, RecoveryAdapter}

  def open(service, handler, initial, codec, options) do
    with :ok <- compatible(),
         :ok <- handler(handler),
         {:ok, recovery} <- recovery(Keyword.fetch!(options, :recovery)) do
      Value.result(
        :transit_station_sdk.open(
          Value.native(service),
          HandlerAdapter,
          {handler, initial},
          codec,
          Keyword.fetch!(options, :failure_policy),
          recovery
        )
      )
    end
  end

  def start_link({service, handler, initial, codec, options}) do
    with :ok <- compatible(),
         :ok <- handler(handler),
         {:ok, recovery} <- recovery(Keyword.fetch!(options, :recovery)) do
      :transit_station_sdk.start_link(
        Value.native(service),
        HandlerAdapter,
        {handler, initial},
        codec,
        Keyword.fetch!(options, :failure_policy),
        recovery
      )
    end
  end

  def child_spec(args),
    do: %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [args]},
      restart: :temporary,
      shutdown: 70_000,
      type: :worker
    }

  def handle(pid), do: Value.result(:transit_station_sdk.handle(pid))
  def next(runner), do: Value.result(:transit_station_sdk.next(runner))
  def reconcile(runner), do: Value.result(:transit_station_sdk.reconcile(runner))
  def evidence(runner), do: Value.result(:transit_station_sdk.evidence(runner))
  def stop(runner), do: :transit_station_sdk.stop(runner)
  def close(runner), do: Value.result(:transit_station_sdk.close(runner))

  defp handler(handler) do
    with {:module, ^handler} <- Code.ensure_loaded(handler),
         true <- function_exported?(handler, :handle_message, 3) do
      :ok
    else
      _ -> {:error, %Transit.Client.Error{kind: :handler, phase: :handler_contract}}
    end
  end

  defp recovery(:fresh_ownership), do: {:ok, :fresh_ownership}

  defp recovery({:persist_before_dispatch, store, options}) do
    with {:module, ^store} <- Code.ensure_loaded(store),
         true <- function_exported?(store, :before_dispatch, 2),
         true <- function_exported?(store, :confirmed, 3) do
      {:ok, {:persist_before_dispatch, RecoveryAdapter, {store, options}}}
    else
      _ -> {:error, %Transit.Client.Error{kind: :handler, phase: :recovery_contract}}
    end
  end

  defp recovery(_),
    do: {:error, %Transit.Client.Error{kind: :invalid_argument, phase: :recovery_policy}}

  @doc false
  def compatible do
    :application.load(:transit_station_sdk)

    case :application.get_key(:transit_station_sdk, :vsn) do
      {:ok, ~c"0.2.0"} ->
        :ok

      _ ->
        {:error, %Transit.Client.Error{kind: :incompatible_native, phase: :station_sdk_version}}
    end
  end
end

defmodule Transit.Station.Sdk do
  alias Transit.Station.Sdk.{Runner, Value}

  def encode_cast(value, codec, native_host \\ nil) do
    with :ok <- Runner.compatible() do
      Value.result(:transit_station_sdk.encode_cast(value, codec, Value.optional(native_host)))
    end
  end

  def export(%Transit.Station.Sdk.FrozenMutation{bytes: bytes}), do: bytes
end
