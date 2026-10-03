defmodule ElixirHttpAdapter do
  @behaviour Transit.Station.Sdk.Codec
  @behaviour Transit.Station.Sdk.Handler
  alias Transit.Client
  alias Transit.Station.Sdk.{Activation, Committed, Incoming, Runner, ServiceConfig, State, Turn}
  alias Transit.Station.Sdk.Http
  alias Transit.Station.Sdk.Http.{Outcome, Part, Prepared, Reader, Rejected, Released, Request}
  alias Transit.SdkExamples.U64Codec

  def replay_error, do: "HttpReplayFailed"
  def type_id, do: "test.http-control"
  def version, do: 1
  def max_encoded_bytes, do: 243
  def encode(bytes), do: {:ok, bytes}
  def decode(bytes), do: {:ok, bytes}

  def prepare(cfg) do
    request = %Request{
      method: :post,
      target: [Http.literal("/items/"), Http.variable("id", "λ /")],
      headers: [
        {"X-Tag", [Http.literal("one")]},
        {"X-Tag", [Http.literal("two")]},
        {"Authorization", [Http.literal("Bearer "), Http.secret("api", 7)]}
      ]
    }

    Http.prepare(
      %Client.ResourceRef{realm: 72, resource: cfg["resource"]},
      18_446_744_073_709_551_615,
      request,
      Base.decode16!(cfg["body"], case: :mixed),
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
        {:ok, value} = Http.decode_reply(72, Base.decode16!(cfg["outcome"], case: :mixed))
        value
      end

    reason =
      Map.fetch!(
        %{
          "retry" => :retry,
          "redirect" => :redirect,
          "reconcile" => :reconcile,
          "cancel" => :cancel
        },
        cfg["followup_reason"] || "retry"
      )

    Runner.open(service, __MODULE__, {shared, peer, request, disposal, reason}, __MODULE__,
      failure_policy: :stop,
      recovery: :fresh_ownership
    )
  end

  def handle_message(turn, input, {shared, peer, request, disposal, reason} = context) do
    :beam_exchange_controller.put(shared, :escaped, turn)
    {:ok, state} = Turn.state(turn)
    {:ok, key} = Turn.key("http-correlation", U64Codec)
    {:ok, release_key} = Turn.key("http-release-correlation", U64Codec)
    {:ok, followup_key} = Turn.key("http-followup-correlation", U64Codec)

    result =
      case input do
        %Incoming{kind: :cast, value: "followup"} ->
          wrong = %{disposal | resource: %{disposal.resource | realm: 73}}

          {:error, %Client.Error{kind: :invalid_argument}} =
            Http.followup(turn, peer, wrong, reason, request)

          {:error, %Client.Error{kind: :invalid_argument}} =
            Http.followup(turn, peer, disposal, :automatic, request)

          {:ok, correlation} = Http.followup(turn, peer, disposal, reason, request)
          {:ok, :ok} = State.put(state, followup_key, correlation)
          %{followup: false}

        %Incoming{kind: :cast, value: "dispose"} ->
          {:error, %Client.Error{kind: :invalid_argument}} =
            Http.release(turn, peer, %{disposal.resource | realm: 73}, disposal.exchange)

          {:ok, correlation} = Http.release(turn, peer, disposal.resource, disposal.exchange)
          {:ok, :ok} = State.put(state, release_key, correlation)
          %{released: false}

        %Incoming{kind: :cast} ->
          called =
            case State.find(state, key) do
              {:ok, {:found, _}} ->
                true

              {:ok, :missing} ->
                {:ok, ready} = Http.stage(turn, request)

                if ready do
                  {:ok, correlation} = Http.call(turn, peer, request)
                  {:ok, :ok} = State.put(state, key, correlation)
                end

                ready
            end

          %{called: called}

        %Incoming{kind: :reply, value: <<"HTF1", _::binary>> = bytes} ->
          {:ok, correlation} = State.require(state, followup_key)
          {:ok, :ok} = Turn.require_reply(turn, input, peer, correlation)

          {:ok, %Rejected{reason: :denied, diagnostic: detail}} =
            Http.decode_reply(72, bytes)

          facts = Map.new(Enum.filter(detail["facts"], &is_map/1), &{&1["field"], &1})
          "provided" = facts["field_path"]["availability"]
          true = String.to_integer(facts["native_input"]["value"]["unsigned"]) > 0
          32 = length(facts["proposal"]["value"]["digest"])

          {:ok, denied} = Turn.key("http-followup-denied", U64Codec)
          {:ok, :ok} = State.put(state, denied, correlation)
          %{followup: true}

        %Incoming{kind: :reply, value: <<"HTK1", _::binary>> = bytes} ->
          {:ok, correlation} = State.require(state, release_key)
          {:ok, :ok} = Turn.require_reply(turn, input, peer, correlation)
          {:ok, %Released{} = released} = Http.decode_reply(72, bytes)
          true = released.resource == disposal.resource && released.exchange == disposal.exchange
          {:ok, disposed} = Turn.key("http-disposed", U64Codec)
          {:ok, :ok} = State.put(state, disposed, released.exchange)
          %{released: true}

        %Incoming{kind: :reply, value: bytes} ->
          {:ok, correlation} = State.require(state, key)
          {:ok, :ok} = Turn.require_reply(turn, input, peer, correlation)
          {:ok, %Outcome{phase: :observed, status: 200}} = Http.decode_reply(72, bytes)
          {:ok, status} = Turn.key("http-status", U64Codec)
          {:ok, :ok} = State.put(state, status, 200)
          %{observed: true}
      end

    :beam_exchange_controller.put(shared, :result, result)
    {:ok, context}
  end

  def next(runner), do: Runner.next(runner)
  def close(runner), do: Runner.close(runner)
  def stop(runner), do: Runner.stop(runner)
  def stage(turn, request), do: Http.stage(turn, request)

  def release_expired(turn),
    do:
      Http.release(
        turn,
        %Client.ProcessRef{realm: 72, pid: 1},
        %Client.ResourceRef{realm: 72, resource: 1},
        1
      )

  def open_capture(runner, outcome), do: Http.open(runner, outcome)

  def followup_expired(turn, request),
    do:
      Http.followup(
        turn,
        %Client.ProcessRef{realm: 72, pid: 1},
        %Outcome{
          phase: :closed_unknown,
          resource: %Client.ResourceRef{realm: 72, resource: 1},
          exchange: 1,
          effect: 1,
          attempt: 1
        },
        :retry,
        request
      )

  def outcome(bytes), do: Http.decode_reply(72, bytes)

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
    resource = %Client.ResourceRef{realm: 72, resource: 8}

    {:ok, %Prepared{} = prepared} =
      Http.prepare(
        resource,
        18_446_744_073_709_551_615,
        %Request{method: :post, target: [Http.literal("/write")]},
        Base.decode16!(fixture["body"], case: :mixed),
        endpoint_revision: 7,
        reconcile_before_ms: 9000,
        max_attempts: 2
      )

    true = Base.encode16(prepared.reference, case: :lower) == fixture["reference"]
    true = prepared.metadata == fixture["metadata"]
    bytes = Base.decode16!(fixture["outcome"], case: :mixed)

    {:ok,
     %Outcome{
       phase: :observed,
       status: 200,
       exchange: 18_446_744_073_709_551_615,
       reference: ref,
       diagnostic: %{"code" => "http.response_observed", "outcome" => "completed"}
     }} =
      Http.decode_reply(72, bytes)

    true = is_binary(ref)

    {:ok, %Rejected{reason: :denied, diagnostic: %{"code" => "http.request_denied"}}} =
      Http.decode_reply(72, Base.decode16!(fixture["rejection"], case: :mixed))

    {:error, _} = Http.decode_reply(72, binary_part(bytes, 0, 70))
    released = Base.decode16!(fixture["released"], case: :mixed)

    {:ok,
     %Released{
       resource: %Client.ResourceRef{realm: 72, resource: 7},
       exchange: 18_446_744_073_709_551_615
     }} = Http.decode_reply(72, released)

    {:error, _} = Http.decode_reply(72, binary_part(released, 0, 19))

    {:error, _} =
      Http.prepare(
        resource,
        1,
        %Request{method: :get, target: [Http.literal("//other/")]},
        <<>>,
        endpoint_revision: 1,
        reconcile_before_ms: 9000
      )

    :ok
  end
end
