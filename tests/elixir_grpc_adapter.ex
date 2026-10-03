defmodule ElixirGrpcAdapter do
  @behaviour Transit.Station.Sdk.Codec
  @behaviour Transit.Station.Sdk.Handler
  alias Transit.Client
  alias Transit.Station.Sdk.{Activation, Committed, Incoming, Runner, ServiceConfig, State, Turn}
  alias Transit.Station.Sdk.Grpc
  alias Transit.Station.Sdk.Grpc.{Outcome, Part, Reader, Rejected, Released, Request}
  alias Transit.SdkExamples.U64Codec

  def replay_error, do: "GrpcReplayFailed"
  def type_id, do: "test.grpc-control"
  def version, do: 1
  def max_encoded_bytes, do: 243
  def encode(bytes), do: {:ok, bytes}
  def decode(bytes), do: {:ok, bytes}

  def prepare(cfg) do
    {:ok, method} =
      Grpc.method(Base.decode16!(cfg["descriptor"], case: :mixed), "/test.Peer/Bidi")

    :bidi = method.shape

    request = %Request{
      method: method,
      metadata: [
        {"x-tag", Grpc.literal("one")},
        {"x-tag", Grpc.literal("two")},
        {"x-data-bin", Grpc.literal(<<0, 255>>)},
        {"authorization", Grpc.secret("api", 7)}
      ]
    }

    Grpc.prepare(
      %Client.ResourceRef{realm: 72, resource: cfg["resource"]},
      18_446_744_073_709_551_615,
      request,
      [Base.decode16!(cfg["body"], case: :mixed), <<>>],
      endpoint_revision: 7,
      reconcile_before_ms: cfg["deadline"]
    )
  end

  def open(cfg, shared, request) do
    {:ok, client} = Client.config(cfg["url"], :native_v1)

    service = %ServiceConfig{
      client: client,
      activation: %Activation{
        process: %Client.ProcessRef{realm: 72, pid: cfg["pid"]},
        generation: cfg["generation"],
        credential: %Client.Credential{
          realm: 72,
          principal: cfg["principal"],
          seed_file: cfg["seed_file"]
        }
      }
    }

    peer = %Client.ProcessRef{realm: 72, pid: cfg["peer"]}

    disposal =
      if cfg["outcome"] do
        {:ok, value} = Grpc.decode_reply(72, Base.decode16!(cfg["outcome"], case: :mixed))
        value
      end

    Runner.open(service, __MODULE__, {shared, peer, request, disposal}, __MODULE__,
      failure_policy: :stop,
      recovery: :fresh_ownership
    )
  end

  def handle_message(turn, input, {shared, peer, request, disposal} = context) do
    :beam_exchange_controller.put(shared, :escaped, turn)
    {:ok, state} = Turn.state(turn)
    {:ok, key} = Turn.key("grpc-correlation", U64Codec)
    {:ok, release_key} = Turn.key("grpc-release-correlation", U64Codec)
    {:ok, followup_key} = Turn.key("grpc-followup-correlation", U64Codec)

    result =
      case input do
        %Incoming{kind: :cast, value: "followup"} ->
          wrong = %{disposal | resource: %{disposal.resource | realm: 73}}

          {:error, %Client.Error{kind: :invalid_argument}} =
            Grpc.retry(turn, peer, wrong, request)

          {:ok, correlation} = Grpc.retry(turn, peer, disposal, request)
          {:ok, :ok} = State.put(state, followup_key, correlation)
          %{followup: false}

        %Incoming{kind: :cast, value: "dispose"} ->
          {:error, %Client.Error{kind: :invalid_argument}} =
            Grpc.release(turn, peer, %{disposal.resource | realm: 73}, disposal.exchange)

          {:ok, correlation} = Grpc.release(turn, peer, disposal.resource, disposal.exchange)
          {:ok, :ok} = State.put(state, release_key, correlation)
          %{released: false}

        %Incoming{kind: :cast} ->
          called =
            case State.find(state, key) do
              {:ok, {:found, _}} ->
                true

              {:ok, :missing} ->
                {:ok, ready} = Grpc.stage(turn, request)

                if ready do
                  {:ok, correlation} = Grpc.call(turn, peer, request)
                  {:ok, :ok} = State.put(state, key, correlation)
                end

                ready
            end

          %{called: called}

        %Incoming{kind: :reply, value: <<"GRF1", _::binary>> = bytes} ->
          {:ok, correlation} = State.require(state, followup_key)
          {:ok, :ok} = Turn.require_reply(turn, input, peer, correlation)

          {:ok, %Rejected{reason: :denied, diagnostic: %{"code" => "grpc.request_denied"}}} =
            Grpc.decode_reply(72, bytes)

          {:ok, denied} = Turn.key("grpc-followup-denied", U64Codec)
          {:ok, :ok} = State.put(state, denied, correlation)
          %{followup: true}

        %Incoming{kind: :reply, value: <<"GRK1", _::binary>> = bytes} ->
          {:ok, correlation} = State.require(state, release_key)
          {:ok, :ok} = Turn.require_reply(turn, input, peer, correlation)
          {:ok, %Released{} = released} = Grpc.decode_reply(72, bytes)
          true = released.resource == disposal.resource && released.exchange == disposal.exchange
          {:ok, disposed} = Turn.key("grpc-disposed", U64Codec)
          {:ok, :ok} = State.put(state, disposed, released.exchange)
          %{released: true}

        %Incoming{kind: :reply, value: bytes} ->
          {:ok, correlation} = State.require(state, key)
          {:ok, :ok} = Turn.require_reply(turn, input, peer, correlation)
          {:ok, %Outcome{phase: :observed, status: 0}} = Grpc.decode_reply(72, bytes)
          {:ok, status} = Turn.key("grpc-status", U64Codec)
          {:ok, :ok} = State.put(state, status, 0)
          %{observed: true}
      end

    :beam_exchange_controller.put(shared, :result, result)
    {:ok, context}
  end

  def next(runner), do: Runner.next(runner)
  def close(runner), do: Runner.close(runner)
  def stop(runner), do: Runner.stop(runner)
  def stage(turn, request), do: Grpc.stage(turn, request)

  def release_expired(turn),
    do:
      Grpc.release(
        turn,
        %Client.ProcessRef{realm: 72, pid: 1},
        %Client.ResourceRef{realm: 72, resource: 1},
        1
      )

  def open_capture(runner, outcome), do: Grpc.open(runner, outcome)

  def followup_expired(turn, request),
    do:
      Grpc.retry(
        turn,
        %Client.ProcessRef{realm: 72, pid: 1},
        %Outcome{
          phase: :closed_unknown,
          resource: %Client.ResourceRef{realm: 72, resource: 1},
          exchange: 1,
          effect: 1,
          attempt: 1
        },
        request
      )

  def outcome(bytes), do: Grpc.decode_reply(72, bytes)

  def read(reader) do
    case Reader.read(reader) do
      {:ok, {%Part{kind: kind, data: data, complete: complete}, next}} ->
        {:ok, {%{kind: kind, bytes: data, complete: complete}, next}}

      other ->
        other
    end
  end

  def close_capture(reader), do: Reader.close(reader)
  def complete(reader), do: Reader.complete?(reader)
  def view(%Client.Error{} = error), do: Map.from_struct(error)
  def event(%Committed{}), do: :committed
  def event(event), do: event

  def golden(fixture) do
    bytes = Base.decode16!(fixture["outcome_ok_hex"], case: :mixed)

    {:ok,
     %Outcome{
       phase: :observed,
       status: 0,
       exchange: 18_446_744_073_709_551_615,
       reference: ref,
       diagnostic: %{"code" => "grpc.ok_observed", "outcome" => "completed"}
     }} =
      Grpc.decode_reply(72, bytes)

    true = is_binary(ref)

    {:ok, %Outcome{phase: :closed_unknown, status: nil, reference: nil}} =
      Grpc.decode_reply(72, Base.decode16!(fixture["outcome_unknown_hex"], case: :mixed))

    {:ok, %Rejected{reason: :denied, diagnostic: %{"code" => "grpc.request_denied"}}} =
      Grpc.decode_reply(72, Base.decode16!(fixture["rejection_hex"], case: :mixed))

    {:ok,
     %Released{
       resource: %Client.ResourceRef{realm: 72, resource: 7},
       exchange: 18_446_744_073_709_551_615
     }} = Grpc.decode_reply(72, Base.decode16!(fixture["released_hex"], case: :mixed))

    {:error, _} = Grpc.decode_reply(72, binary_part(bytes, 0, 72))
    :ok
  end
end
