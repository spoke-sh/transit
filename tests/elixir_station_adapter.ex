defmodule ElixirStationAdapter do
  @behaviour Transit.Station.Sdk.Handler
  @behaviour Transit.Station.Sdk.RecoveryStore
  alias Transit.Client
  alias Transit.Station.Sdk
  alias Transit.Station.Sdk.{Runner, Turn, State, Source, Table, Query, ResultReader}
  alias Transit.SdkExamples, as: E
  alias :beam_station_controller, as: Proof

  def open(c, s) do
    {:ok, client} = Client.config(c["url"], :native_v1)
    {:ok, process} = Client.process(c["realm"], c["pid"])
    {:ok, credential} = Client.credential(c["realm"], c["principal"], c["seed_file"])

    service = %Sdk.ServiceConfig{
      client: client,
      activation: %Sdk.Activation{
        process: process,
        generation: c["generation"],
        credential: credential
      },
      query_results: c["query_results"]
    }

    codec =
      case c["role"] do
        "service" -> E.CounterCodec
        "requester" -> E.RequesterCodec
        "table" -> E.QueryServiceCodec
        "query" -> E.QueryRequesterCodec
      end

    failure = if String.ends_with?(Proof.get(s, :mode), "-block"), do: :block_input, else: :stop

    Runner.open(service, __MODULE__, s, codec,
      failure_policy: failure,
      recovery: {:persist_before_dispatch, __MODULE__, s}
    )
  end

  def next(r), do: Runner.next(r)
  def reconcile(r), do: Runner.reconcile(r)
  def close(r), do: Runner.close(r)
  def stop(r), do: Runner.stop(r)
  def view(%Sdk.Committed{} = v), do: Map.put(fields(v), :kind, :committed)
  def view(%Sdk.Blocked{} = v), do: Map.put(fields(v), :kind, :blocked)
  def view(%Sdk.NeedsRecovery{} = v), do: Map.put(fields(v), :kind, :needs_recovery)
  def view(v), do: fields(v)

  defp fields(v),
    do: Map.new(Map.from_struct(v), fn {k, v} -> {k, if(v == nil, do: :undefined, else: v)} end)

  @impl true
  def initialize(t, s), do: Proof.initialize(__MODULE__, t, s)
  @impl true
  def handle_message(t, i, s), do: Proof.handle_message(__MODULE__, t, i, s)
  @impl true
  def handle_result(t, i, s), do: Proof.handle_result(__MODULE__, t, i, s)
  @impl true
  def before_dispatch(m, s), do: Proof.before_dispatch(__MODULE__, m, s)
  @impl true
  def confirmed(i, r, s), do: Proof.confirmed(__MODULE__, i, r, s)

  defp context(s) do
    c = Proof.get(s, :config)
    {:ok, peer} = Client.process(c["realm"], c["peer"])

    %{
      peer: peer,
      consume: fn segment ->
        Proof.put(s, {:segment, segment.ordinal}, segment)
        :ok
      end
    }
  end

  defp base("service"), do: E.Counter
  defp base("requester"), do: E.Requester
  defp base("table"), do: E.TableService
  defp base("query"), do: E.QueryRequester

  def example_initialize(role, t, s) do
    m = base(role)
    Code.ensure_loaded!(m)

    if function_exported?(m, :initialize, 2),
      do: {:ok, _} = apply(m, :initialize, [t, context(s)])

    {:ok, s}
  end

  def example_message(role, t, i, s) do
    {:ok, _} = base(role).handle_message(t, i, context(s))
    {:ok, s}
  end

  def example_result(t, i, s) do
    {:ok, _} = E.QueryRequester.handle_result(t, i, context(s))
    {:ok, s}
  end

  def input_variant(%Sdk.Incoming{kind: :cast, value: %E.Rows{}}), do: :rows
  def input_variant(%Sdk.Incoming{kind: :cast, value: %E.Initialize{}}), do: :initialize
  def input_variant(_), do: :other
  def budgets(t), do: Turn.budgets(t)
  def state(t), do: Turn.state(t)
  def key(:total), do: E.Keys.total()
  def require(s, k), do: State.require(s, k)
  def put(s, k, v), do: State.put(s, k, v)

  def require_reentrant(s),
    do: State.require(s, %Sdk.Key{name: "total", codec: ElixirStationReentrant})

  def table(t), do: Table.open(t, 1)
  def basis(t), do: Table.basis(t)
  def table_get(t, k), do: Table.get_key(t, [E.Keys.signed(k)])
  def table_page(t, :undefined), do: Table.page(t)
  def table_page(t, c), do: Table.page(t, c)
  def retain(t), do: Turn.retain(t)
  def open_version(t, v), do: Turn.open_version(t, v)
  def version(v), do: %Sdk.ReadVersion{pid: v["pid"], input: v["input"], index: v["index"]}
  def source_state(s), do: Source.state(s)
  def source_table(s), do: Source.table(s, 1)
  def state_page(s), do: State.page(s)
  def release(t, v), do: Turn.release(t, v)
  def result(t, c), do: Query.result(t, c)
  def manifest(r), do: ResultReader.manifest(r)
  def segment(r, i), do: ResultReader.segment(r, i)

  def recover(c) do
    {:ok, config} = Client.config(c["url"], :native_v1)
    {:ok, client} = Client.open(config)
    {:ok, pending} = Client.recover_mutation(client, File.read!(c["pending"]))
    {:confirmed, _} = Client.dispatch_mutation(client, pending)
    {:ok, _} = Client.close(client)
  end

  def codecs(c) do
    fixtures = Proof.read(c["fixtures"])

    for f <- fixtures["valid"] do
      codec = String.to_existing_atom(f["codec"])
      bytes = Base.decode16!(f["hex"], case: :lower)
      value = fixture(f)
      {:ok, ^bytes} = E.Codec.encode(codec, value)
      {:ok, ^value} = E.Codec.decode(codec, bytes)
    end

    for f <- fixtures["invalid"] do
      {:error, _} =
        E.Codec.decode(
          String.to_existing_atom(f["codec"]),
          Base.decode16!(f["hex"], case: :lower)
        )
    end

    table_fixtures = Proof.read(c["table_fixtures"])

    for f <- table_fixtures["valid"] do
      codec = table_codec(f["codec"])
      bytes = Base.decode16!(f["hex"], case: :lower)
      {:ok, value} = E.TableWork.decode(codec, bytes)
      {:ok, ^bytes} = E.TableWork.encode(codec, value)
    end

    for f <- table_fixtures["invalid"] do
      {:error, _} =
        E.TableWork.decode(table_codec(f["codec"]), Base.decode16!(f["hex"], case: :lower))
    end

    {:ok, <<"STN1", 1, 0::little-64, "TSC", 1, 1, 18_446_744_073_709_551_615::little-64>>} =
      Sdk.encode_cast(%E.Add{value: 18_446_744_073_709_551_615}, E.CounterCodec)

    {:error, %Client.Error{kind: :incompatible_native}} =
      Sdk.encode_cast(
        %E.Read{},
        E.CounterCodec,
        Path.join(Path.dirname(c["fixtures"]), "bad-station-version")
      )
  end

  defp table_codec("queue"), do: :queue
  defp table_codec("work"), do: :work
  defp table_codec("outcome"), do: :outcome

  defp fixture(%{"variant" => "Update", "key" => k} = f),
    do: %E.Update{
      key: String.to_integer(k),
      value: if(is_binary(f["value"]), do: String.to_integer(f["value"]))
    }

  defp fixture(%{"variant" => "Delete", "key" => k}), do: %E.Delete{key: String.to_integer(k)}
  defp fixture(%{"variant" => "Advance"}), do: %E.Advance{}
  defp fixture(%{"variant" => "NotReady"}), do: %E.NotReady{}
  defp fixture(%{"variant" => "Add", "value" => v}), do: %E.Add{value: String.to_integer(v)}
  defp fixture(%{"variant" => "Total", "value" => v}), do: %E.Total{value: String.to_integer(v)}
  defp fixture(%{"variant" => "U64", "value" => v}), do: String.to_integer(v)

  defp fixture(%{"variant" => "Insert", "key" => k} = f),
    do: %E.Insert{
      key: String.to_integer(k),
      value: if(is_binary(f["value"]), do: String.to_integer(f["value"]))
    }

  defp fixture(%{"variant" => "Read"}), do: %E.Read{}
  defp fixture(%{"variant" => "Start"}), do: %E.Start{}
  defp fixture(%{"variant" => "Rows"}), do: %E.Rows{}
  defp fixture(%{"variant" => "Initialize"}), do: %E.Initialize{}
end

defmodule ElixirStationReentrant do
  @behaviour Transit.Station.Sdk.Codec
  @impl true
  def type_id, do: "transit.examples.u64"
  @impl true
  def version, do: 1
  @impl true
  def max_encoded_bytes, do: 12
  @impl true
  def encode(v), do: Transit.SdkExamples.U64Codec.encode(v)
  @impl true
  def decode(bytes) do
    {a, t} = Process.get(:proof_turn)
    :ok = :beam_station_controller.expect(a, :busy, a.budgets(t))
    Transit.SdkExamples.U64Codec.decode(bytes)
  end
end
