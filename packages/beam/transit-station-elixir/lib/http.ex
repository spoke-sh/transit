defmodule Transit.Station.Sdk.Http.Request do
  @enforce_keys [:method, :target]
  @derive {Inspect, only: [:method]}
  defstruct [:method, :target, headers: []]
end

defmodule Transit.Station.Sdk.Http.Prepared do
  @enforce_keys [:resource, :namespace, :reference, :metadata, :body]
  @derive {Inspect, only: [:resource, :namespace]}
  defstruct [:resource, :namespace, :reference, :metadata, :body]
end

defmodule Transit.Station.Sdk.Http.Outcome do
  @enforce_keys [:phase, :resource, :exchange, :effect, :attempt]
  defstruct [:phase, :resource, :exchange, :effect, :attempt, :status, :reference]
end

defmodule Transit.Station.Sdk.Http.Rejected do
  @enforce_keys [:reason]
  defstruct [:reason]
end

defmodule Transit.Station.Sdk.Http.Part do
  @enforce_keys [:kind, :data, :complete]
  @derive {Inspect, only: [:kind, :complete]}
  defstruct [:kind, :data, :complete]
end

defmodule Transit.Station.Sdk.Http.Released do
  @enforce_keys [:resource, :exchange]
  defstruct [:resource, :exchange]
end

defmodule Transit.Station.Sdk.Http.Reader do
  @enforce_keys [:native]
  @derive {Inspect, only: []}
  defstruct [:native]

  def read(%__MODULE__{native: native}) do
    case :transit_http.read(native) do
      {:ok, {part, next}} ->
        {:ok, {Transit.Station.Sdk.Http.convert(part), %__MODULE__{native: next}}}

      error ->
        Transit.Client.convert(error)
    end
  end

  def complete?(%__MODULE__{native: native}), do: :transit_http.complete(native)
  def close(%__MODULE__{native: native}), do: Transit.Client.convert(:transit_http.close(native))
end

defmodule Transit.Station.Sdk.Http do
  alias Transit.Client
  alias Transit.Station.Sdk.{Runner, Turn, Value}
  alias __MODULE__.{Request, Prepared, Outcome, Rejected, Released, Part, Reader}

  def literal(value), do: {:literal, value}
  def variable(name, value), do: {:variable, name, value}
  def secret(binding, version), do: {:secret, binding, version}

  def prepare(resource, namespace, %Request{} = request, body, options) do
    with :ok <- Runner.compatible() do
      result(
        :transit_http.prepare(
          Client.native(resource),
          namespace,
          {:transit_http_request, request.method, request.target, request.headers},
          body,
          Map.new(
            Keyword.take(options, [:endpoint_revision, :reconcile_before_ms, :max_attempts])
          ),
          Value.optional(Keyword.get(options, :native_host))
        )
      )
    end
  end

  def decode_reply(realm, bytes, native_host \\ nil) do
    with :ok <- Runner.compatible() do
      result(:transit_http.decode_reply(realm, bytes, Value.optional(native_host)))
    end
  end

  def stage(%Turn{native: turn}, %Prepared{} = request),
    do: Client.convert(:transit_http.stage(turn, prepared(request)))

  def call(%Turn{native: turn}, peer, %Prepared{} = request),
    do: Client.convert(:transit_http.call(turn, Client.native(peer), prepared(request)))

  def release(%Turn{native: turn}, peer, resource, exchange),
    do:
      Client.convert(
        :transit_http.release(turn, Client.native(peer), Client.native(resource), exchange)
      )

  def open(runner, %Outcome{} = outcome, policy \\ :captured) do
    case :transit_http.open(runner, outcome(outcome), policy) do
      {:ok, reader} -> {:ok, %Reader{native: reader}}
      error -> Client.convert(error)
    end
  end

  def followup(%Turn{native: turn}, peer, %Outcome{} = parent, reason, %Prepared{} = request),
    do:
      Client.convert(
        :transit_http.followup(
          turn,
          Client.native(peer),
          outcome(parent),
          reason,
          prepared(request)
        )
      )

  defp outcome(%Outcome{} = value),
    do:
      {:transit_http_outcome, value.phase, Client.native(value.resource), value.exchange,
       value.effect, value.attempt, Value.optional(value.status), Value.optional(value.reference)}

  defp prepared(%Prepared{} = value),
    do:
      {:transit_http_prepared, Client.native(value.resource), value.namespace, value.reference,
       value.metadata, value.body}

  defp result({:ok, value}), do: {:ok, convert(value)}
  defp result(error), do: Client.convert(error)

  @doc false
  def convert({:transit_http_prepared, resource, namespace, reference, metadata, body}),
    do: %Prepared{
      resource: Client.convert(resource),
      namespace: namespace,
      reference: reference,
      metadata: metadata,
      body: body
    }

  def convert(
        {:transit_http_outcome, phase, resource, exchange, effect, attempt, status, reference}
      ),
      do: %Outcome{
        phase: phase,
        resource: Client.convert(resource),
        exchange: exchange,
        effect: effect,
        attempt: attempt,
        status: Value.convert(status),
        reference: Value.convert(reference)
      }

  def convert({:transit_http_rejected, reason}), do: %Rejected{reason: reason}

  def convert({:transit_http_released, resource, exchange}),
    do: %Released{resource: Client.convert(resource), exchange: exchange}

  def convert({:transit_http_part, kind, data, complete}),
    do: %Part{kind: kind, data: data, complete: complete}

  def convert(:done), do: :done
end
