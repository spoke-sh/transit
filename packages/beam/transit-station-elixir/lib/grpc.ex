defmodule Transit.Station.Sdk.Grpc.Method do
  @enforce_keys [:path, :shape, :descriptor_digest]
  defstruct [:path, :shape, :descriptor_digest]
end

defmodule Transit.Station.Sdk.Grpc.Request do
  @enforce_keys [:method]
  @derive {Inspect, only: [:method]}
  defstruct [:method, metadata: []]
end

defmodule Transit.Station.Sdk.Grpc.Prepared do
  @enforce_keys [:resource, :namespace, :reference, :metadata, :batch]
  @derive {Inspect, only: [:resource, :namespace]}
  defstruct [:resource, :namespace, :reference, :metadata, :batch]
end

defmodule Transit.Station.Sdk.Grpc.Outcome do
  @enforce_keys [:phase, :resource, :exchange, :effect, :attempt]
  defstruct [:phase, :resource, :exchange, :effect, :attempt, :status, :reference]
end

defmodule Transit.Station.Sdk.Grpc.Rejected do
  @enforce_keys [:reason]
  defstruct [:reason]
end

defmodule Transit.Station.Sdk.Grpc.Part do
  @enforce_keys [:kind, :data, :complete]
  @derive {Inspect, only: [:kind, :complete]}
  defstruct [:kind, :data, :complete]
end

defmodule Transit.Station.Sdk.Grpc.Released do
  @enforce_keys [:resource, :exchange]
  defstruct [:resource, :exchange]
end

defmodule Transit.Station.Sdk.Grpc.Reader do
  @enforce_keys [:native]
  @derive {Inspect, only: []}
  defstruct [:native]

  def read(%__MODULE__{native: native}) do
    case :transit_grpc.read(native) do
      {:ok, {part, next}} ->
        {:ok, {Transit.Station.Sdk.Grpc.convert(part), %__MODULE__{native: next}}}

      error ->
        Transit.Client.convert(error)
    end
  end

  def complete?(%__MODULE__{native: native}), do: :transit_grpc.complete(native)
  def close(%__MODULE__{native: native}), do: Transit.Client.convert(:transit_grpc.close(native))
end

defmodule Transit.Station.Sdk.Grpc do
  alias Transit.Client
  alias Transit.Station.Sdk.{Runner, Turn, Value}
  alias __MODULE__.{Method, Request, Prepared, Outcome, Rejected, Released, Part, Reader}

  def literal(value), do: {:literal, value}
  def secret(binding, version), do: {:secret, binding, version}

  def method(descriptor, path, native_host \\ nil) do
    with :ok <- Runner.compatible() do
      result(:transit_grpc.method(descriptor, path, Value.optional(native_host)))
    end
  end

  def prepare(
        resource,
        namespace,
        %Request{method: %Method{} = method} = request,
        messages,
        options
      ) do
    with :ok <- Runner.compatible() do
      result(
        :transit_grpc.prepare(
          Client.native(resource),
          namespace,
          {:transit_grpc_request,
           {:transit_grpc_method, method.path, method.shape, method.descriptor_digest},
           request.metadata},
          messages,
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
      result(:transit_grpc.decode_reply(realm, bytes, Value.optional(native_host)))
    end
  end

  def stage(%Turn{native: turn}, %Prepared{} = request),
    do: Client.convert(:transit_grpc.stage(turn, prepared(request)))

  def call(%Turn{native: turn}, peer, %Prepared{} = request),
    do: Client.convert(:transit_grpc.call(turn, Client.native(peer), prepared(request)))

  def release(%Turn{native: turn}, peer, resource, exchange),
    do:
      Client.convert(
        :transit_grpc.release(turn, Client.native(peer), Client.native(resource), exchange)
      )

  def open(runner, %Outcome{} = outcome, policy \\ :captured) do
    case :transit_grpc.open(runner, outcome(outcome), policy) do
      {:ok, reader} -> {:ok, %Reader{native: reader}}
      error -> Client.convert(error)
    end
  end

  def retry(%Turn{native: turn}, peer, %Outcome{} = parent, %Prepared{} = request),
    do:
      Client.convert(
        :transit_grpc.retry(
          turn,
          Client.native(peer),
          outcome(parent),
          prepared(request)
        )
      )

  defp outcome(%Outcome{} = value),
    do:
      {:transit_grpc_outcome, value.phase, Client.native(value.resource), value.exchange,
       value.effect, value.attempt, Value.optional(value.status), Value.optional(value.reference)}

  defp prepared(%Prepared{} = value),
    do:
      {:transit_grpc_prepared, Client.native(value.resource), value.namespace, value.reference,
       value.metadata, value.batch}

  defp result({:ok, value}), do: {:ok, convert(value)}
  defp result(error), do: Client.convert(error)

  def convert({:transit_grpc_method, path, shape, digest}),
    do: %Method{path: path, shape: shape, descriptor_digest: digest}

  @doc false
  def convert({:transit_grpc_prepared, resource, namespace, reference, metadata, batch}),
    do: %Prepared{
      resource: Client.convert(resource),
      namespace: namespace,
      reference: reference,
      metadata: metadata,
      batch: batch
    }

  def convert(
        {:transit_grpc_outcome, phase, resource, exchange, effect, attempt, status, reference}
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

  def convert({:transit_grpc_rejected, reason}), do: %Rejected{reason: reason}

  def convert({:transit_grpc_released, resource, exchange}),
    do: %Released{resource: Client.convert(resource), exchange: exchange}

  def convert({:transit_grpc_part, kind, data, complete}),
    do: %Part{kind: kind, data: data, complete: complete}

  def convert(:done), do: :done
end
